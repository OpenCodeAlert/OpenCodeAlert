--[[
   Copyright (c) The OpenRA Developers and Contributors
   This file is part of OpenRA, which is free software. It is made
   available to you under the terms of the GNU General Public License
   as published by the Free Software Foundation, either version 3 of
   the License, or (at your option) any later version. For more
   information, see COPYING.
]]
IntroAttackers = { IntroSoldier1, IntroSoldier2, IntroSoldier3 }
TransportTrigger = { CPos.New(75, 58) }
EnemyBaseShroudTrigger = { CPos.New(64, 52), CPos.New(64, 53), CPos.New(64, 54), CPos.New(64, 55), CPos.New(64, 56), CPos.New(64, 57), CPos.New(64, 58), CPos.New(64, 59), CPos.New(64, 60), CPos.New(64, 61), CPos.New(64, 62), CPos.New(64, 63), CPos.New(64, 64) }
ParachuteTrigger = { CPos.New(80, 66), CPos.New(81, 66), CPos.New(82, 66), CPos.New(83, 66), CPos.New(84, 66), CPos.New(85, 66),CPos.New(86, 66), CPos.New(87, 66), CPos.New(88, 66), CPos.New(89, 66) }
EnemyBaseEntranceShroudTrigger = { CPos.New(80, 73), CPos.New(81, 73), CPos.New(82, 73), CPos.New(83, 73), CPos.New(84, 73), CPos.New(85, 73),CPos.New(86, 73), CPos.New(87, 73), CPos.New(88, 73), CPos.New(89, 73) }

AttackWaypoints = { AttackWaypoint1, AttackWaypoint2 }
TankDropPoints = { DropPoint1, DropPoint2 }
AttackGroup = { }
AttackGroupSize = 5
AlliedInfantry = { "e1", "e1", "e3" }

-- 分数配置
local SCORE_PRIMARY_OBJECTIVES = 150.0
local SCORE_ROCKET_SOLDIER = 10.0
local SCORE_TANK = 15.0
local SCORE_TIME_BONUS = 50.0
local SCORE_UNIT_PENALTY_E1 = -1.0
local SCORE_UNIT_PENALTY_YAK = -4.0

-- 游戏状态变量
local gameScore = 0.0
local gameStartTime = 0
local gameCompleted = false
local unitProductionCount = { e1 = 0, yak = 0 }

-- 特殊触发器
DropPoint4Trigger = { CPos.New(74, 61), CPos.New(75, 61), CPos.New(76, 61), CPos.New(74, 62), CPos.New(75, 62), CPos.New(76, 62) }
DropPoint4Triggered = false

-- 次要目标变量
local keepSoldiersObjective
local timeObjective

ProtectedUnits = {rs1, rs2, rs3, rs4, rs5, rs6}
ProtectedTank = Actor121
EnemyYard = Actor50


TankDropConfig = {
    { 
        timeRange = { min = 30, max = 45 },
        unitType = "powerproxy.paratroopers4",
        radius = 2
    },
    { 
        timeRange = { min = 90, max = 120 },
        unitType = "powerproxy.paratroopers4",
        radius = 2
    },
    {
        timeRange = { min = 180, max = 240 },
        unitType = "powerproxy.paratroopers5",
        radius = 5
    }
}
TankDropTimes = {}

SendAttackGroup = function()
	if #AttackGroup < AttackGroupSize then
		return
	end

	local way = Utils.Random(AttackWaypoints)
	Utils.Do(AttackGroup, function(unit)
		if not unit.IsDead then
			unit.AttackMove(way.Location)
			Trigger.OnIdle(unit, unit.Hunt)
		end
	end)

	AttackGroup = { }
end

ProduceInfantry = function()
	if Tent.IsDead then
		return
	end

	Greece.Build({ Utils.Random(AlliedInfantry) }, function(units)
		table.insert(AttackGroup, units[1])
		SendAttackGroup()
		Trigger.AfterDelay(DateTime.Seconds(5), ProduceInfantry)
	end)
end

SendUSSRParadrops = function()
	local paraproxy1 = Actor.Create("powerproxy.paratroopers", false, { Owner = USSR })
	paraproxy1.TargetParatroopers(ParachuteBaseEntrance.CenterPosition, Angle.North)
	paraproxy1.Destroy()
end

SendUSSRParadropsBase = function()
	local paraproxy2 = Actor.Create("powerproxy.paratroopers2", false, { Owner = USSR })
	paraproxy2.TargetParatroopers(ParachuteBase1.CenterPosition, Angle.East)
	paraproxy2.Destroy()
	local paraproxy3 = Actor.Create("powerproxy.paratroopers3", false, { Owner = USSR })
	paraproxy3.TargetParatroopers(ParachuteBase2.CenterPosition, Angle.East)
	paraproxy3.Destroy()
end

