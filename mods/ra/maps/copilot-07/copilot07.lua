WorldLoaded = function()
	Camera.Position = DefaultCameraPosition.CenterPosition
	Trigger.SetAgentMode(true)
	Trigger.SetScore(0.0)  -- 初始化分数为0

	Player1 = Player.GetPlayer("multi1")  -- 进攻方（玩家）
	Enemy = Player.GetPlayer("multi0")    -- 防守方（敌人）

	InitObjectives(Player1)
	
	-- 主要任务1：摧毁敌方基地
	DestroyEnemyBaseObjective = AddPrimaryObjective(Player1, "destroy-enemy-base")
	-- 主要任务2：摧毁敌方所有电厂
	DestroyAllEnemyPowerPlantsObjective = AddPrimaryObjective(Player1, "destroy-all-enemy-power-plants")
	-- 次要任务：摧毁敌方所有战斗单位
	EliminateAllEnemyUnitsObjective = AddSecondaryObjective(Player1, "eliminate-all-enemy-units")
	
	-- 通过类型搜索获取敌方基地建筑
	EnemyBases = Enemy.GetActorsByTypes({ "fact" })  -- 敌方工厂（基地）
	-- 通过类型搜索获取敌方电厂
	EnemyPowerPlants = Enemy.GetActorsByTypes({ "powr", "apwr" })  -- 敌方电厂（powr和apwr）
	
	-- 获取敌方所有战斗单位
	AllEnemyUnits = Enemy.GetActorsByTypes({ "e1", "e3", "ftrk", "3tnk", "4tnk" })
	
	-- 获取我方所有战斗单位
	AllPlayerUnits = Player1.GetActorsByTypes({ "e1", "e3", "ftrk", "3tnk", "4tnk" })
	
	-- 初始化计数器
	EnemyUnitsKilled = 0
	TotalEnemyUnits = #AllEnemyUnits
	PowerPlantsDestroyed = 0
	TotalPowerPlants = #EnemyPowerPlants
	BasesDestroyed = 0
	TotalBases = #EnemyBases
	VictoryChecked = false
	FailureChecked = false
	
	-- 设置相机位置到玩家基地
	-- Camera.Position = Map.NamedActor("Actor69").CenterPosition  -- 玩家工厂位置
	
	-- 监听敌方单位死亡
	Utils.Do(AllEnemyUnits, function(unit)
		Trigger.OnKilled(unit, function()
			EnemyUnitsKilled = EnemyUnitsKilled + 1
			Trigger.AddScore(1.0)  -- 每摧毁一个敌方单位给1分
			
			-- 检查次要任务是否完成
			if EnemyUnitsKilled >= TotalEnemyUnits then
				Player1.MarkCompletedObjective(EliminateAllEnemyUnitsObjective)
				Trigger.AddScore(30.0)  -- 完成次要任务给30分
				Media.DisplayMessage("Destroyed all enemy units, secondary task completed!", "Debug")
			end
			
			-- 延迟一帧后检查胜利条件
			Trigger.AfterDelay(1, CheckVictoryCondition)
		end)
	end)
	
	-- 监听敌方基地被摧毁
	Utils.Do(EnemyBases, function(base)
		Trigger.OnKilled(base, function()
			BasesDestroyed = BasesDestroyed + 1
			Trigger.AddScore(50.0)  -- 摧毁敌方基地给50分
			Media.DisplayMessage("Primary task 1 completed! Destroyed enemy base " .. BasesDestroyed .. "/" .. TotalBases, "Debug")
			
			-- 检查主要任务1是否完成
			if BasesDestroyed >= TotalBases then
				Player1.MarkCompletedObjective(DestroyEnemyBaseObjective)
				Media.DisplayMessage("Primary task 1 completed! Destroyed all enemy bases", "Debug")
			end
			
			CheckVictoryCondition()
		end)
	end)
	
	-- 监听敌方电厂被摧毁
	Utils.Do(EnemyPowerPlants, function(powerPlant)
		Trigger.OnKilled(powerPlant, function()
			PowerPlantsDestroyed = PowerPlantsDestroyed + 1
			Trigger.AddScore(10.0)  -- 每摧毁一个电厂给10分
			
			-- 检查主要任务2是否完成
			if PowerPlantsDestroyed >= TotalPowerPlants then
				Player1.MarkCompletedObjective(DestroyAllEnemyPowerPlantsObjective)
				Media.DisplayMessage("Primary task 2 completed! Destroyed all enemy power plants", "Debug")
			end
			
			CheckVictoryCondition()
		end)
	end)
	
	-- 监听我方单位死亡，检查失败条件并扣分
	Utils.Do(AllPlayerUnits, function(unit)
		Trigger.OnKilled(unit, function()
			Trigger.AddScore(-2.0)  -- 我方单位死亡扣2分
			Trigger.AfterDelay(1, CheckFailureCondition)
		end)
	end)
	
	-- 定期检查胜利和失败条件
	Trigger.AfterDelay(DateTime.Seconds(1), function()
		CheckVictoryCondition()
		CheckFailureCondition()
	end)
end

CheckVictoryCondition = function()
	if VictoryChecked then
		return
	end
	
	-- 检查两个主要任务是否都完成
	if BasesDestroyed >= TotalBases and PowerPlantsDestroyed >= TotalPowerPlants then
		VictoryChecked = true
		Media.DisplayMessage("Victory! Destroyed all enemy bases and power plants!", "Debug")
		-- 可以在这里添加胜利后的额外逻辑
	end
end

CheckFailureCondition = function()
	if FailureChecked then
		return
	end
	
	-- 检查我方是否还有战斗单位
	if Player1.HasNoRequiredUnits() then
		FailureChecked = true
		Player1.MarkFailedObjective(DestroyEnemyBaseObjective)
		Player1.MarkFailedObjective(DestroyAllEnemyPowerPlantsObjective)
		Player1.MarkFailedObjective(EliminateAllEnemyUnitsObjective)
		Media.DisplayMessage("Failure! All player units have been destroyed!", "Debug")
	end
end

Tick = function()
	-- 每60帧检查一次胜利和失败条件
	if DateTime.GameTime % 60 == 0 then
		CheckVictoryCondition()
		CheckFailureCondition()
	end
end
