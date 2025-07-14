using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using OpenRA.Graphics;
using OpenRA.Mods.Common.Activities;
using OpenRA.Mods.Common.Traits;
using OpenRA.Mods.Common.Widgets;
using OpenRA.Traits;
namespace OpenRA.Mods.Common.Commands
{
	[TraitLocation(SystemActors.World)]
	[Desc("Attach this to the world actor.")]
	public class ServerCommandsInfo : TraitInfo<ServerCommands> { }
	public class ServerCommands : IWorldLoaded, ITick
	{
		public static List<Actor> GetTargets(JToken targets, World world, Player player)
		{
			var result = new List<Actor>();

			var actorIds = targets["actorId"]?.ToObject<List<int>>();
			if (actorIds != null)
			{
				foreach (var actorId in actorIds)
				{
					var actor = world.Actors.FirstOrDefault(a => a.ActorID == actorId);
					if (actor != null)
					{
						result.Add(actor);
					}
				}

				// var restrainss = targets["restrain"]?.ToList();
				// if (restrainss != null)
				// {
				// 	foreach (var restrain in restrainss)
				// 	{
						// 这里默认就只能看见 visible的才合理啊，不然作弊了

						// var visible = restrain["visible"]?.ToObject<bool>();
						// if (visible == true)
						// {
							result = result.Where(a =>
							{
								var tar = Target.FromActor(a);
								_ = tar.Recalculate(player.PlayerActor.Owner, out var targetIsHiddenActor);
								return !targetIsHiddenActor && a.CanBeViewedByPlayer(player.PlayerActor.Owner);
							})
							.ToList();
						// }
					// }
				// }

				return result;
			}

			// 解析参数
			var range = targets["range"]?.ToString() ?? "all";
			var groupIds = targets["groupId"]?.ToObject<List<int>>() ?? new List<int>();
			var rawtypes = targets["type"]?.ToObject<List<string>>() ?? new List<string>();
			var faction = targets["faction"]?.ToString() ?? "己方";
			var types = new List<string>();
			foreach (var type in rawtypes)
			{
				types.AddRange(CopilotsConfig.GetConfigNameByChinese(type));
			}

			IEnumerable<Actor> actors;
			if (faction is "己方" or "自己" or "我" or "我的" or "我方")
				actors = world.Actors.Where(a => a.Owner == player && a.OccupiesSpace != null);
			else if (faction is "敌方" or "敌人" or "对面" or "他的" or "他")
				actors = world.Actors.Where(a => a.Owner != player && a.Owner.IsBot && a.OccupiesSpace != null);
			else
				if (faction == "中立")
				actors = world.Actors.Where(a => (a.Owner == null || (a.Owner != player && !a.Owner.IsBot)) && a.OccupiesSpace != null);
			else

				// throw new ArgumentException($"Invalid faction: {faction}");
				//  throw new ArgumentException($"Invalid faction: {faction}");
				actors = world.Actors.Where(a => a.OccupiesSpace != null);

			// 根据范围筛选
			switch (range)
			{
				case "screen":
					var viewport = Game.worldRenderer.Viewport;
					actors = actors.Where(a => CopilotsUtils.IsVisibleInViewport(Game.worldRenderer, world.Map.CenterOfCell(a.Location)));
					break;
				case "selected":
					actors = actors.Where(a => world.Selection.Contains(a));
					break;
				case "all":
				default:
					// 不做任何筛选
					break;
			}

			// 根据groupId筛选
			if (groupIds.Count > 0)
			{
				var groupActors = new List<Actor>();
				foreach (var groupId in groupIds)
				{
					groupActors.AddRange(world.ControlGroups.GetActorsInControlGroup(groupId - 1));
				}

				actors = actors.Intersect(groupActors);
			}

			// 根据type筛选
			if (types.Count > 0)
			{
				actors = actors.Where(a => types.Contains(a.Info.Name));
			}

			// 这里默认就只能看见 visible的才合理啊，不然作弊了
			actors = actors.Where(a =>
						{
							var tar = Target.FromActor(a);
							_ = tar.Recalculate(player.PlayerActor.Owner, out var targetIsHiddenActor);
							return !targetIsHiddenActor && a.CanBeViewedByPlayer(player.PlayerActor.Owner);
						});

			var restrains = targets["restrain"]?.ToList();
			if (restrains != null)
			{
				foreach (var restrain in restrains)
				{
					var direction = restrain["relativeDirection"]?.ToString();
					var maxNum = restrain["maxNum"]?.ToObject<int>();
					var dis = restrain["distance"]?.ToObject<int>();
					// var visible = restrain["visible"]?.ToObject<bool>();

					if (direction != null && maxNum.HasValue)
					{
						var directionVector = CopilotsUtils.GetDirectionVector(direction);
						actors = actors.OrderBy(a => -a.Location.X * directionVector.X - a.Location.Y * directionVector.Y);
						actors = actors.Take(maxNum.Value);
					}
					else if (maxNum.HasValue)
					{
						actors = actors.Take(maxNum.Value);
					}
					else if (dis.HasValue)
					{
						var loc = GetLocation(targets["location"]);
						actors = actors.Where(a => Math.Abs(a.Location.X - loc.X) + Math.Abs(a.Location.Y - loc.Y) <= dis.Value);
					}
					// else if (visible == true)
					// {
						
					// }
				}
			}

			// 返回符合条件的ActorID
			result.AddRange(actors);

			return result;
		}

		public static CPos GetLocation(JToken location)
		{
			var x = location["x"]?.ToObject<int>();
			var y = location["y"]?.ToObject<int>();
			if (x != null && y != null)
			{
				return new CPos(x.Value, y.Value);
			}

			throw new NotImplementedException("Missing parameters in \"Location\" for command");
		}

