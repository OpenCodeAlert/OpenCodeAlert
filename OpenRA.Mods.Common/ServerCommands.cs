using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using OpenRA.Graphics;
using OpenRA.Mods.Common.Traits;
using OpenRA.Mods.Common.Widgets;
using OpenRA.Support;
using OpenRA.Traits;
using System;
using System.Collections.Generic;
using System.Linq;
namespace OpenRA.Mods.Common.Commands
{
	[TraitLocation(SystemActors.World)]
	[Desc("Attach this to the world actor.")]
	public class ServerCommandsInfo : TraitInfo<ServerCommands> { }
	public class ServerCommands : IWorldLoaded, ITick
	{

		public static bool IsFactionOk(Player player, Actor actor, string faction)
		{
			if (faction is "己方" or "自己" or "我" or "我的" or "我方")
				return CopilotsUtils.GetFactionRelation(player, actor) == "己方";
			else if (faction is "敌方" or "敌人" or "对面" or "他的" or "他")
				return CopilotsUtils.GetFactionRelation(player, actor) == "敌方";
			else if (faction == "中立")
				return CopilotsUtils.GetFactionRelation(player, actor) == "中立";
			else if (faction is "友方" or "盟军" or "盟友" or "同盟")
				return CopilotsUtils.GetFactionRelation(player, actor) == "友方";
			else
				return actor.OccupiesSpace != null;
		}

		public static Player ResolvePlayer(JObject json, World world)
		{
			var playerId = json?.TryGetFieldValue("__playerId")?.ToString();
			if (!string.IsNullOrEmpty(playerId))
			{
				var byName = world.Players.FirstOrDefault(p => p.InternalName == playerId && IsPlayerContextValid(p));
				if (byName != null)
					return byName;
			}

			if (IsPlayerContextValid(world.LocalPlayer))
				return world.LocalPlayer;

			if (IsPlayerContextValid(world.RenderPlayer))
				return world.RenderPlayer;

			var fallback = world.Players.FirstOrDefault(p => !p.NonCombatant && IsPlayerContextValid(p));
			if (fallback != null)
				return fallback;

			throw new InvalidOperationException("No valid in-world player context available.");
		}

		static bool IsPlayerContextValid(Player player)
		{
			return player != null
				&& player.PlayerActor != null
				&& !player.PlayerActor.Disposed
				&& player.PlayerActor.IsInWorld;
		}

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
			actors = world.Actors.Where(a => IsFactionOk(player, a, faction) && a.OccupiesSpace != null);

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
			var player = ResolvePlayer(json, world);
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
			var player = ResolvePlayer(json, world);
			var isCombine = json.TryGetFieldValue("isCombine")?.ToObject<int>();
			var actors = GetTargetsFromJson(json, world);
			var newSelection = SelectionUtils.SelectActorsByOwnerAndSelectionClass(actors, new List<Player> { player }, null).ToList();
			world.Selection.Combine(world, newSelection, isCombine > 0, false);
			return "Actor Selected";
		}

		public static string FormGroupCommand(JObject json, World world)
		{
			var player = ResolvePlayer(json, world);
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
			var player = ResolvePlayer(json, world);
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
			if (!actors.Any())
			{
				return "No Actor";
			}
			var firstActor = actors.FirstOrDefault();
			var directionVector = CopilotsUtils.GetDirectionVector(direction);
			var targetLocation = firstActor.Location + directionVector * distance;

			var groupedIds = actors.Select(a => (int)a.ActorID).ToArray();

			CopilotBus.Enqueue(new IssueOrderIntent
			{
				OrderId = isAttackMove || isAssaultMove ? "AttackMove" : "Move",
				SubjectActorId = null,
				TargetA = TargetSpec.FromCell(targetLocation),
				TargetB = TargetSpec.None(),
				Queued = false,
				GroupedActorIds = groupedIds
			});

			return $"{groupedIds.Length}　Actor Moved";
		}

