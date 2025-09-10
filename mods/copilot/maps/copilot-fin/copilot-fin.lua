-- mods/copilot/maps/copilot_showdown/copilot_mode.lua

-- === 参数区 ===
local MATCH_SECONDS          = 15 * 60
local CAP_RADIUS_CELLS       = 10      -- 占点半径
local AURA_RADIUS_CELLS      = 25      -- Buff 生效半径
local CAP_PER_TICK           = 5       -- 每秒占领值
local CAP_THRESHOLD          = 100     -- 占领阈值（100 满格）
local SCORE_TICK_SECONDS     = 3       -- 积分周期
local SPAWN_INTERVAL_SECONDS = 60      -- 刷塔间隔
local TOWERS_PER_WAVE        = 2       -- 每波刷几个塔
local MAX_TOWERS             = 8       -- 地图最多活动的塔

-- Debug开关
local DEBUG_ENABLED          = true    -- 是否启用debug输出
local FACT_DETECTION_RADIUS  = 5       -- 检测fact附近e1的半径（格）

-- 可抽取的 Buff（就是“条件名”），数值在 YAML 里
local BUFF_POOL = {
  "cp_open_skies",
  "cp_rkt_barrage",
  "cp_inf_dmg_up",
  "cp_inf_slow",
  "cp_inf_berserk",
  "cp_tank_dmg_up",
  "cp_tank_armor_up",
  "cp_tank_slow",
  "cp_aa_overdrive",
  "cp_air_haste",
  "cp_air_slow",
  "cp_air_nerf",
}

-- === 内部状态 ===
local Players = {}
local Scores  = {}   -- [player.Id] = int
local Towers  = {}   -- { actor=Actor, wpos=WPos, capOwner=Player|nil, capProgress=0..100, buff="cond", enterId, exitId, tokens = { [actorId] = token } }
local FactPositions = {}  -- fact位置列表
local E1Tokens = {}  -- 跟踪已添加cp_inf_slow条件的e1单位 { [actorId] = token }

-- === 工具 ===
local function secs(n) return DateTime.Seconds(n) end

-- Debug消息输出函数
local function debugMsg(msg)
  if DEBUG_ENABLED then
    UserInterface.DisplayMessage("[DEBUG] " .. msg)
  end
end

-- 检测fact附近的e1单位并添加cp_inf_slow条件
local function checkE1NearFacts()
  for _, factPos in ipairs(FactPositions) do
    local radius = WDist.FromCells(FACT_DETECTION_RADIUS)
    local nearbyUnits = Map.ActorsInCircle(factPos, radius)
    
    for _, unit in ipairs(nearbyUnits) do
      if unit and not unit.IsDead and unit.Type == "e1" then
        local actorId = unit.ActorID
        
        -- 如果这个e1还没有添加cp_inf_slow条件
        if not E1Tokens[actorId] then
          local token = unit.GrantCondition("cp_inf_slow")
          E1Tokens[actorId] = token
          debugMsg(string.format("E1 %d near fact at (%d,%d) - added cp_inf_slow", 
            actorId, factPos.X, factPos.Y))
        end
      end
    end
  end
  
  -- 检查已添加条件的e1是否还在fact附近，如果不在则移除条件
  for actorId, token in pairs(E1Tokens) do
    local unit = Actor.FromID(actorId)
    if not unit or unit.IsDead then
      -- 单位已死亡，清理token
      E1Tokens[actorId] = nil
      debugMsg(string.format("E1 %d died - removed cp_inf_slow token", actorId))
    else
      -- 检查是否还在任何fact附近
      local stillNearFact = false
      for _, factPos in ipairs(FactPositions) do
        local radius = WDist.FromCells(FACT_DETECTION_RADIUS)
        local distance = (unit.CenterPosition - factPos).Length
        if distance <= radius.Length then
          stillNearFact = true
          break
        end
      end
      
      if not stillNearFact then
        -- 不在fact附近了，移除条件
        unit.RevokeCondition(token)
        E1Tokens[actorId] = nil
        debugMsg(string.format("E1 %d left fact area - removed cp_inf_slow", actorId))
      end
    end
  end
end

local function pickRandom(t)
  -- 用引擎的随机 cell/距离保证一致性；对索引也可用地图 PRNG 的“等价”做法：取随机单元格的 X/Y 做哈希
  local c = Map.RandomCell()                                             -- 共享 RNG（多人一致）
  local idx = (c.X + c.Y) % #t + 1
  return t[idx]
end

local function createTowerAt(cell, buff)
  local pos = Map.CenterOfCell(cell)
  local a = Actor.Create("CP_Tower", { Owner = Player.GetPlayer("Neutral") }, pos)

  local tower = {
    actor = a, wpos = pos, buff = buff,
    capOwner = nil, capProgress = 0,
    tokens = {}, enterId = nil, exitId = nil
  }

  -- 注册进入/离开范围触发（Aura 半径）
  local radius = WDist.FromCells(AURA_RADIUS_CELLS)

  tower.enterId = Trigger.OnEnteredProximityTrigger(pos, radius, function(unit, id)
    if not unit or unit.IsDead or unit.Owner == Player.GetPlayer("Neutral") then return end
    -- 授予条件（返回撤销 token）
    local token = unit.GrantCondition(tower.buff)   -- 需在单位 YAML 预声明 ExternalCondition
    tower.tokens[unit.ActorID] = token
  end)

  tower.exitId = Trigger.OnExitedProximityTrigger(pos, radius, function(unit, id)
    if not unit then return end
    local token = tower.tokens[unit.ActorID]
    if token then
      unit.RevokeCondition(token)
      tower.tokens[unit.ActorID] = nil
    end
  end)

  table.insert(Towers, tower)