		public static List<Actor> GetTargetsFromJson(JObject json, World world, bool bAllowEmpty = false)
		{
			var player = world.LocalPlayer;
			var targets = json.TryGetFieldValue("targets");
			if (targets == null)
			{
				if (bAllowEmpty)
					return new List<Actor>();
				throw new NotImplementedException("Missing parameters \"Targets\" for command");
			}

			var actors = GetTargets(targets, world, player);
			if (actors.Count == 0 && !bAllowEmpty)
			{
				throw new NotImplementedException("NO Valid Actor.");
			}

			return actors;
		}

		public static CPos? GetTargetLocation(JToken location, World world, Player player)
		{
			if (location == null)
				return null;
			var x = location["x"]?.ToObject<int>();
			var y = location["y"]?.ToObject<int>();
			if (x != null && y != null)
			{
				return new CPos(x.Value, y.Value);
			}

			var targets = location.TryGetFieldValue("targets");
			if (targets == null)
			{
				return null;

				// throw new NotImplementedException("Missing parameters targets for location");
			}

			var sum = new CPos(0, 0);
			var targetActors = GetTargets(targets, world, player);

			if (targetActors.Count == 0)
			{
				return null;

				// throw new NotImplementedException("no actor targets for location");
			}

			foreach (var target in targetActors)
			{
				sum = new CPos(sum.X + target.Location.X, sum.Y + target.Location.Y);
			}

			var count = targetActors.Count;
			var averageLocation = new CPos(sum.X / count, sum.Y / count);

			var direction = location.TryGetFieldValue("direction")?.ToObject<string>();
			var distance = location.TryGetFieldValue("distance")?.ToObject<int>();

			if (direction != null && distance != null)
			{
				averageLocation += CopilotsUtils.GetDirectionVector(direction) * distance.Value;
			}

			return averageLocation;
		}

		public static string SelectUnitCommand(JObject json, World world)
		{
			var player = world.LocalPlayer;
			var isCombine = json.TryGetFieldValue("isCombine")?.ToObject<int>();
			var actors = GetTargetsFromJson(json, world);
			var newSelection = SelectionUtils.SelectActorsByOwnerAndSelectionClass(actors, new List<Player> { player }, null).ToList();
			world.Selection.Combine(world, newSelection, isCombine > 0, false);
			return "Actor Selected";
		}

		public static string FormGroupCommand(JObject json, World world)
		{
			var player = world.LocalPlayer;
			var groupId = json.TryGetFieldValue("groupId")?.ToObject<int>();
			if (groupId == null)
			{
				throw new NotImplementedException("Missing parameters groupId for FormGroupCommand");
			}

			var actors = GetTargetsFromJson(json, world);
			var newSelection = SelectionUtils.SelectActorsByOwnerAndSelectionClass(actors, new List<Player> { player }, null).ToList();
			world.Selection.Combine(world, newSelection, false, false);
			world.ControlGroups.CreateControlGroup(groupId.Value - 1);

			return "Group Formed";
		}

		public static string MoveActorCommand(JObject json, World world)
		{
			var player = world.LocalPlayer;
			var actors = GetTargetsFromJson(json, world);
			CPos? location;
			location = null;
			var locationJson = json.TryGetFieldValue("location");
			if (locationJson != null)
			{
				location = GetTargetLocation(locationJson, world, player);
			}

			var direction = json.TryGetFieldValue("direction")?.ToObject<string>();
			var distance = json.TryGetFieldValue("distance")?.ToObject<int>();
			var path = json.TryGetFieldValue("path")?.ToList();
			var isAttackMove = json.TryGetFieldValue("isAttackMove")?.ToObject<int>();
			var isAssaultMove = json.TryGetFieldValue("isAssaultMove")?.ToObject<int>();

			if (location != null)
			{
				return MoveActorToLocation(actors, (CPos)location, isAttackMove > 0, isAssaultMove > 0, world);
			}
			else if (direction != null && distance != null)
			{
				return MoveActorInDirection(actors, direction, distance.Value, isAttackMove > 0, isAssaultMove > 0, world);
			}
			else if (path != null)
			{
				return MoveActorInPath(actors, path, isAttackMove > 0, isAssaultMove > 0, world);
			}
			else
			{
				throw new NotImplementedException("Missing parameters for moveactor command");
			}
		}

		public static string MoveActorInDirection(IEnumerable<Actor> actors, string direction, int distance, bool isAttackMove, bool isAssaultMove, World world)
		{
			var num = 0;
			foreach (var actor in actors)
			{
				var move = actor.TraitOrDefault<IMove>();
				if (move == null)
					continue;
				num++;
				var directionVector = CopilotsUtils.GetDirectionVector(direction);
				var targetLocation = actor.Location + directionVector * distance;

				if (!world.Map.Contains(targetLocation))
				{
					TextNotificationsManager.Debug("Target location is out of bounads");
					throw new NotImplementedException("Target location is out of bounads");
				}

				actor.CancelActivity();
				if (isAttackMove || isAssaultMove)
				{
					actor.QueueActivity(new AttackMoveActivity(actor, () => move.MoveTo(targetLocation, 8, null, true), isAssaultMove));
				}
				else
				{
					actor.QueueActivity(move.MoveTo(targetLocation, 5, null, true));
				}
			}

			return $"{num} Actor Moved";
		}

		public static string MoveActorToLocation(IEnumerable<Actor> actors, CPos targetLocation, bool isAttackMove, bool isAssaultMove, World world)
		{
			var num = 0;
			foreach (var actor in actors)
			{
				var move = actor.TraitOrDefault<IMove>();
				if (move == null)
					continue;
				num++;
				actor.CancelActivity();
				if (isAttackMove || isAssaultMove)
				{
					actor.QueueActivity(new AttackMoveActivity(actor, () => move.MoveTo(targetLocation, 8, null, true), isAssaultMove));
				}
				else
				{
					actor.QueueActivity(move.MoveTo(targetLocation, 5, null, true));
				}
			}

			return $"{num} Actor Moved";
		}

