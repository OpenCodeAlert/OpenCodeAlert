WorldLoaded = function()

	Trigger.SetAgentMode(true)
	Trigger.SetScore(0.0)

	Player1 = Player.GetPlayer("Multi0")  -- 玩家
	Enemy = Player.GetPlayer("Multi1")    -- 敌人

	InitObjectives(Player1)
	
	-- 添加主要任务目标：消灭所有敌方单位
	EliminateEnemyObjective = AddPrimaryObjective(Player1, "Eliminate all enemy units")
	TimeObjective = AddSecondaryObjective(Player1, "Complete mission within 90 seconds")
	
	AllEnemyUnits = Enemy.GetActorsByTypes({ "4tnk", "ftrk", "e1", "3tnk" })
	
	-- 获取玩家主要单位作为基地代表
	PlayerTanks = Player1.GetActorsByTypes({ "3tnk" })
	PlayerInfantry = Player1.GetActorsByTypes({ "e1", "e3" })
	
	-- 记录初始单位数量用于损失计算
	InitialPlayerTanks = #PlayerTanks
	InitialPlayerInfantry = #PlayerInfantry
	
	-- 游戏状态标志
	VictoryChecked = false  -- 防止重复检查胜利条件

    MAX_SECONDS = 90
	DateTime.TimeLimit = DateTime.Seconds(MAX_SECONDS)
	
	-- 为每个敌方单位添加死亡监听，用于实时检查胜利条件和计分
	Utils.Do(AllEnemyUnits, function(unit)
		Trigger.OnKilled(unit, function()
			-- 根据单位类型给予不同分数奖励
			if unit.Type == "4tnk" then
				Trigger.AddScore(40.0)
			elseif unit.Type == "3tnk" then
				Trigger.AddScore(30.0)
			elseif unit.Type == "ftrk" then
				Trigger.AddScore(20.0)
			elseif unit.Type == "e1" then
				Trigger.AddScore(10.0)
			end
			
			-- 延迟一帧后检查胜利条件
			Trigger.AfterDelay(1, CheckVictoryCondition)
		end)
	end)
	
	SetEnemyDefensiveStance()
	
	-- 时间到达时检查任务完成情况
	Trigger.OnTimerExpired(function()
		if not Player1.IsObjectiveCompleted(EliminateEnemyObjective) then
			Media.DisplayMessage("Time's up! Time obje ctive failed.", "Mission")
			Player1.MarkFailedObjective(TimeObjective)
			Trigger.AddScore(-50.0)  -- 时间目标失败扣分
		else
			Player1.MarkCompletedObjective(TimeObjective)
		end
	end)
end

SetEnemyDefensiveStance = function()
	-- 设置所有敌方单位为防守姿态，原地防守
	Utils.Do(AllEnemyUnits, function(unit)
		if not unit.IsDead then
			-- 停止当前行动
			unit.Stop()
			
			-- 设置为防守姿态（如果单位支持姿态设置）
			if unit.HasProperty("Stance") then
				unit.Stance = "Defend"
			end
		end
	end)
end

CheckVictoryCondition = function()
	if VictoryChecked then
		return
	end
	
	-- 计算还存活的敌方单位数量
	local aliveEnemyCount = 0
	Utils.Do(AllEnemyUnits, function(unit)
		if not unit.IsDead then
			aliveEnemyCount = aliveEnemyCount + 1
		end
	end)

	-- 如果所有敌方单位都被消灭，玩家胜利
	if aliveEnemyCount == 0 then
		VictoryChecked = true
		Media.DisplayMessage("Victory! All enemy units eliminated!", "Mission")
		Player1.MarkCompletedObjective(EliminateEnemyObjective)
		
		-- 时间得分
		local maxBonus = 50.0
		local elapsedFrames = DateTime.GameTime
		local elapsedSeconds = elapsedFrames / 25  -- OpenRA默认25帧/秒
		local remainingSeconds = MAX_SECONDS - elapsedSeconds
		
		remainingSeconds = math.max(0, remainingSeconds)
		local timeBonus = math.min(maxBonus, remainingSeconds)  -- 确保时间奖励不超过最大值
		
		-- 单位损失扣分
		local currentTanks = #Player1.GetActorsByTypes({ "3tnk" })
		local currentInfantry = #Player1.GetActorsByTypes({ "e1", "e3" })
		
		local tankLosses = InitialPlayerTanks - currentTanks
		local infantryLosses = InitialPlayerInfantry - currentInfantry
		
		local lossPenalty = tankLosses * 10 + infantryLosses * 5
		
		
		-- 显示详细信息
		-- Media.DisplayMessage(string.format("Time: %.1fs remaining, bonus: %.1f", remainingSeconds, timeBonus), "Mission")
		Media.DisplayMessage(string.format("Losses: %d tanks(-%d), %d infantry(-%d)", tankLosses, tankLosses*10, infantryLosses*5, infantryLosses*2), "Mission")
		-- Media.DisplayMessage(string.format("Final time bonus: %.1f points", finalScore), "Mission")
		
		Trigger.AddScore(- lossPenalty)
		
		Trigger.CompleteObjective("eliminate-all-enemy-units")
	end
end

Tick = function()
	
	if DateTime.GameTime % 60 == 0 then
		CheckVictoryCondition()
	end
end