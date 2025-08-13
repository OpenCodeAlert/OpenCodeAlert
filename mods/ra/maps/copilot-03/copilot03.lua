WorldLoaded = function()

	Trigger.SetAgentMode(true)

	Player1 = Player.GetPlayer("Player")
	MyMCV = Map.NamedActor("MyMCV")

	InitObjectives(Player1)
	
	MainObjective = AddPrimaryObjective(Player1, "Complete all building and production tasks")
	TimeObjective = AddSecondaryObjective(Player1, "Complete within 120 seconds")
	PowerPlantObjective = AddPrimaryObjective(Player1, "build-power-plant")
    -- 兵营的api有问题
	BarracksObjective = AddPrimaryObjective(Player1, "build-barracks")
	WarFactoryObjective = AddPrimaryObjective(Player1, "build-war-factory")
	InfantryObjective = AddPrimaryObjective(Player1, "produce-10-infantry")
	ArtilleryObjective = AddPrimaryObjective(Player1, "produce-10-rocket-soldiers")
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
	progressUpdateInterval = DateTime.Seconds(10)
	
	Media.DisplayMessage("Mission started! Complete all building constructions and unit productions within 90 seconds.")
	
	Trigger.AfterDelay(missionDuration, function()
		if not missionCompleted then
			Player1.MarkFailedObjective(TimeObjective)
			Media.DisplayMessage("Time's up! Time objective failed.", "Mission")
			ShowFinalProgress()
		else
			Player1.MarkCompletedObjective(TimeObjective)
		end
	end)
	
	Trigger.OnAnyProduction(function(producer, produced, productionType)
		if produced.Owner == Player1 and not missionCompleted and not missionFailed then
			HandleProduction(produced)
		end
	end)
end

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
	elseif unitType == "e3" then
		artilleryCount = artilleryCount + 1
		if artilleryCount >= requiredArtillery then
            barracksBuilt = true
			Player1.MarkCompletedObjective(ArtilleryObjective)
            Player1.MarkCompletedObjective(BarracksObjective)
		end
		CheckVictoryConditions()
	elseif unitType == "harv" then
		oreTruckCount = oreTruckCount + 1
		if oreTruckCount >= requiredOreTruck then
			Player1.MarkCompletedObjective(OreTruckObjective)
		end
		CheckVictoryConditions()
	elseif unitType == "ftrk" then
		ftrkCount = ftrkCount + 1
		if ftrkCount >= requiredFTRK then
			Player1.MarkCompletedObjective(FTRKObjective)
		end
		CheckVictoryConditions()
	end
end

function CheckVictoryConditions()
	if missionCompleted or missionFailed then
		return
	end
	
	local allBuildingsBuilt = powerPlantBuilt and barracksBuilt and warFactoryBuilt
	local allUnitsProduced = (infantryCount >= requiredInfantry) and 
	                         (artilleryCount >= requiredArtillery) and 
	                         (oreTruckCount >= requiredOreTruck) and 
	                         (ftrkCount >= requiredFTRK)
	
	if allBuildingsBuilt and allUnitsProduced then
		missionCompleted = true
		Player1.MarkCompletedObjective(MainObjective)
		
		-- 检查时间目标
		if not Player1.IsObjectiveFailed(TimeObjective) then
			Player1.MarkCompletedObjective(TimeObjective)
		else
			-- 如果时间目标失败，扣除分数
			Trigger.AddScore(-50.0)
		end
		
		Media.PlaySpeechNotification(Player1, "ObjectiveMet")
		Media.DisplayMessage("Completed all objectives！")
		
		-- 计算用时
		local timeUsed = DateTime.GameTime - missionStartTime
		local secondsUsed = timeUsed / DateTime.Seconds(1)
		Media.DisplayMessage("Consumed " .. string.format("%.1f", secondsUsed) .. " seconds")
	end
end

function ShowProgress()
	if missionCompleted or missionFailed then
		return
	end
	
	local timeElapsed = DateTime.GameTime - missionStartTime
	local timeRemaining = missionDuration - timeElapsed
	local secondsRemaining = timeRemaining / DateTime.Seconds(1)

	Media.DisplayMessage("Remaining time: " .. string.format("%.0f", secondsRemaining) .. " seconds")

	local buildingStatus = ""
	if powerPlantBuilt then buildingStatus = buildingStatus .. "Power Plant✓ "
	else buildingStatus = buildingStatus .. "Power Plant✗ " end

	if barracksBuilt then buildingStatus = buildingStatus .. "Barracks✓ "
	else buildingStatus = buildingStatus .. "Barracks✗ " end

	if warFactoryBuilt then buildingStatus = buildingStatus .. "War Factory✓"
	else buildingStatus = buildingStatus .. "War Factory✗" end

	Media.DisplayMessage("Buildings: " .. buildingStatus)
	
	Media.DisplayMessage("Units: Rifle Infantry(" .. infantryCount .. "/" .. requiredInfantry .. ") " ..
	                   "Rocket Soldier(" .. artilleryCount .. "/" .. requiredArtillery .. ") " ..
	                   "Ore Truck(" .. oreTruckCount .. "/" .. requiredOreTruck .. ") " ..
	                   "Mobile Flak(" .. ftrkCount .. "/" .. requiredFTRK .. ")")
end

function ShowFinalProgress()
	Media.DisplayMessage("=== Final Results ===")
	
	local buildingStatus = "Buildings Completed: "
	if powerPlantBuilt then buildingStatus = buildingStatus .. "Power Plant✓ "
	else buildingStatus = buildingStatus .. "Power Plant✗ " end
	
	if barracksBuilt then buildingStatus = buildingStatus .. "Barracks✓ "
	else buildingStatus = buildingStatus .. "Barracks✗ " end
	
	if warFactoryBuilt then buildingStatus = buildingStatus .. "War Factory✓"
	else buildingStatus = buildingStatus .. "War Factory✗" end
	
	Media.DisplayMessage(buildingStatus)
	
	Media.DisplayMessage("Units Produced: Rifle Infantry(" .. infantryCount .. "/" .. requiredInfantry .. ") " ..
	                   "Rocket Soldier(" .. artilleryCount .. "/" .. requiredArtillery .. ") " ..
	                   "Ore Truck(" .. oreTruckCount .. "/" .. requiredOreTruck .. ") " ..
	                   "Mobile Flak(" .. ftrkCount .. "/" .. requiredFTRK .. ")")
end


Tick = function()

	if missionCompleted or missionFailed then
		return
	end
	
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