		public static string MoveActorInPath(IEnumerable<Actor> actors, List<JToken> path, bool isAttackMove, bool isAssaultMove, World world)
		{
			var num = 0;
			foreach (var actor in actors)
			{
				var move = actor.TraitOrDefault<IMove>();
				if (move == null)
					continue;
				num++;
				var cposPath = new List<CPos>();
				foreach (var c in path)
					cposPath.Add(GetLocation(c));
				if (cposPath[^1] != actor.Location)
				{
					static int ChebyshevDistance(CPos a, CPos b) => Math.Max(Math.Abs(a.X - b.X), Math.Abs(a.Y - b.Y));

					var nearestIdx = -1;
					var shortestDist = int.MaxValue;
					for (var i = 0; i < cposPath.Count; i++)
					{
						var dist = ChebyshevDistance(actor.Location, cposPath[i]);
						if (dist < shortestDist)
						{
							shortestDist = dist;
							nearestIdx = i;
						}
					}

					if (nearestIdx >= 0)
					{
						var pathFinder = actor.World.WorldActor.Trait<PathFinder>();
						var pathToNearest = pathFinder.FindPathToTargetCell(
							actor,
							new[] { actor.Location },
							cposPath[nearestIdx],
							BlockedByActor.Immovable);

						cposPath.RemoveRange(nearestIdx, cposPath.Count - nearestIdx);
						cposPath.InsertRange(nearestIdx, pathToNearest);
					}
				}

				actor.CancelActivity();

				if (isAttackMove || isAssaultMove)
				{
					actor.QueueActivity(new AttackMoveActivity(actor, () => new Move(actor, check => cposPath), isAssaultMove));
				}
				else
				{
					actor.QueueActivity(new Move(actor, check => cposPath));
				}
			}

			return $"{num} Actor Moved";
		}

		public static JObject StartProductionCommand(JObject json, World world)
		{
			var orders = json.TryGetFieldValue("units")?.ToObject<List<JToken>>();
			var player = world.LocalPlayer;
			var ret_str = "";
			var waitId = -1;
			var autoPlace = json.TryGetFieldValue("autoPlaceBuilding")?.ToObject<bool>() ?? false;

			if (orders == null || orders.Count == 0)
			{
				throw new ArgumentException("No units specified for Produnction command");
			}

			var produceMap = new Dictionary<string, int>();
			foreach (var order in orders)
			{
				var unitName = order.TryGetFieldValue("unit_type")?.ToObject<string>();
				var unitNames = CopilotsConfig.GetConfigNameByChinese(unitName);
				var quantity = order.TryGetFieldValue("quantity")?.ToObject<int>();
				if (unitNames == null || quantity == null)
				{
					throw new NotImplementedException("Missing parameters for StartProdunctionCommand");
				}

				var validUnits = unitNames
				.Select(unitName =>
				{
					if (!world.Map.Rules.Actors.TryGetValue(unitName, out var unit))
					{
						ret_str += $"Error!! There is no unit named {unitName}!! \n";
						return null;
					}

					var bi = unit.TraitInfo<BuildableInfo>();
					var queue = bi.Queue
						.SelectMany(oneQueue => AIUtils.FindQueues(player, oneQueue))
						.Where(q => q.CanBuild(unit))
						.ToList();

					if (queue.Count > 0)
					{
						return new { unitName, queue = queue[0] };
					}

					return null;
				})
				.Where(result => result != null)
				.ToList();

				if (validUnits.Count == 1)
				{
					var validUnit = validUnits[0];

					world.IssueOrder(Order.StartProduction(validUnit.queue.Actor, validUnit.unitName, quantity.Value, true, autoPlace));

					ret_str += $"{unitName} built.\n";
					var newWait = Tuple.Create(unitName, quantity.Value);
					produceMap.Add(validUnit.unitName, quantity.Value);
					waitId = CopilotsUtils.AddWaitEvent_Produce(produceMap);
				}
				else
				{
					ret_str += $"No suitable queue found for unit {unitName}.\n";
				}
			}

			var result = new JObject
			{
				["response"] = ret_str,
				["waitId"] = waitId,
			};
			return result;
		}

		public static string CameraMoveCommand(JObject json, World world)
		{
			var worldRenderer = Game.worldRenderer;
			var direction = json.TryGetFieldValue("direction")?.ToObject<string>();
			var distance = json.TryGetFieldValue("distance")?.ToObject<int>();
			var locationToken = json.TryGetFieldValue("location");
			var location = GetTargetLocation(locationToken, world, world.LocalPlayer);
			if ((direction == null || distance == null) && location == null)
			{
				return "No direction Or No Distance Or No Location !!!!!!";
			}

			var directionVector = new CVec(0, 0);
			if (direction != null && distance != null)
				directionVector = CopilotsUtils.GetDirectionVector(direction) * distance.Value;
			if (location != null)
			{
				worldRenderer.Viewport.Center(world.Map.CenterOfCell(location.Value + directionVector));
				return $"Camera moved to {location.Value + directionVector}";
			}

			directionVector *= world.Map.Grid.TileSize.Width;

			// CopilotsUtils.GetDirectionVector(direction) * distance.Value * world.Map.Grid.TileSize.Width;
			worldRenderer.Viewport.Scroll(new float2(directionVector.X, directionVector.Y), true);

			return $"Camera moved {direction} by {distance.Value}.";
		}

