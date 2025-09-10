# OpenRA Copilot Buff System 完整文档

## 📋 系统概述

OpenRA Copilot Buff System 是一个完整的单位强化系统，为游戏中的各个兵种提供了丰富的buff和debuff机制。每个兵种都拥有通用buff和特色buff，增加了游戏的策略深度和趣味性。

## 🎯 系统特点

- **通用Buff**: 每个兵种都有10个通用buff，涵盖伤害、护甲、速度的增减
- **特色Buff**: 每个兵种有5-8个特色buff，体现兵种特色
- **负面Buff**: 每个兵种都有1-2个特色负面buff，增加策略深度
- **脆弱模式**: 所有兵种都有脆弱模式作为通用负面平衡
- **总计**: 每个兵种有 **16-19个Buff**，整个系统包含 **60+个不同的Buff条件**

## 📊 通用Buff（所有兵种都有）

| Condition名称 | 效果 | Modifier值 |
|---------------|------|------------|
| `cp_dmg_up_50` | 伤害提升50% | 150 |
| `cp_dmg_up_150` | 伤害提升150% | 250 |
| `cp_dmg_down_75` | 伤害降低至75% | 75 |
| `cp_dmg_down_30` | 伤害降低至30% | 30 |
| `cp_armor_30` | 受伤降低至30% | 30 |
| `cp_armor_75` | 受伤降低至75% | 75 |
| `cp_armor_150` | 受伤提升至150% | 150 |
| `cp_armor_300` | 受伤提升至300% | 300 |
| `cp_speed_50` | 速度降低至50% | 50 |
| `cp_speed_200` | 速度提升至200% | 200 |

## 🚶 E1（步兵）特色Buff

| Condition名称 | 效果 | Modifier值 |
|---------------|------|------------|
| `cp_inf_slow` | 步兵减速 | 20 |
| `cp_inf_berserk` | 步兵狂暴（伤害300%，受伤300%，速度200%） | 300/300/200 |
| `cp_inf_rapidfire` | 步兵连射（射速提升，伤害80%） | 30/80 |
| `cp_inf_accuracy` | 步兵精准（射程150%，伤害120%） | 150/120 |
| **`cp_inf_overheat`** | **武器过热（射速降低，伤害50%）** | **200/50** |
| `cp_inf_fragile` | 步兵脆弱（受伤200%） | 200 |

## 🚀 E3（火箭兵）特色Buff

| Condition名称 | 效果 | Modifier值 |
|---------------|------|------------|
| `cp_rkt_slow` | 火箭兵减速 | 20 |
| `cp_rkt_rapidfire` | 火箭连射（射速提升，伤害60%） | 20/60 |
| `cp_rkt_overcharge` | 火箭过充（射速降低，伤害500%） | 300/500 |
| `cp_rkt_anti_armor` | 反装甲（伤害400%，射程120%） | 400/120 |
| `cp_rkt_splash` | 溅射伤害（伤害180%，射程80%） | 180/80 |
| `cp_rkt_accuracy` | 火箭精准（射程150%，伤害120%） | 150/120 |
| **`cp_rkt_malfunction`** | **设备故障（射速降低，伤害30%，射程50%）** | **300/30/50** |
| `cp_rkt_fragile` | 火箭兵脆弱（受伤200%） | 200 |

## 🚗 V2RL（V2火箭）特色Buff

| Condition名称 | 效果 | Modifier值 |
|---------------|------|------------|
| `cp_v2_rapidfire` | V2连射（射速提升，伤害50%） | 30/50 |
| `cp_v2_range_decay` | 射程衰减（射程70%，伤害150%） | 70/150 |
| `cp_v2_overdrive` | V2过载（速度200%，伤害180%） | 200/180 |
| `cp_v2_splash` | 溅射伤害（伤害200%，射程90%） | 200/90 |
| **`cp_v2_guidance_failure`** | **制导故障（伤害25%，射程40%，射速降低）** | **25/40/200** |
| **`cp_v2_cant_move`** | **无法移动（速度10%）** | **10** |
| `cp_v2_fragile` | V2脆弱（受伤200%） | 200 |

## 🚗 FTRK（防空车）特色Buff

| Condition名称 | 效果 | Modifier值 |
|---------------|------|------------|
| `cp_aa_rapidfire` | 防空连射（射速提升，伤害70%） | 25/70 |
| `cp_aa_overdrive` | 防空过载（速度150%，伤害180%） | 150/180 |
| `cp_aa_anti_air` | 反空强化（伤害300%，射程130%） | 300/130 |
| `cp_aa_anti_ground` | 反地强化（伤害250%，射程110%） | 250/110 |
| **`cp_aa_jammed`** | **雷达干扰（射速降低，伤害20%，射程30%）** | **400/20/30** |
| `cp_aa_fragile` | 防空脆弱（受伤200%） | 200 |

## 🚗 3TNK（重坦）特色Buff

| Condition名称 | 效果 | Modifier值 |
|---------------|------|------------|
| `cp_tank_armor_up` | 坦克装甲强化（受伤50%） | 50 |
| `cp_tank_slow` | 坦克减速 | 30 |
| `cp_tank_overdrive` | 坦克过载（速度160%，伤害120%） | 160/120 |
| `cp_tank_ap_rounds` | 穿甲弹（伤害250%，射程120%） | 250/120 |
| **`cp_tank_engine_failure`** | **引擎故障（速度20%，伤害60%）** | **20/60** |
| `cp_tank_fragile` | 坦克脆弱（受伤200%） | 200 |

## 🚗 4TNK（天启坦克）特色Buff

