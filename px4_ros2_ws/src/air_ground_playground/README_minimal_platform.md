# Air-Ground Minimal Platform

## 目标

这个包把当前已经跑通的 `my_px4_offboard/standard_mission` 当作空中任务入口，再补一个最小地面机器人命令节点，形成“无人机 + 小车”的最小多实体平台。

这不是完整的机器人仿真栈，而是一个**工作空间级别的最小工程骨架**：

- PX4 继续负责无人机飞行控制
- `my_px4_offboard` 继续负责标准飞行任务
- `air_ground_playground` 负责地面机器人最小任务
- 真正的差速小车模型、控制器、世界文件通过 `gz_ros2_control_demos` 接入

## 当前目录结构

```text
px4_ros2_ws/src/
├── my_px4_offboard/                  # 现有 PX4 Offboard 任务包
├── air_ground_playground/            # 本包：最小空地平台
│   ├── air_ground_playground/
│   │   ├── ground_robot_commander.py
│   │   └── twist_to_twist_stamped_bridge.py
│   ├── config/
│   │   ├── rover_square.yaml
│   │   └── rover_out_and_back.yaml
│   ├── launch/
│   │   ├── air_ground_minimal.launch.py
│   │   ├── vendor_diffbot_only.launch.py           # 旧版：只起 ros2_control 骨架
│   │   ├── air_ground_with_vendor_diffbot.launch.py
│   │   ├── vendor_gz_diffbot_only.launch.py        # 新版：Gazebo 里可见 DiffBot
│   │   └── air_ground_with_gz_diffbot.launch.py    # 新版：UAV + Gazebo 可见 UGV
│   ├── scripts/
│   │   ├── fetch_vendor_diffbot.sh
│   │   └── fetch_vendor_gz_diffbot.sh
│   └── README_minimal_platform.md
└── external/
    ├── ugv_open_source.repos
    └── README_external_dependencies.md
```

## 关键说明

### 为什么你之前在 Gazebo 里看不到小车

之前的 `vendor_diffbot_only.launch.py` 主要启动的是 `ros2_control_node`、`robot_state_publisher` 和 controller spawner，它更接近“控制骨架联通”，**不是 Gazebo 可见实体小车示例**。

如果你想在 Gazebo 场景里真正看到 DiffBot，应该走 `gz_ros2_control_demos/diff_drive_example.launch.py` 这条官方示例路线。

## 外部依赖接入（Gazebo 可见 DiffBot）

### 系统依赖安装

```bash
sudo apt update
sudo apt install -y \
    ros-jazzy-gz-ros2-control \
    ros-jazzy-gz-ros2-control-demos \
    ros-jazzy-diff-drive-controller \
    ros-jazzy-joint-state-broadcaster \
    ros-jazzy-robot-state-publisher \
    ros-jazzy-xacro \
    ros-jazzy-ros-gz-bridge \
    ros-jazzy-ros-gz-sim \
    python3-vcstool
```

### 拉取外部代码

```bash
# 方式1：使用提供的脚本
cd ~/PX4_pro/px4_ros2_ws/src/air_ground_playground/scripts
./fetch_vendor_gz_diffbot.sh

# 方式2：手动拉取
cd ~/PX4_pro/px4_ros2_ws/src
vcs import . < external/ugv_open_source.repos
```

这将拉取：

- `gz_ros2_control`: Modern Gazebo 与 ros2_control 的官方集成
- `gz_ros2_control_demos`: 仓库内自带的 Gazebo 可见 DiffBot 示例

### Gazebo 可见 DiffBot 关键文件位置

```text
gz_ros2_control/gz_ros2_control_demos/
├── launch/
│   └── diff_drive_example.launch.py
├── config/
│   └── diff_drive_controller.yaml
└── urdf/
    └── test_diff_drive.xacro
```

## 运行方式

### 1. 构建工作空间

```bash
cd ~/PX4_pro/px4_ros2_ws
colcon build --symlink-install --packages-select \
    gz_ros2_control_demos air_ground_playground my_px4_offboard
source install/setup.bash
```

### 2. 单独测试 Gazebo 可见 DiffBot

```bash
ros2 launch air_ground_playground vendor_gz_diffbot_only.launch.py
```

### 3. 单独测试地面机器人指挥官

```bash
ros2 run air_ground_playground ground_robot_commander \
    --ros-args --params-file config/rover_out_and_back.yaml
```

### 4. 空地协同（UAV + Gazebo 可见 UGV）

```bash
ros2 launch air_ground_playground air_ground_with_gz_diffbot.launch.py
```

### 5. 通过 start.sh 启动

修改 `px4sh/config.env`：

```bash
OFFBOARD_CMD="ros2 launch air_ground_playground air_ground_with_gz_diffbot.launch.py ugv_config:=/home/tz/PX4_pro/px4_ros2_ws/install/air_ground_playground/share/air_ground_playground/config/rover_out_and_back.yaml"
```

然后运行：

```bash
cd ~/PX4_pro/px4sh
./start.sh
```

## 话题约定

- `ground_robot_commander` 发布：`/ugv/cmd_vel_unstamped`（`geometry_msgs/Twist`）
- `twist_to_twist_stamped_bridge` 转换到：`/cmd_vel`（`geometry_msgs/TwistStamped`）
- `gz_ros2_control_demos` DiffBot 订阅：`/cmd_vel`

这样可以复用你当前已经写好的地面指挥官，而不必重写 Gazebo demo 本身。

## 下一步建议

1. 先单独跑 `vendor_gz_diffbot_only.launch.py`，确认 Gazebo 里能看到车。
2. 再单独启动 `ground_robot_commander + twist_to_twist_stamped_bridge`，确认 `/cmd_vel` 能驱动车。
3. 最后再和 `my_px4_offboard/standard_mission` 组合成空地协同。

## 参考文档

- [gz_ros2_control 文档](https://control.ros.org/jazzy/doc/gz_ros2_control/doc/index.html)
- [gz_ros2_control GitHub 仓库](https://github.com/ros-controls/gz_ros2_control)
- [ros2_control 官方文档](https://control.ros.org/jazzy/)