		static List<List<byte>> GetTileInfo(World world, Actor actor)
		{
			var map = world.Map;
			var tileInfo = new List<List<byte>>();
			for (var x = 0; x < map.Bounds.Width; x++)
			{
				var tempList = new List<byte>();
				for (var y = 0; y < map.Bounds.Height; y++)
				{
					var pos = new CPos(x, y);

					// var target = Target.FromCell(world, pos);
					var mobile = actor.TraitOrDefault<Mobile>();
					if (mobile == null)
						return null;

					var pathFinder = actor.World.WorldActor.Trait<PathFinder>();
					var locomotor = mobile.Locomotor;
					var canMove = pathFinder.PathExistsForLocomotor(locomotor, actor.Location, pos);

					// 	var orders = actor.TraitsImplementing<IIssueOrder>()
					// .SelectMany(trait => trait.Orders.Select(x => new { Trait = trait, Order = x }))
					// .Where(order => order.Order. == "Move" || order.OrderName == "AttackMove")
					// .Select(x => x)
					// .OrderByDescending(x => x.Order.OrderPriority)
					// .ToList();
					// 	var CanMove = false;
					// 	foreach (var o in orders)
					// 	{
					// 		var localModifiers = TargetModifiers.None;
					// 		string cursor = null;
					// 		if (o.Order.CanTarget(actor, target, ref localModifiers, ref cursor))
					// 			CanMove = true;
					// 	}
					tempList.Add((byte)(canMove ? 0 : 1));

					// var terrainTile = map.Tiles[new MPos(x, y)];
				}

				tileInfo.Add(tempList);
			}

			return tileInfo;
		}

		static List<List<byte>> CompressTileInfo(List<List<byte>> tileInfo, int compressLevel)
		{
			var width = tileInfo.Count;
			var height = tileInfo[0].Count;
			var compressedWidth = (width + compressLevel - 1) / compressLevel;
			var compressedHeight = (height + compressLevel - 1) / compressLevel;

			var compressedTileInfo = new List<List<byte>>();

			for (var x = 0; x < compressedWidth; x++)
			{
				var compressedRow = new List<byte>();
				for (var y = 0; y < compressedHeight; y++)
				{
					var count = 0;
					var total = 0;

					for (var i = 0; i < compressLevel; i++)
					{
						for (var j = 0; j < compressLevel; j++)
						{
							var xi = x * compressLevel + i;
							var yj = y * compressLevel + j;
							if (xi < width && yj < height)
							{
								total++;
								if (tileInfo[xi][yj] == 1)
								{
									count++;
								}
							}
						}
					}

					// 如果1的数量超过50%，则压缩后的格子为1，否则为0
					compressedRow.Add((byte)(count > total / 2 ? 1 : 0));
				}

				compressedTileInfo.Add(compressedRow);
			}

			return compressedTileInfo;
		}

		static CPos? FindClosestEmptyPoint(List<List<byte>> map, int x, int y)
		{
			var centerX = x + 2;
			var centerY = y + 2;
			var minDistance = int.MaxValue;
			CPos? closestPoint = null;

			for (var i = 0; i < 5; i++)
			{
				for (var j = 0; j < 5; j++)
				{
					var checkX = x + i;
					var checkY = y + j;

					if (checkX >= 0 && checkX < map.Count && checkY >= 0 && checkY < map[0].Count && map[checkX][checkY] == 0)
					{
						var distance = Math.Abs(checkX - centerX) + Math.Abs(checkY - centerY);
						if (distance < minDistance)
						{
							minDistance = distance;
							closestPoint = new CPos(checkX, checkY);
						}
					}
				}
			}

			return closestPoint;
		}

		public static string AttackCommand(JObject json, World world)
		{
			var player = world.LocalPlayer;
			var attacker = GetTargets(json["attackers"], world, player).First();
			var target = GetTargetsFromJson(json, world).FirstOrDefault();

			if (attacker == null)
			{
				throw new NotImplementedException("No Attacker");
			}

			if (target == null)
			{
				throw new NotImplementedException("No Attack Target");
			}

			// 是否是多点下令
			const bool Queued = false;
			var tar = Target.FromActor(target);
			_ = tar.Recalculate(attacker.Owner, out var targetIsHiddenActor);
			if (targetIsHiddenActor || !target.CanBeViewedByPlayer(attacker.Owner))
				return "Target is hidden now";

			// throw new NotImplementedException("Target is hidden now");
			world.IssueOrder(new Order("Attack", attacker, tar, Queued));

			return "Attack action executed.";
		}

		public static string DeployCommand(JObject json, World world)
		{
			var actors = GetTargetsFromJson(json, world);
			var selectedDeploys = Array.Empty<TraitPair<IIssueDeployOrder>>();
			selectedDeploys = actors
				.SelectMany(a => a.TraitsImplementing<IIssueDeployOrder>()
				.Select(d => new TraitPair<IIssueDeployOrder>(a, d)))
				.ToArray();

			// 是否是多点下令
			const bool Queued = false;
			var orders = selectedDeploys
				.Where(pair => pair.Trait.CanIssueDeployOrder(pair.Actor, Queued))
				.Select(d => d.Trait.IssueDeployOrder(d.Actor, Queued))
				.Where(d => d != null)
				.ToArray();

			foreach (var o in orders)
				world.IssueOrder(o);

			orders.PlayVoiceForOrders();
			return "Deploy action executed.";
		}

		public static string ViewCommand(JObject json, World world)
		{
			var actorId = json["actorId"]?.ToObject<int>();
			if (actorId == null)
				throw new ArgumentException("Missing actorId for View command");

			var actor = world.Actors.FirstOrDefault(a => a.ActorID == actorId);
			if (actor == null)
				throw new ArgumentException("Actor not found for View command");

			var worldRenderer = Game.worldRenderer;
			worldRenderer.Viewport.Center(world.Map.CenterOfCell(actor.Location));
			return "Camera moved to actor.";
		}