-- 获取随机空投位置
GetRandomDropPosition = function(dropPoint, radius)
    local offsetX = Utils.RandomInteger(-radius, radius + 1)
    local offsetY = Utils.RandomInteger(-radius, radius + 1)
    local randomPos = CPos.New(dropPoint.Location.X + offsetX, dropPoint.Location.Y + offsetY)
    return Map.CenterOfCell(randomPos)
end

-- 执行坦克空投
SendTankDrop = function(config)
    -- 从配置的空投点中随机选择一个
    local randomDropPoint = Utils.Random(TankDropPoints)
    local dropPosition = GetRandomDropPosition(randomDropPoint, config.radius)
    
    -- 创建指定类型的空投单位
    local tankProxy = Actor.Create(config.unitType, false, { Owner = Greece })
    tankProxy.TargetParatroopers(dropPosition, Angle.South)
    tankProxy.Destroy()
    
    Media.PlaySpeechNotification(USSR, "EnemyUnitsApproaching")
end

ScheduleTankDrop = function()
    -- 为每个空投配置生成随机时间并安排空投
    Utils.Do(TankDropConfig, function(config)
        local randomTime = Utils.RandomInteger(config.timeRange.min, config.timeRange.max + 1)
        table.insert(TankDropTimes, randomTime)
        
        Trigger.AfterDelay(DateTime.Seconds(randomTime), function()
            SendTankDrop(config)
        end)
    end)
end

-- DropPoint4特殊空投
SendSpecialDrop = function()
    local dropPosition = GetRandomDropPosition(DropPoint4, 3)
    local specialProxy = Actor.Create("powerproxy.paratroopers6", false, { Owner = USSR })
    specialProxy.TargetParatroopers(dropPosition, Angle.South)
    specialProxy.Destroy()
    
    Media.PlaySpeechNotification(USSR, "ReinforcementsArrived")
end

-- 监听玩家生产的单位
MonitorUnitProduction = function()
    Trigger.OnAnyProduction(function(producer, produced, productionType)
        if produced and produced.Owner == USSR then
            local unitType = produced.Type
            
            if unitType == "e1" then
                unitProductionCount.e1 = unitProductionCount.e1 + 1
				if unitProductionCount.e1 % 10 == 0 then
                    Media.DisplayMessage("Produced Infantry: " .. unitProductionCount.e1, "Notification")
                end
            elseif unitType == "yak" then
                unitProductionCount.yak = unitProductionCount.yak + 1
                if unitProductionCount.yak % 5 == 0 then
                    Media.DisplayMessage("Produced Yak: " .. unitProductionCount.yak, "Notification")
                end
            end
        end
    end)
end

-- 计算最终分数
CalculateFinalScore = function()
    local finalScore = gameScore
    
    -- 计算保护单位奖励
    local survivingCount = 0
    if ProtectedUnits then
        Utils.Do(ProtectedUnits, function(unit)
            if unit and not unit.IsDead then
                finalScore = finalScore + SCORE_ROCKET_SOLDIER
                survivingCount = survivingCount + 1
            end
        end)
    end
    
    -- 检查坦克存活
    if ProtectedTank and not ProtectedTank.IsDead then
        finalScore = finalScore + SCORE_TANK
    end
    
    -- 时间奖励检查
    local currentTime = (DateTime.GameTime - gameStartTime) / 25
    if currentTime <= 360 then
             finalScore = finalScore + SCORE_TIME_BONUS
        USSR.MarkCompletedObjective(timeObjective)
    else
        USSR.MarkFailedObjective(timeObjective)
		finalScore = finalScore - (SCORE_TIME_BONUS / 2)
    end
    
    -- 生产单位惩罚
    finalScore = finalScore + (unitProductionCount.e1 * SCORE_UNIT_PENALTY_E1)
    finalScore = finalScore + (unitProductionCount.yak * SCORE_UNIT_PENALTY_YAK)
    
    return finalScore
end

-- 完成游戏
CompleteGame = function()
    if gameCompleted then
        return
    end
    
    gameCompleted = true
    local finalScore = CalculateFinalScore()
    
    Trigger.SetScore(finalScore)
    
    local survivingUnits = 0
    if ProtectedUnits then
        Utils.Do(ProtectedUnits, function(unit)
            if unit and not unit.IsDead then
                survivingUnits = survivingUnits + 1
            end
        end)
    end
    
    local tankSurvived = false
    if ProtectedTank and not ProtectedTank.IsDead then
        tankSurvived = true
    end
    
    if ProtectedUnits and survivingUnits == #ProtectedUnits and tankSurvived then
        USSR.MarkCompletedObjective(keepSoldiersObjective)
    else
        USSR.MarkFailedObjective(keepSoldiersObjective)
    end
    
    local currentTime = (DateTime.GameTime - gameStartTime) / 25
    Media.DisplayMessage("Mission completed! Time: " .. math.floor(currentTime) .. "s, Score: " .. math.floor(finalScore), "Menacing")
