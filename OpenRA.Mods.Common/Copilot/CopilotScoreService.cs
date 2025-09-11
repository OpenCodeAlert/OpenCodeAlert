using OpenRA.Graphics;
using OpenRA.Mods.Common.Effects;
using OpenRA.Mods.Common.Traits;
using OpenRA.Traits;
using System.Collections.Generic;

namespace OpenRA.Mods.Common
{
	[TraitLocation(SystemActors.World)]
	[Desc("Attach this to the world actor.")]
	public class CopilotScoreServiceInfo : ConditionalTraitInfo
	{
		[Desc("Time limit in seconds.")]
		public readonly int TimeLimit = 7500;

		public override object Create(ActorInitializer init)
		{
			return new CopilotScoreService(this);
		}
	}

	public class CopilotScoreService : ConditionalTrait<CopilotScoreServiceInfo>, IWorldLoaded, ITick
	{
		public World World;
		public Dictionary<Player, int> Score;
		public int RemainingTime;

		public CopilotScoreService(CopilotScoreServiceInfo info)
			: base(info)
		{
			RemainingTime = Info.TimeLimit;
			Score = new Dictionary<Player, int>();
		}

		public void WorldLoaded(World w, WorldRenderer wr)
		{
			World = w;
		}

		public void AddMatchScore(Player player, int score, WPos pos)
		{
			if (!Score.ContainsKey(player))
				Score[player] = 0;
			Score[player] += score;

			World.Add(new FloatingText(pos, player.Color, FloatingText.FormatCashTick(score), 30));
		}

		public int GetScore(Player player)
		{
			return Score.ContainsKey(player) ? Score[player] : 0;
		}

		public void ResetScore()
		{
			Score.Clear();
		}

		void ITick.Tick(Actor self)
		{
			RemainingTime--;
		}
	}
}
