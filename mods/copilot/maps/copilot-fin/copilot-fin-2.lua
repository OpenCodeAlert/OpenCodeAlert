local ALL_SPAWN_POINTS = {
  -- map中的预定义生成点
  Actor1, Actor3
}

-- 兵种类型
local UNIT_TYPES = {
  "e1", "e3", "v2rl", "ftrk", "3tnk", "4tnk", "mig", "yak"
}

local BUFF_CONFIGS = {
  -- 简化的Buff配置，后续在BuffSystem中使用
  {unitType = "e1", condition = "firepower_boost", name = "Infantry Firepower"},
  {unitType = "3tnk", condition = "armor_boost", name = "Tank Armor"},  
  {unitType = "any", condition = "speed_boost", name = "Movement Speed"}
}

local CONFIG = {
  game = {
    -- 总游戏时间5分钟
    duration = 5 * 60,
    debug = true
  },
  controlPoints = {
    maxActive = 5,
    -- 每个控制点2分钟
    lifetime = 2 * 60,
    spawnInterval = {30, 90},
    buffRadius = 12
  },
  scoring = {
    -- 优势比例
    advantageRatio = 2.0,
    pointsPerSecond = 1,
    updateInterval = 1
  },
  buffs = {
    checkInterval = 2,
    stabilityTime = 2
  }
}

