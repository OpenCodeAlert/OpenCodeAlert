using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading.Tasks;

namespace OpenRA
{
	public class CopilotCommandServer
	{
		readonly Socket serverSocket = new(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
		readonly int port;
		readonly World world;
		bool isRunning;
		public const string CurrentApiVersion = "1.0";

		// 添加调试模式开关
		public bool DebugMode { get; set; } = false;

		// 统计记录器接口
		public interface IGameStatsRecorder
		{
			void RecordApiCall(string command, bool isQuery);
		}

		public IGameStatsRecorder StatsRecorder { get; set; }

		public delegate string CommandHandler(JObject json, World world);
		public delegate JObject QueryHandler(JObject json, World world);

		public Dictionary<string, CommandHandler> CommandHandlers = new();
		public Dictionary<string, QueryHandler> QueryHandlers = new();

		// 错误信息的多语言支持
		static readonly Dictionary<string, Dictionary<string, string>> ErrorMessages = new()
		{
			["INVALID_REQUEST"] = new()
			{
				["en"] = "Invalid JSON format",
				["zh"] = "无效的JSON格式"
			},
			["INVALID_VERSION"] = new()
			{
				["en"] = "Unsupported API version, current version: {0}",
				["zh"] = "不支持的API版本，当前版本: {0}"
			},
			["COMMAND_EXECUTION_ERROR"] = new()
			{
				["en"] = "Command execution failed",
				["zh"] = "命令执行失败"
			},
			["QUERY_EXECUTION_ERROR"] = new()
			{
				["en"] = "Query execution failed",
				["zh"] = "查询执行失败"
			},
			["INVALID_COMMAND"] = new()
			{
				["en"] = "Unknown command",
				["zh"] = "未知的命令"
			},
			["INTERNAL_ERROR"] = new()
			{
				["en"] = "Server internal error",
				["zh"] = "服务器内部错误"
			},

			// 新增参数验证相关的错误码
			["INVALID_PARAMS_MOVE_ACTOR"] = new()
			{
				["en"] = "Move command parameters cannot be empty",
				["zh"] = "移动命令参数不能为空"
			},
			["MISSING_TARGETS"] = new()
			{
				["en"] = "Missing targets parameter",
				["zh"] = "缺少targets参数"
			},
			["INVALID_PARAMS_ATTACK"] = new()
			{
				["en"] = "Attack command parameters cannot be empty",
				["zh"] = "攻击命令参数不能为空"
			},
			["MISSING_ATTACKERS_OR_TARGETS"] = new()
			{
				["en"] = "Missing attackers or targets parameter",
				["zh"] = "缺少attackers或targets参数"
			}
		};

		// 获取指定语言和错误码的错误信息
		static string GetErrorMessage(string errorCode, string language, params object[] args)
		{
			if (string.IsNullOrEmpty(language) || !ErrorMessages.ContainsKey(errorCode) || !ErrorMessages[errorCode].ContainsKey(language))
			{
				language = "zh"; // 默认使用中文
			}

			var messageTemplate = ErrorMessages[errorCode][language];
			return string.Format(messageTemplate, args);
		}

		public CopilotCommandServer(int port, World world)
		{
			this.port = port;
			this.world = world;
		}

		~CopilotCommandServer()
		{
			End();
		}

		public void Start()
		{
			serverSocket.Bind(new IPEndPoint(IPAddress.Any, port));
			serverSocket.Listen(10);
			isRunning = true;
			Console.WriteLine($"Listening for connections on port {port}");

			_ = Task.Run(async () =>
			{
				while (isRunning)
				{
					try
					{
						var clientSocket = await serverSocket.AcceptAsync();
						HandleClient(clientSocket);
					}
					catch (SocketException) when (!isRunning)
					{
						break;
					}
				}
			});
		}

		public void End()
		{
			if (isRunning)
			{
				isRunning = false;
				serverSocket.Close();
				Console.WriteLine("CopilotServer has been stopped.");
			}
		}

		async void HandleClient(Socket clientSocket)
		{
			using (clientSocket)
			{
				try
				{
					if (clientSocket == null)
					{
						throw new ArgumentException("clientSocket Uninit");
					}

					var buffer = new byte[16384];
					var received = await clientSocket.ReceiveAsync(buffer, SocketFlags.None);
					var jsonString = Encoding.UTF8.GetString(buffer, 0, received);

					// 只在调试模式下打印接收到的数据
					if (DebugMode)
					{
						Console.WriteLine("=== 接收到的数据 ===");
						Console.WriteLine(CustomJsonFormat(jsonString));
						Console.WriteLine("==================");
					}

					MCPRequest request;
					try
					{
						request = JsonConvert.DeserializeObject<MCPRequest>(jsonString);
					}
					catch (JsonException)
					{
						SendErrorResponse(clientSocket, new MCPError
						{
							Code = MCPErrorCodes.InvalidRequest,
							Message = GetErrorMessage("INVALID_REQUEST", "zh")
						}, null, DebugMode);
						return;
					}

					// 使用请求中的语言或默认为中文
					var language = request.Language ?? "zh";
					if (language is not "en" and not "zh")
					{
						language = "zh"; // 如果不是支持的语言，默认使用中文
					}

					// 验证请求
					var (isValid, validationError) = MCPValidator.ValidateRequest(request);
					if (!isValid)
					{
						validationError.Message = GetErrorMessage(validationError.Code, language);
						SendErrorResponse(clientSocket, validationError, null, DebugMode);
						return;
					}

					// 验证API版本
					if (request.ApiVersion != CurrentApiVersion)
					{
						SendErrorResponse(clientSocket, new MCPError
						{
							Code = MCPErrorCodes.InvalidVersion,
							Message = GetErrorMessage("INVALID_VERSION", language, CurrentApiVersion)
						}, null, DebugMode);
						return;
					}

					// 验证命令参数
					var (isParamsValid, paramsError) = MCPValidator.ValidateCommandParams(request.Command, request.Params);
					if (!isParamsValid)
					{
						paramsError.Message = GetErrorMessage(paramsError.Code, language);
						SendErrorResponse(clientSocket, paramsError, null, DebugMode);
						return;
					}

					// 处理命令
					if (CommandHandlers.TryGetValue(request.Command, out var commandHandler))
					{
						try
						{
							// 记录API调用统计
							StatsRecorder?.RecordApiCall(request.Command, false);

							var result = commandHandler?.Invoke(request.Params, world);
							SendSuccessResponse(clientSocket, result, request.RequestId, null, DebugMode);
						}
						catch (Exception ex)
						{
							SendErrorResponse(clientSocket, new MCPError
							{
								Code = MCPErrorCodes.CommandExecutionError,
								Message = GetErrorMessage("COMMAND_EXECUTION_ERROR", language),
								Details = new JObject { ["error"] = ex.Message }
							}, request.RequestId, DebugMode);
						}
					}
					else if (QueryHandlers.TryGetValue(request.Command, out var queryHandler))
					{
						try
						{
							// 记录API调用统计
							StatsRecorder?.RecordApiCall(request.Command, true);

							var resultJson = queryHandler?.Invoke(request.Params, world);
							SendSuccessResponse(clientSocket, null, request.RequestId, resultJson, DebugMode);
						}
						catch (Exception ex)
						{
							SendErrorResponse(clientSocket, new MCPError
							{
								Code = MCPErrorCodes.CommandExecutionError,
								Message = GetErrorMessage("QUERY_EXECUTION_ERROR", language),
								Details = new JObject { ["error"] = ex.Message }
							}, request.RequestId, DebugMode);
						}
					}
					else
					{
						SendErrorResponse(clientSocket, new MCPError
						{
							Code = MCPErrorCodes.InvalidCommand,
							Message = GetErrorMessage("INVALID_COMMAND", language)
						}, request.RequestId, DebugMode);
					}
				}
				catch (Exception ex)
				{
					SendErrorResponse(clientSocket, new MCPError
					{
						Code = MCPErrorCodes.InternalError,
						Message = GetErrorMessage("INTERNAL_ERROR", "zh"),
						Details = new JObject { ["error"] = ex.Message }
					}, null, DebugMode);
				}
			}
		}

		static void SendSuccessResponse(Socket clientSocket, string message = null, string requestId = null, JObject data = null, bool debugMode = false)
		{
			var response = new MCPResponse
			{
				Status = 1,
				RequestId = requestId,
				Response = message,
				Data = data
			};

			var responseJson = JsonConvert.SerializeObject(response);
			var buffer = Encoding.UTF8.GetBytes(responseJson);
			_ = clientSocket.Send(buffer);

			// 只在调试模式下打印发送的数据
			if (debugMode)
			{
				Console.WriteLine("=== 发送成功响应 ===");
				Console.WriteLine(CustomJsonFormat(responseJson));
				Console.WriteLine("==================");
			}
		}

		static void SendErrorResponse(Socket clientSocket, MCPError error, string requestId = null, bool debugMode = false)
		{
			var response = new MCPResponse
			{
				Status = -1,
				RequestId = requestId,
				Error = error
			};

			var responseJson = JsonConvert.SerializeObject(response);
			var buffer = Encoding.UTF8.GetBytes(responseJson);
			_ = clientSocket.Send(buffer);

			// 只在调试模式下打印发送的数据
			if (debugMode)
			{
				Console.WriteLine("=== 发送错误响应 ===");
				Console.WriteLine(CustomJsonFormat(responseJson));
				Console.WriteLine("==================");
			}
		}

		public static string CustomJsonFormat(string json)
		{
			var stringBuilder = new StringBuilder();
			var indent = 0;
			var arrayLevel = 0;

			foreach (var ch in json)
			{
				if (ch == '[')
				{
					if (arrayLevel == 0)
					{
						_ = stringBuilder.AppendLine(new string(' ', indent) + ch);
						indent += 2;
					}
					else
					{
						_ = stringBuilder.Append(ch);
					}

					arrayLevel++;
				}
				else if (ch == ']')
				{
					arrayLevel--;
					if (arrayLevel == 0)
					{
						indent -= 2;
						_ = stringBuilder.AppendLine().Append(new string(' ', indent) + ch);
					}
					else
					{
						_ = stringBuilder.Append(ch);
					}
				}
				else if (ch == ',')
				{
					_ = stringBuilder.Append(ch);
					if (arrayLevel == 1)
					{
						_ = stringBuilder.AppendLine();
						_ = stringBuilder.Append(new string(' ', indent));
					}
					else
					{
						_ = stringBuilder.Append(' ');
					}
				}
				else
				{
					if (ch is '\n' or '\r' or ' ')
						continue;

					_ = stringBuilder.Append(ch);
				}
			}

			return stringBuilder.ToString();
		}
	}
}
