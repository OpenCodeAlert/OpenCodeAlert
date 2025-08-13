WorldLoaded = function()
    Camera.Position = DefaultCameraPosition.CenterPosition
    Trigger.SetAgentMode(true)

    Player1 = Player.GetPlayer("multi1")  -- 玩家
    Enemy = Player.GetPlayer("multi0")    -- 敌方

    InitObjectives(Player1)

    MainObjective = AddPrimaryObjective(Player1, "Destroy enemy base")
    TimeObjective = AddSecondaryObjective(Player1, "Complete within 120 seconds")
    
    missionStartTime = DateTime.GameTime
    missionDuration = DateTime.Seconds(120)
    missionCompleted = false
    missionFailed = false
    
    Trigger.SetScore(220.0)  -- 初始化分数为200

    -- 进度显示计数器
    progressUpdateCounter = 0
    progressUpdateInterval = DateTime.Seconds(10)
    
    -- 获取玩家的战斗机（使用具体ID）
    playerYaks = {}
    for i = 1, 20 do
        local yak = Map.NamedActor("yak_" .. i)
        if yak then
            table.insert(playerYaks, yak)
        end
    end
    initialYakCount = #playerYaks
    
    -- 获取敌方基地
    enemyBase = Map.NamedActor("m0_yard")
    
    Media.DisplayMessage("Air Strike Mission! Destroy the enemy base within 120 seconds!")
    Media.DisplayMessage("Target: Enemy base")
    
    Trigger.AfterDelay(missionDuration, function()
        if not missionCompleted then
            Player1.MarkFailedObjective(TimeObjective)
            Media.DisplayMessage("Time's up! Time objective failed.", "Mission")
            ShowFinalReport()
        else
            Player1.MarkCompletedObjective(TimeObjective)
        end
    end)
    
    Trigger.OnAnyProduction(function(producer, produced, productionType)
        if produced.Owner == Player1 and not missionCompleted and not missionFailed then
            missionFailed = true
            Player1.MarkFailedObjective(MainObjective)
            Media.DisplayMessage("Mission Failed! Building/Production is not allowed in this mission!")
            ShowFinalReport()
        end
    end)
    
    Trigger.OnKilled(enemyBase, function()
        if not missionCompleted and not missionFailed then
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
            Media.DisplayMessage("Mission Accomplished! Enemy base destroyed!")
            
            local timeUsed = DateTime.GameTime - missionStartTime
            local secondsUsed = timeUsed / DateTime.Seconds(1)
            Media.DisplayMessage("Time used: " .. string.format("%.1f", secondsUsed) .. " seconds")
            ShowFinalReport()
        end
    end)
    
    -- 设置敌方单位的基本防御行为
    SetupEnemyDefense()
end

function SetupEnemyDefense()
    local enemyInfantry = Enemy.GetActorsByTypes({"e1", "e3"})
    
    -- 设置敌方步兵的防御行为
    Utils.Do(enemyInfantry, function(unit)
        if not unit.IsDead then
            Trigger.OnDamaged(unit, function(self, attacker)
                if attacker and not attacker.IsDead and self.CanTarget(attacker) then
                    self.Attack(attacker)
                end
            end)
        end
    end)
    
    -- SAM导弹会自动攻击飞机，不需要额外设置
end

function ShowProgress()
    if missionCompleted or missionFailed then
        return
    end
    
    local timeElapsed = DateTime.GameTime - missionStartTime
    local timeRemaining = missionDuration - timeElapsed
    local secondsRemaining = timeRemaining / DateTime.Seconds(1)

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
end

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
    Trigger.AddScore(-5.0 * lostYaks)  -- 每损失一架战斗机扣5分
    
    local finalTime = DateTime.GameTime - missionStartTime
    local finalSeconds = finalTime / DateTime.Seconds(1)
    Trigger.AddScore( (- finalSeconds) )  -- 根据完成时间奖励分数，时间越短分数越高，最多奖励120分
    
    Media.DisplayMessage("Time used: " .. string.format("%.1f", finalSeconds) .. "/120 seconds")
    
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