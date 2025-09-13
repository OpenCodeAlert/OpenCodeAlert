相聚杭州，一起探究LLM和RTS游戏融合的边界，我们会采用对战的逻辑让大家在比赛中操控着自己的智能体和自己一同作战，完成最后的Mission!
Mission Fin 可公开情报如下：

1. 有别于传统RTS对战，Mission Fin采用计时占点的方式对战，单局对局时长7min（420s），通过控制据点获得分数，分数高者获胜
2. 据点随机刷出，每个据点最多存在2min
3. 据点附近存在针对随机兵种的随机buff，影响点内作战局势
4. 提供全新的 据点/Buff 分数 剩余时长 查询接口
5. 仅1张地图，双方初始直接提供基础建筑和作战单位
6. 双败淘汰赛，决赛bo5，其余bo3
7. 【平衡性调整】V2火箭伤害降低至70%，E1步兵伤害提升至150%
8. Depoy矿车和MoveDirection导致的OOS均已修复
9. query_actor会提供两部分，"actors"和"frozenActors"，其中frozenActors字段结构和actor相同，但仅type，faction，position为有效值
10. 据点会从第10s刷出第一个，之后每隔（随机30~60s）刷出一个新的，每个据点存在2min
11. 当据点内一方单位大于等于5个，并且该方单位数量大于等于敌方5倍时，该方每秒得1分，如果比例小于5倍，双方都不得分
12. 时长结束时分数高者获胜，如果一方建筑完全被摧毁，另一方获胜


# api修改

## **查询性指令**

查询指令的响应内容，指的响应包中的"data": {  }部分

### **query_actor - 查询单位信息**

**Command**：query_actor

**Sample Params**：

```
{
  "targets": {
    "range": "all",
    "faction": "己方",
    "type": ["步兵", "坦克"],
    "groupId": [1, 2]
  }
}
```

**描述**： 查询指定条件的单位信息，包括普通单位和冻结单位（残像）。

**参数**：

​                ● targets（object，可选）：目标筛选条件

​                ○ range（string，可选）：查询范围，支持："all"（全部）、"screen"（屏幕内）、"selected"（已选中），默认为"all"

​                ○ faction（string，可选）：阵营筛选，支持："己方"、"敌方"、"中立"、"友方"，默认为"己方"

​                ○ type（array，可选）：单位类型筛选，支持中文名称如["步兵", "坦克"]

​                ○ groupId（array，可选）：编组ID筛选，如[1, 2]表示查询编组1和2中的单位

​                ○ actorId（array，可选）：直接指定Actor ID列表

​                ○ restrain（array，可选）：额外限制条件

​                ○ relativeDirection（string，可选）：相对方向排序

​                ○ maxNum（int，可选）：最大返回数量

​                ○ distance（int，可选）：距离限制

​                ○ location（object，可选）：参考位置

**响应示例**：

```
{
  "actors": [
    {
      "id": 101,
      "isFrozen": false,
      "type": "步兵",
      "faction": "己方",
      "hp": 100,
      "maxHp": 100,
      "isDead": false,
      "position": {
        "x": 50,
        "y": 60
      }
    }
  ],
  "frozenActors": [
    {
      "id": -1,
      "isFrozen": true,
      "type": "坦克",
      "faction": "敌方",
      "hp": -1,
      "maxHp": -1,
      "isDead": false,
      "position": {
        "x": 45,
        "y": 55
      }
    }
  ]
}
```

**响应字段说明**：

​                ● actors（array）：普通单位列表

​                ○ id（int）：单位ID

​                ○ isFrozen（bool）：是否为冻结单位，普通单位为false

​                ○ type（string）：单位类型中文名称

​                ○ faction（string）：阵营关系

​                ○ hp（int）：当前生命值，-1表示无生命值

​                ○ maxHp（int）：最大生命值，-1表示无生命值

​                ○ isDead（bool）：是否死亡

​                ○ position（object）：位置坐标

​                ○ x（int）：X坐标

