using Newtonsoft.Json;
using OpenRA.Mods.Common.Traits;
using System;
using System.Collections.Generic;
using System.Security.Cryptography;
using System.Text;

namespace OpenRA
{
	public class GameStatsRecorder : CopilotCommandServer.IGameStatsRecorder
	{
		public class ObjectiveInfo
		{
			public string Id { get; set; }
			public string Name { get; set; }
			public DateTime? CompletedAt { get; set; }
			public bool IsCompleted { get; set; }
			public TimeSpan? CompletionTime { get; set; }
		}

		public class ResourceStats
		{
			public int InitialCash { get; set; }
			public int FinalCash { get; set; }
			public int TotalSpent { get; set; }
			public int TotalEarned { get; set; }
			public int PowerGenerated { get; set; }
			public int PowerConsumed { get; set; }
		}

		public class UnitStats
		{
			public Dictionary<string, int> UnitsProduced { get; set; } = new();
			public Dictionary<string, int> BuildingsBuilt { get; set; } = new();

			// 单位统计数据
			public int UnitsKilled { get; set; }
			public int UnitsLost { get; set; }
			public int BuildingsKilled { get; set; }
			public int BuildingsLost { get; set; }
			public int KillsCost { get; set; }
			public int DeathsCost { get; set; }
			public int ArmyValue { get; set; }
			public int AssetsValue { get; set; }
			public int OrderCount { get; set; }
			public int Experience { get; set; }
		}

		public class ApiCallStats
		{
			public Dictionary<string, int> CommandCalls { get; set; } = new();
			public Dictionary<string, int> QueryCalls { get; set; } = new();
			public int TotalCalls { get; set; }
			public DateTime FirstCall { get; set; }
			public DateTime LastCall { get; set; }
		}

		public class GameSessionStats
		{
			public string MapName { get; set; }
			public string PlayerName { get; set; }
			public DateTime StartTime { get; set; }
			public DateTime? EndTime { get; set; }
			public TimeSpan? Duration { get; set; }
			public bool Victory { get; set; }
			public List<ObjectiveInfo> Objectives { get; set; } = new();
			public ResourceStats Resources { get; set; } = new();
			public UnitStats Units { get; set; } = new();
			public ApiCallStats ApiCalls { get; set; } = new();
			public Dictionary<string, object> CustomData { get; set; } = new();
		}

		readonly GameSessionStats stats = new();
		readonly World world;
		readonly Player player;
		bool isRecording;
		int initialCash;

		public GameStatsRecorder(World world, Player player)
		{
			this.world = world;
			this.player = player;
			stats.StartTime = DateTime.Now;
			stats.MapName = world.Map.Title;
			stats.PlayerName = player.PlayerName;

			var playerRes = player.PlayerActor.Trait<PlayerResources>();
			var resources = player.PlayerActor.TraitOrDefault<PlayerResources>();
			if (resources != null)
			{
				initialCash = resources.Cash;
				stats.Resources.InitialCash = initialCash;
			}

			isRecording = true;
		}

		public void RecordObjective(string id, string name)
		{
			if (!isRecording) return;

			stats.Objectives.Add(new ObjectiveInfo
			{
				Id = id,
				Name = name,
				IsCompleted = false
			});
		}

		public void CompleteObjective(string id)
		{
			if (!isRecording) return;

			var objective = stats.Objectives.FirstOrDefault(o => o.Id == id);
			if (objective != null)
			{
				objective.CompletedAt = DateTime.Now;
				objective.IsCompleted = true;
				objective.CompletionTime = objective.CompletedAt - stats.StartTime;
			}
		}

		// 单位生产统计方法
		public void RecordUnitProduced(string unitType)
		{
			if (!isRecording) return;

			if (!stats.Units.UnitsProduced.ContainsKey(unitType))
				stats.Units.UnitsProduced[unitType] = 0;
			stats.Units.UnitsProduced[unitType]++;
		}

		public void RecordBuildingBuilt(string buildingType)
		{
			if (!isRecording) return;

			if (!stats.Units.BuildingsBuilt.ContainsKey(buildingType))
				stats.Units.BuildingsBuilt[buildingType] = 0;
			stats.Units.BuildingsBuilt[buildingType]++;
		}

		public void RecordApiCall(string command, bool isQuery)
		{
			if (!isRecording) return;

			var now = DateTime.Now;
			if (stats.ApiCalls.TotalCalls == 0)
				stats.ApiCalls.FirstCall = now;
			stats.ApiCalls.LastCall = now;
			stats.ApiCalls.TotalCalls++;

			if (isQuery)
			{
				if (!stats.ApiCalls.QueryCalls.ContainsKey(command))
					stats.ApiCalls.QueryCalls[command] = 0;
				stats.ApiCalls.QueryCalls[command]++;
			}
			else
			{
				if (!stats.ApiCalls.CommandCalls.ContainsKey(command))
					stats.ApiCalls.CommandCalls[command] = 0;
				stats.ApiCalls.CommandCalls[command]++;
			}
		}

		public void SetCustomData(string key, object value)
		{
			if (!isRecording) return;
			stats.CustomData[key] = value;
		}

