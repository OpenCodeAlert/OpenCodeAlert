-- 分数配置
local SCORE_PRIMARY_RESOURCES = 40.0
local SCORE_PRIMARY_BUILDINGS = 40.0
local SCORE_SECONDARY_NO_POWER_SHORTAGE = 10.0
local SCORE_SECONDARY_NO_RESOURCE_SHORTAGE = 10.0
local SCORE_SECONDARY_TIME_BONUS = 20.0
local SCORE_TIME_PENALTY = -50.0

-- 目标配置
local TARGET_RESOURCES = 15000
local TIME_LIMIT = 300
local REQUIRED_BUILDINGS = {"powr", "barr", "proc", "weap", "dome", "fix", "apwr", "afld", "stek"}

-- 状态变量
local player
local hasHadPowerShortage = false
local hasHadResourceShortage = false
local resourcesObjectiveCompleted = false
local buildingsObjectiveCompleted = false
local gameCompleted = false

-- 目标变量
local resourcesObjective
local buildingsObjective
local noPowerShortageObjective
local noResourceShortageObjective
local timeObjective

function WorldLoaded()
    Trigger.SetAgentMode(true)
    Trigger.SetScore(0.0)
    
    player = Player.GetPlayer("Multi0")
    InitObjectives(player)
    
    resourcesObjective = AddPrimaryObjective(player, "accumulate-15000-resources")
    buildingsObjective = AddPrimaryObjective(player, "build-9-required-buildings")
    noPowerShortageObjective = AddSecondaryObjective(player, "no-power-shortage")
    noResourceShortageObjective = AddSecondaryObjective(player, "no-resource-shortage")
    timeObjective = AddSecondaryObjective(player, "complete-within-300-seconds")
    
    DateTime.TimeLimit = DateTime.Seconds(TIME_LIMIT)
    
    StartObjectiveMonitoring()
    
    Media.DisplayMessage("Objective: Accumulate 15000 resources, build 9 specified buildings")
end

function StartObjectiveMonitoring()
    local function MonitorLoop()
        if gameCompleted then
            return
        end
        
        CheckObjectives()
        Trigger.AfterDelay(25, MonitorLoop)
    end
    
    Trigger.AfterDelay(25, MonitorLoop)
end

function CheckObjectives()
    -- 检查资源目标
    if not resourcesObjectiveCompleted and (player.Cash + player.Resources) >= TARGET_RESOURCES then
        resourcesObjectiveCompleted = true
        Trigger.AddScore(SCORE_PRIMARY_RESOURCES)
        player.MarkCompletedObjective(resourcesObjective)
        Media.DisplayMessage("Resources objective completed!")
    end
    
    -- 检查建筑目标
    if not buildingsObjectiveCompleted then
        local completedBuildings = 0
        for _, buildingType in pairs(REQUIRED_BUILDINGS) do
            local buildings = player.GetActorsByType(buildingType)
            if #buildings > 0 then
                completedBuildings = completedBuildings + 1
            end
        end
        
        if completedBuildings >= 9 then
            buildingsObjectiveCompleted = true
            Trigger.AddScore(SCORE_PRIMARY_BUILDINGS)
            player.MarkCompletedObjective(buildingsObjective)
            Media.DisplayMessage("Buildings objective completed!")
        end
    end
    
    -- 检查电力不足
    if not hasHadPowerShortage and (player.PowerState == "Low" or player.PowerState == "Critical") then
        hasHadPowerShortage = true
        player.MarkFailedObjective(noPowerShortageObjective)
        Media.DisplayMessage("Power shortage detected")
    end
    
    -- 检查资源不足
    if not hasHadResourceShortage and (player.Cash + player.Resources) <= 0 then
        hasHadResourceShortage = true
        player.MarkFailedObjective(noResourceShortageObjective)
        Media.DisplayMessage("Resource shortage detected")
    end
    
    -- 检查游戏完成
    if resourcesObjectiveCompleted and buildingsObjectiveCompleted and not gameCompleted then
        gameCompleted = true
        CompleteGame()
    end
end

function CompleteGame()
    local currentTimeFrames = DateTime.GameTime
    local currentTimeSeconds = currentTimeFrames / 25  -- 25帧 = 1秒
    
    -- 处理次要目标
    if not hasHadPowerShortage then
        Trigger.AddScore(SCORE_SECONDARY_NO_POWER_SHORTAGE)
        player.MarkCompletedObjective(noPowerShortageObjective)
    end
    
    if not hasHadResourceShortage then
        Trigger.AddScore(SCORE_SECONDARY_NO_RESOURCE_SHORTAGE)
        player.MarkCompletedObjective(noResourceShortageObjective)
    end
    
    if currentTimeSeconds <= TIME_LIMIT then
        Trigger.AddScore(SCORE_SECONDARY_TIME_BONUS)
        player.MarkCompletedObjective(timeObjective)
        Media.DisplayMessage("Time bonus achieved!")
    else
        Trigger.AddScore(SCORE_TIME_PENALTY)
        player.MarkFailedObjective(timeObjective)
    end
    
    Media.DisplayMessage("Mission completed! Final time: " .. math.floor(currentTimeSeconds) .. " seconds")
end

Tick = function()
    if player.HasNoRequiredUnits() then
        player.MarkFailedObjective(resourcesObjective)
        player.MarkFailedObjective(buildingsObjective)
    end
end
