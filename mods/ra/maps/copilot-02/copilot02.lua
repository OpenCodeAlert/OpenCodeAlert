WorldLoaded = function()

	Trigger.SetAgentMode(true)

	Player1 = Player.GetPlayer("Player")
	MyPlane = Map.NamedActor("MyPlane")

	InitObjectives(Player1)
	
	ExploreObjective = AddPrimaryObjective(Player1, "Explore 80% of the map")
	TimeObjective = AddSecondaryObjective(Player1, "Complete within 100 seconds")
	
	exploredCells = {}  -- 存储已探索的格子，使用格子坐标作为key
	targetExploredCells = 600  -- 若设为800则可基本覆盖40x40的地图
	planeVisionRange = 3  -- 飞机视野半径（格子数）
	missionStartTime = DateTime.GameTime
	missionDuration = DateTime.Seconds(100)
	targetExplorePercentage = 80
	
	-- 任务状态
	missionCompleted = false
	missionFailed = false
	
	-- 进度显示计数器
	progressUpdateCounter = 0
	progressUpdateInterval = DateTime.Seconds(5)
	timeHalfwayReminder = false
	
	Trigger.AfterDelay(missionDuration, function()
		if not missionCompleted then
			local currentExploredCount = 0
			for _ in pairs(exploredCells) do
				currentExploredCount = currentExploredCount + 1
			end
			Player1.MarkFailedObjective(TimeObjective)
			Media.DisplayMessage("Time's up! Time objective failed.", "Mission")
			Media.DisplayMessage("Current exploration: " .. currentExploredCount .. " cells (Target: " .. targetExploredCells .. ")", "Mission")
		else
			Player1.MarkCompletedObjective(TimeObjective)
		end
	end)
	
	-- 监听飞机死亡
	Trigger.OnKilled(MyPlane, function()
		if not missionCompleted and not missionFailed then
			missionFailed = true
			Player1.MarkFailedObjective(ExploreObjective)
			Media.PlaySpeechNotification(Player1, "ObjectiveNotMet")
			Media.DisplayMessage("Mission Failed! MyPlane destroyed")
		end
	end)
end

-- 计算飞机视野范围内的格子
function GetVisionCells(centerPos, range)
	local visionCells = {}
	
	-- 遍历以centerPos为中心，range为半径的正方形区域
	for x = centerPos.X - range, centerPos.X + range do
		for y = centerPos.Y - range, centerPos.Y + range do
			-- 创建格子坐标
			local cellPos = CPos.New(x, y)
			-- 简化检查：仅检查距离，不检查地图边界（让引擎处理）
			local distance = math.sqrt((x - centerPos.X)^2 + (y - centerPos.Y)^2)
			if distance <= range then
				local cellKey = x .. "," .. y
				table.insert(visionCells, cellKey)
			end
		end
	end
	
	return visionCells
end

-- 更新探索进度
function UpdateExplorationProgress()
	if MyPlane.IsDead or not MyPlane.IsInWorld then
		return
	end
	
	-- 获取飞机当前位置
	local currentPos = MyPlane.Location
	
	-- 计算视野范围内的格子
	local visionCells = GetVisionCells(currentPos, planeVisionRange)
	
	-- 添加新探索的格子
	local newCellsCount = 0
	for _, cellKey in pairs(visionCells) do
		if not exploredCells[cellKey] then
			exploredCells[cellKey] = true
			newCellsCount = newCellsCount + 1
		end
	end
	
	-- 计算当前探索百分比
	local currentExploredCount = 0
	for _ in pairs(exploredCells) do
		currentExploredCount = currentExploredCount + 1
	end
	
	local currentPercentage = (currentExploredCount / targetExploredCells) * 100
	
	if currentExploredCount >= targetExploredCells and not missionCompleted then
		missionCompleted = true
		Player1.MarkCompletedObjective(ExploreObjective)
		-- 计算用时
		local timeUsed = DateTime.GameTime - missionStartTime
		local secondsUsed = timeUsed / DateTime.Seconds(1)
		Media.DisplayMessage("Time used: " .. string.format("%.1f", secondsUsed) .. " seconds")
		local durationSeconds = missionDuration / DateTime.Seconds(1)
		Trigger.SetScore(15.0  + durationSeconds - secondsUsed)  -- 根据用时计算分数
		
		-- 检查时间目标
		if not Player1.IsObjectiveFailed(TimeObjective) then
			Player1.MarkCompletedObjective(TimeObjective)
		else
			-- 如果时间目标失败，扣除分数
			Trigger.AddScore(-50.0)
		end
		
		Media.PlaySpeechNotification(Player1, "ObjectiveMet")
		Media.DisplayMessage("Mission Completed! Explored " .. currentExploredCount .. " cells (Target: " .. targetExploredCells .. ")")
	end
	
	return currentPercentage, newCellsCount
end

function ShowProgress()
	if missionCompleted or missionFailed then
		return
	end
	
	local currentExploredCount = 0
	for _ in pairs(exploredCells) do
		currentExploredCount = currentExploredCount + 1
	end
	
	local progressPercentage = (currentExploredCount / targetExploredCells) * 100
	local timeElapsed = DateTime.GameTime - missionStartTime
	local timeRemaining = missionDuration - timeElapsed
	local secondsRemaining = timeRemaining / DateTime.Seconds(1)
	
	Media.DisplayMessage("Exploration progress: " .. currentExploredCount .. "/" .. targetExploredCells .. " cells (" .. string.format("%.1f", progressPercentage) .. "%) | Time remaining: " .. string.format("%.0f", secondsRemaining) .. " seconds")
	
	if timeElapsed >= missionDuration / 2 and not timeHalfwayReminder then
		timeHalfwayReminder = true
		Media.DisplayMessage("Notice: Time is halfway through, current progress " .. currentExploredCount .. "/" .. targetExploredCells .. " cells")
	end
end


Tick = function()

	if missionCompleted or missionFailed then
		return
	end
	
	if MyPlane.IsDead or not MyPlane.IsInWorld then
		if not missionFailed then
			missionFailed = true
			Player1.MarkFailedObjective(ExploreObjective)
			Media.DisplayMessage("Mission Failed! MyPlane is not in world or has been destroyed")
		end
		return
	end
	
	UpdateExplorationProgress()
	
	progressUpdateCounter = progressUpdateCounter + 1
	if progressUpdateCounter >= progressUpdateInterval then
		progressUpdateCounter = 0
		ShowProgress()
	end
end
