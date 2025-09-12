-- mods/copilot/maps/copilot_showdown/copilot_mode.lua

-- === 参数区 ===
local CONTROL_POINT_LIFETIME = 2 * 60  -- 控制点持续时间（2分钟）
local CONTROL_POINT_SPAWN_MIN = 30     -- 控制点生成间隔最小值（30秒）
local CONTROL_POINT_SPAWN_MAX = 90     -- 控制点生成间隔最大值（90秒）
local BUFF_REFRESH_MIN = 30            -- Buff刷新间隔最小值（30秒）
local BUFF_REFRESH_MAX = 90            -- Buff刷新间隔最大值（90秒）
local BUFF_RADIUS_CELLS = 12           -- Buff生效半径（12格）
local MAX_CONTROL_POINTS = 5           -- 最大控制点数量

-- Debug开关
local DEBUG_ENABLED          = false    -- 是否启用debug输出

-- 兵种类型
local UNIT_TYPES = {
  "e1", "e3", "v2rl", "ftrk", "3tnk", "4tnk", "mig", "yak"
}

-- 通用Buff池
local GENERIC_BUFFS = {
  "cp_dmg_up_50", "cp_dmg_up_150", "cp_dmg_down_75", "cp_dmg_down_30",
  "cp_armor_30", "cp_armor_75", "cp_armor_150", "cp_armor_300",
  "cp_speed_50", "cp_speed_200"
}

-- 特殊Buff池（按兵种分类）
local SPECIAL_BUFFS = {
  e1 = {
    "cp_inf_slow", "cp_inf_berserk", "cp_inf_rapidfire", 
    "cp_inf_accuracy", "cp_inf_overheat", "cp_inf_fragile"
  },
  e3 = {
    "cp_rkt_slow", "cp_rkt_rapidfire", "cp_rkt_overcharge",
    "cp_rkt_anti_armor", "cp_rkt_splash", "cp_rkt_accuracy",
    "cp_rkt_malfunction", "cp_rkt_fragile"
  },
  v2rl = {
    "cp_v2_rapidfire", "cp_v2_range_decay", "cp_v2_overdrive",
    "cp_v2_splash", "cp_v2_guidance_failure", "cp_v2_cant_move", "cp_v2_fragile"
  },
  ftrk = {
    "cp_aa_rapidfire", "cp_aa_overdrive", "cp_aa_anti_air",
    "cp_aa_anti_ground", "cp_aa_jammed", "cp_aa_fragile"
  },
  ["3tnk"] = {
    "cp_tank_armor_up", "cp_tank_slow", "cp_tank_overdrive",
    "cp_tank_ap_rounds", "cp_tank_engine_failure", "cp_tank_fragile"
  },
  ["4tnk"] = {
    "cp_mammoth_armor_up", "cp_mammoth_slow", "cp_mammoth_dual_cannon",
    "cp_mammoth_apex", "cp_mammoth_system_overload", "cp_mammoth_fragile"
  },
  mig = {
    "cp_mig_speed_up", "cp_mig_anti_armor", "cp_mig_overdrive",
    "cp_mig_maverick", "cp_mig_stall", "cp_mig_fragile"
  },
  yak = {
    "cp_yak_rapidfire", "cp_yak_anti_infantry", "cp_yak_overdrive",
    "cp_yak_chaingun", "cp_yak_jammed", "cp_yak_fragile"
  }
}

-- === 内部状态 ===
local Players = {}
local Multi0, Multi1 -- 玩家引用
local ControlPoints = {}  -- 控制点列表
local ControlPointTimes = {}  -- 控制点创建时间记录
local ControlPointCounter = 0  -- 控制点计数器

-- 控制点占领相关
local OCCUPATION_MIN_UNITS = 5  -- 占领所需最少单位数
local OCCUPATION_RATIO = 5  -- 占领比例要求（5倍）

-- 游戏目标相关
local gameCompleted = false
local SovietObjective, AlliedObjective

-- Buff处理计时器
local buffCheckTicks = 0
local BUFF_CHECK_INTERVAL = 15  -- 每15个tick检查一次（约0.6秒）
local ALL_SPAWN_POINTS = {
  CP_Spawn_01, CP_Spawn_02, CP_Spawn_03, CP_Spawn_04, CP_Spawn_05,
  CP_Spawn_06, CP_Spawn_07, CP_Spawn_08, CP_Spawn_09, CP_Spawn_10,
  CP_Spawn_11, CP_Spawn_12, CP_Spawn_13, CP_Spawn_14, CP_Spawn_15
}
local UNUSED_SPAWN_POINTS = ALL_SPAWN_POINTS
local UsedSpawnPoints = {}  -- 已使用的生成点

