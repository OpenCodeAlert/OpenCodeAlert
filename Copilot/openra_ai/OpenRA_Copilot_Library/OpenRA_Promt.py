from typing import List, Dict, Optional
from dataclasses import dataclass

@dataclass
class Location:
    # 表示游戏中的二维位置坐标，左上角是原点，x 轴向右，y 轴向下
    x: int  # x 是地图中的水平偏移量。
    y: int  # y 是地图中的垂直偏移量。

    def __add__(self, other):
        # 两个位置相加，返回新位置。
        pass

    def __floordiv__(self, other):
        # 将位置的坐标按整数除法缩小，返回新位置。
        pass

    def to_dict(self):
        # 将位置转换为字典表示。
        pass

    def manhattan_distance(self, other):
        # 计算曼哈顿距离。
        pass

    def euclidean_distance(self, other):
        # 计算欧几里得距离。
        pass

# 查询目标的查询参数，用于查询符合条件的目标。
# 基本上是用这个结构体来表明一个或一些Actor
@dataclass
class TargetsQueryParam:
    type: Optional[str] = None  # 目标类型，值为 {ALL_UNITS} 列表或 None。
    faction: Optional[str] = None  # 阵营，值为 {ALL_ACTORS} 中的一个或 None。
    group_id: Optional[List[int]] = None  # {ALL_GROUPS} 列表或 None。
    restrain: Optional[dict] = None  # 约束条件。
    ''' 约束条件是一个字典，可以为空，也包含以下键值对：
    {"distance": int}   # 距离（只选中距离小于等于distance的单位）
    {"visible": bool}  # 是否可见
    {"maxnum": int}  # 最大数量（如果direction有值，会选择最靠近direction的maxnum个单位，否则随机选择maxnum个单位）
    '''
    location: Optional[Location] = None  # 位置，仅用于配合distance约束使用，会判断这个点和目标的距离。
    direction: Optional[str] = None  # {ALL_DIRECTIONS} 中的一个或 None，仅用于配合maxnum使用，会选择所有满足条件的单位，最靠近direction的maxnum个单位。
    range: Optional[str] = None  # 从哪些Actor中筛选，取值为 {"screen", "selected", "all"} 中的一个，默认为all，selected表示只在选中的单位中筛选。

    def to_dict(self):
        # 将查询参数转换为字典表示。
        pass

@dataclass
class Actor:
    actor_id: int  # Actor ID。
    type: Optional[str] = None  # Actor类型，值为 {ALL_UNITS} 中的一个。
    faction: Optional[str] = None  # 阵营，值为 {ALL_ACTORS} 中的一个。
    position: Optional[Location] = None  # Actor的位置。
    hppercent: Optional[int] = None  # Actor的生命值百分比。

# 地图信息查询返回结构体，IsVisible 是当前视野可见的部分为 True，IsExplored 是探索过的格子为 True。
@dataclass
class MapQueryResult:
    MapWidth: int  # 地图宽度。
    MapHeight: int  # 地图高度。
    Height: List[List[int]]  # 每个格子的高度。
    IsVisible: List[List[bool]]  # 每个格子是否可见。
    IsExplored: List[List[bool]]  # 每个格子是否已探索。
    Terrain: List[List[str]]  # 每个格子的地形类型。
    ResourcesType: List[List[str]]  # 每个格子的资源类型。
    Resources: List[List[int]]  # 每个格子的资源数量。

    def get_value_at_location(self, grid_name: str, location: 'Location'):
        # 根据位置获取指定网格中的值。
        pass

# 玩家基础信息查询返回结构体，Cash 和 Resources 的和是玩家持有的金钱，Power 是剩余电力。
@dataclass
class PlayerBaseInfo:
    Cash: int  # 玩家持有的现金。
    Resources: int  # 玩家持有的资源。
    Power: int  # 玩家当前剩余电力。
    PowerDrained: int  # 玩家消耗的电力。
    PowerProvided: int  # 玩家提供的电力。

