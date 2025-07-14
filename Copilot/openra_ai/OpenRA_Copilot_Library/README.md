# OpenRA Copilot 库

为OpenRA（开源红警）项目提供的AI辅助库。

## 安装

建议先开启venv后再执行
在openra_ai文件夹或本文件夹下执行
```bash
pip install -e .
```

## 使用方法

### 检查服务器是否运行

在尝试创建连接前，可以使用静态方法检查服务器是否运行：

```python
from OpenRA_Copilot_Library import GameAPI

# 检查服务器是否运行
if GameAPI.is_server_running():
    print("服务器已启动，可以连接！")
else:
    print("服务器未启动或无法访问，请启动游戏服务器")

# 使用自定义地址和端口
if GameAPI.is_server_running(host="192.168.1.100", port=8080, timeout=1.0):
    print("远程服务器可访问")
```

### 基本使用

```python
from OpenRA_Copilot_Library import GameAPI
from OpenRA_Copilot_Library import Location, TargetsQueryParam

# 初始化API
api = GameAPI("localhost", 7445)

# 查询Actor
targets_query = TargetsQueryParam()
targets_query.add_owner_condition("player")  # 只查询玩家自己的单位
targets_query.add_actor_type_condition("MCV")  # 只查询MCV
mcvs = api.query_actor(targets_query)

if mcvs:
    # 移动相机到MCV
    api.move_camera_to(mcvs[0])
    
    # 部署MCV
    api.deploy_units(mcvs)
```

### 生产队列管理

```python
# 查询生产队列
building_queue = api.query_production_queue("Building")  # 建筑队列
infantry_queue = api.query_production_queue("Infantry")  # 步兵队列

# 生产单位
api.produce("步兵", 3)  # 生产3个步兵

# 管理生产队列
api.manage_production("Infantry", "pause")   # 暂停步兵生产
api.manage_production("Infantry", "resume")  # 恢复步兵生产 
api.manage_production("Infantry", "cancel")  # 取消步兵生产

# 放置建筑
api.place_building("Building")  # 自动放置建筑队列中已就绪的建筑
api.place_building("Building", Location(10, 15))  # 在指定位置放置建筑
```

### 支持的队列类型

- `"Building"` - 建筑队列
- `"Defense"` - 防御建筑队列
- `"Infantry"` - 步兵队列
- `"Vehicle"` - 载具队列
- `"Aircraft"` - 飞机队列
- `"Naval"` - 海军队列 