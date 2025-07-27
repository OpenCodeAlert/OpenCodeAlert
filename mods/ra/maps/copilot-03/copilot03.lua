WorldLoaded = function()
	-- 设置 Agent 模式
	Trigger.SetAgentMode(false)

	Player1 = Player.GetPlayer("Player")
	MyMCV = Map.NamedActor("MyMCV")

	InitObjectives(Player1)
	
	-- 添加主要任务目标
	MainObjective = AddPrimaryObjective(Player1, "complete-production-in-120-seconds")
	
	-- 添加具体的子目标
	PowerPlantObjective = AddPrimaryObjective(Player1, "build-power-plant")
    -- 兵营的api有问题
	BarracksObjective = AddPrimaryObjective(Player1, "build-barracks")
	WarFactoryObjective = AddPrimaryObjective(Player1, "build-war-factory")
	InfantryObjective = AddPrimaryObjective(Player1, "produce-10-infantry")
	ArtilleryObjective = AddPrimaryObjective(Player1, "produce-10-artillery")
	OreTruckObjective = AddPrimaryObjective(Player1, "produce-1-ore-truck")
	FTRKObjective = AddPrimaryObjective(Player1, "produce-1-ftrk")
	
	-- 初始化任务变量
	missionStartTime = DateTime.GameTime
	missionDuration = DateTime.Seconds(120)
	missionCompleted = false
	missionFailed = false
	
	-- 建筑完成状态
	powerPlantBuilt = false
    barracksBuilt = false
	warFactoryBuilt = false
	
	-- 单位生产计数
	infantryCount = 0
	artilleryCount = 0
	oreTruckCount = 0
	ftrkCount = 0
	
	-- 目标数量
	requiredInfantry = 10
	requiredArtillery = 10
	requiredOreTruck = 1
	requiredFTRK = 1
	
	-- 进度显示计数器
	progressUpdateCounter = 0
	progressUpdateInterval = DateTime.Seconds(10)  -- 每10秒显示一次进度
	
	-- 里程碑提醒
	timeHalfwayReminder = false
	time75PercentReminder = false
	
	Media.DisplayMessage("Mission started! Complete all building constructions and unit productions within 90 seconds.")
	
	Trigger.AfterDelay(missionDuration, function()
		if not missionCompleted then
			missionFailed = true
			Player1.MarkFailedObjective(MainObjective)
			Media.PlaySpeechNotification(Player1, "ObjectiveNotMet")
			Media.DisplayMessage("Mission failed! Time's up!")
			ShowFinalProgress()
		end
	end)
	
	Trigger.OnAnyProduction(function(producer, produced, productionType)
		if produced.Owner == Player1 and not missionCompleted and not missionFailed then
			HandleProduction(produced)
		end
	end)
end

-- 处理生产事件
function HandleProduction(produced)
	local unitType = produced.Type
	
	-- 检查建筑
	if unitType == "powr" and not powerPlantBuilt then
		powerPlantBuilt = true
		Player1.MarkCompletedObjective(PowerPlantObjective)
		CheckVictoryConditions()
	elseif unitType == "weap" and not warFactoryBuilt then
		warFactoryBuilt = true
		Player1.MarkCompletedObjective(WarFactoryObjective)
		CheckVictoryConditions()
	end
	
	-- 检查单位生产
	if unitType == "e1" then
		infantryCount = infantryCount + 1
		if infantryCount >= requiredInfantry then
            barracksBuilt = true
			Player1.MarkCompletedObjective(InfantryObjective)
            Player1.MarkCompletedObjective(BarracksObjective)
		end
		CheckVictoryConditions()
	elseif unitType == "e3" then  -- 炮兵（火箭筒兵）
		artilleryCount = artilleryCount + 1
		if artilleryCount >= requiredArtillery then
            barracksBuilt = true
			Player1.MarkCompletedObjective(ArtilleryObjective)
            Player1.MarkCompletedObjective(BarracksObjective)
		end
		CheckVictoryConditions()
	elseif unitType == "harv" then  -- 矿车
		oreTruckCount = oreTruckCount + 1
		if oreTruckCount >= requiredOreTruck then
			Player1.MarkCompletedObjective(OreTruckObjective)
		end
		CheckVictoryConditions()
	elseif unitType == "ftrk" then  -- 防空车
		ftrkCount = ftrkCount + 1
		if ftrkCount >= requiredFTRK then
			Player1.MarkCompletedObjective(FTRKObjective)
		end
		CheckVictoryConditions()
	end
end

