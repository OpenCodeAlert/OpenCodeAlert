#region Copyright & License Information
/*
 * Copyright (c) The OpenRA Developers and Contributors
 * This file is part of OpenRA, which is free software. It is made
 * available to you under the terms of the GNU General Public License
 * as published by the Free Software Foundation, either version 3 of
 * the License, or (at your option) any later version. For more
 * information, see COPYING.
 */
#endregion

using OpenRA.Network;
using OpenRA.Traits;

namespace OpenRA.Mods.Common.Traits
{
	/// <summary>
	/// 记录 actor 最近一次被执行(Resolve)的 Order，用于调试/查询接口。
	/// 注意：OpenRA 默认不会把“当前正在执行的 Order”保存在 Actor 上；
	/// Order 会被分发到 Actor.ResolveOrder(...) 然后由各 trait 处理。
	/// </summary>
	[Desc("Records the last resolved Order for debugging/queries.")]
	public sealed class TrackLastResolvedOrderInfo : TraitInfo
	{
		public override object Create(ActorInitializer init) { return new TrackLastResolvedOrder(); }
	}

	public sealed class TrackLastResolvedOrder : IResolveOrder
	{
		/// <summary>最近一次 order 的 id（OrderString）。</summary>
		public string LastOrderString { get; private set; } = "";

		/// <summary>最近一次 order 的 TargetString（如果有）。</summary>
		public string LastOrderTargetString { get; private set; } = "";

		/// <summary>最近一次 order 是否 queued。</summary>
		public bool LastOrderQueued { get; private set; }

		/// <summary>
		/// 给外部(如 ServerCommands)直接用的展示字符串。
		/// </summary>
		public string LastOrderLabel
		{
			get
			{
				if (string.IsNullOrEmpty(LastOrderString))
					return "";

				// 例：Move, Attack, Harvest...；若 TargetString 有值则拼上，方便调试
				if (string.IsNullOrEmpty(LastOrderTargetString))
					return LastOrderQueued ? $"{LastOrderString} (Queued)" : LastOrderString;

				return LastOrderQueued
					? $"{LastOrderString} -> {LastOrderTargetString} (Queued)"
					: $"{LastOrderString} -> {LastOrderTargetString}";
			}
		}

		void IResolveOrder.ResolveOrder(Actor self, Order order)
		{
			// 仅记录信息，不影响逻辑与同步
			LastOrderString = order?.OrderString ?? "";
			LastOrderTargetString = order?.TargetString ?? "";
			LastOrderQueued = order != null && order.Queued;
		}
	}
}