		public static string OccupyCommand(JObject json, World world)
		{
			var player = world.LocalPlayer;
			var actors = GetTargets(json["occupiers"], world, player);
			var targets = GetTargets(json["targets"], world, player);

			var capturers = actors
				.Select(a => new TraitPair<CaptureManager>(a, a.TraitOrDefault<CaptureManager>()))
				.Where(tp => tp.Trait != null)
				.ToArray();

			if (capturers.ToList().Count == 0)
				return "No Capturer";

			var capturableTargetOptions = targets
				.Where(target =>
				{
					var captureManager = target.TraitOrDefault<CaptureManager>();
					if (captureManager == null)
						return false;

					return capturers.Any(tp => tp.Trait.CanTarget(captureManager));
				})
				.OrderByDescending(target => target.GetSellValue());

			var capturableTargetOptionsList = capturableTargetOptions.ToList();
			if (capturableTargetOptionsList.Count == 0)
				return "No Target Can Be Capture";
			foreach (var capturer in capturers)
			{
				var targetActor = capturableTargetOptionsList.ClosestToWithPathFrom(capturer.Actor);
				if (targetActor == null)
					continue;

				world.IssueOrder(new Order("CaptureActor", capturer.Actor, Target.FromActor(targetActor), true));
			}

			return "Order Executed";
		}

		public static string RepairCommand(JObject json, World world)
		{
			var actors = GetTargetsFromJson(json, world);
			var player = world.LocalPlayer;
			foreach (var a in actors)
			{
				if (a.Info.HasTraitInfo<RepairableBuildingInfo>())
					world.IssueOrder(new Order("RepairBuilding", player.PlayerActor, Target.FromActor(a), false));
				else
				{
					Actor repairBuilding = null;
					var orderId = "Repair";

					// Test for generic Repairable (used on units).
					var repairable = a.TraitOrDefault<Repairable>();
					if (repairable != null)
						repairBuilding = repairable.FindRepairBuilding(a);
					else
					{
						var repairableNear = a.TraitOrDefault<RepairableNear>();
						if (repairableNear != null)
						{
							orderId = "RepairNear";
							repairBuilding = repairableNear.FindRepairBuilding(a);
						}
					}

					if (repairBuilding == null)
						continue;

					world.IssueOrder(new Order(orderId, a, Target.FromActor(repairBuilding), Target.FromActor(a), false));
				}
			}

			return "Repair Executed";
		}

		public static string StopCommand(JObject json, World world)
		{
			var actors = GetTargetsFromJson(json, world);
			foreach (var a in actors)
			{
				world.IssueOrder(new Order("Stop", a, false));
			}

			return "Stop Executed";
		}

		public static string SetRallyPointCommand(JObject json, World world)
		{
			var player = world.LocalPlayer;
			var actors = GetTargetsFromJson(json, world);
			var retstr = "";
			var locationToken = json.TryGetFieldValue("location");
			if (locationToken == null)
				throw new ArgumentException("缺少location参数");

			var location = GetTargetLocation(locationToken, world, player);
			if (location == null)
				throw new ArgumentException("无效的集结点位置");
			foreach (var building in actors)
			{
				// 检查该建筑是否有RallyPoint特性
				if (!building.Info.HasTraitInfo<RallyPointInfo>())
				{
					retstr += "建筑(ID:" + building.ActorID + ") 不支持设置集结点\n";
					continue;
				}

				var rallyPoint = building.TraitOrDefault<RallyPoint>();
				if (rallyPoint == null)
				{
					retstr += "建筑(ID:" + building.ActorID + ") 没有集结点\n";
					continue;
				}

				world.IssueOrder(new Order("SetRallyPoint", building, Target.FromCell(world, location.Value), false)
				{
					SuppressVisualFeedback = true
				});

				retstr += "建筑(ID:" + building.ActorID + ") 集结点已设置\n";
			}

			return retstr;
		}

		public static string ManageProductionCommand(JObject json, World world)
		{
			var player = world.LocalPlayer;

			// 获取队列类型
			var queueType = json.TryGetFieldValue("queueType")?.ToString();
			if (string.IsNullOrEmpty(queueType))
				throw new ArgumentException("必须指定queueType参数，可选值：'Building', 'Defense', 'Infantry', 'Vehicle', 'Aircraft', 'Naval'");

			// 查找所有有指定类型生产队列的建筑
			var allWithProduction = world.ActorsWithTrait<ProductionQueue>();
			var validBuildings = allWithProduction
				.Where(q => q.Actor.Owner == player && q.Trait.Info.Type == queueType)
				.Select(q => new { Actor = q.Actor, Queue = q.Trait })
				.ToList();

			if (validBuildings.Count == 0)
				throw new ArgumentException($"玩家没有类型为 {queueType} 的生产队列建筑");

			// 查找有生产项目的队列
			var activeBuilding = validBuildings.FirstOrDefault(b => b.Queue.AllQueued().Any());
			if (activeBuilding == null)
				return "没有正在进行的生产任务";

			var targetQueue = activeBuilding.Queue;
			var building = activeBuilding.Actor;

			// 确保队列有项目
			var queuedItems = targetQueue.AllQueued().ToList();
			if (queuedItems.Count == 0)
				return "生产队列为空";

			// 获取队列中第一个项目
			var firstItem = queuedItems.First();
			if (firstItem == null)
				return "生产队列为空";

			// 获取操作类型
			var action = json.TryGetFieldValue("action")?.ToString();
			if (string.IsNullOrEmpty(action))
				throw new ArgumentException("缺少action参数，必须指定 'pause', 'cancel', 或 'resume'");

			switch (action.ToLowerInvariant())
			{
				case "pause":
					// 暂停生产
					if (firstItem.Paused)
						return "生产已经处于暂停状态";

					world.IssueOrder(Order.PauseProduction(building, firstItem.Item, true));
					return $"已暂停生产: {CopilotsConfig.GetChineseByConfigName(firstItem.Item)}";

				case "resume":
					// 恢复生产
					if (!firstItem.Paused)
						return "生产已经处于进行状态";

					world.IssueOrder(Order.PauseProduction(building, firstItem.Item, false));
					return $"已恢复生产: {CopilotsConfig.GetChineseByConfigName(firstItem.Item)}";

				case "cancel":
					// 取消生产
					world.IssueOrder(Order.CancelProduction(building, firstItem.Item, 1));
					return $"已取消生产: {CopilotsConfig.GetChineseByConfigName(firstItem.Item)}";

				default:
					throw new ArgumentException("无效的action参数，必须是 'pause', 'cancel', 或 'resume'");
			}
		}


