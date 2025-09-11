using OpenRA.Mods.Common.Widgets;
using OpenRA.Widgets;
using System.Linq;

namespace OpenRA.Mods.Common.Chrome
{
	public sealed class CopilotScoreChrome : ChromeLogic
	{
		readonly World world;
		readonly LabelWidget scoreLabel;
		readonly LabelWidget timerLabel;

		[ObjectCreator.UseCtor]
		public CopilotScoreChrome(Widget widget, World world)
		{
			this.world = world;
			scoreLabel = widget.Get<LabelWidget>("CopilotScoreLabel");
			timerLabel = widget.Get<LabelWidget>("CopilotTimerLabel");
			var ticker = widget.Get<LogicTickerWidget>("COPILOT_SCORE_TICKER");
			ticker.OnTick = () => UpdateTexts();
		}

		void UpdateTexts()
		{
			var svc = world.WorldActor.TraitOrDefault<CopilotScoreService>();
			if (svc != null)
			{
				// 1v1：取两个非中立玩家
				var ps = world.Players.Where(p => !p.NonCombatant).Take(2).ToArray();
				var a = ps.Length > 0 ? svc.GetScore(ps[0]) : 0;
				var b = ps.Length > 1 ? svc.GetScore(ps[1]) : 0;
				scoreLabel.Text = $"{a} - {b}";
			}

			var mt = world.WorldActor.TraitOrDefault<CopilotScoreService>();
			if (mt != null)
			{
				var remain = mt.RemainingTime;  // 给 CopilotMatchTimer 增加一个只读属性即可
				if (remain < 0) remain = 0;
				timerLabel.Text = $"{remain / 25:D2}:{remain % 25:D2}";
			}
		}
	}
}
