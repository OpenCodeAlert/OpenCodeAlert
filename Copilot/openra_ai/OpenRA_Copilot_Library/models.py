from typing import List, Dict, Optional
from dataclasses import dataclass

@dataclass
class Location:
    # 表示游戏中的二维位置坐标，左上角是原点，x 轴向右，y 轴向下
    x: int  # x 是地图中的水平偏移量。
    y: int  # y 是地图中的垂直偏移量。

    def __add__(self, other):
        # 两个位置相加，返回新位置。
        return Location(self.x + other.x, self.y + other.y) if isinstance(other, Location) else NotImplemented

    def __floordiv__(self, other):
        # 将位置的坐标按整数除法缩小，返回新位置。
        return Location(self.x // other, self.y // other) if isinstance(other, int) else NotImplemented

    def to_dict(self):
        # 将位置转换为字典表示。
        return {"x": self.x, "y": self.y}

    def manhattan_distance(self, other):
        # 计算曼哈顿距离。
        return abs(self.x - other.x) + abs(self.y - other.y)

    def euclidean_distance(self, other):
        # 计算欧几里得距离。
        return ((self.x - other.x) ** 2 + (self.y - other.y) ** 2) ** 0.5

# 查询目标的查询参数，用于查询符合条件的目标。
# 基本上是用这个结构体来表明一个或一些Actor
@dataclass
class TargetsQueryParam:
    type: Optional[List[str]] = None  # 目标类型，值为 {ALL_UNITS} 列表或 None。
    faction: Optional[str] = None  # 阵营，值为 {ALL_ACTORS} 中的一个或 None。
    group_id: Optional[List[int]] = None  # {ALL_GROUPS} 列表或 None。
    restrain: Optional[List[dict]] = None  # 约束条件。
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
        return {
            "type": self.type,
            "faction": self.faction,
            "groupId": self.group_id,
            "restrain": self.restrain,
            "location": self.location.to_dict() if self.location else None,
            "direction": self.direction,
            "range": self.range
        }

@dataclass
class Actor:
    actor_id: int  # 单位 ID。
    type: Optional[str] = None  # 单位类型，值为 {ALL_UNITS} 中的一个。
    faction: Optional[str] = None  # 阵营，值为 {ALL_ACTORS} 中的一个。
    position: Optional[Location] = None  # 单位的位置。
    hppercent: Optional[int] = None

    def __hash__(self):
        #actor_id 作为哈希值
        return hash(self.actor_id)

    def __eq__(self, other):
        # 判断两个 Actor 是否相等，基于 actor_id
        if isinstance(other, Actor):
            return self.actor_id == other.actor_id
        return False

    def update_details(self, type: str, faction: str, position: Location, hppercent: int):
        # 更新单位的详细信息。
        self.type = type
        self.faction = faction
        self.position = position
        self.hppercent = hppercent

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
        grid = getattr(self, grid_name, None)
        if grid is None:
            raise AttributeError(f"网格 '{grid_name}' 不存在。")
        if 0 <= location.x < len(grid) and 0 <= location.y < len(grid[0]):
            return grid[location.x][location.y]
        else:
            raise ValueError("位置超出范围。")

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
        return {
            "ScreenMin": self.ScreenMin.to_dict() if isinstance(self.ScreenMin, Location) else self.ScreenMin,
            "ScreenMax": self.ScreenMax.to_dict() if isinstance(self.ScreenMax, Location) else self.ScreenMax,
            "IsMouseOnScreen": self.IsMouseOnScreen,
            "MousePosition": self.MousePosition.to_dict() if isinstance(self.MousePosition, Location) else self.MousePosition,
        }