		public static string PlaceBuildingCommand(JObject json, World world)
		{
			var player = world.LocalPlayer;

			// 获取队列类型
			var queueType = json.TryGetFieldValue("queueType")?.ToString();
			if (string.IsNullOrEmpty(queueType))
				throw new ArgumentException("必须指定queueType参数，可选值：'Building', 'Defense', 'Infantry', 'Vehicle', 'Aircraft', 'Naval'");

			// 查找所有有指定类型生产队列的建筑
			var allWithProduction = world.ActorsWithTrait<ProductionQueue>();
			var validBuildings = allWithProduction
				.Where(q => q.Actor.Owner == player && q.Trait.Info.Type == queueType)
				.Select(q => new { Actor = q.Actor, Queue = q.Trait })
				.ToList();

			if (validBuildings.Count == 0)
				throw new ArgumentException($"玩家没有类型为 {queueType} 的生产队列建筑");

			// 查找有就绪项目的队列
			ProductionQueue queue = validBuildings.FirstOrDefault().Queue;
			var readyBuilding = queue.AllQueued().Any(item => item.Done);
			if (readyBuilding == null)
				return "没有就绪的建筑可以放置";

			var readyItem = queue.AllQueued().First(item => item.Done);

			// 获取放置位置
			var locationToken = json.TryGetFieldValue("location");
			CPos? location = null;
			
			if (locationToken != null)
			{
				location = GetTargetLocation(locationToken, world, player);
			}

			if (location == null)
			{
				CopilotsUtils.TryBuild(world, readyItem.Item, player.PlayerActor, queue);
				
			}

			// 检查位置是否可建造
			var actorInfo2 = world.Map.Rules.Actors[readyItem.Item];
			var buildingInfo2 = actorInfo2.TraitInfoOrDefault<BuildingInfo>();
			if (!world.CanPlaceBuilding(location.Value, actorInfo2, buildingInfo2, null))
				return "无法在指定位置放置建筑";

			// 放置建筑
			world.IssueOrder(new Order("PlaceBuilding", player.PlayerActor, Target.FromCell(world, location.Value), false)
			{
				TargetString = readyItem.Item,
				ExtraLocation = location.Value,
			});

			return $"已在位置({location.Value.X}, {location.Value.Y})放置建筑: {CopilotsConfig.GetChineseByConfigName(readyItem.Item)}";
		}


		public static JObject PathQueryCommand(JObject json, World world)
		{
			var actors = GetTargetsFromJson(json, world);
			var actor = actors.Last();
			var destination = json.TryGetFieldValue("destination");
			if (destination == null)
			{
				throw new NotImplementedException("Missing parameters destination for Command");
			}

			var desPos = GetLocation(destination);

			var mobile = actor.TraitOrDefault<Mobile>();
			if (mobile == null)
				return null;
			var pathFinder = actor.World.WorldActor.Trait<PathFinder>();
			var locomotor = mobile.Locomotor;
			Func<CPos, int> customCost = null;
			var method = json.TryGetFieldValue("method")?.ToString();
			if (method != null)
			{
				customCost = CopilotsUtils.GetCustomMethod(actor.Location, desPos, method);
			}

			var path = pathFinder.FindPathToTargetCell(actor, new[] { actor.Location }, desPos, BlockedByActor.Immovable, customCost);

			if (path.Count <= 0)
			{
				var dests = new List<CPos>();
				for (var i = -1; i <= 1; i++)
					for (var j = -1; j <= 1; j++)
						dests.Add(new CPos(i + desPos.X, j + desPos.Y));
				path = pathFinder.FindPathToTargetCells(actor, actor.Location, dests, BlockedByActor.Immovable, customCost);
			}

			var pathArray = new JArray();
			foreach (var cpos in path)
			{
				pathArray.Add(new JObject
				{
					["x"] = cpos.X,
					["y"] = cpos.Y
				});
			}

			var result = new JObject
			{
				["path"] = pathArray
			};

			return result;
		}

		public static JObject ActorQueryCommand(JObject json, World world)
		{
			var player = world.LocalPlayer;
			var targets = json.TryGetFieldValue("targets");
			List<Actor> targetActors;
			if (targets == null)
			{
				return null;

				// targetActors = world.Actors.Where(a => a.OccupiesSpace != null).ToList();
			}
			else
			{
				targetActors = GetTargets(targets, world, player);
			}

			var sum = new CPos(0, 0);

			var actorsInfo = targetActors
				.ConvertAll(actor =>
				{
					var hashealth = actor.Info.HasTraitInfo<HealthInfo>();
					var health = actor.TraitOrDefault<Health>();
					return new JObject
					{
						["id"] = actor.ActorID,
						["type"] = CopilotsConfig.GetChineseByConfigName(actor.Info.Name),
						["faction"] = actor.Owner == player ? "己方" : (actor.Owner != null && actor.Owner.IsBot ? "敌方" : "中立"),
						["hp"] = hashealth ? health.HP : -1,
						["maxHp"] = hashealth ? health.MaxHP : -1,
						["isDead"] = hashealth && health.IsDead,
						["position"] = new JObject
						{
							["x"] = actor.Location.X,
							["y"] = actor.Location.Y
						}
					};
				});

			var result = new JObject
			{
				// ["status"] = "success",
				["actors"] = new JArray(actorsInfo)
			};

			return result;
		}

		public static JObject WaitQueryCommand(JObject json, World world)
		{
			var waitId = json.TryGetFieldValue("waitId")?.ToObject<int>();
			if (waitId == null)
			{
				return null;
			}

			var result = new JObject
			{
				["waitStatus"] = CopilotsUtils.QueryWaitStatus(waitId.Value)
			};

			return result;
		}