		public static string MoveActorToLocation(IEnumerable<Actor> actors, CPos targetLocation, bool isAttackMove, bool isAssaultMove, World world)
		{
			actors = actors.Where(a => a.TraitOrDefault<IMove>() != null);
			var groupedIds = actors.Select(a => (int)a.ActorID).ToArray();
			CopilotBus.Enqueue(new IssueOrderIntent
			{
				OrderId = isAttackMove || isAssaultMove ? "AttackMove" : "Move",
				SubjectActorId = null,
				TargetA = TargetSpec.FromCell(targetLocation),
				TargetB = TargetSpec.None(),
				Queued = false,
				GroupedActorIds = groupedIds
			});

			return $"{groupedIds.Length} Actor Moved";
		}

		public static string MoveActorInPath(IEnumerable<Actor> actors, List<JToken> path, bool isAttackMove, bool isAssaultMove, World world)
		{
			if (path.Count == 0)
			{
				throw new NotImplementedException("Missing parameters for moveactor command");
			}

			actors = actors.Where(a => a.TraitOrDefault<IMove>() != null);

			// 将输入的路径点转换为 CPos
			var inputPath = new List<CPos>();
			foreach (var c in path)
				inputPath.Add(GetLocation(c));
			var groupedIds = actors.Select(a => (int)a.ActorID).ToArray();
			for (var i = 0; i < inputPath.Count; i++)
			{
				var targetPos = inputPath[i];
				CopilotBus.Enqueue(new IssueOrderIntent
				{
					OrderId = "Move",
					SubjectActorId = null,
					TargetA = TargetSpec.FromCell(targetPos),
					TargetB = TargetSpec.None(),
					Queued = true,
					GroupedActorIds = groupedIds
				});
			}

			return $"{groupedIds.Length} Actor Moved";
		}

		public static JObject StartProductionCommand(JObject json, World world)
		{
			var orders = json.TryGetFieldValue("units")?.ToObject<List<JToken>>();
			var player = ResolvePlayer(json, world);
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

					var buildingId = (int)validUnit.queue.Actor.ActorID;
					CopilotBus.Enqueue(new IssueOrderIntent
					{
						Factory = "StartProduction",
						SubjectActorId = buildingId,
						FactoryItem = validUnit.unitName,
						FactoryCount = quantity.Value,
						ExtraData = autoPlace ? 1 : 0
					});

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
			var player = ResolvePlayer(json, world);
			var location = GetTargetLocation(locationToken, world, player);
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
			var player = ResolvePlayer(json, world);
			var attacker = GetTargets(json["attackers"], world, player);
			var target = GetTargetsFromJson(json, world);

			if (attacker == null)
			{
				throw new NotImplementedException("No Attacker");
			}

			if (target == null)
			{
				throw new NotImplementedException("No Attack Target");
			}

			var ret_str = "";
			MersenneTwister random = new();
			foreach (var a in attacker)
			{
				var taractor = target.RandomOrDefault(random);
				var tar = Target.FromActor(taractor);
				_ = tar.Recalculate(a.Owner, out var targetIsHiddenActor);
				if (targetIsHiddenActor || !taractor.CanBeViewedByPlayer(a.Owner))
				{
					ret_str += $"Target is hidden now {tar.Actor.ActorID}\n";
					continue;
				}
				CopilotBus.Enqueue(new IssueOrderIntent
				{
					OrderId = "Attack",
					SubjectActorId = (int)a.ActorID,
					TargetA = TargetSpec.FromActorId((int)tar.Actor.ActorID),
					TargetB = TargetSpec.None(),
					Queued = false
				});
				ret_str += $"Attack {a.ActorID} to {tar.Actor.ActorID}\n";
			}

			return ret_str;
		}

		public static string DeployCommand(JObject json, World world)
		{
			var actors = GetTargetsFromJson(json, world);

			var harvs = actors.Where(a => a.Info.HasTraitInfo<HarvesterInfo>()).ToList();
			if (harvs.Count > 0)
			{
				foreach (var h in harvs)
				{
					CopilotBus.Enqueue(new IssueOrderIntent { OrderId = "Stop", SubjectActorId = (int)h.ActorID });
					CopilotBus.Enqueue(new IssueOrderIntent { SubjectActorId = (int)h.ActorID, OrderId = "Harvest" });
				}
				return "Deploy action executed.";
			}

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
			{
				var subjectId = o.Subject != null ? (int)o.Subject.ActorID : (int?)null;
				var tA = o.Target.Type == TargetType.Actor ? TargetSpec.FromActorId((int)o.Target.Actor.ActorID)
					: TargetSpec.None();
				CopilotBus.Enqueue(new IssueOrderIntent
				{
					OrderId = o.OrderString,
					SubjectActorId = subjectId,
					TargetA = tA,
					TargetB = TargetSpec.None(),
					Queued = o.Queued
				});
			}

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
			var player = ResolvePlayer(json, world);
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

				CopilotBus.Enqueue(new IssueOrderIntent
				{
					OrderId = "CaptureActor",
					SubjectActorId = (int)capturer.Actor.ActorID,
					TargetA = TargetSpec.FromActorId((int)targetActor.ActorID),
					TargetB = TargetSpec.None(),
					Queued = true
				});
			}

