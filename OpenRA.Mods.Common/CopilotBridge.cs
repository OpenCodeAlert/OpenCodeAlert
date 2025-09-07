using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Channels;
using OpenRA;
using OpenRA.Traits;
using OpenRA.Graphics;

namespace OpenRA.Mods.Common.Commands
{
	// 单例/静态通道, 多写单读
	public static class CopilotBus
	{
		public static readonly Channel<CopilotIntent> Chan =
			Channel.CreateUnbounded<CopilotIntent>(
				new UnboundedChannelOptions { SingleReader = true, SingleWriter = false });

		public static bool Enqueue(CopilotIntent intent)
		{
			// 尽量不阻塞, 失败也不抛异常
			return Chan.Writer.TryWrite(intent);
		}
	}

	// 基础意图类型
	public abstract class CopilotIntent
	{
		public abstract void Execute(World world);
		protected static Actor ResolveActor(World world, int actorId)
		{
			return world.Actors.FirstOrDefault(a => a.ActorID == actorId);
		}
	}

	public enum TargetKind
	{
		None,
		ActorId,
		Cell
	}

	public struct TargetSpec
	{
		public TargetKind Kind;
		public int ActorId;
		public CPos Cell;

		public static TargetSpec None() => new TargetSpec { Kind = TargetKind.None };
		public static TargetSpec FromActorId(int id) => new TargetSpec { Kind = TargetKind.ActorId, ActorId = id };
		public static TargetSpec FromCell(CPos cell) => new TargetSpec { Kind = TargetKind.Cell, Cell = cell };

		public Target ToTarget(World world)
		{
			switch (Kind)
			{
				case TargetKind.ActorId:
					var id = ActorId;
					var actor = world.Actors.FirstOrDefault(a => a.ActorID == id);
					return actor != null ? Target.FromActor(actor) : Target.Invalid;
				case TargetKind.Cell:
					return Target.FromCell(world, Cell);
				default:
					return Target.Invalid;
			}
		}
	}

	// 取消当前活动
	public sealed class CancelActivityIntent : CopilotIntent
	{
		public int ActorId;
		public override void Execute(World world)
		{
			var actor = ResolveActor(world, ActorId);
			if (actor == null)
				return;
			actor.CancelActivity();
		}
	}

	// 排队执行特定活动 (目前用于 Harvester 的 FindAndDeliverResources)
	public sealed class QueueActivityIntent : CopilotIntent
	{
		public int ActorId;
		public string ActivityName;
		public override void Execute(World world)
		{
			var actor = ResolveActor(world, ActorId);
			if (actor == null)
				return;

			// 仅实现已知安全的活动名称
			switch (ActivityName)
			{
				case "FindAndDeliverResources":
					var harv = actor;
					actor.QueueActivity(new OpenRA.Mods.Common.Activities.FindAndDeliverResources(harv));
					break;
				default:
					// 未知活动忽略
					break;
			}
		}
	}

	// 发出 Order 的意图（通用）
	public sealed class IssueOrderIntent : CopilotIntent
	{
		public string OrderId;
		public int? SubjectActorId; // 可以为 null
		public TargetSpec TargetA;
		public TargetSpec TargetB;
		public bool Queued;
		public int[] GroupedActorIds; // 可为空
		public bool SuppressVisualFeedback;
		public string TargetString; // 可为空
		public CPos? ExtraLocation;
		public int? ExtraData;

		// 一些需要工厂方法构建的 Order （例如生产/暂停等）
		public string Factory; // "StartProduction", "PauseProduction", "CancelProduction" 等，可空
		public string FactoryItem; // 对应的 Item 名称
		public int? FactoryCount; // 数量/标志等

		public override void Execute(World world)
		{
			try
			{
				Order order;
				if (!string.IsNullOrEmpty(Factory))
				{
					// 处理特殊工厂方法
					var subject = SubjectActorId.HasValue ? ResolveActor(world, SubjectActorId.Value) : null;
					if (subject == null)
						return;

					if (Factory == "StartProduction")
					{
						var qty = FactoryCount ?? 1;
						var autoPlace = ExtraData == 1; // ExtraData=1 表示自动放置
						order = Order.StartProduction(subject, FactoryItem, qty, true, autoPlace);
					}
					else if (Factory == "PauseProduction")
					{
						var pause = (FactoryCount ?? 0) != 0; // 非0表示暂停
						order = Order.PauseProduction(subject, FactoryItem, pause);
					}
					else if (Factory == "CancelProduction")
					{
						var count = FactoryCount ?? 1;
						order = Order.CancelProduction(subject, FactoryItem, count);
					}
					else
					{
						return;
					}
				}
				else
				{
					var subject = SubjectActorId.HasValue ? ResolveActor(world, SubjectActorId.Value) : null;
					var tA = TargetA.ToTarget(world);
					var tB = TargetB.ToTarget(world);
					Actor[] grouped = null;
					if (GroupedActorIds != null && GroupedActorIds.Length > 0)
					{
						grouped = GroupedActorIds.Select(id => ResolveActor(world, id)).Where(a => a != null).ToArray();
						if (grouped.Length == 0)
							grouped = null;
					}

					if (TargetB.Kind != TargetKind.None)
					{
						order = new Order(OrderId, subject, tA, tB, Queued);
					}
					else if (grouped != null)
					{
						order = new Order(OrderId, null, tA, Queued, groupedActors: grouped);
					}
					else
					{
						order = new Order(OrderId, subject, tA, Queued);
					}

					order.SuppressVisualFeedback = SuppressVisualFeedback;
					order.TargetString = TargetString;
					order.ExtraLocation = ExtraLocation ?? default;
					order.ExtraData = (uint)(ExtraData ?? 0);
				}

				world.IssueOrder(order);
			}
			catch
			{
				// 忽略单条失败, 避免影响主线程稳定性
			}
		}
	}

	// 桥接: 主线程每 Tick 消费并执行意图
	[Desc("Attach this to the world actor.")]
	[TraitLocation(SystemActors.World)]
	public sealed class CopilotBridgeInfo : TraitInfo<CopilotBridge> { }

	public sealed class CopilotBridge : IWorldLoaded, ITick
	{
		World world;

		void IWorldLoaded.WorldLoaded(World w, WorldRenderer wr) => world = w;

		void ITick.Tick(Actor self)
		{
			// 每 tick 消费一定数量, 防止长帧
			var reader = CopilotBus.Chan.Reader;
			var processed = 0;
			const int maxPerTick = 256;
			while (processed < maxPerTick && reader.TryRead(out var intent))
			{
				try
				{
					intent?.Execute(world);
				}
				catch
				{
					// 单条失败不影响后续
				}
				processed++;
			}
		}
	}
}