-- === 工具函数 ===
local Utils = {
  secs = function(n) 
    return DateTime.Seconds(n) 
  end,
  
  debugMsg = function(msg)
    if CONFIG.game.debug then
      Media.DisplayMessage("[DEBUG] " .. msg)
    end
  end,
  
  Random = function(min, max)
    return min + (DateTime.GameTime % (max - min + 1))
  end,

  pickRandom = function(tbl)
    if not tbl or #tbl == 0 then return nil end
    return tbl[Utils.Random(1, #tbl)]
  end,
  
  generateRandomBuffs = function()
    -- 简单返回固定配置，后续可扩展为随机生成
    return {
      {unitType = "e1", condition = "firepower_boost"},
      {unitType = "3tnk", condition = "armor_boost"}
    }
  end,
  
  getUnitsInRadius = function(position, radius, excludeNeutral)
    local units = Map.ActorsInCircle(position, WDist.FromCells(radius))
    local result = {}
    
    for _, unit in ipairs(units) do
        if unit and not unit.IsDead then
        if not excludeNeutral or unit.Owner.Name ~= "Neutral" then
            table.insert(result, unit)
        end
        end
    end
    
    return result
  end,
  
  Where = function(collection, predicate)
    local result = {}
    for _, item in ipairs(collection) do
      if predicate(item) then
        table.insert(result, item)
      end
    end
    return result
  end
}

local EventHandler = {
  onControlPointCreated = function(point)
    -- 暂时空实现，BuffSystem 初始化后会正确处理
    if BuffSystem and BuffSystem.onPointCreated then
      BuffSystem:onPointCreated(point)
    end
  end,
  
  onControlPointDestroyed = function(pointId)
    -- 暂时空实现，BuffSystem 初始化后会正确处理
    if BuffSystem and BuffSystem.onPointDestroyed then
      BuffSystem:onPointDestroyed(pointId)
    end
  end,
  
  onUnitDied = function(unit)
    -- 清理该单位的所有Buff记录
  end
}

local GameCore = {
  initialized = false,
  players = {},
  objectives = {},
  
  init = function(self)
    Utils.debugMsg("Initializing GameCore...")
     
    self:initPlayers()
    self:initObjectives()
    
    self.initialized = true
    Utils.debugMsg("GameCore initialized successfully")
  end,
  
  initPlayers = function(self)
    self.players[1] = Player.GetPlayer("Multi0")
    self.players[2] = Player.GetPlayer("Multi1")
    if not self.players[1] or not self.players[2] then
        Utils.debugMsg("Warning: Could not find both players!")
    end
  end,
  
  initObjectives = function(self)
    InitObjectives(self.players[1])
    InitObjectives(self.players[2])
    self.objectives.p1Primary = AddPrimaryObjective(self.players[1], "destroy-enemy-base-or-win-by-score")
    self.objectives.p1Secondary = AddSecondaryObjective(self.players[1], "control-strategic-points")
  
    self.objectives.p2Primary = AddPrimaryObjective(self.players[2], "defend-enemy-base-or-win-by-score") 
    self.objectives.p2Secondary = AddSecondaryObjective(self.players[2], "control-strategic-points")
  end,
  
  setupTimers = function(self)
    -- 设置各系统的定时更新
  end,
  
  provideTestUnits = function(self)
    if not self.players[1] then
      Utils.debugMsg("Cannot provide test units - player not found")
      return
    end
    
    -- 在玩家基地附近生成测试单位
    local testUnits = Reinforcements.Reinforce(self.players[1], {"e1", "e1", "3tnk"}, {CPos.New(25, 95), CPos.New(26, 95)})
    Utils.debugMsg("Provided " .. #testUnits .. " test units for player")
    Media.DisplayMessage("Test units deployed! Move them to control points to test the system.", "Notification")
  end
}

-- 控制点管理器
local ControlPointManager = {
  activePoints = {},
  availableSpawns = {},
  nextSpawnTime = 0,
  
  init = function(self)
    for _, spawn in ipairs(ALL_SPAWN_POINTS) do
      if spawn and not spawn.IsDead then
        table.insert(self.availableSpawns, spawn)
      end
    end
  self.nextSpawnTime = DateTime.GameTime + Utils.secs(Utils.Random(30, 60))
  end,
  
  update = function(self)
    local currentTime = DateTime.GameTime
    
    -- 检查是否需要生成新控制点
    if currentTime >= self.nextSpawnTime and #self.activePoints < CONFIG.controlPoints.maxActive then
      if self:createPoint() then
        -- 设置下次生成时间
        local interval = Utils.Random(CONFIG.controlPoints.spawnInterval[1], CONFIG.controlPoints.spawnInterval[2])
        self.nextSpawnTime = currentTime + Utils.secs(interval)
        Utils.debugMsg("Next control point spawn in " .. interval .. " seconds")
      end
    end
    
    -- 清理过期的控制点
    self:cleanupExpiredPoints()
  end,
  
  createPoint = function(self)
    -- 选择生成位置
    -- 创建控制点Actor
    -- 生成随机Buff配置
    -- 通知其他系统
    if #self.activePoints >= CONFIG.controlPoints.maxActive then
        return false
    end
  
    if #self.availableSpawns == 0 then
        Utils.debugMsg("No available spawn points!")
        return false
    end
  
    local spawnIndex = Utils.Random(1, #self.availableSpawns)
    local spawn = self.availableSpawns[spawnIndex]
    table.remove(self.availableSpawns, spawnIndex)
    
    local point = {
        id = "cp_" .. DateTime.GameTime,
        spawn = spawn,
        position = spawn.CenterPosition,
        createdAt = DateTime.GameTime,
        expiresAt = DateTime.GameTime + Utils.secs(CONFIG.controlPoints.lifetime),
        buffs = Utils.generateRandomBuffs()
    }
    
    table.insert(self.activePoints, point)
    Utils.debugMsg("Created control point: " .. point.id)
    
    EventHandler.onControlPointCreated(point)
    return true
  end,
  
  destroyPoint = function(self, pointId)
    for i, point in ipairs(self.activePoints) do
      if point.id == pointId then
        -- 释放生成位置
        table.insert(self.availableSpawns, point.spawn)
        
        -- 从活跃列表中移除
        table.remove(self.activePoints, i)
        
        -- 通知其他系统
        EventHandler.onControlPointDestroyed(pointId)
        
        Utils.debugMsg("Destroyed control point: " .. pointId)
        return true
      end
    end
    return false
  end,
  
  cleanupExpiredPoints = function(self)
    local currentTime = DateTime.GameTime
    local toRemove = {}
    
    for i, point in ipairs(self.activePoints) do
      if currentTime >= point.expiresAt then
        table.insert(toRemove, i)
        Utils.debugMsg("Control point " .. point.id .. " expired")
      end
    end
    
    -- 从后往前删除，避免索引问题
    for i = #toRemove, 1, -1 do
      local pointIndex = toRemove[i]
      local point = self.activePoints[pointIndex]
      
      -- 释放生成位置
      table.insert(self.availableSpawns, point.spawn)
      
      -- 通知其他系统
      EventHandler.onControlPointDestroyed(point.id)
      
      -- 从活跃列表中移除
      table.remove(self.activePoints, pointIndex)
    end
  end,
  
  getActivePoints = function(self)
    return self.activePoints
  end
}

-- Buff系统
local BuffSystem = {
  activeBuffs = {},  -- {pointId: {unitId: buffData}}
  lastCheckTime = 0,
  
  init = function(self)
    self.activeBuffs = {}
    self.lastCheckTime = DateTime.GameTime
    Utils.debugMsg("BuffSystem initialized (basic version)")
  end,
  
  update = function(self)
    -- 暂时空实现，第三阶段会完整实现
    -- Utils.debugMsg("BuffSystem update (placeholder)")
  end,
  
  processPointBuffs = function(self, point)
    -- 获取范围内单位
    -- 应用新Buff
    -- 移除过期Buff
  end,
  
  applyBuff = function(self, unit, buffName, pointId)
    -- 检查单位类型匹配
    -- 应用Buff条件
    -- 记录Buff状态
  end,
  
  removeBuff = function(self, unit, buffName, pointId)
    -- 移除Buff条件
    -- 清理记录
  end,
  
  onPointCreated = function(self, point)
    -- 初始化该控制点的Buff记录
  end,
  
  onPointDestroyed = function(self, pointId)
    -- 清理该控制点的所有Buff
  end
}

-- 计分系统
local ScoreSystem = {
  scores = {0, 0},
  lastUpdate = 0,
  lastDisplayTime = 0,
  
  init = function(self)
    self.scores = {0, 0}
    self.lastUpdate = DateTime.GameTime
    self.lastDisplayTime = DateTime.GameTime
    Utils.debugMsg("ScoreSystem initialized")
  end,
  
  update = function(self)
    local currentTime = DateTime.GameTime
    if currentTime - self.lastUpdate < Utils.secs(CONFIG.scoring.updateInterval) then
      return
    end
    
    local p1Units, p2Units = self:calculateUnitCounts()
    self:updateScores(p1Units, p2Units)
    
    self.lastUpdate = currentTime
  end,
  
  calculateUnitCounts = function(self)
    local p1Units = 0
    local p2Units = 0
    local players = GameCore.players
    
    for _, point in ipairs(ControlPointManager:getActivePoints()) do
      local units = Utils.getUnitsInRadius(point.position, CONFIG.controlPoints.buffRadius, true)
      
      for _, unit in ipairs(units) do
        if unit.Owner == players[1] then
          p1Units = p1Units + 1
        elseif unit.Owner == players[2] then
          p2Units = p2Units + 1
        end
      end
    end
    
    return p1Units, p2Units
  end,
  
  updateScores = function(self, p1Units, p2Units)
    local scoreGained = false
    local players = GameCore.players
    
    -- 如果玩家1有优势
    if (p2Units > 0 and p1Units >= p2Units * CONFIG.scoring.advantageRatio) or 
       (p2Units == 0 and p1Units > 0) then
      self.scores[1] = self.scores[1] + CONFIG.scoring.pointsPerSecond
      scoreGained = true
      Trigger.AddMatchScore(players[1], CONFIG.scoring.pointsPerSecond)
      Utils.debugMsg(string.format("Player 1 gains %d point! (%d vs %d units)", 
        CONFIG.scoring.pointsPerSecond, p1Units, p2Units))
    -- 如果玩家2有优势  
    elseif (p1Units > 0 and p2Units >= p1Units * CONFIG.scoring.advantageRatio) or 
           (p1Units == 0 and p2Units > 0) then
      self.scores[2] = self.scores[2] + CONFIG.scoring.pointsPerSecond
      scoreGained = true
      Trigger.AddMatchScore(players[2], CONFIG.scoring.pointsPerSecond)
      Utils.debugMsg(string.format("Player 2 gains %d point! (%d vs %d units)", 
        CONFIG.scoring.pointsPerSecond, p2Units, p1Units))
    end
    
    -- 定期显示分数更新
    local currentTime = DateTime.GameTime
    if scoreGained or (currentTime - self.lastDisplayTime) > Utils.secs(30) then
      self:displayScoreUpdate(scoreGained, p1Units, p2Units)
      self.lastDisplayTime = currentTime
    end
  end,
  
  getScores = function(self)
    return self.scores
  end,
  
  displayScoreUpdate = function(self, gained, p1Units, p2Units)
    local players = GameCore.players
    local message = string.format("Score: %s: %d, %s: %d", 
      players[1] and players[1].Name or "Player1", self.scores[1],
      players[2] and players[2].Name or "Player2", self.scores[2])
    
    if gained then
      message = message .. " (Point gained!)"
    end
    
    Media.DisplayMessage(message, "Notification")
  end
}

-- 胜利条件检查器
local VictoryConditions = {
  gameCompleted = false,
  gameStartTime = 0,
  
  init = function(self)
    self.gameStartTime = DateTime.GameTime
  end,
  
  check = function(self)
    if self.gameCompleted then return end
    
    -- 检查建筑摧毁条件（优先级更高）
    if self:checkBuildingDestruction() then
      return
    end
    
    -- 检查时间是否到期
    self:checkTimeLimit()
  end,
  
  checkTimeLimit = function(self)
    local currentTime = DateTime.GameTime
    local elapsed = currentTime - self.gameStartTime
    local timeLimit = Utils.secs(CONFIG.game.duration)
    
    if elapsed >= timeLimit then
      -- 时间到期，按分数判断胜负
      local scores = ScoreSystem:getScores()
      
      if scores[1] > scores[2] then
        self:declareVictory(1, "score", scores)
      elseif scores[2] > scores[1] then
        self:declareVictory(2, "score", scores)
      else
        self:declareVictory(0, "draw", scores) -- 平局
      end
      
      return true
    end
    
    return false
  end,
  
  checkBuildingDestruction = function(self)
    local players = GameCore.players
    if not players[1] or not players[2] then return false end
    
    -- 检查玩家1的建筑
    local p1Buildings = Utils.Where(Map.ActorsInWorld, function(actor)
      return actor.Owner == players[1] and actor.HasProperty("StartBuildingRepairs") and not actor.IsDead
    end)
    
    -- 检查玩家2的建筑
    local p2Buildings = Utils.Where(Map.ActorsInWorld, function(actor)
      return actor.Owner == players[2] and actor.HasProperty("StartBuildingRepairs") and not actor.IsDead
    end)
    
    if #p1Buildings == 0 then
      self:declareVictory(2, "destruction", ScoreSystem:getScores())
      return true
    elseif #p2Buildings == 0 then
      self:declareVictory(1, "destruction", ScoreSystem:getScores())
      return true
    end
    
    return false
  end,
  
  declareVictory = function(self, winner, reason, finalScores)
    self.gameCompleted = true
    
    local players = GameCore.players
    local objectives = GameCore.objectives
    
    local message = ""
    if winner == 0 then
      -- 平局
      message = string.format("Game Over - Draw! Final Score: %d-%d", finalScores[1], finalScores[2])
      if objectives.p1Primary then players[1].MarkFailedObjective(objectives.p1Primary) end
      if objectives.p2Primary then players[2].MarkFailedObjective(objectives.p2Primary) end
    elseif winner == 1 then
      -- 玩家1胜利
      if reason == "destruction" then
        message = "Victory! Enemy base destroyed!"
      else
        message = string.format("Victory by Score! Final: %d-%d", finalScores[1], finalScores[2])
      end
      if objectives.p1Primary then players[1].MarkCompletedObjective(objectives.p1Primary) end
      if objectives.p2Primary then players[2].MarkFailedObjective(objectives.p2Primary) end
    elseif winner == 2 then
      -- 玩家2胜利
      if reason == "destruction" then
        message = "Defeat! Your base was destroyed!"
      else
        message = string.format("Defeat by Score! Final: %d-%d", finalScores[2], finalScores[1])
      end
      if objectives.p1Primary then players[1].MarkFailedObjective(objectives.p1Primary) end
      if objectives.p2Primary then players[2].MarkCompletedObjective(objectives.p2Primary) end
    end
    
    Media.DisplayMessage(message, "Menacing")
    Utils.debugMsg("Game completed: " .. message)
  end
}

-- === 事件处理 ===
-- local EventHandler = {
--   onControlPointCreated = function(point)
--     BuffSystem:onPointCreated(point)
--   end,
  
--   onControlPointDestroyed = function(pointId)
--     BuffSystem:onPointDestroyed(pointId)
--   end,
  
--   onUnitDied = function(unit)
--     -- 清理该单位的所有Buff记录
--   end
-- }

local function setupPeriodicTasks()
  -- 控制点管理 - 每秒更新
  local function controlPointTask()
    ControlPointManager:update()
    Trigger.AfterDelay(Utils.secs(1), controlPointTask)
  end
  Trigger.AfterDelay(Utils.secs(1), controlPointTask)
  
  -- Buff系统 - 每2秒更新  
  local function buffTask()
    BuffSystem:update()
    Trigger.AfterDelay(Utils.secs(CONFIG.buffs.checkInterval), buffTask)
  end
  Trigger.AfterDelay(Utils.secs(CONFIG.buffs.checkInterval), buffTask)
  
  -- 计分系统 - 每秒更新
  local function scoreTask()
    ScoreSystem:update()
    Trigger.AfterDelay(Utils.secs(CONFIG.scoring.updateInterval), scoreTask)
  end
  Trigger.AfterDelay(Utils.secs(CONFIG.scoring.updateInterval), scoreTask)
end

-- === 主入口点 ===
WorldLoaded = function()
  Utils.debugMsg("Initializing Control Point Conquest Mode...")
  
  Trigger.SetAgentMode(false)

  -- 初始化游戏核心
  GameCore:init()
  
  -- 初始化各个系统
  ControlPointManager:init()
  BuffSystem:init()
  ScoreSystem:init()
  VictoryConditions:init()
  
  -- 设置定时任务
  setupPeriodicTasks()
  
  -- 提供测试单位
  Trigger.AfterDelay(Utils.secs(2), function()
    GameCore:provideTestUnits()
  end)
  
  -- 测试控制点
  Trigger.AfterDelay(Utils.secs(5), function()
    ControlPointManager:createPoint()
  end)
  
  Utils.debugMsg("System initialization complete!")
  
  -- 显示游戏规则
  Media.DisplayMessage(string.format("Control Point Conquest - %d minutes to victory!", CONFIG.game.duration / 60), "Notification")
  Trigger.AfterDelay(Utils.secs(3), function()
    Media.DisplayMessage("Destroy enemy base OR win by score! Get 2x more units in control points to gain points.", "Notification")
  end)
end

-- main game loop tick
Tick = function()
  VictoryConditions:check()
end