end

local function spawnTowersWave()
  local toSpawn = math.min(TOWERS_PER_WAVE, math.max(0, MAX_TOWERS - #Towers))
  for i=1,toSpawn do
    local cell = Map.RandomCell()
    local buff = pickRandom(BUFF_POOL)
    createTowerAt(cell, buff)
  end
end

-- 每秒做占点推进（CAP 半径更小）
local function tickCapture()
  for _, t in ipairs(Towers) do
    if t.actor and not t.actor.IsDead then
      local capRadius = WDist.FromCells(CAP_RADIUS_CELLS)
      local around = Map.ActorsInCircle(t.wpos, capRadius)

      -- 统计非中立单位按阵营分布
      local present = {}
      for _, u in ipairs(around) do
        if not u.IsDead and u.Owner and u.Owner ~= Player.GetPlayer("Neutral") then
          present[u.Owner.InternalName] = true
        end
      end

      local aloneOwner = nil
      for _, p in ipairs(Players) do
        local key = p.InternalName
        if present[key] then
          if aloneOwner == nil then aloneOwner = p else aloneOwner = false break end
        end
      end

      if aloneOwner and aloneOwner ~= false then
        -- 只有一方在圈内且无敌对，推进
        if t.capOwner == nil or t.capOwner == aloneOwner then
          t.capProgress = math.min(CAP_THRESHOLD, t.capProgress + CAP_PER_TICK)
          if t.capProgress >= CAP_THRESHOLD then
            t.capOwner = aloneOwner
            -- 可加个文本提示
            UserInterface.DisplayMessage(string.format("Point captured by %s", aloneOwner.Name))
          end
        else
          -- 被另一方争夺，先清空再推进
          t.capProgress = math.max(0, t.capProgress - CAP_PER_TICK)
          if t.capProgress == 0 then
            t.capOwner = nil
          end
        end
      else
        -- 双方都在/都不在：停滞或缓慢衰减
        t.capProgress = math.max(0, t.capProgress - 1)
        if t.capProgress == 0 then t.capOwner = nil end
      end
    end
  end

  Trigger.AfterDelay(secs(1), tickCapture)
end

-- 每 SCORE_TICK_SECONDS 结算得分
local function tickScore()
  for _, t in ipairs(Towers) do
    if t.capOwner ~= nil then
      Scores[t.capOwner.InternalName] = (Scores[t.capOwner.InternalName] or 0) + 1
    end
  end

  -- 简单显示：每 3 秒刷一次消息（UI 组件修改需 C#，地图层不支持改 UI）
  local aScore = Scores[Players[1].InternalName] or 0
  local bScore = Scores[Players[2].InternalName] or 0
  UserInterface.DisplayMessage(string.format("Score  A:%d  B:%d", aScore, bScore))

  Trigger.AfterDelay(secs(SCORE_TICK_SECONDS), tickScore)
end

-- Match 计时与结束判定
local function startMatchTimer()
  local remaining = MATCH_SECONDS
  local function tick()
    remaining = remaining - 1
    if remaining <= 0 then
      local a = Players[1]; local b = Players[2]
      local sA = Scores[a.InternalName] or 0
      local sB = Scores[b.InternalName] or 0
      if sA > sB then
        a.Win()
        b.Lose()
      elseif sB > sA then
        b.Win()
        a.Lose()
      else
        -- 平局（可加细化 tie-break）
        UserInterface.DisplayMessage("Tie! Sudden death not implemented.")
        a.Lose(); b.Lose()
      end
      return
    end
    Trigger.AfterDelay(secs(1), tick)
  end
  Trigger.AfterDelay(secs(1), tick)
end

-- 定时刷塔
local function scheduleSpawn()
  spawnTowersWave()
  Trigger.AfterDelay(secs(SPAWN_INTERVAL_SECONDS), scheduleSpawn)
end

-- 定时检查fact附近的e1单位
local function scheduleE1Check()
  debugMsg("Checking e1 near facts")
  checkE1NearFacts()
  Trigger.AfterDelay(secs(1), scheduleE1Check)  -- 每秒检查一次
end

-- === 入口 ===
WorldLoaded = function()
  -- 两个非中立玩家
  Players = { Player.GetPlayer("Multi0"), Player.GetPlayer("Multi1") }
  for _, p in ipairs(Players) do Scores[p.InternalName] = 0 end

  -- 初始化fact位置（从地图文件中获取）
  FactPositions = {
    Map.CenterOfCell(CPos.New(31, 99)),  -- Actor351: fact
    Map.CenterOfCell(CPos.New(27, 94)),  -- Actor351: fact (第二个fact)
    Map.CenterOfCell(CPos.New(83, 12))   -- Actor352: fact
  }
  
  debugMsg(string.format("Initialized %d fact positions", #FactPositions))

  -- 开始循环
  tickCapture()
  tickScore()
  scheduleSpawn()
  scheduleE1Check()  -- 启动e1检查
  startMatchTimer()
end
