WorldLoaded = function()
	-- 设置 Agent 模式
	Trigger.SetAgentMode(true)

	Player1 = Player.GetPlayer("Player")
	MCV = Map.NamedActor("MyMCV")

	InitObjectives(Player1)
	Trigger.SetScore(100.0)
	-- 添加胜利目标
	Objective = AddPrimaryObjective(Player1, "deploy-your-base")
	Trigger.RecordObjective("deploy-mcv", "部署基地车")
	
	-- 添加建筑和单位目标
	PowerPlantObjective = AddPrimaryObjective(Player1, "build-power-plant")
	Trigger.RecordObjective("build-power-plant", "建造电厂")
	
	InfantryObjective = AddPrimaryObjective(Player1, "build-3-infantry")
	Trigger.RecordObjective("build-3-infantry", "生产3个步兵")
	
	RefineryObjective = AddPrimaryObjective(Player1, "build-refinery")
	Trigger.RecordObjective("build-refinery", "建造矿场")
	
	WarFactoryObjective = AddPrimaryObjective(Player1, "build-war-factory")
	Trigger.RecordObjective("build-war-factory", "建造车间")
	
	FlakTruckObjective = AddPrimaryObjective(Player1, "build-2-flak-trucks")
	Trigger.RecordObjective("build-2-flak-trucks", "生产2个防空车")
	
	RadarObjective = AddPrimaryObjective(Player1, "build-radar")
	Trigger.RecordObjective("build-radar", "建造雷达站")
	
	NukePlantObjective = AddPrimaryObjective(Player1, "build-nuke-plant")
	Trigger.RecordObjective("build-nuke-plant", "建造核电厂")
	
	-- 初始化计数器
	InfantryCount = 0
	FlakTruckCount = 0
	
	-- 监听 MCV 是否被替换成 base（部署后会自动删除 MCV，生成 base）
	Trigger.OnRemovedFromWorld(MCV, function()
		-- 胜利条件：只要不是被摧毁（即部署）
		if not MCV.IsDead then
			Player1.MarkCompletedObjective(Objective)
			Trigger.CompleteObjective("deploy-mcv")
			Media.PlaySpeechNotification(Player1, "ObjectiveMet")
		else
			Player1.MarkFailedObjective(Objective)
			Media.PlaySpeechNotification(Player1, "ObjectiveNotMet")
		end
	end)
	
	-- 监听生产事件（单位）
	Trigger.OnAnyProduction(function(producer, produced, productionType)
		-- 调试信息
		Media.DisplayMessage("生产事件触发: " .. produced.Type .. " 由 " .. (producer and producer.Type or "未知") .. " 生产")
		
		if produced.Owner == Player1 then
			Media.DisplayMessage("检测到玩家生产: " .. produced.Type)
			
			-- 检查步兵 (E1)
			if produced.Type == "e1" then
				InfantryCount = InfantryCount + 1
				Media.DisplayMessage("步兵计数: " .. InfantryCount .. "/3")
				if InfantryCount >= 3 then
					Player1.MarkCompletedObjective(InfantryObjective)
					Trigger.CompleteObjective("build-3-infantry")
					Media.PlaySpeechNotification(Player1, "ObjectiveMet")
					Media.DisplayMessage("步兵目标完成！")
				end
			end
			
			-- 检查防空车 (FTRK)
			if produced.Type == "ftrk" then
				FlakTruckCount = FlakTruckCount + 1
				Media.DisplayMessage("防空车计数: " .. FlakTruckCount .. "/2")
				if FlakTruckCount >= 2 then
					Player1.MarkCompletedObjective(FlakTruckObjective)
					Trigger.CompleteObjective("build-2-flak-trucks")
					Media.PlaySpeechNotification(Player1, "ObjectiveMet")
					Media.DisplayMessage("防空车目标完成！")
				end
			end
		end
	end)
end

-- 添加Tick函数来定期检查建筑和单位
Tick = function()
	-- Media.DisplayMessage("Tick函数执行")
	-- 每10秒检查一次
	-- if DateTime.GameTime % 60 == 0 then
		-- 检查电厂
	local powerPlants = Player1.GetActorsByType("powr")
	if #powerPlants > 0 and not Player1.IsObjectiveCompleted(PowerPlantObjective)then
		Player1.MarkCompletedObjective(PowerPlantObjective)
		Trigger.CompleteObjective("build-power-plant")
		Media.DisplayMessage("Tick检测到电厂，目标完成！")
	end
	
	-- 检查矿场
	local refineries = Player1.GetActorsByType("fact")
	if #refineries > 0 and not Player1.IsObjectiveCompleted(RefineryObjective) then
		Player1.MarkCompletedObjective(RefineryObjective)
		Trigger.CompleteObjective("build-refinery")
		Media.DisplayMessage("Tick检测到矿场，目标完成！")
	end
	
	-- 检查车间
	local warFactories = Player1.GetActorsByType("weap")
	if #warFactories > 0 and not Player1.IsObjectiveCompleted(WarFactoryObjective)then
		Player1.MarkCompletedObjective(WarFactoryObjective)
		Trigger.CompleteObjective("build-war-factory")
		Media.DisplayMessage("Tick检测到车间，目标完成！")
	end
	
	-- 检查雷达
	local radars = Player1.GetActorsByType("dome")
	if #radars > 0 and not Player1.IsObjectiveCompleted(RadarObjective) then
		Player1.MarkCompletedObjective(RadarObjective)
		Trigger.CompleteObjective("build-radar")
		Media.DisplayMessage("Tick检测到雷达，目标完成！")
	end
	
	-- 检查核电厂
	local nukePlants = Player1.GetActorsByType("apwr")
	if #nukePlants > 0 and not Player1.IsObjectiveCompleted(NukePlantObjective) then
		Player1.MarkCompletedObjective(NukePlantObjective)
		Trigger.CompleteObjective("build-nuke-plant")
		Media.DisplayMessage("Tick检测到核电厂，目标完成！")
	end
	
	-- 检查步兵
	local infantry = Player1.GetActorsByType("e1")
	if #infantry >= 3 and not Player1.IsObjectiveCompleted(InfantryObjective) then
		Player1.MarkCompletedObjective(InfantryObjective)
		Trigger.CompleteObjective("build-3-infantry")
		Media.DisplayMessage("Tick检测到3个步兵，目标完成！")
	end
	
	-- 检查防空车
	local flakTrucks = Player1.GetActorsByType("ftrk")
	if #flakTrucks >= 2 and not Player1.IsObjectiveCompleted(FlakTruckObjective)then
		Player1.MarkCompletedObjective(FlakTruckObjective)
		Trigger.CompleteObjective("build-2-flak-trucks")
		Media.DisplayMessage("Tick检测到2个防空车，目标完成！")
	end
	
	-- 调试信息：显示当前拥有的建筑和单位数量
	-- Media.DisplayMessage("Tick检查 - 电厂:" .. #powerPlants .. " 矿场:" ..#refineries .. " 车间:" .. #warFactories .. " 雷达:" .. #radars .. " 核电厂:" ..#nukePlants .. " 步兵:" .. #infantry .. " 防空车:" .. #flakTrucks)
	-- end
end