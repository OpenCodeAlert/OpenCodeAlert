# 这个是一个示例文件，展示了如何使用OpenRA_Copilot_Library库，尽可能详细的包含了库中的所有功能，可以作为参考

# 该代码对应了一个基础的开局行为：展开基地车，建造电厂，兵营，各种基本单位，然后步兵探索地图，飞机探索地图，同时发展了我的科技，建造了各种部队，最后进攻敌方基地

import sys
import os
import time
import json
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))


import OpenRA_Copilot_Library as OpenRA
from OpenRA_Copilot_Library import *

api = OpenRA.GameAPI("localhost")

# 展开基地车

# api.deploy_mcv_and_wait(wait_time=1.0)
# print("基地车已展开完毕")

# # 建造电厂和兵营
# api.ensure_can_build_wait("电厂")
# build = api.produce_wait("电厂", 1, True)
# api.ensure_can_build_wait("矿场")
# build = api.produce_wait("矿场", 1, True)
# # 因为电厂本来就是兵营前置了，所以先电厂后兵营
# api.ensure_can_build_wait("兵营")
# build = api.produce_wait("兵营", 1, True)


# if api.ensure_can_produce_unit("步兵"):
#     print("开始生产3个步兵...")
#     wtank = api.produce("步兵", 5)
#     api.wait(wtank)
# else:
#     raise RuntimeError("无法生产防空车")

# # # # 蓝噪声算法，用于探索地图
# def _shadow_points(mapinfo: MapQueryResult, step, exponly=True):
#     W, H = mapinfo.MapWidth -2 , mapinfo.MapHeight -2
#     StartX, StartY = 2, 2
#     vis = mapinfo.IsVisible
#     exp = mapinfo.IsExplored
#     if exponly:  # 备选：完全未探明的
#         pts = [Location(x, y) for y in range(StartY, H, step)
#                for x in range(StartX, H, step) if not exp[x][y]]
#     else:
#         pts = [Location(x, y) for y in range(StartY, W, step)
#                for x in range(StartX, H, step) if not vis[x][y]]
#     return pts


# def explore(api: GameAPI, unit: list[Actor], mapinfo: MapQueryResult, r=18, per_unit=4, spacing=4, step=2):
#     if not unit:
#         return
#     all_shadow = _shadow_points(mapinfo, step)
#     if not all_shadow:
#         return

#     taken = []                   # 全局蓝噪声约束
#     batch = []

#     for u in unit:
#         api.update_actor(u)
#         upos = u.position
#         local = [p for p in all_shadow if p.manhattan_distance(upos) <= r]
#         if not local:
#             local = [
#                 p for p in all_shadow if p.manhattan_distance(upos) <= 2*r]
#         if not local:
#             continue
#         # 远且分散优先
#         random.shuffle(local)
#         local.sort(key=lambda p: min([p.manhattan_distance(q)
#                    for q in taken] or [1e9]), reverse=True)

#         picks = []
#         for i in range(per_unit):
#             last = None
#             if last:
#                 local.sort(key=lambda p: 2 * min([p.manhattan_distance(q)
#                                                   for q in taken] or [1e9]) - p.manhattan_distance(last), reverse=True)
#             picked = False
#             for p in local:
#                 if len(picks) >= per_unit:
#                     picked = True
#                     break
#                 if all(p.manhattan_distance(q) >= spacing for q in picks) and all(p.manhattan_distance(q) >= spacing for q in taken):
#                     picks.append(p)
#                     taken.append(p)
#                     picked = True
#                     last = p
#             if not picked:
#                 r += 5
#                 local = [
#                     p for p in all_shadow if p.manhattan_distance(upos) <= r]
#                 i -= 1

#         api.move_units_by_path([u], picks, attack_move=True)

# infantry_list = api.query_actor(
#     TargetsQueryParam(type=["步兵"], faction="自己"))
# api.form_group(infantry_list, group_id=1)
# mapinfo = api.map_query()

# explore(api, infantry_list, mapinfo)

# api.ensure_can_build_wait("机场")
# api.produce("核电厂", 1, auto_place_building=True)
# api.produce("矿场", 1, auto_place_building=True)
# api.produce("防空车", 5)
# api.produce("修理中心", 1, auto_place_building=True)
# api.produce_wait("机场", 1)
# api.produce("车间", 1, auto_place_building=True)
# api.produce("步兵", 10)
# time.sleep(1)
# api.produce_wait("Yak", 3)
# api.produce("矿车", 2)
# api.produce("核电厂", 1,auto_place_building=True)
# api.produce("修理厂", 1,auto_place_building=True)
# api.produce("科技中心", 1,auto_place_building=True)


# # 再探索一下
# infantry_list = api.query_actor(
#     TargetsQueryParam(type=["步兵"], faction="自己"))
# mapinfo = api.map_query()
# explore(api, infantry_list, mapinfo, r=28)


# # 飞机探索就大一点
# inti_r = 48
# enemy_base = None
# for i in range(5):
#     aircraft_list = api.query_actor(TargetsQueryParam(type=["Yak"], faction="自己"))
#     mapinfo = api.map_query()
#     explore(api, aircraft_list, mapinfo, r=inti_r,
#             per_unit=4, spacing=10, step=8)
#     for x in range(40):
#         enemy = api.query_actor(TargetsQueryParam(type=[""], faction="敌方"))
#         for unit in enemy:
#             if unit.type == "基地" or unit.type == "建造厂":
#                 enemy_base = unit
#                 break
#         if enemy_base:
#             break
#         time.sleep(0.5)
#     inti_r += 20

# # 建造"矿场"、"车间"以便生产载具
# api.produce("步兵", 5)
# api.produce("火箭兵", 5)
# api.produce("重坦", 3)
# api.produce("V2", 3)
# api.produce("天启坦克", 3)

if enemy_base:
    battle_unit = api.query_actor(
        TargetsQueryParam(type=["战斗单位"], faction="自己"))
    api.move_units_by_location(
        battle_unit, enemy_base.position, attack_move=True)

# time.sleep(30)

enemy = api.query_actor(TargetsQueryParam(type=[""], faction="敌方"))
for unit in enemy:
    if unit.type == "基地" or unit.type == "建造厂":
        enemy_base = unit
        break

for i in range(2000):
    if enemy_base:
        battle_unit = api.query_actor(
            TargetsQueryParam(type=["战斗单位"], faction="自己"))
        print(battle_unit)
        api.move_units_by_location(
            battle_unit, enemy_base.position, attack_move=True)
        for unit in battle_unit:
            api.update_actor(unit)
            print(unit.position.manhattan_distance(enemy_base.position))
            if unit.position.manhattan_distance(enemy_base.position) <= 5:
                api.attack_target(unit, enemy_base)
        if not battle_unit:
            break
    else:
        enemy = api.query_actor(TargetsQueryParam(type=[""], faction="敌方"))
        for unit in enemy:
            if unit.type == "基地" or unit.type == "建造厂":
                enemy_base = unit
                break
    time.sleep(0.1  )