using System;
using System.Collections.Generic;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace OpenRA
{
    public class MCPRequest
    {
        [JsonProperty("apiVersion", Required = Required.Always)]
        public string ApiVersion { get; set; }

        [JsonProperty("requestId", Required = Required.Always)]
        public string RequestId { get; set; }

        [JsonProperty("command", Required = Required.Always)]
        public string Command { get; set; }

        [JsonProperty("params")]
        public JObject Params { get; set; }

        [JsonProperty("language")]
        public string Language { get; set; } = "zh";
    }

    public class MCPResponse
    {
        [JsonProperty("status")]
        public int Status { get; set; }

        [JsonProperty("requestId")]
        public string RequestId { get; set; }

        [JsonProperty("response")]
        public string Response { get; set; }

        [JsonProperty("data")]
        public JObject Data { get; set; }

        [JsonProperty("error")]
        public MCPError Error { get; set; }
    }

    public class MCPError
    {
        [JsonProperty("code")]
        public string Code { get; set; }

        [JsonProperty("message")]
        public string Message { get; set; }

        [JsonProperty("details")]
        public JObject Details { get; set; }
    }

    public static class MCPErrorCodes
    {
        public const string InvalidRequest = "INVALID_REQUEST";
        public const string InvalidVersion = "INVALID_VERSION";
        public const string InvalidCommand = "INVALID_COMMAND";
        public const string InvalidParams = "INVALID_PARAMS";
        public const string CommandExecutionError = "COMMAND_EXECUTION_ERROR";
        public const string InternalError = "INTERNAL_ERROR";
    }

    public static class MCPValidator
    {
        public static (bool isValid, MCPError error) ValidateRequest(MCPRequest request)
        {
            if (request == null)
            {
                return (false, new MCPError 
                { 
                    Code = MCPErrorCodes.InvalidRequest,
                    Message = "请求格式无效"
                });
            }

            if (string.IsNullOrEmpty(request.ApiVersion))
            {
                return (false, new MCPError 
                { 
                    Code = MCPErrorCodes.InvalidVersion,
                    Message = "API版本号不能为空"
                });
            }

            if (string.IsNullOrEmpty(request.Command))
            {
                return (false, new MCPError 
                { 
                    Code = MCPErrorCodes.InvalidCommand,
                    Message = "命令不能为空"
                });
            }

            // 可以添加更多验证逻辑

            return (true, null);
        }

        public static (bool isValid, MCPError error) ValidateCommandParams(string command, JObject parameters)
        {
            // 根据不同命令验证参数
            switch (command)
            {
                case "move_actor":
                    return ValidateMoveActorParams(parameters);
                case "attack":
                    return ValidateAttackParams(parameters);
                // 添加更多命令的参数验证
                default:
                    return (true, null);
            }
        }

        private static (bool isValid, MCPError error) ValidateMoveActorParams(JObject parameters)
        {
            if (parameters == null)
            {
                return (false, new MCPError 
                { 
                    Code = "INVALID_PARAMS_MOVE_ACTOR",
                    Message = "移动命令参数不能为空"
                });
            }

            // 检查必需参数
            if (!parameters.ContainsKey("targets"))
            {
                return (false, new MCPError 
                { 
                    Code = "MISSING_TARGETS",
                    Message = "缺少targets参数"
                });
            }

            // 可以添加更多具体的参数验证

            return (true, null);
        }

        private static (bool isValid, MCPError error) ValidateAttackParams(JObject parameters)
        {
            if (parameters == null)
            {
                return (false, new MCPError 
                { 
                    Code = "INVALID_PARAMS_ATTACK",
                    Message = "攻击命令参数不能为空"
                });
            }

            // 检查必需参数
            if (!parameters.ContainsKey("attackers") || !parameters.ContainsKey("targets"))
            {
                return (false, new MCPError 
                { 
                    Code = "MISSING_ATTACKERS_OR_TARGETS",
                    Message = "缺少attackers或targets参数"
                });
            }

            return (true, null);
        }
    }
} 