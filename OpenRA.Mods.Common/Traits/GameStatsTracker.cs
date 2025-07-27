using OpenRA.Graphics;
using OpenRA.Traits;
using System;

namespace OpenRA.Mods.Common.Traits
{
	[TraitLocation(SystemActors.World)]
	[Desc("跟踪游戏统计数据，包括单位生产、死亡、建筑建造等")]
	public class GameStatsTrackerInfo : TraitInfo
	{
		[Desc("是否启用统计跟踪")]
		public readonly bool Enabled = true;

		[Desc("统计跟踪的玩家名称")]
		public readonly string PlayerName = "Player";

		[Desc("RSA公钥，用于签名Hash值验证")]
		public readonly string RSAPublicKey = "";

		public override object Create(ActorInitializer init) { return new GameStatsTracker(init, this); }
	}

	public class GameStatsTracker : IWorldLoaded, IEndGame
	{
		readonly GameStatsTrackerInfo info;
		readonly World world;
		GameStatsRecorder statsRecorder;
		Player trackedPlayer;
		bool gameEnded;

		public GameStatsTracker(ActorInitializer init, GameStatsTrackerInfo info)
		{
			this.info = info;
			world = init.World;
		}

		public void WorldLoaded(World w, WorldRenderer wr)
		{
			if (!info.Enabled)
				return;

			// 查找要跟踪的玩家
			trackedPlayer = w.Players.FirstOrDefault(p => p.PlayerName == info.PlayerName);

			// 如果未指定玩家，则默认跟踪本地玩家
			trackedPlayer ??= w.LocalPlayer;

			if (trackedPlayer == null)
			{
				Console.WriteLine($"警告：无法找到玩家 '{info.PlayerName}'，统计跟踪已禁用");
				return;
			}

			// 初始化统计记录器
			statsRecorder = new GameStatsRecorder(w, trackedPlayer);

			// 设置CopilotServer的统计记录器
			if (w.CopilotServer != null)
			{
				w.CopilotServer.StatsRecorder = statsRecorder;
			}

			Console.WriteLine($"游戏统计跟踪已启用，跟踪玩家: {trackedPlayer.PlayerName}");
		}

		// 使用Tick来检查单位状态变化，而不是直接监听事件
		// 这样可以避免接口依赖问题

		// 提供给外部调用的方法
		public void RecordObjective(string id, string name)
		{
			statsRecorder?.RecordObjective(id, name);
		}

		public void CompleteObjective(string id)
		{
			statsRecorder?.CompleteObjective(id);
		}

		public void SetCustomData(string key, object value)
		{
			statsRecorder?.SetCustomData(key, value);
		}

		public GameStatsRecorder GetStatsRecorder()
		{
			return statsRecorder;
		}

		// 手动触发保存日志（用于调试或强制保存）
		public void ForceSaveLog()
		{
			if (!info.Enabled || statsRecorder == null || trackedPlayer == null)
			{
				Console.WriteLine("强制保存失败：统计系统未正确初始化");
				return;
			}

			if (gameEnded)
			{
				Console.WriteLine("强制保存失败：日志已经保存过了");
				return;
			}

			gameEnded = true;
			var victory = trackedPlayer.WinState == WinState.Won;

			statsRecorder.EndSession(victory);
			statsRecorder.SaveLogToFile(null, info.RSAPublicKey);

			Console.WriteLine($"强制保存统计日志 - 胜利: {victory}");
		}

		public void EndGame(World world)
		{
			if (!info.Enabled || statsRecorder == null || trackedPlayer == null || gameEnded)
				return;

			gameEnded = true;

			// 确定胜利状态
			var victory = false;
			if (trackedPlayer.WinState == WinState.Won)
				victory = true;
			else if (trackedPlayer.WinState == WinState.Lost)
				victory = false;

			// 结束统计会话并保存日志
			statsRecorder.EndSession(victory);
			statsRecorder.SaveLogToFile(null, info.RSAPublicKey);

			Console.WriteLine($"游戏结束事件触发，统计日志已保存 - 胜利: {victory}");
			Console.WriteLine($"玩家状态: WinState={trackedPlayer.WinState}");
		}
	}
}
