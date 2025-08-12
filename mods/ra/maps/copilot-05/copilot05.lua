WorldLoaded = function()

	Trigger.SetAgentMode(true)
	Trigger.SetScore(10.0)  -- 初始化分数为10

	Player1 = Player.GetPlayer("Multi0")  -- 防守方（玩家）
	Enemy = Player.GetPlayer("Multi1")    -- 进攻方（敌人）

	InitObjectives(Player1)
	
	DefendBaseObjective = AddPrimaryObjective(Player1, "defend-base-180-seconds")
	EliminateEnemyObjective = AddSecondaryObjective(Player1, "eliminate-all-enemy-units")
	
	PlayerBase = Map.NamedActor("Actor2")
	EnemyBase1 = Map.NamedActor("Actor43")
	EnemyBase2 = Map.NamedActor("Actor84")
	
	AllEnemyUnits = Enemy.GetActorsByTypes({ "e1", "e3", "ftrk" })
	
	EnemyGroup1 = {}
	EnemyGroup2 = {}
	
	Utils.Do(AllEnemyUnits, function(unit)
		local pos = unit.Location
		-- 以Y坐标25为分界线，分为北部和南部两组
		if pos.Y < 25 then
			table.insert(EnemyGroup1, unit)
		else
			table.insert(EnemyGroup2, unit)
		end
	end)
	
	Group1_InitialCount = #EnemyGroup1
	Group2_InitialCount = #EnemyGroup2
	
	Group1_AttackStarted = false
	Group1_Retreated = false
	Group2_AttackStarted = false
	Group2_Retreated = false
	VictoryChecked = false  -- 防止重复检查胜利条件
	
	DateTime.TimeLimit = DateTime.Seconds(180)
	
	Trigger.OnKilled(PlayerBase, function()
		Player1.MarkFailedObjective(DefendBaseObjective)
	end)
	
	Trigger.OnAllKilled(AllEnemyUnits, function()
		if not VictoryChecked then
			VictoryChecked = true
			Trigger.AddScore(50.0)
			Player1.MarkCompletedObjective(EliminateEnemyObjective)
			Player1.MarkCompletedObjective(DefendBaseObjective)
		end
	end)
	
	-- 为每个敌方单位添加死亡监听，用于实时检查胜利条件
	Utils.Do(AllEnemyUnits, function(unit)
		Trigger.OnKilled(unit, function()
			Trigger.AddScore(2.0)  -- 每消灭一个敌方单位奖励5分
			-- 延迟一帧后检查胜利条件
			Trigger.AfterDelay(1, CheckVictoryCondition)
		end)
	end)
	
	-- 时间到达时检查胜利条件
	Trigger.OnTimerExpired(function()
		Player1.MarkCompletedObjective(DefendBaseObjective)
	end)
	
	Trigger.AfterDelay(DateTime.Seconds(30), function()
		StartGroup1Attack()
	end)
	
	Trigger.AfterDelay(DateTime.Seconds(60), function()
		StartGroup2Attack()
	end)
	
	Trigger.AfterDelay(DateTime.Seconds(100), function()
		StartGroup1SecondAttack()
	end)
	
	Trigger.AfterDelay(DateTime.Seconds(100), function()
		StartGroup2SecondAttack()
	end)
	
	Camera.Position = PlayerBase.CenterPosition
end

StartGroup1Attack = function()
	if Group1_AttackStarted then
		return
	end
	
	Group1_AttackStarted = true
	
	Utils.Do(EnemyGroup1, function(unit)
		if not unit.IsDead then
			unit.AttackMove(PlayerBase.Location)
		end
	end)
	
	MonitorGroup1Losses()
end

StartGroup2Attack = function()
	if Group2_AttackStarted then
		return
	end
	
	Group2_AttackStarted = true
	
	Utils.Do(EnemyGroup2, function(unit)
		if not unit.IsDead then
			unit.AttackMove(PlayerBase.Location)
		end
	end)
	
	MonitorGroup2Losses()
end

StartGroup1SecondAttack = function()
	Group1_Retreated = false  -- 重置撤退状态
	
	local aliveCount = 0
	Utils.Do(EnemyGroup1, function(unit)
		if not unit.IsDead then
			aliveCount = aliveCount + 1
			unit.AttackMove(PlayerBase.Location)
		end
	end)
	
end

StartGroup2SecondAttack = function()
	Group2_Retreated = false  -- 重置撤退状态
	
	local aliveCount = 0
	Utils.Do(EnemyGroup2, function(unit)
		if not unit.IsDead then
			aliveCount = aliveCount + 1
			unit.AttackMove(PlayerBase.Location)
		end
	end)
	
end

MonitorGroup1Losses = function()
	local function CheckLosses()
		if Group1_Retreated then
			return
		end
		
		local aliveCount = 0
		Utils.Do(EnemyGroup1, function(unit)
			if not unit.IsDead then
				aliveCount = aliveCount + 1
			end
		end)
		
		local lossCount = Group1_InitialCount - aliveCount
		
		
		if lossCount >= 5 then
			Group1_Retreated = true
			RetreatGroup1()
		else
			Trigger.AfterDelay(DateTime.Seconds(1), CheckLosses)
		end
	end
	
	Trigger.AfterDelay(DateTime.Seconds(1), CheckLosses)
end

MonitorGroup2Losses = function()
	local function CheckLosses()
		if Group2_Retreated then
			return
		end
		
		local aliveCount = 0
		Utils.Do(EnemyGroup2, function(unit)
			if not unit.IsDead then
				aliveCount = aliveCount + 1
			end
		end)
		
		local lossCount = Group2_InitialCount - aliveCount
		
		if lossCount >= 5 then
			Group2_Retreated = true
			RetreatGroup2()
		else
			Trigger.AfterDelay(DateTime.Seconds(1), CheckLosses)
		end
	end
	
	Trigger.AfterDelay(DateTime.Seconds(1), CheckLosses)
end

RetreatGroup1 = function()
	Utils.Do(EnemyGroup1, function(unit)
		if not unit.IsDead then
			unit.Stop()
			unit.Move(EnemyBase1.Location)
			
			if unit.HasProperty("Stance") then
				unit.Stance = "Defend"
			end
		end
	end)
end

RetreatGroup2 = function()
	Utils.Do(EnemyGroup2, function(unit)
		if not unit.IsDead then
			unit.Stop()
			unit.Move(EnemyBase2.Location)
			
			if unit.HasProperty("Stance") then
				unit.Stance = "Defend"
			end
		end
	end)
end


Tick = function()

	if Player1.HasNoRequiredUnits() then
		Player1.MarkFailedObjective(DefendBaseObjective)
	end
	
	if DateTime.GameTime % 60 == 0 then
		CheckVictoryCondition()
	end
end

CheckVictoryCondition = function()
	if VictoryChecked then
		return
	end
	
	local aliveEnemyCount = 0
	Utils.Do(AllEnemyUnits, function(unit)
		if not unit.IsDead then
			aliveEnemyCount = aliveEnemyCount + 1
		end
	end)

	if aliveEnemyCount == 0 then
		VictoryChecked = true
		Media.DisplayMessage("Victory! All enemy units eliminated!", "Debug")
		Player1.MarkCompletedObjective(EliminateEnemyObjective)
		Player1.MarkCompletedObjective(DefendBaseObjective)
	end
end