		public void EndSession(bool victory)
		{
			if (!isRecording) return;

			stats.EndTime = DateTime.Now;
			stats.Duration = stats.EndTime - stats.StartTime;
			stats.Victory = victory;

			// 记录最终资源状态
			var resources = player.PlayerActor.TraitOrDefault<PlayerResources>();
			if (resources != null)
			{
				stats.Resources.FinalCash = resources.Cash;
				stats.Resources.TotalSpent = initialCash - resources.Cash + stats.Resources.TotalEarned;
			}

			var powerManager = player.PlayerActor.TraitOrDefault<PowerManager>();
			if (powerManager != null)
			{
				stats.Resources.PowerGenerated = powerManager.PowerProvided;
				stats.Resources.PowerConsumed = powerManager.PowerDrained;
			}

			// 记录单位统计数据
			var playerStats = player.PlayerActor.TraitOrDefault<PlayerStatistics>();
			if (playerStats != null)
			{
				stats.Units.UnitsKilled = playerStats.UnitsKilled;
				stats.Units.UnitsLost = playerStats.UnitsDead;
				stats.Units.BuildingsKilled = playerStats.BuildingsKilled;
				stats.Units.BuildingsLost = playerStats.BuildingsDead;
				stats.Units.KillsCost = playerStats.KillsCost;
				stats.Units.DeathsCost = playerStats.DeathsCost;
				stats.Units.ArmyValue = playerStats.ArmyValue;
				stats.Units.AssetsValue = playerStats.AssetsValue;
				stats.Units.OrderCount = playerStats.OrderCount;
				stats.Units.Experience = playerStats.Experience;
			}

			isRecording = false;
		}

		public string GenerateSignedLog(string rsaPublicKey = "")
		{
			var jsonStats = JsonConvert.SerializeObject(stats, Formatting.Indented);
			var hash = EncryptionUtils.ComputeHash(jsonStats);
			var signature = "";

			// 如果提供了公钥，使用RSA签名Hash
			if (!string.IsNullOrEmpty(rsaPublicKey))
			{
				try
				{
					signature = EncryptionUtils.SignHash(hash, rsaPublicKey);
				}
				catch (Exception ex)
				{
					Console.WriteLine($"RSA签名失败: {ex.Message}");
					signature = "SIGNATURE_ERROR";
				}
			}

			// 添加头部信息
			var logHeader = new
			{
				Version = "2.0",
				GameName = "OpenRA",
				GeneratedAt = DateTime.Now,
				MapHash = world.Map.Uid,
				DataHash = hash,
				Signature = signature,
				HasSignature = !string.IsNullOrEmpty(signature) && signature != "SIGNATURE_ERROR" && signature != "CLIENT_SIDE_NO_SIGNATURE"
			};

			var headerJson = JsonConvert.SerializeObject(logHeader, Formatting.Indented);

			return $"===OPENRA_STATS_LOG_BEGIN===\n{headerJson}\n===STATS_DATA===\n{jsonStats}\n===OPENRA_STATS_LOG_END===";
		}

		public void SaveLogToFile(string filePath = null, string rsaPublicKey = "")
		{
			var timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
			var mapName = world.Map.Title.Replace(" ", "_").Replace("/", "_").Replace("\\", "_").Replace(":", "_");
			var statName = $"{stats.PlayerName}_{mapName}_{timestamp}.log";

			// 使用OpenRA的Log系统保存日志
			var signedLog = GenerateSignedLog(rsaPublicKey);

			Log.AddChannel(statName, statName);
			// 保存到OpenRA的日志目录
			Log.Write(statName, signedLog);

			Console.WriteLine($"游戏统计日志已保存到OpenRA日志目录，log名字：{statName}，地图: {mapName}, 时间: {timestamp}");
		}

		public GameSessionStats GetStats() => stats;
	}

	public static class EncryptionUtils
	{
		public static string ComputeHash(string input)
		{
			using var sha256 = SHA256.Create();
			var hash = sha256.ComputeHash(Encoding.UTF8.GetBytes(input));
			return Convert.ToBase64String(hash);
		}

		public static string SignHash(string hash, string publicKeyXml)
		{
			// 在客户端，我们使用公钥进行签名（实际是加密hash值）
			try
			{
				using var rsa = RSA.Create();
				rsa.FromXmlString(publicKeyXml);

				var hashBytes = Convert.FromBase64String(hash);
				// 使用公钥加密hash值作为签名
				var signatureBytes = rsa.Encrypt(hashBytes, RSAEncryptionPadding.OaepSHA256);
				return Convert.ToBase64String(signatureBytes);
			}
			catch (Exception ex)
			{
				Console.WriteLine($"RSA签名失败: {ex.Message}");
				return "SIGNATURE_ERROR";
			}
		}

		public static bool VerifySignature(string hash, string signature, string privateKeyXml)
		{
			try
			{
				using var rsa = RSA.Create();
				rsa.FromXmlString(privateKeyXml);

				var hashBytes = Convert.FromBase64String(hash);
				var signatureBytes = Convert.FromBase64String(signature);

				// 使用私钥解密签名，然后比较hash值
				var decryptedHashBytes = rsa.Decrypt(signatureBytes, RSAEncryptionPadding.OaepSHA256);
				var decryptedHash = Convert.ToBase64String(decryptedHashBytes);

				return hash == decryptedHash;
			}
			catch (Exception ex)
			{
				Console.WriteLine($"RSA验证错误: {ex.Message}");
				return false;
			}
		}

		// 工具方法：生成RSA密钥对（仅用于测试）
		public static (string publicKey, string privateKey) GenerateRSAKeyPair()
		{
			using var rsa = RSA.Create(2048);
			return (rsa.ToXmlString(false), rsa.ToXmlString(true));
		}
	}
}
