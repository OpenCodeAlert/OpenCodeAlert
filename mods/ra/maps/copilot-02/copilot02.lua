WorldLoaded = function()
	-- 设置 Agent 模式
	Trigger.SetAgentMode(false)

	Player1 = Player.GetPlayer("Player")
	MyPlane = Map.NamedActor("MyPlane")

	InitObjectives(Player1)
	
	-- 添加探索目标
	ExploreObjective = AddPrimaryObjective(Player1, "explore-80-percent-map-in-100-seconds")
	
	-- 初始化探索相关变量
	exploredCells = {}  -- 存储已探索的格子，使用格子坐标作为key
	targetExploredCells = 600  -- 若设为800则可基本覆盖40x40的地图
	planeVisionRange = 3  -- 飞机视野半径（格子数）
	missionStartTime = DateTime.GameTime
	missionDuration = DateTime.Seconds(100)  -- 100秒任务时间
	targetExplorePercentage = 80  -- 显示用的目标探索百分比
	
	-- 任务状态
	missionCompleted = false
	missionFailed = false
	
	-- 进度显示计数器
	progressUpdateCounter = 0
	progressUpdateInterval = DateTime.Seconds(5)  -- 每5秒显示一次进度
	
	-- 里程碑提醒
	milestone25 = false
	milestone50 = false
	milestone75 = false
	timeHalfwayReminder = false
	
	Media.DisplayMessage("探索任务开始！使用MyPlane在100秒内探索足够的地图区域")
	Media.DisplayMessage("目标：探索至少 " .. targetExploredCells .. " 个地图格子")
	
	-- 设置100秒时间限制
	Trigger.AfterDelay(missionDuration, function()
		if not missionCompleted then
			missionFailed = true
			local currentExploredCount = 0
			for _ in pairs(exploredCells) do
				currentExploredCount = currentExploredCount + 1
			end
			Player1.MarkFailedObjective(ExploreObjective)
			Media.PlaySpeechNotification(Player1, "ObjectiveNotMet")
			Media.DisplayMessage("任务失败！时间到，最终探索: " .. currentExploredCount .. " 格子 (目标: " .. targetExploredCells .. ")")
		end
	end)
	
	-- 监听飞机死亡
	Trigger.OnKilled(MyPlane, function()
		if not missionCompleted and not missionFailed then
			missionFailed = true
			Player1.MarkFailedObjective(ExploreObjective)
			Media.PlaySpeechNotification(Player1, "ObjectiveNotMet")
			Media.DisplayMessage("任务失败！MyPlane被摧毁")
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
	
	-- 检查是否完成目标
	if currentExploredCount >= targetExploredCells and not missionCompleted then
		missionCompleted = true
		Player1.MarkCompletedObjective(ExploreObjective)
		Media.PlaySpeechNotification(Player1, "ObjectiveMet")
		Media.DisplayMessage("任务完成！已探索 " .. currentExploredCount .. " 个格子 (目标: " .. targetExploredCells .. ")")
		
		-- 计算用时
		local timeUsed = DateTime.GameTime - missionStartTime
		local secondsUsed = timeUsed / DateTime.Seconds(1)
		Media.DisplayMessage("用时: " .. string.format("%.1f", secondsUsed) .. " 秒")
	end
	
	return currentPercentage, newCellsCount
end

-- 显示进度信息
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
	
	Media.DisplayMessage("探索进度: " .. currentExploredCount .. "/" .. targetExploredCells .. " 格子 (" .. string.format("%.1f", progressPercentage) .. "%) | 剩余时间: " .. string.format("%.0f", secondsRemaining) .. "秒")
	
	-- 里程碑提醒
	if progressPercentage >= 25 and not milestone25 then
		milestone25 = true
		Media.DisplayMessage("很好！已完成25%探索")
	elseif progressPercentage >= 50 and not milestone50 then
		milestone50 = true
		Media.DisplayMessage("不错！已完成50%探索")
	elseif progressPercentage >= 75 and not milestone75 then
		milestone75 = true
		Media.DisplayMessage("优秀！已完成75%探索，再接再厉！")
	end
	
	-- 时间过半提醒
	if timeElapsed >= missionDuration / 2 and not timeHalfwayReminder then
		timeHalfwayReminder = true
		Media.DisplayMessage("注意：时间已过半，当前进度 " .. currentExploredCount .. "/" .. targetExploredCells .. " 格子")
	end
end

-- 主循环函数
Tick = function()
	-- 检查任务是否已结束
	if missionCompleted or missionFailed then
		return
	end
	
	-- 检查飞机状态
	if MyPlane.IsDead or not MyPlane.IsInWorld then
		if not missionFailed then
			missionFailed = true
			Player1.MarkFailedObjective(ExploreObjective)
			Media.DisplayMessage("任务失败！MyPlane不在世界中或已被摧毁")
		end
		return
	end
	
	-- 更新探索进度（每帧都检查）
	UpdateExplorationProgress()
	
	-- 定期显示进度（每5秒一次）
	progressUpdateCounter = progressUpdateCounter + 1
	if progressUpdateCounter >= progressUpdateInterval then
		progressUpdateCounter = 0
		ShowProgress()
	end
end