		public static JObject QueryCanProduceCommand(JObject json, World world)
		{
			var orders = json.TryGetFieldValue("units")?.ToObject<List<JToken>>();
			var player = world.LocalPlayer;
			var ret_str = "";
			var canProduce = false;

			if (orders == null || orders.Count == 0)
			{
				throw new ArgumentException("No units specified for CanProduce command");
			}

			var produceMap = new Dictionary<string, int>();
			foreach (var order in orders)
			{
				var unitName = order.TryGetFieldValue("unit_type")?.ToObject<string>();
				var unitNames = CopilotsConfig.GetConfigNameByChinese(unitName);
				if (unitNames == null)
				{
					throw new NotImplementedException("Missing parameters for QueryCanProduceCommand");
				}

				var validUnits = unitNames
				.Select(unitName =>
				{
					if (!world.Map.Rules.Actors.TryGetValue(unitName, out var unit))
					{
						ret_str += $"Error!! There is no unit named {unitName}!! \n";
						return null;
					}

					var bi = unit.TraitInfo<BuildableInfo>();
					var queue = bi.Queue
					.SelectMany(oneQueue => AIUtils.FindQueues(player, oneQueue))
					.Where(q => q.CanBuild(unit))
					.ToList();

					if (queue.Count > 0)
					{
						return unitName;
					}

					return null;
				})
				.Where(result => result != null)
				.ToList();

				if (validUnits.Count == 1)
				{
					canProduce = true;
				}
				else
				{
					ret_str += $"No suitable queue found for unit {unitName}.\n";
				}
			}

			var result = new JObject
			{
				["response"] = ret_str,
				["canProduce"] = canProduce,
			};
			return result;
		}

		public static JObject FogQueryCommand(JObject json, World world)
		{
			var jpos = json.TryGetFieldValue("pos");
			if (jpos == null)
			{
				throw new NotImplementedException("Missing parameters pos for command");
			}

			var pos = GetLocation(jpos);

			var result = new JObject
			{
				["IsVisible"] = world.FogObscures(pos),
				["IsExplored"] = world.ShroudObscures(pos)
			};
			return result;
		}

		public static JObject MapQueryCommand(JObject json, World world)
		{
			var map = world.Map;
			var width = map.MapSize.X;
			var height = map.MapSize.Y;

			// 初始化二维数组
			var heightArray = new JArray();
			var isVisibleArray = new JArray();
			var isExploredArray = new JArray();
			var terrainArray = new JArray();
			var resourcesTypeArray = new JArray();
			var resourcesArray = new JArray();

			for (var x = 0; x < width; x++)
			{
				var heightRow = new JArray();
				var isVisibleRow = new JArray();
				var isExploredRow = new JArray();
				var terrainRow = new JArray();
				var resourcesTypeRow = new JArray();
				var resourcesRow = new JArray();

				for (var y = 0; y < height; y++)
				{
					var pos = new CPos(x, y);
					heightRow.Add(map.Height[pos]);
					isVisibleRow.Add(!world.FogObscures(pos));
					isExploredRow.Add(!world.ShroudObscures(pos));
					terrainRow.Add(map.Tiles[pos].Type);
					resourcesTypeRow.Add(map.Resources[pos].Type);
					resourcesRow.Add(map.Resources[pos].Index);
				}

				heightArray.Add(heightRow);
				isVisibleArray.Add(isVisibleRow);
				isExploredArray.Add(isExploredRow);
				terrainArray.Add(terrainRow);
				resourcesTypeArray.Add(resourcesTypeRow);
				resourcesArray.Add(resourcesRow);
			}

			var result = new JObject
			{
				["MapWidth"] = width,
				["MapHeight"] = height,
				["Height"] = heightArray,
				["IsVisible"] = isVisibleArray,
				["IsExplored"] = isExploredArray,
				["Terrain"] = terrainArray,
				["ResourcesType"] = resourcesTypeArray,
				["Resources"] = resourcesArray
			};

			return result;
		}

		public static JObject UnitAttributeQueryCommand(JObject json, World world)
		{
			var actors = GetTargetsFromJson(json, world);

			// 获取攻击范围内的单位
			var actorIds = new List<uint>();
			foreach (var a in actors)
			{
				var autoTarget = a.TraitOrDefault<AutoTarget>();
				if (autoTarget != null)
				{
					var t = autoTarget.ScanForTarget(a, true, true, true);
					if (t.Type == TargetType.Actor)
						actorIds.Add(t.Actor.ActorID);
				}
			}

			// 获取单位属性（目前为占位符，可扩展添加更多属性）
			var attributes = actors.Select(a => new JObject
			{
				["id"] = a.ActorID,
				["type"] = CopilotsConfig.GetChineseByConfigName(a.Info.Name),
				["speed"] = a.TraitOrDefault<Mobile>()?.Info.Speed ?? 0,
				["hasAttackRange"] = a.TraitOrDefault<AutoTarget>() != null,
				["targets"] = new JArray(actorIds)
			}).ToArray();

			var result = new JObject
			{
				["attributes"] = new JArray(attributes)
			};
			return result;
		}

		public static JObject PingCommand(JObject json, World world)
		{
			// 简单返回服务器状态和API版本
			var result = new JObject
			{
				["timestamp"] = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
			};

			return result;
		}

		public static JObject PlayerBaseInfoQueryCommand(JObject json, World world)
		{
			var player = world.LocalPlayer;
			var playerRes = player.PlayerActor.Trait<PlayerResources>();
			var powerManager = player.PlayerActor.Trait<PowerManager>();
			if (playerRes == null || powerManager == null)
				throw new NotImplementedException("PlayerResources or PowerManager trait not found.");
			var result = new JObject
			{
				["Cash"] = playerRes.Cash,
				["Resources"] = playerRes.Resources,
				["Power"] = powerManager.ExcessPower,
				["PowerDrained"] = powerManager.PowerDrained,
				["PowerProvided"] = powerManager.PowerProvided
			};

			return result;
		}