# 屏幕信息查询返回结果，Min 是屏幕左上角，Max 是右下角，MousePosition 是当前鼠标所在位置，Location 都是整数坐标。
@dataclass
class ScreenInfoResult:
    ScreenMin: Location  # 屏幕左上角的位置。
    ScreenMax: Location  # 屏幕右下角的位置。
    IsMouseOnScreen: bool  # 鼠标是否在屏幕上。
    MousePosition: Location  # 鼠标当前位置。

    def to_dict(self) -> Dict:
        # 将屏幕信息转换为字典表示。
        pass
import socket
import json
import time
from typing import List, Optional
from .models import *

class GameAPI:
    '''游戏API接口类，用于与游戏服务器进行通信
    提供了一系列方法来与游戏服务器进行交互，包括Actor移动、生产、查询等功能。
    所有的通信都是通过socket连接完成的。'''
    def __init__(self, host: str, port: int = 7445):
        '''初始化 GameAPI 类

        Args:
            host (str): 游戏服务器地址，本地就填"localhost"。
            port (int): 游戏服务器端口，默认为 7445。
        '''
        pass

    def _send_request(self, command: str, data: dict) -> Optional[dict]:
        '''通过socket和Game交互，发送信息并接收响应

        Args:
            command (str): 要执行的命令
            data (dict): 命令相关的数据参数

        Returns:
            dict: 服务器返回的JSON响应数据
            None: 如果响应解析失败
        '''
        pass

    def move_camera_by_location(self, location: Location) -> None:
        '''根据给定的位置移动相机

        Args:
            location (Location): 要移动到的位置
        '''
        pass

    def move_camera_by_direction(self, direction: str, distance: int) -> None:
        '''向某个方向移动相机

        Args:
            direction (str): 移动的方向，必须在 {ALL_DIRECTIONS} 中
            distance (int): 移动的距离
        '''
        pass

    def able_to_produce(self, unit_type: str) -> bool:
        '''检查是否可以生产指定类型的Actor

        Args:
            unit_type (str): Actor类型，必须在 {ALL_UNITS} 中

        Returns:
            bool: 是否可以生产
        '''
        pass

    def produce_units(self, unit_type: str, quantity: int) -> Optional[int]:
        '''生产指定数量的Actor

        Args:
            unit_type (str): Actor类型
            quantity (int): 生产数量

        Returns:
            int: 生产任务的 waitId
            None: 如果任务创建失败
        '''
        pass

    def is_ready(self, waitId: int) -> bool:
        '''检查生产任务是否完成

        Args:
            waitId (int): 生产任务的 ID

        Returns:
            bool: 是否完成
        '''
        pass

    def wait(self, waitId: int, maxWaitTime: float = 20.0) -> bool:
        '''等待生产任务完成

        Args:
            waitId (int): 生产任务的 ID
            maxWaitTime (float): 最大等待时间，默认为 20 秒

        Returns:
            bool: 是否成功完成等待（false表示超时）
        '''
        pass

    def move_units_by_location(self, actors: List[Actor], location: Location, attackmove: bool = False) -> None:
        '''移动Actor到指定位置

        Args:
            actors (List[Actor]): 要移动的Actor列表
            location (Location): 目标位置
            attackmove (bool): 是否为攻击移动
        '''
        pass

    def move_units_by_direction(self, actors: List[Actor], direction: str, distance: int) -> None:
        '''向指定方向移动Actor

        Args:
            actors (List[Actor]): 要移动的Actor列表
            direction (str): 移动方向
            distance (int): 移动距离
        '''
        pass

    def move_units_by_path(self, actors: List[Actor], path: List[Location]) -> None:
        '''沿路径移动Actor

        Args:
            actors (List[Actor]): 要移动的Actor列表
            path (List[Location]): 移动路径
        '''
        pass

    def select_units(self, query_params: TargetsQueryParam) -> List[Actor]:
        '''选中符合条件的Actor

        Args:
            query_params (TargetsQueryParam): 查询参数

        Returns:
            List[Actor]: 选择的Actor列表
        '''
        pass

    def form_group(self, actors: List[Actor], group_id: int) -> None:
        '''将Actor编成编组

        Args:
            actors (List[Actor]): 要分组的Actor列表
            group_id (int): 群组 ID
        '''
        pass

    def query_actor(self, query_params: TargetsQueryParam) -> List[Actor]:
        '''查询符合条件的Actor

        Args:
            query_params (TargetsQueryParam): 查询参数

        Returns:
            List[Actor]: 符合条件的Actor列表
        '''
        pass

    def find_path(self, actors: List[Actor], destination: Location, method: str) -> List[Location]:
        '''为Actor找到到目标的路径

        Args:
            actors (List[Actor]): 要移动的Actor列表
            destination (Location): 目标位置
            method (str): 寻路方法，必须在 {"最短路"，"左路"，"右路"} 中

        Returns:
            List[Location]: 路径点列表，第0个是目标点，最后一个是Actor当前位置，相邻的点都是八方向相连的点
        '''
        pass

    def get_actor(self, actor_id: int) -> Optional[Actor]:
        '''获取指定 ID 的Actor，这是根据ActorID获取Actor的接口，只有已知ActorID是才能调用这个接口

        Args:
            actor_id (int): Actor ID

        Returns:
            Actor: 对应的Actor
            None: 如果Actor不存在
        '''
        pass

    def update_actor(self, actor: Actor) -> bool:
        '''更新Actor信息，如果时间改变了，需要调用这个来更新Actor的各种属性（位置等）。

        Args:
            actor (Actor): 要更新的Actor

        Returns:
            bool: 如果Actor已死，会返回false，否则返回true
        '''
        pass

    def deploy_units(self, actors: List[Actor]) -> dict:
        '''部署/展开 Actor

        Args:
            actors (List[Actor]): 要部署/展开 的Actor列表

        Returns:
            dict: 操作结果
        '''
        pass

    def move_camera_to(self, actor: Actor) -> None:
        '''将相机移动到指定Actor

        Args:
            actor (Actor): Actor对象
        '''
        pass

    def occupy_units(self, occupiers: List[Actor], targets: List[Actor]) -> None:
        '''指定Actor占领目标

        Args:
            occupiers (List[Actor]): 执行占领的Actor
            targets (List[Actor]): 被占领的目标
        '''
        pass

    def attack_target(self, attacker: Actor, target: Actor) -> bool:
        '''攻击指定目标

        Args:
            attacker (Actor): 发起攻击的Actor
            target (Actor): 被攻击的目标

        Returns:
            bool: 是否成功发起攻击(如果目标不可见，或者不可达，或者攻击者已经死亡，都会返回false)
        '''
        pass

    def repair_units(self, actors: List[Actor]) -> Optional[int]:
        '''修复Actor

        Args:
            actors (List[Actor]): 要修复的Actor列表，可以是载具或者建筑，修理载具需要修建修理中心

        Returns:
            int: 修复任务的 ID
            None: 如果任务创建失败
        '''
        pass

    def stop(self, actors: List[Actor]) -> None:
        '''停止Actor

        Args:
            actors (List[Actor]): 要停止的Actor列表
        '''
        pass

    def visible_query(self, location: Location) -> bool:
        '''查询指定位置是否可见

        Args:
            location (Location): 要查询的位置

        Returns:
            bool: 是否可见
        '''
        pass

    def explorer_query(self, location: Location) -> bool:
        '''查询指定位置是否已探索

        Args:
            location (Location): 要查询的位置

        Returns:
            bool: 是否已探索
        '''
        pass

    def unit_range_query(self, actors: List[Actor]) -> List[int]:
        '''查询Actor攻击范围内的目标

        Args:
            actors (List[Actor]): 要查询的Actor列表

        Returns:
            List[int]: 攻击范围内的目标 ID 列表
        '''
        pass

    def map_query(self) -> MapQueryResult:
        '''查询地图信息

        Returns:
            MapQueryResult: 地图信息
        '''
        pass

    def player_base_info_query(self) -> PlayerBaseInfo:
        '''查询玩家基础信息

        Returns:
            PlayerBaseInfo: 玩家基础信息
        '''
        pass

    def screen_info_query(self) -> ScreenInfoResult:
        '''查询当前屏幕信息

        Returns:
            ScreenInfoResult: 屏幕信息
        '''
        pass