-- 检查胜利条件
function CheckVictoryConditions()
	if missionCompleted or missionFailed then
		return
	end
	
	-- 检查是否所有目标都完成了
	local allBuildingsBuilt = powerPlantBuilt and barracksBuilt and warFactoryBuilt
	local allUnitsProduced = (infantryCount >= requiredInfantry) and 
	                         (artilleryCount >= requiredArtillery) and 
	                         (oreTruckCount >= requiredOreTruck) and 
	                         (ftrkCount >= requiredFTRK)
	
	if allBuildingsBuilt and allUnitsProduced then
		missionCompleted = true
		Player1.MarkCompletedObjective(MainObjective)
		Media.PlaySpeechNotification(Player1, "ObjectiveMet")
		Media.DisplayMessage("Completed all objectives！")
		
		-- 计算用时
		local timeUsed = DateTime.GameTime - missionStartTime
		local secondsUsed = timeUsed / DateTime.Seconds(1)
		Media.DisplayMessage("Consumed " .. string.format("%.1f", secondsUsed) .. " seconds")
	end
end

-- 显示进度信息
function ShowProgress()
	if missionCompleted or missionFailed then
		return
	end
	
	local timeElapsed = DateTime.GameTime - missionStartTime
	local timeRemaining = missionDuration - timeElapsed
	local secondsRemaining = timeRemaining / DateTime.Seconds(1)

	Media.DisplayMessage("Remaining time: " .. string.format("%.0f", secondsRemaining) .. " seconds")

	-- 建筑进度
	local buildingStatus = ""
	if powerPlantBuilt then buildingStatus = buildingStatus .. "Power Plant✓ "
	else buildingStatus = buildingStatus .. "Power Plant✗ " end

	if barracksBuilt then buildingStatus = buildingStatus .. "Barracks✓ "
	else buildingStatus = buildingStatus .. "Barracks✗ " end

	if warFactoryBuilt then buildingStatus = buildingStatus .. "War Factory✓"
	else buildingStatus = buildingStatus .. "War Factory✗" end

	Media.DisplayMessage("Buildings: " .. buildingStatus)
	
	-- 单位进度
	Media.DisplayMessage("Units: Infantry(" .. infantryCount .. "/" .. requiredInfantry .. ") " ..
	                   "Artillery(" .. artilleryCount .. "/" .. requiredArtillery .. ") " ..
	                   "Ore Truck(" .. oreTruckCount .. "/" .. requiredOreTruck .. ") " ..
	                   "FTRK(" .. ftrkCount .. "/" .. requiredFTRK .. ")")
end

-- 显示最终进度
function ShowFinalProgress()
	Media.DisplayMessage("=== Final Results ===")
	
	-- 建筑完成情况
	local buildingStatus = "Buildings Completed: "
	if powerPlantBuilt then buildingStatus = buildingStatus .. "Power Plant✓ "
	else buildingStatus = buildingStatus .. "Power Plant✗ " end
	
	if barracksBuilt then buildingStatus = buildingStatus .. "Barracks✓ "
	else buildingStatus = buildingStatus .. "Barracks✗ " end
	
	if warFactoryBuilt then buildingStatus = buildingStatus .. "War Factory✓"
	else buildingStatus = buildingStatus .. "War Factory✗" end
	
	Media.DisplayMessage(buildingStatus)
	
	-- 单位生产情况
	Media.DisplayMessage("Units Produced: Infantry(" .. infantryCount .. "/" .. requiredInfantry .. ") " ..
	                   "Artillery(" .. artilleryCount .. "/" .. requiredArtillery .. ") " ..
	                   "Ore Truck(" .. oreTruckCount .. "/" .. requiredOreTruck .. ") " ..
	                   "FTRK(" .. ftrkCount .. "/" .. requiredFTRK .. ")")
end

-- 主循环函数
Tick = function()
	-- 检查任务是否已结束
	if missionCompleted or missionFailed then
		return
	end
	
	-- 定期显示进度（每10秒一次）
	progressUpdateCounter = progressUpdateCounter + 1
	if progressUpdateCounter >= progressUpdateInterval then
		progressUpdateCounter = 0
		ShowProgress()
	end
	
	-- 额外的建筑检查（防止生产事件遗漏）
	if not powerPlantBuilt then
		local powerPlants = Player1.GetActorsByType("powr")
		if #powerPlants > 0 then
			powerPlantBuilt = true
			Player1.MarkCompletedObjective(PowerPlantObjective)
			CheckVictoryConditions()
		end
	end
	
	if not barracksBuilt then
		local barracks = Player1.GetActorsByType("tent")
		if #barracks > 0 then
			barracksBuilt = true
			Player1.MarkCompletedObjective(BarracksObjective)
			CheckVictoryConditions()
		end
	end
	
	if not warFactoryBuilt then
		local warFactories = Player1.GetActorsByType("weap")
		if #warFactories > 0 then
			warFactoryBuilt = true
			Player1.MarkCompletedObjective(WarFactoryObjective)
			CheckVictoryConditions()
		end
	end
end