			return "Order Executed";
		}

		public static string RepairCommand(JObject json, World world)
		{
			var actors = GetTargetsFromJson(json, world);
			var player = ResolvePlayer(json, world);
			foreach (var a in actors)
			{
				if (a.Info.HasTraitInfo<RepairableBuildingInfo>())
					CopilotBus.Enqueue(new IssueOrderIntent
					{
						OrderId = "RepairBuilding",
						SubjectActorId = (int)player.PlayerActor.ActorID,
						TargetA = TargetSpec.FromActorId((int)a.ActorID),
						TargetB = TargetSpec.None(),
						Queued = false
					});
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

					CopilotBus.Enqueue(new IssueOrderIntent
					{
						OrderId = orderId,
						SubjectActorId = (int)a.ActorID,
						TargetA = TargetSpec.FromActorId((int)repairBuilding.ActorID),
						TargetB = TargetSpec.FromActorId((int)a.ActorID),
						Queued = false
					});
				}
			}

			return "Repair Executed";
		}

		public static string StopCommand(JObject json, World world)
		{
			var actors = GetTargetsFromJson(json, world);
			foreach (var a in actors)
			{
				CopilotBus.Enqueue(new IssueOrderIntent
				{
					OrderId = "Stop",
					SubjectActorId = (int)a.ActorID,
					TargetA = TargetSpec.None(),
					TargetB = TargetSpec.None(),
					Queued = false
				});
			}

			return "Stop Executed";
		}

		public static string SetRallyPointCommand(JObject json, World world)
		{
			var player = ResolvePlayer(json, world);
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

				CopilotBus.Enqueue(new IssueOrderIntent
				{
					OrderId = "SetRallyPoint",
					SubjectActorId = (int)building.ActorID,
					TargetA = TargetSpec.FromCell(location.Value),
					TargetB = TargetSpec.None(),
					Queued = false,
					SuppressVisualFeedback = true
				});

				retstr += "建筑(ID:" + building.ActorID + ") 集结点已设置\n";
			}

			return retstr;
		}

		public static string ManageProductionCommand(JObject json, World world)
		{
			var player = ResolvePlayer(json, world);

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

			var ownerActorId = json.TryGetFieldValue("ownerActorId")?.ToObject<int?>();
			var itemName = json.TryGetFieldValue("itemName")?.ToObject<string>();
			var count = json.TryGetFieldValue("count")?.ToObject<int?>() ?? 1;

			// 查找有生产项目的队列
			var activeBuilding = ownerActorId.HasValue
				? validBuildings.FirstOrDefault(b => (int)b.Actor.ActorID == ownerActorId.Value)
				: validBuildings.FirstOrDefault(b => b.Queue.AllQueued().Any());
			if (activeBuilding == null)
				return ownerActorId.HasValue ? $"未找到 ownerActorId={ownerActorId.Value} 的生产队列建筑" : "没有正在进行的生产任务";

			var targetQueue = activeBuilding.Queue;
			var building = activeBuilding.Actor;

			// 确保队列有项目
			var queuedItems = targetQueue.AllQueued().ToList();
			if (queuedItems.Count == 0)
				return "生产队列为空";

			// 默认使用队列中的第一个项目；如果指定 itemName，则对该 item 操作
			var firstItem = !string.IsNullOrEmpty(itemName)
				? queuedItems.FirstOrDefault(i => i.Item == itemName)
				: queuedItems.First();
			if (firstItem == null)
				return !string.IsNullOrEmpty(itemName)
					? $"生产队列中没有项目: {CopilotsConfig.GetChineseByConfigName(itemName)}"
					: "生产队列为空";

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

					CopilotBus.Enqueue(new IssueOrderIntent
					{
						Factory = "PauseProduction",
						SubjectActorId = (int)building.ActorID,
						FactoryItem = firstItem.Item,
						FactoryCount = 1
					});
					return $"已暂停生产: {CopilotsConfig.GetChineseByConfigName(firstItem.Item)}";

				case "resume":
					// 恢复生产
					if (!firstItem.Paused)
						return "生产已经处于进行状态";

					CopilotBus.Enqueue(new IssueOrderIntent
					{
						Factory = "PauseProduction",
						SubjectActorId = (int)building.ActorID,
						FactoryItem = firstItem.Item,
						FactoryCount = 0
					});
					return $"已恢复生产: {CopilotsConfig.GetChineseByConfigName(firstItem.Item)}";

				case "cancel":
					// 取消生产
					CopilotBus.Enqueue(new IssueOrderIntent
					{
						Factory = "CancelProduction",
						SubjectActorId = (int)building.ActorID,
						FactoryItem = firstItem.Item,
						FactoryCount = count
					});
					return $"已取消生产: {CopilotsConfig.GetChineseByConfigName(firstItem.Item)} x{count}";

				default:
					throw new ArgumentException("无效的action参数，必须是 'pause', 'cancel', 或 'resume'");
			}
		}


		public static string PlaceBuildingCommand(JObject json, World world)
		{
			var player = ResolvePlayer(json, world);

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

			var ownerActorId = json.TryGetFieldValue("ownerActorId")?.ToObject<int?>();
			var targetBuilding = ownerActorId.HasValue
				? validBuildings.FirstOrDefault(b => (int)b.Actor.ActorID == ownerActorId.Value)
				: validBuildings.FirstOrDefault(b => b.Queue.AllQueued().Any(item => item.Done));
			if (targetBuilding == null)
				return ownerActorId.HasValue ? $"ownerActorId={ownerActorId.Value} 队列中没有就绪建筑" : "没有就绪的建筑可以放置";

			var buildingActor = targetBuilding.Actor;
			ProductionQueue queue = targetBuilding.Queue;
			var readyItem = queue.AllQueued().FirstOrDefault(item => item.Done);
			if (readyItem == null)
				return ownerActorId.HasValue ? $"ownerActorId={ownerActorId.Value} 队列中没有就绪建筑" : "没有就绪的建筑可以放置";

			// 获取放置位置
			var locationToken = json.TryGetFieldValue("location");
			CPos? location = null;

			if (locationToken != null)
			{
				location = GetTargetLocation(locationToken, world, player);
			}

			if (location == null)
			{
				if (!CopilotsUtils.TryBuildIntent(world, readyItem.Item, player.PlayerActor, queue))
					throw new InvalidOperationException($"无法自动放置建筑: {CopilotsConfig.GetChineseByConfigName(readyItem.Item)}");
				return $"已尝试自动放置建筑: {CopilotsConfig.GetChineseByConfigName(readyItem.Item)}";
			}

			// 检查位置是否可建造
			var actorInfo2 = world.Map.Rules.Actors[readyItem.Item];
			var buildingInfo2 = actorInfo2.TraitInfoOrDefault<BuildingInfo>();
			if (!world.CanPlaceBuilding(location.Value, actorInfo2, buildingInfo2, null))
				return "无法在指定位置放置建筑";

			// 放置建筑
			CopilotBus.Enqueue(new IssueOrderIntent
			{
				OrderId = "PlaceBuilding",
				SubjectActorId = (int)player.PlayerActor.ActorID,
				TargetA = TargetSpec.FromCell(location.Value),
				TargetB = TargetSpec.None(),
				Queued = false,
				TargetString = readyItem.Item,
				ExtraLocation = location.Value,
				ExtraData = (int)buildingActor.ActorID
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

		public static IEnumerable<JObject> QueryFrozenActors(JToken targets, World world, Player player,
	string range, IReadOnlyCollection<string> types)
		{
			var result = new List<JObject>();


			// 1) 取玩家的 FrozenActorLayer
			var layer = player.PlayerActor.TraitOrDefault<FrozenActorLayer>();
			if (layer == null)
				return result;

			var faction = targets["faction"]?.ToString() ?? "己方";
			var viewport = Game.worldRenderer.Viewport;

			var dis = new WDist(307200);
			foreach (var eachFrozenActor in layer.FrozenActorsInCircle(world, WPos.Zero, dis))
			{
				var id = -1;
				var frozenActor = eachFrozenActor;
				var info = frozenActor.Info;
				var owner = frozenActor.Owner;
				var center = frozenActor.CenterPosition;
				var loc = world.Map.CellContaining(center);
				var infoName = info.Name;
				var wpos = center;
				var relationOk = IsFactionOk(player, owner.PlayerActor, "敌方");

				var typeOk = types == null || types.Count == 0 || types.Contains(infoName);

				var rangeOk = range switch
				{
					"screen" => CopilotsUtils.IsVisibleInViewport(Game.worldRenderer, world.Map.CenterOfCell(loc)),
					"selected" => false, // Frozen 残像不在选中集里，直接 false
					_ => true
				};

				if (!(relationOk && typeOk && rangeOk)) continue;

				result.Add(new JObject
				{
					["id"] = id,
					["isFrozen"] = true,
					["type"] = CopilotsConfig.GetChineseByConfigName(infoName),
					["faction"] = CopilotsUtils.GetFactionRelation(player, owner.PlayerActor),
					["hp"] = -1,
					["maxHp"] = -1,
					["isDead"] = false,
					["position"] = new JObject
					{
						["x"] = loc.X,
						["y"] = loc.Y
					}
				});
			}

			return result;
		}

		public static JObject ActorQueryCommand(JObject json, World world)
		{
			var player = ResolvePlayer(json, world);
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
					var activity = actor.CurrentActivity;
					var lastOrder = actor.TraitOrDefault<TrackLastResolvedOrder>();
					return new JObject
					{
						["id"] = actor.ActorID,
						["isFrozen"] = false,
						["type"] = CopilotsConfig.GetChineseByConfigName(actor.Info.Name),
						["faction"] = CopilotsUtils.GetFactionRelation(player, actor),
						["hp"] = hashealth ? health.HP : -1,
						["maxHp"] = hashealth ? health.MaxHP : -1,
						["isDead"] = hashealth && health.IsDead,
						// 与调试红字 RenderDebugState 一致：Activity.DebugLabelComponents().JoinWith(".")
						["activity"] = activity != null ? activity.DebugLabelComponents().JoinWith(".") : "",
						// OpenRA 默认不提供“当前 order”的直接读取，这里返回最近一次 ResolveOrder 记录到 trait 的值
						["order"] = lastOrder?.LastOrderLabel ?? "",
						["position"] = new JObject
						{
							["x"] = actor.Location.X,
							["y"] = actor.Location.Y
						}
					};
				});

			var range = targets["range"]?.ToString() ?? "all";
			var groupIds = targets["groupId"]?.ToObject<List<int>>() ?? new List<int>();
			var rawtypes = targets["type"]?.ToObject<List<string>>() ?? new List<string>();
			var faction = targets["faction"]?.ToString() ?? "己方";
			var types = new List<string>();
			foreach (var type in rawtypes)
			{
				types.AddRange(CopilotsConfig.GetConfigNameByChinese(type));
			}

			var frozenActors = QueryFrozenActors(targets, world, player, range, types);

			var result = new JObject
			{
				// ["status"] = "success",
				["actors"] = new JArray(actorsInfo),
				["frozenActors"] = new JArray(frozenActors)
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
			var player = ResolvePlayer(json, world);
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
			var player = ResolvePlayer(json, world);
			var jpos = json.TryGetFieldValue("pos");
			if (jpos == null)
			{
				throw new NotImplementedException("Missing parameters pos for command");
			}

			var pos = GetLocation(jpos);

			var result = new JObject
			{
				["IsVisible"] = player.Shroud.IsVisible(pos),
				["IsExplored"] = player.Shroud.IsExplored(pos)
			};
			return result;
		}

		public static JObject MapQueryCommand(JObject json, World world)
		{
			var player = ResolvePlayer(json, world);
			var map = world.Map;
			var width = map.MapSize.X - 2;
			var height = map.MapSize.Y - 2;

			// Optional field filter — when set, only requested fields are returned.
			HashSet<string> fields = null;
			var fieldsToken = json["params"]?["fields"] as JArray;
			if (fieldsToken != null)
				fields = new HashSet<string>(fieldsToken.Select(t => t.ToString()));

			var needHeight = fields == null || fields.Contains("Height");
			var needIsVisible = fields == null || fields.Contains("IsVisible");
			var needIsExplored = fields == null || fields.Contains("IsExplored");
			var needTerrain = fields == null || fields.Contains("Terrain");
			var needResourcesType = fields == null || fields.Contains("ResourcesType");
			var needResources = fields == null || fields.Contains("Resources");
			var needIsExploredPacked = fields != null && fields.Contains("IsExplored_packed");
			var needIsVisiblePacked = fields != null && fields.Contains("IsVisible_packed");

			// Always compute explored_pct (almost free during traversal).
			var exploredCount = 0;
			var totalCells = width * height;

			// Bitpack arrays: each int holds 32 bools.
			int[] exploredPacked = needIsExploredPacked ? new int[(totalCells + 31) / 32] : null;
			int[] visiblePacked = needIsVisiblePacked ? new int[(totalCells + 31) / 32] : null;

			// 2D arrays — only allocate when needed.
			JArray heightArray = needHeight ? new JArray() : null;
			JArray isVisibleArray = needIsVisible ? new JArray() : null;
			JArray isExploredArray = needIsExplored ? new JArray() : null;
			JArray terrainArray = needTerrain ? new JArray() : null;
			JArray resourcesTypeArray = needResourcesType ? new JArray() : null;
			JArray resourcesArray = needResources ? new JArray() : null;

			var bitIdx = 0;
			for (var x = 1; x <= width; x++)
			{
				JArray heightRow = needHeight ? new JArray() : null;
				JArray isVisibleRow = needIsVisible ? new JArray() : null;
				JArray isExploredRow = needIsExplored ? new JArray() : null;
				JArray terrainRow = needTerrain ? new JArray() : null;
				JArray resourcesTypeRow = needResourcesType ? new JArray() : null;
				JArray resourcesRow = needResources ? new JArray() : null;

				for (var y = 1; y <= height; y++)
				{
					var pos = new CPos(x, y);
					var explored = player.Shroud.IsExplored(pos);
					if (explored) exploredCount++;

					if (needHeight) heightRow.Add(map.Height[pos]);
					if (needIsVisible)
					{
						var vis = player.Shroud.IsVisible(pos);
						isVisibleRow.Add(vis);
					}
					if (needIsExplored) isExploredRow.Add(explored);
					if (needTerrain) terrainRow.Add(map.Tiles[pos].Type);
					if (needResourcesType) resourcesTypeRow.Add(map.Resources[pos].Type);
					if (needResources) resourcesRow.Add(map.Resources[pos].Index);

					if (needIsExploredPacked && explored)
						exploredPacked[bitIdx / 32] |= 1 << (bitIdx % 32);
					if (needIsVisiblePacked && player.Shroud.IsVisible(pos))
						visiblePacked[bitIdx / 32] |= 1 << (bitIdx % 32);
					bitIdx++;
				}

				if (needHeight) heightArray.Add(heightRow);
				if (needIsVisible) isVisibleArray.Add(isVisibleRow);
				if (needIsExplored) isExploredArray.Add(isExploredRow);
				if (needTerrain) terrainArray.Add(terrainRow);
				if (needResourcesType) resourcesTypeArray.Add(resourcesTypeRow);
				if (needResources) resourcesArray.Add(resourcesRow);
			}

			var result = new JObject
			{
				["MapWidth"] = width,
				["MapHeight"] = height,
				["explored_pct"] = totalCells > 0 ? (double)exploredCount / totalCells : 0.0,
			};

			if (needHeight) result["Height"] = heightArray;
			if (needIsVisible) result["IsVisible"] = isVisibleArray;
			if (needIsExplored) result["IsExplored"] = isExploredArray;
			if (needTerrain) result["Terrain"] = terrainArray;
			if (needResourcesType) result["ResourcesType"] = resourcesTypeArray;
			if (needResources) result["Resources"] = resourcesArray;
			if (needIsExploredPacked) result["IsExplored_packed"] = new JArray(exploredPacked);
			if (needIsVisiblePacked) result["IsVisible_packed"] = new JArray(visiblePacked);

			// Resource spawner actors (MINE/GMINE)
			if (fields == null || fields.Contains("resourceActors"))
			{
				result["resourceActors"] = new JArray(
					world.ActorsHavingTrait<SeedsResource>()
						.Where(a => a.IsInWorld && !a.IsDead)
						.Select(a => new JObject
						{
							["type"] = a.Info.Name,
							["displayName"] = CopilotsConfig.GetChineseByConfigName(a.Info.Name),
							["resourceType"] = a.Info.TraitInfo<SeedsResourceInfo>().ResourceType,
							["x"] = a.Location.X,
							["y"] = a.Location.Y
						}).ToArray()
				);
			}

			// Oil wells / cash trickler buildings
			if (fields == null || fields.Contains("oilWells"))
			{
				result["oilWells"] = new JArray(
					world.ActorsHavingTrait<CashTrickler>()
						.Where(a => a.IsInWorld && !a.IsDead)
						.Select(a => new JObject
						{
							["type"] = a.Info.Name,
							["displayName"] = CopilotsConfig.GetChineseByConfigName(a.Info.Name),
							["owner"] = a.Owner?.InternalName ?? "Neutral",
							["x"] = a.Location.X,
							["y"] = a.Location.Y
						}).ToArray()
				);
			}

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
			var player = ResolvePlayer(json, world);
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
			var player = ResolvePlayer(json, world);

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

		public static JObject QueryProducibleItemsCommand(JObject json, World world)
		{
			var player = ResolvePlayer(json, world);
			var result = new JObject();

			var queues = world.ActorsWithTrait<ProductionQueue>()
				.Where(a => a.Actor.Owner == player && !a.Actor.IsDead && a.Trait.Enabled)
				.Select(a => a.Trait)
				.ToList();

			var grouped = new Dictionary<string, JArray>();
			var seen = new Dictionary<string, HashSet<string>>();

			foreach (var queue in queues)
			{
				var queueType = queue.Info.Type;
				if (!grouped.ContainsKey(queueType))
				{
					grouped[queueType] = new JArray();
					seen[queueType] = new HashSet<string>();
				}

				foreach (var item in queue.BuildableItems())
				{
					var name = item.Name.ToLowerInvariant();
					if (!seen[queueType].Add(name))
						continue;

					var valued = item.TraitInfoOrDefault<ValuedInfo>();
					var buildable = item.TraitInfoOrDefault<BuildableInfo>();

					var entry = new JObject
					{
						["name"] = name,
						["display_name"] = CopilotsConfig.GetChineseByConfigName(name),
						["cost"] = valued?.Cost ?? 0,
						["queue"] = queueType,
					};
					grouped[queueType].Add(entry);
				}
			}

			foreach (var kv in grouped)
				result[kv.Key] = kv.Value;

			return result;
		}

		public static JObject QueryPlayersCommand(JObject json, World world)
		{
			var players = world.Players
				.Where(p => !p.NonCombatant)
				.Select(p => new JObject
				{
					["internalName"] = p.InternalName,
					["clientIndex"] = p.ClientIndex,
					["faction"] = p.Faction.InternalName,
					["isBot"] = p.IsBot,
					["team"] = p.PlayerReference.Team,
					["color"] = p.Color.ToString(),
					["isLocalPlayer"] = p == world.LocalPlayer
				}).ToArray();

			var result = new JObject
			{
				["players"] = new JArray(players)
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
				w.CopilotServer.QueryHandlers["query_producible_items"] = QueryProducibleItemsCommand;
				w.CopilotServer.QueryHandlers["map_query"] = MapQueryCommand;
				w.CopilotServer.QueryHandlers["fog_query"] = FogQueryCommand;
				w.CopilotServer.QueryHandlers["unit_attribute_query"] = UnitAttributeQueryCommand;
				w.CopilotServer.QueryHandlers["player_baseinfo_query"] = PlayerBaseInfoQueryCommand;
				w.CopilotServer.QueryHandlers["screen_info_query"] = ScreenInfoQueryCommand;
				w.CopilotServer.QueryHandlers["ping"] = PingCommand;
				w.CopilotServer.QueryHandlers["query_players"] = QueryPlayersCommand;

				CopilotsConfig.LoadConfig();
				CopilotsUtils.WaitInit();
			}
		}

		public void Tick(Actor self)
		{
		}
	}
}
