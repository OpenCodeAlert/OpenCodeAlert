local ALL_SPAWN_POINTS = {
  -- map中的预定义生成点
  Actor1, Actor3
}

-- 兵种类型
local UNIT_TYPES = {
  "e1", "e3", "v2rl", "ftrk", "3tnk", "4tnk", "mig", "yak"
}

local BUFF_CONFIGS = {

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
  self.nextSpawnTime = DateTime.GameTime + Utils.secs(Utils.random(30, 60))
  end,
  
  update = function(self)
    -- 检查是否需要生成新控制点
    -- 清理过期的控制点
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
  
    local spawnIndex = Utils.random(1, #self.availableSpawns)
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
    -- 清理控制点
    -- 释放生成位置
    -- 通知其他系统
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
    -- 初始化系统
  end,
  
  update = function(self)
    -- 检查是否到达更新间隔
    -- 处理所有控制点的Buff
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
    -- 初始化计分系统
  end,
  
  update = function(self)
    -- 统计控制点内单位
    -- 计算分数变化
    -- 更新显示
  end,
  
  calculateUnitCounts = function(self)
    -- 遍历所有控制点
    -- 统计各方单位数量
    -- 返回统计结果
  end,
  
  updateScores = function(self, p1Units, p2Units)
    -- 根据优势比例计算得分
    -- 更新分数
    -- 触发显示更新
  end,
  
  getScores = function(self)
    return self.scores
  end,
  
  displayScoreUpdate = function(self, gained, p1Units, p2Units)
    -- 显示得分信息
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
    
    -- 检查时间是否到期
    -- 检查建筑摧毁条件
    -- 触发相应的胜利/失败逻辑
  end,
  
  checkTimeLimit = function(self)
    -- 计算剩余时间
    -- 按分数判断胜负
  end,
  
  checkBuildingDestruction = function(self)
    -- 当某一方基地被摧毁时，立即结束游戏
  end,
  
  declareVictory = function(self, winner, reason, finalScores)
    -- 标记游戏完成
    -- 设置目标状态
    -- 显示胜利信息
  end
}

local GameCore = {
  initialized = false,
  players = {},
  objectives = {},
  
  init = function(self)
    -- 获取玩家引用
    -- 初始化目标系统  
    -- 初始化各个子系统
    -- 设置定时器
    self.initialized = true
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
    -- 为测试提供初始单位
  end
}

-- === 事件处理 ===
local EventHandler = {
  onControlPointCreated = function(point)
    BuffSystem:onPointCreated(point)
  end,
  
  onControlPointDestroyed = function(pointId)
    BuffSystem:onPointDestroyed(pointId)
  end,
  
  onUnitDied = function(unit)
    -- 清理该单位的所有Buff记录
  end
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
    -- 生成随机Buff配置
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
  end
}

local function setupPeriodicTasks()
  -- 每秒更新控制点管理
  Trigger.AfterDelay(Utils.secs(1), function()
    ControlPointManager:update()
    Trigger.AfterDelay(Utils.secs(1), setupPeriodicTasks)
  end)
  
  -- 每2秒更新Buff系统  
  Trigger.AfterDelay(Utils.secs(CONFIG.buffs.checkInterval), function()
    BuffSystem:update()
  end)
  
  -- 每秒更新计分系统
  Trigger.AfterDelay(Utils.secs(CONFIG.scoring.updateInterval), function()
    ScoreSystem:update()
  end)
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
end

-- main game loop tick
Tick = function()
  VictoryConditions:check()
end