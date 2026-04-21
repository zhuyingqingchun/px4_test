# my_px4_offboard Workspace Skeleton

这是面向“某一任务标准工程”的最小工作空间骨架，目标不是替换你当前已经能飞的
`offboard_takeoff_hover.py` 和 `offboard_trajectory.py`，而是给后续任务演进提供一个稳定的工程底座。

## 设计目标

- 把“示例脚本”过渡为“标准任务工程”
- 把**轨迹定义**、**状态机**、**安全规则**、**任务执行**分层
- 保持最小侵入：本补丁只新增文件，不修改现有可飞脚本
- 让纯 Python 部分可单测，减少每次都必须启动 PX4 SITL

## 目录说明

```text
my_px4_offboard/
├── config/
│   ├── hover.yaml
│   └── square.yaml
├── launch/
│   └── offboard_standard_mission.launch.py
├── my_px4_offboard/
│   ├── mission_executor.py
│   ├── offboard_state_machine.py
│   ├── px4_state_monitor.py
│   ├── safety_guard.py
│   └── trajectory_library.py
└── test/
    └── test_trajectory_library.py
```

## 模块职责

### trajectory_library.py
提供任务无关的轨迹生成能力，目前包含：

- 悬停参考点
- 正方形轨迹点生成
- 往返/巡航类轨迹扩展的统一入口

### offboard_state_machine.py
把任务流程抽象为显式状态：

- `WAITING_FOR_HEARTBEAT`
- `WAITING_FOR_ODOMETRY`
- `ARMING`
- `ENTERING_OFFBOARD`
- `TAKEOFF`
- `HOVER`
- `MISSION`
- `LANDING`
- `DISARMED`
- `FAILED`

### mission_executor.py
负责任务级调度，后续可被真正的 ROS 2 node 包一层：

- 根据配置加载任务
- 拉取参考轨迹
- 驱动状态机
- 接入安全守护

### px4_state_monitor.py
维护飞行所需的最小状态快照，避免把订阅回调逻辑直接写死在业务代码里。

### safety_guard.py
承担边界检查：

- 最大高度
- 超时
- 定位有效性
- 任务中止条件

## 推荐演进顺序

1. 先用现有 `offboard_trajectory.py` 接入 `trajectory_library.py`
2. 再把模式切换和阶段流转接到 `offboard_state_machine.py`
3. 最后补 `setup.py/package.xml`，把标准任务节点注册成新的 `console_script`

## 为什么这版不改 setup.py / package.xml

这是刻意保守的设计：

- 你当前已有脚本已经能飞
- 这次补丁优先给“标准工程骨架”
- 不在同一轮里同时改入口注册和行为逻辑，降低回归风险

下一轮如果要落成正式可运行节点，再补：

- `standard_mission_node.py`
- `setup.py` console entry point
- `package.xml` 的 launch/test 依赖
