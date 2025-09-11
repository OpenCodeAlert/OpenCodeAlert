-- mods/copilot/maps/copilot_showdown/copilot_mode.lua

-- === 参数区 ===
local MATCH_SECONDS          = 15 * 60
local CONTROL_POINT_LIFETIME = 2 * 60  -- 控制点持续时间（2分钟）
local CONTROL_POINT_SPAWN_MIN = 30     -- 控制点生成间隔最小值（30秒）
local CONTROL_POINT_SPAWN_MAX = 90     -- 控制点生成间隔最大值（90秒）
local BUFF_REFRESH_MIN = 30            -- Buff刷新间隔最小值（30秒）
local BUFF_REFRESH_MAX = 90            -- Buff刷新间隔最大值（90秒）
local BUFF_RADIUS_CELLS = 12           -- Buff生效半径（12格）
local MAX_CONTROL_POINTS = 5           -- 最大控制点数量

-- Debug开关
local DEBUG_ENABLED          = true    -- 是否启用debug输出

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
local ControlPoints = {}  -- 控制点列表
local ControlPointTimes = {}  -- 控制点创建时间记录
local ControlPointCounter = 0  -- 控制点计数器
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
  ControlPointTimes[name] = GameTime
  
  -- 从可用列表中移除，添加到已使用列表
  for i, spawn in ipairs(UNUSED_SPAWN_POINTS) do
    if spawn == selectedSpawn then
      table.remove(UNUSED_SPAWN_POINTS, i)
      break
    end
  end
  UsedSpawnPoints[selectedSpawn] = true
    
    
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

  local currentTime = GameTime
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
    
    if isExpired then
      table.insert(toRemove, i)
      if cp.actor and not cp.actor.IsDead then
        Trigger.RemoveControlPoint(cp.name)
      end
      
      -- 清理CAMERA
      if cp.camera1 and not cp.camera1.IsDead then
        cp.camera1.Destroy()
        -- debugMsg(string.format("Destroyed camera1 for control point %s", cp.name))
      end
      
      if cp.camera2 and not cp.camera2.IsDead then
        cp.camera2.Destroy()
        -- debugMsg(string.format("Destroyed camera2 for control point %s", cp.name))
      end
      
      -- 释放生成点
      if cp.spawnPoint then
        UsedSpawnPoints[cp.spawnPoint] = nil
        table.insert(UNUSED_SPAWN_POINTS, cp.spawnPoint)
        -- debugMsg(string.format("Released spawn point %s", cp.spawnPoint.Name))
      end
      
      -- 清理时间记录
      ControlPointTimes[cp.name] = nil
      
      -- 清理相关的Buff记录
      for buffName, units in pairs(cp.buffedUnits) do
        for unit, buffData in pairs(units) do
          if buffData.token and not unit.IsDead then
            unit.RevokeCondition(buffData.token)
            debugMsg(string.format("Removed buff %s from %s due to control point removal", 
              buffName, unit.Type))
          end
        end
      end
      cp.buffedUnits = {}  -- 清空该控制点的Buff记录
      
      debugMsg(string.format("Removed control point %s: %s", cp.name, reason))
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

-- 定时检查控制点Buff
local function scheduleControlPointCheck()

--   debugMsg(string.format("Checking control points: %d active", #ControlPoints))
--   checkControlPointBuffs()
  cleanupExpiredControlPoints()
--   debugMsg("Scheduling next control point check in 1 second")
  Trigger.AfterDelay(secs(1), scheduleControlPointCheck)  -- 每秒检查一次
end


-- === 入口 ===
WorldLoaded = function()
  -- 两个非中立玩家
  Players = { Player.GetPlayer("Multi0"), Player.GetPlayer("Multi1") }
  
  debugMsg("ControlPoint system initializing...")
  debugMsg(string.format("Players: %s, %s", Players[1].Name, Players[2].Name))
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
  scheduleControlPointSpawn()  -- 启动控制点生成
  
  debugMsg("Starting control point check scheduler...")
  scheduleControlPointCheck()  -- 启动控制点检查
  
  debugMsg("ControlPoint system fully initialized")
end

-- Tick函数：处理控制点Buff的应用和移除
Tick = function()
  -- 处理每个控制点的Buff
  for _, cp in ipairs(ControlPoints) do
    if cp.actor and not cp.actor.IsDead and cp.buffs then
    -- debugMsg(string.format("Checking control point %s", cp.name))
      local pos = cp.actor.CenterPosition
      local radius = WDist.FromCells(BUFF_RADIUS_CELLS)
      local nearbyUnits = Map.ActorsInCircle(pos, radius)
      
      -- 收集当前范围内的单位
      local currentUnits = {}
      for _, unit in ipairs(nearbyUnits) do
        unitID = tostring(unit)
        if unit and not unit.IsDead and unit.Owner ~= Player.GetPlayer("Neutral") then
          currentUnits[unitID] = true
          for _, buff in ipairs(cp.buffs) do
            local unitType, buffType, buffName = buff[1], buff[2], buff[3]
            -- 初始化buffName表
            if not cp.buffedUnits[buffName] then
              cp.buffedUnits[buffName] = {}
            end
            if unit.Type == unitType then
                -- 如果单位还没有这个Buff，添加它
                if not cp.buffedUnits[buffName][unit] then
                local token = unit.GrantCondition(buffName)
                if token then
                    cp.buffedUnits[buffName][unit] = {
                    unit = unit,
                    token = token
                    }
                    debugMsg(string.format("Applied buff %s to %s at control point %s", 
                    buffName, unitType, cp.name))
                else
                    debugMsg(string.format("Failed to grant buff %s to %s at control point %s", 
                    buffName, unitType, cp.name))
                end
                else
                --   debugMsg(string.format("Unit %s already has buff %s at control point %s", unitType, buffName, cp.name))
                end
            end
          end
        end
      end

      -- 清理不在范围内的单位的Buff
      for buffName, units in pairs(cp.buffedUnits) do
        for unit, buffData in pairs(units) do
          -- 如果单位死亡或不在范围内，移除Buff
          if not currentUnits[buffData.unit] then
            if buffData.token then
              unit.RevokeCondition(buffData.token)
              debugMsg(string.format("Removed buff %s from %s at control point %s (reason: %s)", 
                buffName, unit.Type, cp.name, unit.IsDead and "dead" or "out of range"))
            end
            cp.buffedUnits[buffName][unit] = nil
          end
        end
      end
    end
  end
end