​                ○ y（int）：Y坐标

​                ● frozenActors（array）：冻结单位（残像）列表，字段结构与actors相同

### **match_info_query - 查询比赛信息**

**Command**：match_info_query

**Sample Params**：

```
{}
```

**描述**： 查询当前比赛的分数和剩余时间信息。

**参数**： 无

**响应示例**：

```
{
  "selfScore": 150,
  "enemyScore": 120,
  "remainingTime": "211:15"
}
```

**响应字段说明**：

​                ● selfScore（int）：己方当前分数

​                ● enemyScore（int）：敌方当前分数

​                ● remainingTime（string）：剩余时间，格式为"Second:Ticks"，一秒是25帧

### **query_control_points - 查询据点信息**

**Command**：query_control_points

**Sample Params**：

```
{}
```

**描述**： 查询当前地图上所有据点的位置和Buff信息。

**参数**： 无

**响应示例**：

```
{
  "controlPoints": [
    {
      "name": "ControlPoint1",
      "x": 50,
      "y": 60,
      "hasBuffs": true,
      "buffs": [
        {
          "unitType": "e1",
          "buffType": "generic",
          "buffName": "cp_dmg_up_50"
        }
      ]
    }
  ]
}
```

**响应字段说明**：

​                ● controlPoints（array）：据点列表

​                ○ name（string）：据点名称

​                ○ x（int）：据点X坐标

​                ○ y（int）：据点Y坐标

​                ○ hasBuffs（bool）：是否有Buff效果

​                ○ buffs（array）：Buff效果列表

​                ○ unitType（string）：适用单位类型

​                ○ buffType（string）：Buff类型："generic" or "special"

​                ○ buffName（string）：Buff配置名称，详细见下方buff表





# Buff表  

注意：以下 Buff 名称与地图脚本中的配置保持一致，示例中的数值均直接取自 YAML 规则中的 Modifier。

## 通用Buff（所有单位可用）

| Condition名称 | 效果 | 说明 |
|---------------|------|------|
| cp_dmg_up_150  | 火力大幅提升 | 攻击力提升150% |
| cp_dmg_down_30 | 火力骤降 | 攻击力降低70% |
| cp_armor_30    | 坚固 | 受到伤害降低70% (伤害系数修改为30%) |
| cp_armor_300   | 极度脆弱 | 受到伤害增加200%  (伤害系数修改为300%)|

---

## E1（步兵）特色Buff

| Condition名称 | 效果 | 说明 |
|---------------|------|------|
| cp_inf_slow       | 迟缓 | 移动速度降低80% |
| cp_inf_berserk    | 狂暴 | 攻击力提升200%，移动速度提升100%，受到伤害增加200% |
| cp_inf_accuracy   | 精准 | 射程提升50%，攻击力提升20% |
| cp_inf_overheat   | 过热 | 装填时间增加100%（射速降低），攻击力降低50% |
| cp_inf_fragile    | 易伤 | 受到伤害增加300% |

---

## RK（火箭兵）特色Buff

| Condition名称 | 效果 | 说明 |
|---------------|------|------|
| cp_rkt_slow        | 迟缓 | 移动速度降低80% |
| cp_rkt_rapidfire   | 连发 | 装填时间减少80%（射速大幅提升），攻击力降低40% |
| cp_rkt_overcharge  | 过充 | 攻击力提升400%，装填时间增加200%（射速大幅降低） |
| cp_rkt_anti_armor  | 对装强化 | 攻击力提升300%，射程提升20% |
| cp_rkt_splash      | 溅射增幅 | 攻击力提升80%，射程降低20% |
| cp_rkt_accuracy    | 精准 | 射程提升50%，攻击力提升20% |
| cp_rkt_malfunction | 故障 | 攻击力降低70%，装填时间增加200%，射程降低50% |
| cp_rkt_fragile     | 易伤 | 受到伤害增加300% |

---

## V2RL（V2火箭）特色Buff