| Condition名称 | 效果 | Modifier值 |
|---------------|------|------------|
| `cp_mammoth_armor_up` | 天启装甲强化（受伤40%） | 40 |
| `cp_mammoth_slow` | 天启减速 | 25 |
| `cp_mammoth_dual_cannon` | 双炮模式（伤害180%，射速80%） | 180/80 |
| `cp_mammoth_apex` | 天启顶点（伤害300%，速度80%，射程110%） | 300/80/110 |
| **`cp_mammoth_system_overload`** | **系统过载（速度15%，伤害40%，射速降低）** | **15/40/250** |
| `cp_mammoth_fragile` | 天启脆弱（受伤600%） | 600 |

## ✈️ MIG（米格战机）特色Buff

| Condition名称 | 效果 | Modifier值 |
|---------------|------|------------|
| `cp_mig_speed_up` | 米格加速 | 130 |
| `cp_mig_anti_armor` | 反装甲（伤害250%，射程120%） | 250/120 |
| `cp_mig_overdrive` | 米格过载（速度150%，伤害140%） | 150/140 |
| `cp_mig_maverick` | 小牛导弹（伤害300%，射速60%） | 300/60 |
| **`cp_mig_stall`** | **失速（速度30%，伤害40%，射程50%）** | **30/40/50** |
| `cp_mig_fragile` | 米格脆弱（受伤200%） | 200 |

## ✈️ YAK（雅克战机）特色Buff

| Condition名称 | 效果 | Modifier值 |
|---------------|------|------------|
| `cp_yak_rapidfire` | 雅克连射（射速提升，伤害80%） | 20/80 |
| `cp_yak_anti_infantry` | 反步兵（伤害200%，速度120%） | 200/120 |
| `cp_yak_overdrive` | 雅克过载（速度140%，伤害130%） | 140/130 |
| `cp_yak_chaingun` | 链炮模式（伤害180%，射速30%） | 180/30 |
| **`cp_yak_jammed`** | **卡弹（射速降低，伤害10%，速度60%）** | **500/10/60** |
| `cp_yak_fragile` | 雅克脆弱（受伤200%） | 200 |

## 🎮 使用方式

### Lua脚本中的使用方法

```lua
-- 激活buff
local token = unit.GrantCondition("condition_name")

-- 移除buff
unit.RevokeCondition(token)

-- 示例：为E1步兵激活反坦克模式
local antiTankToken = unit.GrantCondition("cp_inf_anti_tank")

-- 示例：为V2火箭激活过载模式
local overdriveToken = unit.GrantCondition("cp_v2_overdrive")
```

### 在copilot-fin.lua中的集成示例

```lua
-- 检测E1靠近工厂时给予减速buff
local function checkE1NearFacts()
    local nearbyE1s = {}
    for _, factPos in ipairs(FactPositions) do
        local radius = WDist.FromCells(FACT_DETECTION_RADIUS)
        local nearbyUnits = Map.ActorsInCircle(factPos, radius)
        for _, unit in ipairs(nearbyUnits) do
            if unit and not unit.IsDead and unit.Type == "e1" then
                nearbyE1s[unit] = true
                if not E1Tokens[unit] then
                    local token = unit.GrantCondition("cp_inf_slow")
                    E1Tokens[unit] = token
                    debugMsg(string.format("E1 near fact at (%d,%d) - added cp_inf_slow", factPos.X, factPos.Y))
                end
            end
        end
    end
    
    -- 清理离开范围的单位
    for unit, token in pairs(E1Tokens) do
        if not unit or unit.IsDead then
            E1Tokens[unit] = nil
            debugMsg("E1 died - removed cp_inf_slow token")
        elseif not nearbyE1s[unit] then
            unit.RevokeCondition(token)
            E1Tokens[unit] = nil
            debugMsg("E1 left fact area - removed cp_inf_slow")
        end
    end
end
```

## 📁 文件结构

```
mods/copilot/rules/
├── defaults.yaml          # 通用buff定义（^CopilotBase）
├── infantry.yaml          # 步兵单位buff（E1, E3）
├── vehicles.yaml          # 车辆单位buff（V2RL, FTRK, 3TNK, 4TNK）
└── aircraft.yaml          # 飞机单位buff（MIG, YAK）
```

## 🔧 技术实现

### ExternalCondition定义
```yaml
ExternalCondition@CP_INF_SLOW:
    Condition: cp_inf_slow
```

### Multiplier定义
```yaml
SpeedMultiplier@CP_INF_SLOW:
    RequiresCondition: cp_inf_slow
    Modifier: 20
```

### 继承关系
```yaml
E1:
    Inherits@COPILOT: ^CopilotBase  # 继承通用buff
    # 然后定义特色buff
```

## ⚖️ 平衡设计

### 正面Buff
- **伤害提升**: 50%-500%不等，根据兵种特色调整
- **速度提升**: 最高200%，保持游戏节奏
- **射程提升**: 最高150%，避免过度远程

### 负面Buff
- **脆弱模式**: 所有兵种受伤200%，天启坦克600%（更脆弱）
- **特色负面**: 每个兵种都有独特的负面效果
- **移动限制**: V2火箭有无法移动模式（速度10%）

### 风险与收益
- 高伤害buff通常伴随高风险
- 过载模式提供强大效果但可能带来负面后果
- 每个buff都有明确的代价和收益

## 🎯 策略建议

1. **组合使用**: 可以同时激活多个buff，但要注意负面效果
2. **时机选择**: 根据战场情况选择合适的buff
3. **风险控制**: 避免在高风险情况下使用负面buff
4. **兵种配合**: 不同兵种的buff可以相互配合

## 📈 系统扩展

该系统设计为可扩展的，可以轻松添加：
- 新的兵种buff
- 新的通用buff类型
- 更复杂的buff组合效果
- 条件触发的buff系统

---

*本文档基于OpenRA Copilot Mod的Buff系统，版本：最新*
