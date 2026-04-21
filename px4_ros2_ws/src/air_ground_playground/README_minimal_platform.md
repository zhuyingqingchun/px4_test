# Air-Ground Minimal Platform

## 目标

这个包把当前已经跑通的 `my_px4_offboard/standard_mission` 当作空中任务入口，再补一个最小地面机器人命令节点，形成“无人机 + 小车”的最小多实体平台。

这不是完整的机器人仿真栈，而是一个**工作空间级别的最小工程骨架**：

- PX4 继续负责无人机飞行控制
- `my_px4_offboard` 继续负责标准飞行任务
- `air_ground_playground` 负责地面机器人最小任务
- 真正的差速小车模型、控制器、世界文件可以后续替换为开源项目

## 建议目录结构

```text
px4_ros2_ws/src/
├── my_px4_offboard/                  # 现有 PX4 Offboard 任务包
│   ├── my_px4_offboard/
│   ├── config/
│   └── launch/
├── air_ground_playground/            # 本补丁新增：最小空地平台包
│   ├── air_ground_playground/
│   │   └── ground_robot_commander.py
│   ├── config/
│   │   ├── rover_square.yaml
│   │   └── rover_out_and_back.yaml
│   ├── launch/
│   │   └── air_ground_minimal.launch.py
│   └── README_minimal_platform.md
└── future_manipulation_stack/        # 预留：后续机械臂包
    ├── arm_description/
    ├── arm_control/
    └── air_manipulation_coordinator/
```

## 当前实现内容

### 1. 无人机侧

直接复用：

- `my_px4_offboard` 中已经验证成功的 `standard_mission`
- 默认参数文件 `square.yaml`

### 2. 小车侧

`ground_robot_commander.py` 只做一件事：按时间脚本持续发布 `geometry_msgs/Twist` 到 `cmd_vel` 话题。

支持的最小任务：

- `idle`
- `forward`
- `square`
- `out_and_back`

它不依赖具体机器人模型，所以后面可以替换成任何兼容 `cmd_vel` 的差速车开源栈。

## 推荐接入方式

当前补丁默认使用：

- 无人机：`my_px4_offboard/standard_mission`
- 小车控制接口：`/ugv/cmd_vel`

后面如果你接入开源差速小车模型，只要它对外暴露 `cmd_vel` 接口，就可以直接复用这个节点。

## 运行方式

```bash
colcon build --packages-select my_px4_offboard air_ground_playground
source install/setup.bash
ros2 launch air_ground_playground air_ground_minimal.launch.py
```

## 下一步建议

### 开源小车接入

优先找带下面特征的开源项目：

- 现代 Gazebo / `gz_ros2_control`
- `diff_drive_controller`
- `cmd_vel` 控制接口
- `odom` / `tf` 输出

### 机械臂扩展

机械臂不要一开始就和 PX4 飞行控制强耦合。建议顺序：

1. 先在同一个 world 中加入固定机械臂
2. 用独立 ROS 2 包控制机械臂
3. 再做无人机与机械臂任务协同
4. 最后才考虑空中机械臂耦合