| Condition名称 | 效果 | 说明 |
|---------------|------|------|
| cp_v2_rapidfire        | 连发 | 装填时间减少70%，攻击力降低50% |
| cp_v2_range_decay      | 射程衰减 | 射程降低30%，攻击力提升50% |
| cp_v2_overdrive        | 过载 | 移动速度提升100%，攻击力提升80% |
| cp_v2_splash           | 溅射增幅 | （已移除） |
| cp_v2_guidance_failure | 制导失效 | 攻击力降低75%，射程降低60%，装填时间增加100% |
| cp_v2_cant_move        | 定身 | 移动速度降低90% |
| cp_v2_fragile          | 易伤 | 受到伤害增加300% |

---

## FTRK（防空车）特色Buff

| Condition名称 | 效果 | 说明 |
|---------------|------|------|
| cp_aa_rapidfire  | 连发 | 装填时间减少75%，攻击力提升70% |
| cp_aa_overdrive  | 过载 | 移动速度提升50%，攻击力提升80% |
| cp_aa_anti_air   | 防空强化 | （已移除） |
| cp_aa_anti_ground| 对地强化 | 攻击力提升150%，射程提升10% |
| cp_aa_jammed     | 受干扰 | 攻击力降低80%，装填时间增加300%，射程降低70% |
| cp_aa_fragile    | 易伤 | 受到伤害增加300% |

---

## 3TNK（三坦）特色Buff

| Condition名称 | 效果 | 说明 |
|---------------|------|------|
| cp_tank_armor_up       | 护甲强化 | 受到伤害降低50% |
| cp_tank_slow           | 迟缓 | 移动速度降低70% |
| cp_tank_overdrive      | 过载 | （已移除） |
| cp_tank_super_weak     | 超级衰弱 | 攻击力降低80%，受到伤害增加200% |
| cp_tank_ap_rounds      | 穿甲弹 | 攻击力提升150%，射程提升20% |
| cp_tank_engine_failure | 引擎故障 | 移动速度降低80%，攻击力降低40% |
| cp_tank_fragile        | 易伤 | 受到伤害增加300% |

---

## 4TNK（天启坦克）特色Buff

| Condition名称 | 效果 | 说明 |
|---------------|------|------|
| cp_mammoth_armor_up        | 护甲强化 | （已移除） |
| cp_mammoth_slow            | 迟缓 | （已移除） |
| cp_mammoth_dual_cannon     | 双炮齐射 | （已移除） |
| cp_mammoth_apex            | 巅峰系统 | 攻击力提升200%，移动速度降低20%，射程提升10% |
| cp_mammoth_system_overload | 系统过载 | 攻击力降低60%，移动速度降低85%，装填时间增加150% |
| cp_mammoth_fragile         | 极度易伤 | 受到伤害增加500% |
| cp_mammoth_super_weak      | 超级衰弱 | 攻击力降低80%，受到伤害增加200% |

---

## MIG（米格战机）特色Buff

| Condition名称 | 效果 | 说明 |
|---------------|------|------|
| cp_mig_speed_up   | 加速 | （已移除） |
| cp_mig_anti_armor | 对装/建筑强化 | 攻击力提升150%，射程提升20% |
| cp_mig_overdrive  | 过载 | 移动速度提升50%，攻击力提升40% |
| cp_mig_maverick   | 王牌 | 攻击力提升200%，装填时间减少40% |
| cp_mig_stall      | 失速 | 移动速度降低70%，攻击力降低60%，射程降低50% |
| cp_mig_fragile    | 易伤 | 受到伤害增加300% |

---

## YAK（雅克战机）特色Buff

| Condition名称 | 效果 | 说明 |
|---------------|------|------|
| cp_yak_rapidfire    | 连发 | 装填时间减少80%，攻击力降低20% |
| cp_yak_anti_infantry| 反步强化 | 攻击力提升100%，移动速度提升20% |
| cp_yak_overdrive    | 过载 | （已移除） |
| cp_yak_chaingun     | 链枪 | 攻击力提升80%，装填时间减少70% |
| cp_yak_jammed       | 受干扰 | 攻击力降低90%，移动速度降低40%，装填时间增加400% |
| cp_yak_fragile      | 易伤 | 受到伤害增加300% |