-- === 工具 ===
local function secs(n) return DateTime.Seconds(n) end

-- Debug消息输出函数
local function debugMsg(msg)
  if DEBUG_ENABLED then
    Media.DisplayMessage("[DEBUG] " .. msg)
  end
end

-- 随机选择函数
local function pickRandom(t)
  if not t or #t == 0 then 
    debugMsg("Warning: pickRandom called with empty or nil table")
    return nil 
  end
  local c = Map.RandomCell()
  local idx = (c.X + c.Y) % #t + 1
  local result = t[idx]
  debugMsg(string.format("pickRandom: selected index %d from table of size %d, result: %s", idx, #t, tostring(result)))
  return result
end

-- 生成随机Buff
local function generateRandomBuffs()
  local buffs = {}
  local buffCount = 2 + Map.RandomCell().X % 3  -- 2-4个buff
  
  debugMsg(string.format("Generating %d random buffs", buffCount))
  
  for i = 1, buffCount do
    debugMsg(string.format("Generating buff %d/%d", i, buffCount))
    
    -- 随机选择兵种
    local unitType = pickRandom(UNIT_TYPES)
    if not unitType then 
      debugMsg("Warning: No unit type selected")
      break 
    end
    
    -- 随机选择Buff类型（通用或特殊）
    local buffType = Map.RandomCell().X % 2 == 0 and "generic" or "special"
    local buffName = nil
    
    if buffType == "generic" then
      buffName = pickRandom(GENERIC_BUFFS)
    else
      local specialBuffs = SPECIAL_BUFFS[unitType]
      if specialBuffs and #specialBuffs > 0 then
        buffName = pickRandom(specialBuffs)
      else
        -- 如果特殊Buff不存在，回退到通用Buff
        debugMsg(string.format("Warning: No special buffs for unit type %s, falling back to generic", unitType))
        buffName = pickRandom(GENERIC_BUFFS)
        buffType = "generic"
      end
    end
    
    if buffName then
      table.insert(buffs, {unitType, buffType, buffName})
      debugMsg(string.format("Generated buff: %s for %s (%s)", buffName, unitType, buffType))
    else
      debugMsg(string.format("Warning: No buff name generated for unit type %s", unitType))
    end
  end
  
  debugMsg(string.format("Generated %d buffs total", #buffs))
  
  -- 验证生成的Buff
  for i, buff in ipairs(buffs) do
    local unitType, buffType, buffName = buff[1], buff[2], buff[3]
    debugMsg(string.format("Buff %d: %s for %s (%s)", i, buffName, unitType, buffType))
  end
  
  return buffs
end

-- 创建控制点
local function createControlPoint()

  -- 如果没有可用生成点，返回
  if #UNUSED_SPAWN_POINTS == 0 then
    debugMsg("Warning: No available spawn points for control point creation")
    return
  end
  
  -- 随机选择一个生成点
  local selectedSpawn = pickRandom(UNUSED_SPAWN_POINTS)
  if not selectedSpawn then
    debugMsg("Warning: Failed to select spawn point")
    return
  end
  
  local pos = selectedSpawn.Location
--   local cell = Map.CellContaining(pos)
  
--   debugMsg(string.format("Attempting to create control point at %s (%d,%d)", selectedSpawn.Name, cell.X, cell.Y))
  
  -- 创建控制点Actor
  local initTable = {
    Owner = Player.GetPlayer("Neutral"),
    Location = pos
  }
  local actor = Actor.Create("GAP", true, initTable)
  
  if not actor then
    debugMsg("Warning: Failed to create control point actor")
    return
  end
  
  -- 生成唯一名称
  ControlPointCounter = ControlPointCounter + 1
  local name = "ControlPoint_" .. ControlPointCounter
  
--   debugMsg(string.format("Creating control point %s at %s (%d,%d)", name, selectedSpawn.Name, cell.X, cell.Y))
  
  -- 添加到ControlPoint管理器
  Trigger.AddControlPoint(name, actor, pos.X, pos.Y)
  
  -- 为两个阵营创建CAMERA
  local camera1 = Actor.Create("CAMERA", true, {
    Owner = Players[1],
    Location = pos
  })
  
  local camera2 = Actor.Create("CAMERA", true, {
    Owner = Players[2], 
    Location = pos
  })
  
  if camera1 then
    -- debugMsg(string.format("Created camera for %s at control point %s", Players[1].Name, name))
  else
    debugMsg("Warning: Failed to create camera for player 1")
  end
  
  if camera2 then
    -- debugMsg(string.format("Created camera for %s at control point %s", Players[2].Name, name))
  else
    debugMsg("Warning: Failed to create camera for player 2")
  end

  local buffs = generateRandomBuffs()

  -- 记录到本地列表
  table.insert(ControlPoints, {
    name = name,
    actor = actor,
    pos = pos,
    spawnPoint = selectedSpawn,
    camera1 = camera1,
    camera2 = camera2,
    buffs = buffs,
    buffedUnits = {}  -- 每个控制点维护自己的Buff单位记录 {buffName: {actor: {unit, token}}}
  })
  
  -- 记录创建时间
  ControlPointTimes[name] = DateTime.GameTime
  
  -- 从可用列表中移除，添加到已使用列表
  for i, spawn in ipairs(UNUSED_SPAWN_POINTS) do
    if spawn == selectedSpawn then
      table.remove(UNUSED_SPAWN_POINTS, i)
      break
    end
  end
  UsedSpawnPoints[selectedSpawn.ActorID] = true
    
    
  -- 创建Lua表传递给C#
  local buffsTable = {}
  for i, buff in ipairs(buffs) do
    local unitType, buffType, buffName = buff[1], buff[2], buff[3]
    buffsTable[i] = {unitType, buffType, buffName}
    debugMsg(string.format("Buff table entry %d: {%s, %s, %s}", i, unitType, buffType, buffName))
  end
  
--   debugMsg(string.format("Setting %d buffs for control point %s", #buffs, name))
  Trigger.SetControlPointBuffs(name, buffsTable)

  debugMsg(string.format("Successfully created control point at %s (%d,%d)", name, pos.X, pos.Y))
end


-- 清理过期的控制点
local function cleanupExpiredControlPoints()

  local currentTime = DateTime.GameTime
  local toRemove = {}
  
--   debugMsg(string.format("Checking %d control points for cleanup", #ControlPoints))
  
  for i, cp in ipairs(ControlPoints) do
    local isExpired = false
    local reason = ""
    
    if not cp.actor then
      isExpired = true
      reason = "actor is nil"
    elseif cp.actor.IsDead then
      isExpired = true
      reason = "actor is dead"
    elseif ControlPointTimes[cp.name] and (currentTime - ControlPointTimes[cp.name]) > secs(CONTROL_POINT_LIFETIME) then
      isExpired = true
      reason = "lifetime expired"
    end

    debugMsg(string.format("Control point %s remaining time: %d", cp.name,secs(CONTROL_POINT_LIFETIME) - (currentTime - ControlPointTimes[cp.name])))
    
    if isExpired then
      table.insert(toRemove, i)
      
      -- 先清理Buff，再移除控制点
      for buffName, units in pairs(cp.buffedUnits) do
        for unitActorID, buffData in pairs(units) do
          local unit = buffData.unit
          if buffData.token and not unit.IsDead then
            unit.RevokeCondition(buffData.token)
            debugMsg(string.format("Removed buff %s from %s due to control point removal", 
              buffName, unit.Type))
          end
        end
      end
      cp.buffedUnits = {}  -- 清空该控制点的Buff记录
      
      -- 移除控制点（无论actor是否死亡都要调用）
      Trigger.RemoveControlPoint(cp.name)
      debugMsg(string.format("Removed control point %s: %s", cp.name, reason))
      
      -- 销毁控制点Actor
      if cp.actor and not cp.actor.IsDead then
        cp.actor.Destroy()
        debugMsg(string.format("Destroyed control point actor %s", cp.name))
      end
      
      -- 清理CAMERA
      if cp.camera1 and not cp.camera1.IsDead then
        cp.camera1.Destroy()
        debugMsg(string.format("Destroyed camera1 for control point %s", cp.name))
      end
      
      if cp.camera2 and not cp.camera2.IsDead then
        cp.camera2.Destroy()
        debugMsg(string.format("Destroyed camera2 for control point %s", cp.name))
      end
      
      -- 释放生成点
      if cp.spawnPoint then
        UsedSpawnPoints[cp.spawnPoint.ActorID] = nil
        table.insert(UNUSED_SPAWN_POINTS, cp.spawnPoint)
        -- debugMsg(string.format("Released spawn point %s", cp.spawnPoint.ActorID))
      end
      
      -- 清理时间记录
      ControlPointTimes[cp.name] = nil
    else
    --   debugMsg(string.format("Control point %s is still active", cp.name))
    end
  end

  -- 从后往前删除，避免索引问题
  for i = #toRemove, 1, -1 do
    table.remove(ControlPoints, toRemove[i])
  end
  
  if #toRemove > 0 then
    debugMsg(string.format("Cleaned up %d expired control points", #toRemove))
  end
end

-- 定时创建控制点
local function scheduleControlPointSpawn()
  debugMsg(string.format("Checking control point spawn: %d/%d", #ControlPoints, MAX_CONTROL_POINTS))
  
  if #ControlPoints < MAX_CONTROL_POINTS then
    debugMsg("Creating new control point...")
    createControlPoint()
  else
    debugMsg("Maximum control points reached, skipping spawn")
  end
  
  -- 随机间隔30-90秒
  local nextSpawnDelay = CONTROL_POINT_SPAWN_MIN + Map.RandomCell().X % (CONTROL_POINT_SPAWN_MAX - CONTROL_POINT_SPAWN_MIN + 1)
  debugMsg(string.format("Next control point spawn in %d seconds", nextSpawnDelay))
  Trigger.AfterDelay(secs(nextSpawnDelay), scheduleControlPointSpawn)
end

-- 延迟创建第一个控制点
local function scheduleFirstControlPoint()
  debugMsg("Scheduling first control point in 10 seconds...")
  Trigger.AfterDelay(secs(10), function()
    debugMsg("Creating first control point...")
    -- createControlPoint()
    -- 创建第一个控制点后，启动正常的生成调度
    scheduleControlPointSpawn()
  end)
end

-- 定时检查控制点Buff
local function scheduleControlPointCheck()

--   debugMsg(string.format("Checking control points: %d active", #ControlPoints))
--   checkControlPointBuffs()
  cleanupExpiredControlPoints()
--   debugMsg("Scheduling next control point check in 1 second")
  Trigger.AfterDelay(secs(1), scheduleControlPointCheck)  -- 每秒检查一次
end


-- 游戏胜利检查
local function checkVictoryConditions()
  if gameCompleted then
    return
  end
  
  -- 检查Multi1（敌方）是否还有建筑
  local Multi1Buildings = Utils.Where(Map.ActorsInWorld, function(actor)
    return actor.Owner == Multi1 and actor.HasProperty("StartBuildingRepairs") and not actor.IsDead
  end)
  
  if #Multi1Buildings == 0 then
    gameCompleted = true
    Multi0.MarkCompletedObjective(SovietObjective)
    if AlliedObjective then Multi1.MarkFailedObjective(AlliedObjective) end
    debugMsg("Multi0 wins! All Multi1 buildings destroyed.")
    Media.DisplayMessage("Victory! All Multi1 buildings destroyed.", "Menacing")
    return
  end
  
  -- 检查Multi0（玩家）是否还有建筑
  local Multi0Buildings = Utils.Where(Map.ActorsInWorld, function(actor)
    return actor.Owner == Multi0 and actor.HasProperty("StartBuildingRepairs") and not actor.IsDead
  end)
  
  if #Multi0Buildings == 0 then
    gameCompleted = true
    if AlliedObjective then Multi1.MarkCompletedObjective(AlliedObjective) end
    Multi0.MarkFailedObjective(SovietObjective)
    debugMsg("Multi1 wins! All Multi0 buildings destroyed.")
    Media.DisplayMessage("Defeat! All Multi0 buildings are destroyed.", "Menacing")
  end
end


-- 检查控制点占领状态并加分
local function checkControlPointOccupation()
  if #ControlPoints == 0 then
    -- 如果没有控制点，1秒后再次检查
    Trigger.AfterDelay(secs(1), checkControlPointOccupation)
    return
  end
  
  for _, cp in ipairs(ControlPoints) do
    if cp.actor and not cp.actor.IsDead then
      local pos = cp.actor.CenterPosition
      local radius = WDist.FromCells(BUFF_RADIUS_CELLS)
      local nearbyUnits = Map.ActorsInCircle(pos, radius)
      
      -- 统计各阵营单位数量，因为有摄像机，所以需要-1
      local player0Units = -1
      local player1Units = -1
      
      for _, unit in ipairs(nearbyUnits) do
        if unit and not unit.IsDead and unit.Owner ~= Player.GetPlayer("Neutral") then
          if unit.Owner == Multi0 then
            player0Units = player0Units + 1
          elseif unit.Owner == Multi1 then
            player1Units = player1Units + 1
          end
        end
      end
      
      -- 检查占领条件
      local occupiedBy = nil
      local occupationScore = 0
      
      -- 检查Multi0是否占领
      if player0Units >= OCCUPATION_MIN_UNITS and player0Units >= player1Units * OCCUPATION_RATIO then
        occupiedBy = Multi0
        occupationScore = 1
        debugMsg(string.format("Control point %s occupied by %s (%d vs %d units)", 
          cp.name, Multi0.Name, player0Units, player1Units))
      -- 检查Multi1是否占领
      elseif player1Units >= OCCUPATION_MIN_UNITS and player1Units >= player0Units * OCCUPATION_RATIO then
        occupiedBy = Multi1
        occupationScore = 1
        debugMsg(string.format("Control point %s occupied by %s (%d vs %d units)", 
          cp.name, Multi1.Name, player1Units, player0Units))
      end
      
      -- 如果被占领，给对应玩家加分
      if occupiedBy and occupationScore > 0 then
        Trigger.AddMatchScore(occupiedBy, occupationScore, pos)
        debugMsg(string.format("Added %d point to %s for controlling %s", 
          occupationScore, occupiedBy.Name, cp.name))
      end
    end
  end
  
  -- 1秒后再次检查
  Trigger.AfterDelay(secs(1), checkControlPointOccupation)
end


-- === 入口 ===
WorldLoaded = function()
  Trigger.SetAgentMode(true)
  -- 获取玩家引用
  for _, p in ipairs(Player.GetAllPlayer()) do
      -- debugMsg(string.format("Player:%s", tostring(p.IsNonCombatant)))
      if not p.IsNonCombatant then
          table.insert(Players, p)
      end
  end
  -- debugMsg(string.format("PlayersNum:%d", #Players))
  Multi0 = Players[1]
  Multi1 = Players[2]

   if not Multi0 then
     debugMsg("Warning: Multi0 not found")
   end
   if not Multi1 then
     debugMsg("Warning: Multi1 not found")
   end
   

  InitObjectives(Multi0)
  InitObjectives(Multi1)
  
  -- 设置目标
  SovietObjective = AddPrimaryObjective(Multi0, "control-strategic-points")
  AddSecondaryObjective(Multi0, "defend-your-base")
  AlliedObjective = AddPrimaryObjective(Multi1, "control-strategic-points")
  AddSecondaryObjective(Multi1, "defend-your-base")
  
  -- 设置摄像机位置到玩家基地附近
  -- Camera.Position = CPos.New(30, 95).CenterPosition
  
  debugMsg("ControlPoint system initializing...")
  debugMsg(string.format("Players: %s vs %s", Multi0.Name, Multi1.Name))
  debugMsg(string.format("Unit types: %d", #UNIT_TYPES))
  debugMsg(string.format("Generic buffs: %d", #GENERIC_BUFFS))
  
  -- 检查生成点
  local availableSpawns = 0
  for _, spawn in ipairs(ALL_SPAWN_POINTS) do
    if spawn and not spawn.IsDead then
      availableSpawns = availableSpawns + 1
    --   debugMsg(string.format("Found spawn point: %s at (%d,%d)", spawn.Name, Map.CellContaining(spawn.CenterPosition).X, Map.CellContaining(spawn.CenterPosition).Y))
    else
    --   debugMsg(string.format("Warning: Spawn point %s not found or dead", spawn.Name))
    end
  end
  debugMsg(string.format("Total available spawn points: %d/15", availableSpawns))

  -- 启动控制点系统
  debugMsg("Starting control point spawn scheduler...")
  scheduleFirstControlPoint()  -- 延迟10秒创建第一个控制点
  
  debugMsg("Starting control point check scheduler...")
  scheduleControlPointCheck()  -- 启动控制点检查
  
  debugMsg("Starting control point occupation check...")
  checkControlPointOccupation()  -- 启动占领检查

  debugMsg("ControlPoint system fully initialized")
end

-- 处理控制点Buff
local function processControlPointBuffs()
  if #ControlPoints == 0 then
    return
  end
  
  -- debugMsg(string.format("Processing buffs for %d control points", #ControlPoints))
  
  for _, cp in ipairs(ControlPoints) do
    if cp.actor and not cp.actor.IsDead and cp.buffs then
    -- debugMsg(string.format("Checking control point %s", cp.name))
      local pos = cp.actor.CenterPosition
      local radius = WDist.FromCells(BUFF_RADIUS_CELLS)
      local nearbyUnits = Map.ActorsInCircle(pos, radius)
      
      -- 收集当前范围内的单位
      local currentUnits = {}
      for _, unit in ipairs(nearbyUnits) do
        if unit and not unit.IsDead and unit.Owner ~= Player.GetPlayer("Neutral") then
          local unitID = unit.ActorID
          currentUnits[unitID] = unit
          for _, buff in ipairs(cp.buffs) do
            local unitType, buffType, buffName = buff[1], buff[2], buff[3]
            -- 初始化buffName表
            if not cp.buffedUnits[buffName] then
              cp.buffedUnits[buffName] = {}
            end
            if unit.Type == unitType then
                -- 如果单位还没有这个Buff，添加它
                if not cp.buffedUnits[buffName][unitID] then
                  local token = unit.GrantCondition(buffName)
                  if token then
                      cp.buffedUnits[buffName][unitID] = {
                      unit = unit,
                      token = token
                      }
                      debugMsg(string.format("Applied buff %s to %s at control point %s", 
                      buffName, unitType, cp.name))
                  else
                      debugMsg(string.format("Failed to grant buff %s to %s at control point %s", 
                      buffName, unitType, cp.name))
                  end
                end
            end
          end
        end
      end

      -- 清理不在范围内的单位的Buff
      for buffName, units in pairs(cp.buffedUnits) do
        local toRemove = {}
        for unitActorID, buffData in pairs(units) do
          local unit = buffData.unit

          -- debugMsg(string.format("Current Buff:%s, unit:%s, currentUnits:%s", tostring(buffName), tostring(unit), tostring(currentUnits[unit.ActorID])))
          -- 如果单位死亡或不在范围内，移除Buff
          if unit.IsDead then
            debugMsg(string.format("Unit %s died, buff %s automatically removed at control point %s", 
                unit.Type, buffName, cp.name))
            table.insert(toRemove, unitActorID)
          elseif not currentUnits[unitActorID] then
            if buffData.token then
              -- 只对活着的单位调用RevokeCondition
              unit.RevokeCondition(buffData.token)
              debugMsg(string.format("Removed buff %s from %s at control point %s (reason: out of range)", 
                buffName, unit.Type, cp.name))
              table.insert(toRemove, unitActorID)
            end
          end
          
        end
        
        -- 批量移除已标记的单位
        for _, unitActorID in ipairs(toRemove) do
          cp.buffedUnits[buffName][unitActorID] = nil
        end
      end
    end
  end
end

-- Tick函数：处理控制点Buff的应用和移除，以及胜利条件检查
Tick = function()
  -- 检查比赛时间是否结束
  local matchTime = Trigger.GetMatchTime()
  if matchTime == 0 and not gameCompleted then
    gameCompleted = true
    
    -- 获取自己和敌人的分数
    local Multi0Score = Trigger.GetMatchScore(Multi0)
    local Multi1Score = Trigger.GetMatchScore(Multi1)
    
    debugMsg(string.format("Match time ended! Multi0 score: %d, Multi1 score: %d", Multi0Score, Multi1Score))
    
    -- 比较分数判断胜负
    if Multi0Score > Multi1Score then
      -- Multi0胜利
      Multi0.MarkCompletedObjective(SovietObjective)
      Multi1.MarkFailedObjective(AlliedObjective)
    elseif Multi1Score > Multi0Score then
      Multi1.MarkCompletedObjective(AlliedObjective)
      Multi0.MarkFailedObjective(SovietObjective)
    else
      -- 平局
      debugMsg("Draw! Same score.")
      Media.DisplayMessage("Draw! Same score.", "Menacing")
    end
    
    return
  end
  
  -- 检查胜利条件（每个tick检查，因为这个很轻量）
  checkVictoryConditions()
  
  -- 控制Buff处理频率，避免性能问题
  buffCheckTicks = buffCheckTicks + 1
  if buffCheckTicks >= BUFF_CHECK_INTERVAL then
    buffCheckTicks = 0
    processControlPointBuffs()
  end
end
