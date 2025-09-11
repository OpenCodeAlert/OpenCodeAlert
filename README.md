相聚杭州，一起探究LLM和RTS游戏融合的边界，我们会采用对战的逻辑让大家在比赛中操控着自己的智能体和自己一同作战，完成最后的Mission!
Mission Fin 可公开情报如下：

1. 有别于传统RTS对战，Mission Fin采用计时占点的方式对战，单局对局时长5min（300s），通过控制据点获得分数，分数高者获胜
2. 据点随机刷出，每个据点最多存在2min
3. 据点附近存在针对随机兵种的随机buff，影响点内作战局势
4. 提供全新的 据点/Buff 分数 剩余时长 查询接口
5. 仅1张地图，双方初始直接提供基础建筑和作战单位
6. 双败淘汰赛，决赛bo5，其余bo3
7. 【平衡性调整】V2火箭伤害降低至70%，E1步兵伤害提升至150%
8. Depoy矿车和MoveDirection导致的OOS均已修复
9. query_actor会提供两部分，"actors"和"frozenActors"，其中frozenActors字段结构和actor相同，但仅type，faction，position为有效值
10. 据点会从第10s刷出第一个，之后每隔（随机30~90s）刷出一个新的，每个据点存在2min
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
          "buffName": "cp_atk_up_50"
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

## 通用Buff（所有单位可用）

| Condition名称 | 效果 | Modifier值 |
|---------------|------|------------|
| cp_atk_up_50  | 攻击力提升50% | 150 |
| cp_atk_up_150 | 攻击力提升150% | 250 |
| cp_atk_up_250 | 攻击力提升250% | 350 |
| cp_def_down_15 | 防御降低至85% | 200 |
| cp_def_down_30 | 防御降低至70% | 200 |
| cp_def_down_50 | 防御降低至50% | 200 |
| cp_armor_25   | 装甲降低至25% | 75 |
| cp_armor_50   | 装甲降低至50% | 150 |
| cp_armor_75   | 装甲降低至75% | 300 |
| cp_move_150   | 移动速度提升50% | 150 |
| cp_move_200   | 移动速度提升100% | 200 |
| cp_speed_aqua | 移动速度提升200% | 200 |

---

## E1（步兵）特色Buff

| Condition名称 | 效果 | Modifier值 |
|---------------|------|------------|
| cp_inf_slow   | 移动减速 | 20 |
| cp_inf_berserk | 狂暴状态（攻击速度提升300/400/200%，防御力降低至50%） | 300/400/200 |
| cp_inf_rapidfire | 火力压制（射速提升140%，防御力降低至50%） | 150/20 |
| cp_inf_accuracy | 瞄准强化（射程150%，命中率150%） | 150/20 |
| up_inf_power | 攻击力提升200% | 200 |
| cp_inf_fragile | 防御降低至50% | 200 |

---

## RK（火箭兵）特色Buff

| Condition名称 | 效果 | Modifier值 |
|---------------|------|------------|
| cp_rkt_slowfire | 火箭连发减速 | 20/50 |
| cp_rkt_rapidfire | 火箭连发（射速提升） | 20/50 |
| cp_rkt_anti_large | 高爆武器（对建筑伤害200%） | 300/500 |
| cp_rkt_anti_tank | 高爆武器（对坦克伤害200%） | 400/120 |
| cp_rkt_splash   | 溅射伤害（范围180%） | 180/50 |
| cp_rkt_accuracy | 瞄准强化（射程150%，命中率150%） | 150/20 |
| cp_rkt_multifunction | 多用途武器（对步兵200%，对建筑200%） | 300/30/50 |
| cp_rkt_fragile  | 防御降低至50% | 200 |

---

## V2RL（V2火箭）特色Buff

| Condition名称 | 效果 | Modifier值 |
|---------------|------|------------|
| cp_v2_rapidfire | V2连发（射速提升） | 30/90 |
| cp_v2_range_up  | 射程增加（射程150%） | 70/150 |
| cp_v2_overdrive | V2过载（速度140%，伤害180%） | 140/180 |
| cp_v2_splash    | 溅射伤害（伤害200%，射程90%） | 200/200 |
| cp_v2_guidance_failure | 制导失效（精度降低20%，伤害提升200%） | 25/40/200 |
| cp_v2_fragile   | 防御降低至50% | 200 |
| cp_v2_cant_move | 移动速度降低到10%| 10 |

---

## FTRK（防空车）特色Buff

| Condition名称 | 效果 | Modifier值 |
|---------------|------|------------|
| cp_aa_rapidfire | 射速提升（防空火力增强） | 25/70 |
| cp_aa_range     | 射程增加（射程200%） | 100/150 |
| cp_aa_overdrive | 射速降低50%，攻击力提升200% | 140/180 |
| cp_aa_multifunction | 多用途武器（对步兵250%，对建筑110%） | 240/110 |
| cp_aa_accuracy  | 瞄准强化（射程150%，命中率150%） | 150/20 |
| cp_aa_fragile   | 防御降低至50% | 200 |

---

## 3TNK（三坦）特色Buff

| Condition名称 | 效果 | Modifier值 |
|---------------|------|------------|
| cp_tank_armor_up | 护甲强化（装甲提升50%） | 50 |
| cp_tank_slow     | 移动减速 | 20 |
| cp_tank_overdrive | 过载（射速降低50%，攻击力提升200%） | 180/120 |
| cp_tank_accuracy  | 瞄准强化（射程150%，命中率150%） | 250/120 |
| cp_tank_engine_failure | 引擎损坏（速度降低50%） | 30/20 |
| cp_tank_fragile   | 防御降低至50% | 200 |

---

## 4TNK（天启坦克）特色Buff

| Condition名称 | 效果 | Modifier值 |
|---------------|------|------------|
| cp_mammoth_atm_up | 火箭发射管（空地导弹+40%） | 40 |
| cp_mammoth_slow   | 巨型坦克移动减速 | 25 |
| cp_mammoth_armor  | 装甲提升 | 180/180 |
| cp_mammoth_dual_cannon | 双炮齐射（攻击力提升200%） | 250/80 |
| cp_mammoth_system_overload | 系统过载（射速降低50%，攻击力提升200%） | 150/40/50 |

---

## MIG（米格战机）特色Buff

| Condition名称 | 效果 | Modifier值 |
|---------------|------|------------|
| cp_mig_speed_up | 速度强化 | 130 |
| cp_mig_anti_armor | 高爆武器（对建筑200%，对坦克200%） | 250/120 |
| cp_mig_overdrive | 过载（射速降低50%，攻击力提升200%） | 150/140 |
| cp_mig_swerve    | 高机动性（射速提升300%，防御降低至50%） | 300/50 |
| cp_mig_stealth   | 隐形（不可见，持续40秒） | 30/40/50 |
| cp_mig_fragile   | 防御降低至50% | 200 |

---

## YAK（雅克战机）特色Buff

| Condition名称 | 效果 | Modifier值 |
|---------------|------|------------|
| cp_yak_rapidfire | 火力压制（射速提升） | 20/90 |
| cp_yak_anti_infantry | 对步兵伤害200% | 200 |
| cp_yak_overdrive | 过载（射速降低50%，攻击力提升200%） | 140/130 |
| cp_yak_chakram   | 空中机动（射速180%，防御降低至50%） | 180/30 |
| cp_yak_swerve    | 高机动性（射速500%，防御降低至50%） | 500/100/50 |
| cp_yak_fragile   | 防御降低至50% | 200 |

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