---



# OpenRA

A Libre/Free Real Time Strategy game engine supporting early Westwood classics.

* Website: [https://www.openra.net](https://www.openra.net)
* Chat: [#openra on Libera](ircs://irc.libera.chat:6697/openra) ([web](https://web.libera.chat/#openra)) or [Discord](https://discord.openra.net) ![Discord Badge](https://discordapp.com/api/guilds/153649279762694144/widget.png)
* Repository: [https://github.com/OpenRA/OpenRA](https://github.com/OpenRA/OpenRA) ![Continuous Integration](https://github.com/OpenRA/OpenRA/workflows/Continuous%20Integration/badge.svg)

Please read the [FAQ](https://github.com/OpenRA/OpenRA/wiki/FAQ) in our [Wiki](https://github.com/OpenRA/OpenRA/wiki) and report problems at [https://github.com/OpenRA/OpenRA/issues](https://github.com/OpenRA/OpenRA/issues).

Join the [Forum](https://forum.openra.net/) for discussion.

## Play

Distributed mods include a reimagining of

* Command & Conquer: Red Alert
* Command & Conquer: Tiberian Dawn
* Dune 2000

EA has not endorsed and does not support this product.

Check our [Playing the Game](https://github.com/OpenRA/OpenRA/wiki/Playing-the-game) Guide to win multiplayer matches.

## Contribute

* Please read [INSTALL.md](https://github.com/OpenRA/OpenRA/blob/bleed/INSTALL.md) and [Compiling](https://github.com/OpenRA/OpenRA/wiki/Compiling) on how to set up an OpenRA development environment.
* See [Hacking](https://github.com/OpenRA/OpenRA/wiki/Hacking) for a (now very outdated) overview of the engine.
* Read and follow our [Code of Conduct](https://github.com/OpenRA/OpenRA/blob/bleed/CODE_OF_CONDUCT.md).
* To get your patches merged, please adhere to the [Contributing](https://github.com/OpenRA/OpenRA/blob/bleed/CONTRIBUTING.md) guidelines.

## Mapping

* We offer a [Mapping](https://github.com/OpenRA/OpenRA/wiki/Mapping) Tutorial as you can change gameplay drastically with custom rules.
* For scripted mission have a look at the [Lua API](https://docs.openra.net/en/latest/release/lua/).
* If you want to share your maps with the community, upload them at the [OpenRA Resource Center](https://resource.openra.net).

## Modding

* Download a copy of the [OpenRA Mod SDK](https://github.com/OpenRA/OpenRAModSDK) to start your own mod.
* Check the [Modding Guide](https://github.com/OpenRA/OpenRA/wiki/Modding-Guide) to create your own classic RTS.
* There exists an auto-generated [Trait documentation](https://docs.openra.net/en/latest/release/traits/) to get started with yaml files.
* Some hints on how to create new OpenRA compatible [Pixelart](https://github.com/OpenRA/OpenRA/wiki/Pixelart).
* Upload total conversions at [our Mod DB profile](https://www.moddb.com/games/openra/mods).

## Support

* Sponsor a [mirror server](https://github.com/OpenRA/OpenRAWebsiteV3/tree/master/packages) if you have some bandwidth to spare.
* You can immediately set up a [Dedicated](https://github.com/OpenRA/OpenRA/wiki/Dedicated-Server) Game Server.

## License
Copyright (c) OpenRA Developers and Contributors
This file is part of OpenRA, which is free software. It is made
available to you under the terms of the GNU General Public License
as published by the Free Software Foundation, either version 3 of
the License, or (at your option) any later version. For more
information, see [COPYING](https://github.com/OpenRA/OpenRA/blob/bleed/COPYING).