		public static JObject ScreenInfoQueryCommand(JObject json, World world)
		{
			var wr = Game.worldRenderer;
			var viewport = wr.Viewport;

			var screenMin = ((MPos)viewport.VisibleCellsInsideBounds.TopLeft).ToCPos(world.Map);
			var screenMax = ((MPos)viewport.VisibleCellsInsideBounds.BottomRight).ToCPos(world.Map);

			var mousePos = world.Map.CellContaining(wr.ProjectedPosition(viewport.ViewToWorldPx(Game.Cursor.GetMousePos())));

			var isMouseOnScreen = mousePos.X >= screenMin.X && mousePos.X <= screenMax.X &&
								   mousePos.Y >= screenMin.Y && mousePos.Y <= screenMax.Y;

			// 返回结果
			var result = new JObject
			{
				["ScreenMin"] = new JObject
				{
					["X"] = screenMin.X,
					["Y"] = screenMin.Y
				},
				["ScreenMax"] = new JObject
				{
					["X"] = screenMax.X,
					["Y"] = screenMax.Y
				},
				["IsMouseOnScreen"] = isMouseOnScreen,
				["MousePosition"] = new JObject
				{
					["X"] = mousePos.X,
					["Y"] = mousePos.Y
				}
			};

			return result;
		}

		public static JObject QueryProductionQueueCommand(JObject json, World world)
		{
			var player = world.LocalPlayer;

			// 获取队列类型
			var queueType = json.TryGetFieldValue("queueType")?.ToString();
			if (string.IsNullOrEmpty(queueType))
				throw new ArgumentException("必须指定queueType参数，可选值：'Building', 'Defense', 'Infantry', 'Vehicle', 'Aircraft', 'Naval'");

			// 获取所有带有 ProductionQueue trait 的 actor
			var allWithProduction = world.ActorsWithTrait<ProductionQueue>();

			// 过滤出指定玩家且类型为指定建筑的 actor
			var filteredByOwnerAndName = allWithProduction
				.Where(q => q.Actor.Owner == player && q.Trait.Info.Type == queueType);

			// 提取出对应的 ProductionQueue trait
			var allQueues = filteredByOwnerAndName
				.Select(q => q.Trait)
				.ToList();

			if (allQueues.Count == 0)
				throw new ArgumentException($"玩家没有类型为 {queueType} 的生产队列");

			// 从所有队列中获取项目信息
			var allItems = allQueues.SelectMany(queue => queue.AllQueued()).ToList();

			var itemsInfo = allItems.Select((item, index) => new JObject
			{
				["name"] = item.Item,
				["chineseName"] = CopilotsConfig.GetChineseByConfigName(item.Item),
				["remaining_time"] = item.RemainingTime,
				["total_time"] = item.TotalTime,
				["remaining_cost"] = item.RemainingCost,
				["total_cost"] = item.TotalCost,
				["paused"] = item.Paused,
				["done"] = item.Done,
				["progress_percent"] = item.TotalCost > 0 ?
					(int)((item.TotalCost - item.RemainingCost) * 100 / item.TotalCost) : 0,
				["owner_actor_id"] = item.Queue.Actor.ActorID,
				["status"] = item.Done ? "completed" : 
					item.Paused ? "paused" : 
					index == 0 ? "in_progress" : "waiting"
			}).ToArray();

			var result = new JObject
			{
				["queue_type"] = queueType,
				["queue_items"] = new JArray(itemsInfo),
				["has_ready_item"] = allItems.Any(item => item.Done)
			};

			return result;
		}



		public void WorldLoaded(World w, WorldRenderer wr)
		{
			if (w.Type == WorldType.Regular && w.CopilotServer != null)
			{
				w.CopilotServer.CommandHandlers["move_actor"] = MoveActorCommand;
				w.CopilotServer.CommandHandlers["camera_move"] = CameraMoveCommand;
				w.CopilotServer.CommandHandlers["select_unit"] = SelectUnitCommand;
				w.CopilotServer.CommandHandlers["form_group"] = FormGroupCommand;
				w.CopilotServer.CommandHandlers["attack"] = AttackCommand;
				w.CopilotServer.CommandHandlers["deploy"] = DeployCommand;
				w.CopilotServer.CommandHandlers["view"] = ViewCommand;
				w.CopilotServer.CommandHandlers["occupy"] = OccupyCommand;
				w.CopilotServer.CommandHandlers["repair"] = RepairCommand;
				w.CopilotServer.CommandHandlers["stop"] = StopCommand;
				w.CopilotServer.CommandHandlers["set_rally_point"] = SetRallyPointCommand;

				w.CopilotServer.CommandHandlers["place_building"] = PlaceBuildingCommand;
				w.CopilotServer.CommandHandlers["manage_production"] = ManageProductionCommand;
				w.CopilotServer.QueryHandlers["start_production"] = StartProductionCommand;

				w.CopilotServer.QueryHandlers["query_actor"] = ActorQueryCommand;
				w.CopilotServer.QueryHandlers["query_wait_info"] = WaitQueryCommand;
				w.CopilotServer.QueryHandlers["query_path"] = PathQueryCommand;
				w.CopilotServer.QueryHandlers["query_can_produce"] = QueryCanProduceCommand;
				w.CopilotServer.QueryHandlers["query_production_queue"] = QueryProductionQueueCommand;
				w.CopilotServer.QueryHandlers["map_query"] = MapQueryCommand;
				w.CopilotServer.QueryHandlers["fog_query"] = FogQueryCommand;
				w.CopilotServer.QueryHandlers["unit_attribute_query"] = UnitAttributeQueryCommand;
				w.CopilotServer.QueryHandlers["player_baseinfo_query"] = PlayerBaseInfoQueryCommand;
				w.CopilotServer.QueryHandlers["screen_info_query"] = ScreenInfoQueryCommand;
				w.CopilotServer.QueryHandlers["ping"] = PingCommand;

				CopilotsConfig.LoadConfig();
				CopilotsUtils.WaitInit();
			}
		}

		public void Tick(Actor self)
		{
		}
	}
}
