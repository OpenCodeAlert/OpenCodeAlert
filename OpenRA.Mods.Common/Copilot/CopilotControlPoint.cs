using System.Collections.Generic;
using System.Linq;
using OpenRA.Graphics;
using OpenRA.Traits;

namespace OpenRA.Mods.Common
{
	public struct ControlPoint
	{
		public Actor Actor;
		public string Name;
		public List<ControlPointBuff> Buffs;
		public bool HasBuffs;
		public int X;
		public int Y;
	}

	public struct ControlPointBuff
	{
		public string UnitType;
		public string BuffType;
		public string BuffName;
	}

	[TraitLocation(SystemActors.World)]
	[Desc("Attach this to the world actor.")]
	public class CopilotControlPointInfo : TraitInfo<CopilotControlPoint> { }
	public class CopilotControlPoint : IWorldLoaded
	{
		public World World;
		public Dictionary<string, ControlPoint> ControlPoints;

		public void WorldLoaded(World w, WorldRenderer wr)
		{
			ControlPoints = new Dictionary<string, ControlPoint>();
			World = w;
		}

		public void AddControlPoint(string name, Actor actor, int x, int y)
		{
			ControlPoints[name] = new ControlPoint
			{
				Actor = actor,
				Name = name,
				Buffs = new List<ControlPointBuff>(),
				HasBuffs = false,
				X = x,
				Y = y
			};
		}

		public void RemoveControlPoint(string name)
		{
			ControlPoints.Remove(name);
		}

		public void SetBuffs(string name, List<ControlPointBuff> buffs)
		{
			if (ControlPoints.ContainsKey(name))
			{
				var cp = ControlPoints[name];
				cp.Buffs = buffs;
				cp.HasBuffs = buffs.Count > 0;
				ControlPoints[name] = cp;
			}
		}

		public List<ControlPointBuff> GetBuffs(string name)
		{
			return ControlPoints.ContainsKey(name) ? ControlPoints[name].Buffs : new List<ControlPointBuff>();
		}

		public List<ControlPoint> GetAllControlPoints()
		{
			return ControlPoints.Values.ToList();
		}

		public ControlPoint? GetControlPoint(string name)
		{
			return ControlPoints.ContainsKey(name) ? ControlPoints[name] : null;
		}

		public bool ShouldRefreshBuffs(string name)
		{
			if (!ControlPoints.ContainsKey(name))
				return false;

			var cp = ControlPoints[name];
			return !cp.HasBuffs;
		}
	}
}
