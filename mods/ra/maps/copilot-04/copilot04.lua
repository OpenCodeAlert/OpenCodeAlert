WorldLoaded = function()
    -- 设置 Agent 模式
    Trigger.SetAgentMode(false)

    -- 获取玩家对象
    Player1 = Player.GetPlayer("multi1")  -- 玩家
    Enemy = Player.GetPlayer("multi0")    -- 敌方

    InitObjectives(Player1)
    
    -- 添加主要任务目标
    MainObjective = AddPrimaryObjective(Player1, "destroy-enemy-base-in-100-seconds")
    
    -- 初始化任务变量
    missionStartTime = DateTime.GameTime
    missionDuration = DateTime.Seconds(180)  -- 180秒任务时间
    missionCompleted = false
    missionFailed = false
    
    -- 进度显示计数器
    progressUpdateCounter = 0
    progressUpdateInterval = DateTime.Seconds(10)  -- 每10秒显示一次进度
    
    -- 获取玩家的战斗机（使用具体ID）
    playerYaks = {}
    for i = 1, 20 do
        local yak = Map.NamedActor("yak_" .. i)
        if yak then
            table.insert(playerYaks, yak)
        end
    end
    initialYakCount = #playerYaks
    
    -- 获取敌方大本营
    enemyBase = Map.NamedActor("m0_yard")
    
    Media.DisplayMessage("Air Strike Mission! Destroy the enemy base within 100 seconds!")
    Media.DisplayMessage("You have " .. initialYakCount .. " fighters available.")
    Media.DisplayMessage("Target: Enemy base (m0_yard)")
    
    -- 设置180秒时间限制
    Trigger.AfterDelay(missionDuration, function()
        if not missionCompleted then
            missionFailed = true
            Player1.MarkFailedObjective(MainObjective)
            Media.PlaySpeechNotification(Player1, "ObjectiveNotMet")
            Media.DisplayMessage("Mission Failed! Time's up!")
            ShowFinalReport()
        end
    end)
    
    -- 监听玩家生产事件（禁止生产）
    Trigger.OnAnyProduction(function(producer, produced, productionType)
        if produced.Owner == Player1 and not missionCompleted and not missionFailed then
            missionFailed = true
            Player1.MarkFailedObjective(MainObjective)
            Media.DisplayMessage("Mission Failed! Building/Production is not allowed in this mission!")
            ShowFinalReport()
        end
    end)
    
    -- 监听敌方大本营被摧毁
    Trigger.OnKilled(enemyBase, function()
        if not missionCompleted and not missionFailed then
            missionCompleted = true
            Player1.MarkCompletedObjective(MainObjective)
            Media.PlaySpeechNotification(Player1, "ObjectiveMet")
            Media.DisplayMessage("Mission Accomplished! Enemy base destroyed!")
            
            -- 计算用时
            local timeUsed = DateTime.GameTime - missionStartTime
            local secondsUsed = timeUsed / DateTime.Seconds(1)
            Media.DisplayMessage("Time used: " .. string.format("%.1f", secondsUsed) .. " seconds")
            ShowFinalReport()
        end
    end)
    
    -- 设置敌方单位的基本防御行为
    SetupEnemyDefense()
end

-- 设置敌方防御行为
function SetupEnemyDefense()
    -- 获取敌方地面单位
    local enemyInfantry = Enemy.GetActorsByTypes({"e1", "e3"})
    
    -- 设置敌方步兵的防御行为
    Utils.Do(enemyInfantry, function(unit)
        if not unit.IsDead then
            -- 当受到攻击时进行反击
            Trigger.OnDamaged(unit, function(self, attacker)
                if attacker and not attacker.IsDead and self.CanTarget(attacker) then
                    self.Attack(attacker)
                end
            end)
        end
    end)
    
    -- SAM导弹会自动攻击飞机，不需要额外设置
end

-- 显示进度信息
function ShowProgress()
    if missionCompleted or missionFailed then
        return
    end
    
    local timeElapsed = DateTime.GameTime - missionStartTime
    local timeRemaining = missionDuration - timeElapsed
    local secondsRemaining = timeRemaining / DateTime.Seconds(1)

    -- 计算当前状态
    local survivingYakCount = 0
    Utils.Do(playerYaks, function(yak)
        if not yak.IsDead then
            survivingYakCount = survivingYakCount + 1
        end
    end)
    local lostYaks = initialYakCount - survivingYakCount
    
    local baseStatus = "Intact"
    if enemyBase.IsDead then
        baseStatus = "Destroyed"
    end
    
    Media.DisplayMessage("Time remaining: " .. string.format("%.0f", secondsRemaining) .. " seconds")
    Media.DisplayMessage("Fighters: " .. survivingYakCount .. "/" .. initialYakCount .. " (Lost: " .. lostYaks .. ")")
    Media.DisplayMessage("Enemy base status: " .. baseStatus)
end

-- 显示最终报告
function ShowFinalReport()
    Media.DisplayMessage("=== Mission Report ===")
    
    -- 计算最终统计
    local survivingYakCount = 0
    Utils.Do(playerYaks, function(yak)
        if not yak.IsDead then
            survivingYakCount = survivingYakCount + 1
        end
    end)
    local lostYaks = initialYakCount - survivingYakCount
    local survivalRate = (survivingYakCount / initialYakCount) * 100
    
    local finalTime = DateTime.GameTime - missionStartTime
    local finalSeconds = finalTime / DateTime.Seconds(1)
    
    Media.DisplayMessage("Time used: " .. string.format("%.1f", finalSeconds) .. "/100 seconds")
    Media.DisplayMessage("Aircraft losses: " .. lostYaks .. "/" .. initialYakCount .. " (" .. string.format("%.1f", 100-survivalRate) .. "% lost)")
    Media.DisplayMessage("Survival rate: " .. string.format("%.1f", survivalRate) .. "%")
    
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
    
    -- 检查是否所有战斗机都被摧毁
    local survivingYakCount = 0
    Utils.Do(playerYaks, function(yak)
        if not yak.IsDead then
            survivingYakCount = survivingYakCount + 1
        end
    end)
    
    if survivingYakCount == 0 and not missionCompleted then
        missionFailed = true
        Player1.MarkFailedObjective(MainObjective)
        Media.DisplayMessage("Mission Failed! All fighters destroyed!")
        ShowFinalReport()
    end
end