end

Trigger.OnEnteredFootprint(ParachuteTrigger, function(a)
	if not ParachuteTriggered and a.Owner == USSR then
		ParachuteTriggered = true
		SendUSSRParadrops()
		Media.PlaySpeechNotification(USSR, "ReinforcementsArrived")
	end
end)

Trigger.OnEnteredFootprint(TransportTrigger, function(a, id)
	if not TransportTriggered and a.Type == "truk" then
		TransportTriggered = true
		if not TransportTruck.IsDead then
			TransportTruck.Wait(DateTime.Seconds(5))
			TransportTruck.Move(TransportWaypoint2.Location)
			TransportTruck.Wait(DateTime.Seconds(5))
			TransportTruck.Move(TransportWaypoint3.Location)
			TransportTruck.Wait(DateTime.Seconds(5))
			TransportTruck.Move(TransportWaypoint1.Location)
		end
		Trigger.AfterDelay(DateTime.Seconds(10), function()
			TransportTriggered = false
		end)
	end
end)

-- DropPoint4特殊触发器
Trigger.OnEnteredFootprint(DropPoint4Trigger, function(a)
	if not DropPoint4Triggered and a.Owner == USSR then
		DropPoint4Triggered = true
		SendSpecialDrop()
		Media.PlaySpeechNotification(USSR, "EnemyUnitsApproaching")
	end
end)

-- Actor141被击杀时触发
Trigger.OnKilled(Actor141, function()
		SendUSSRParadropsBase()
		Media.PlaySpeechNotification(USSR, "ReinforcementsArrived")
end)

Trigger.OnKilled(Church1, function()
	Actor.Create("moneycrate", true, { Owner = USSR, Location = TransportWaypoint3.Location })
end)

Trigger.OnKilled(Church2, function()
	Actor.Create("healcrate", true, { Owner = USSR, Location = Church2.Location })
end)

Trigger.OnKilled(ForwardCommand, function()
	Greece.MarkCompletedObjective(AlliedObjective)
end)

-- 添加敌方基地被摧毁的胜利条件
Trigger.OnKilled(EnemyYard, function()
	if not gameCompleted then
		gameScore = gameScore + SCORE_PRIMARY_OBJECTIVES
		USSR.MarkCompletedObjective(SovietObjective1)
		USSR.MarkCompletedObjective(SovietObjective2)
		CompleteGame()
	end
end)

WorldLoaded = function()
    Camera.Position = DefaultCameraPosition.CenterPosition
	Trigger.SetAgentMode(true)
	
	USSR = Player.GetPlayer("Multi0")
	Greece = Player.GetPlayer("Multi1")

	gameStartTime = DateTime.GameTime
	Trigger.SetScore(0.0)
	
	Utils.Do(IntroAttackers, function(actor)
		if not actor.IsDead then
			Trigger.OnIdle(actor, actor.Hunt)
		end
	end)
	Trigger.AfterDelay(0, function()
		local buildings = Utils.Where(Map.ActorsInWorld, function(self) return self.Owner == Greece and self.HasProperty("StartBuildingRepairs") end)
		Utils.Do(buildings, function(actor)
			Trigger.OnDamaged(actor, function(building)
				if building.Owner == Greece and building.Health < building.MaxHealth * 0.8 then
					building.StartBuildingRepairs()
				end
			end)
		end)
	end)

	InitObjectives(USSR)
	AlliedObjective = AddPrimaryObjective(Greece, "")
	SovietObjective1 = AddPrimaryObjective(USSR, "protect-command-center")
	SovietObjective2 = AddPrimaryObjective(USSR, "destroy-enemy-base")
	
	keepSoldiersObjective = AddSecondaryObjective(USSR, "keep-rocket-soldier-alive")
	timeObjective = AddSecondaryObjective(USSR, "complete-within-360-seconds")

	Greece.Resources = 5000
	Trigger.AfterDelay(DateTime.Seconds(30), ProduceInfantry)
	
	-- 启动坦克空投
	ScheduleTankDrop()
	
	-- 延迟启动单位生产监控，确保所有建筑都已加载
	Trigger.AfterDelay(DateTime.Seconds(1), MonitorUnitProduction)
end

Tick = function()
	if USSR.HasNoRequiredUnits() then
		Greece.MarkCompletedObjective(AlliedObjective)
	end
	-- 移除了原来的"摧毁所有敌方单位"检查
	-- 现在胜利条件改为摧毁EnemyYard，在OnKilled触发器中处理

	if Greece.Resources >= Greece.ResourceCapacity * 0.75 then
		Greece.Cash = Greece.Cash + Greece.Resources - Greece.ResourceCapacity * 0.25
		Greece.Resources = Greece.ResourceCapacity * 0.25
	end
end
