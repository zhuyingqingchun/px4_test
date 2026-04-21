# Air-Ground Minimal Platform

## 目标

这个包把当前已经跑通的 `my_px4_offboard/standard_mission` 当作空中任务入口，再补一个最小地面机器人命令节点，形成"无人机 + 小车"的最小多实体平台。

这不是完整的机器人仿真栈，而是一个**工作空间级别的最小工程骨架**：

- PX4 继续负责无人机飞行控制
- `my_px4_offboard` 继续负责标准飞行任务
- `air_ground_playground` 负责地面机器人最小任务
- 真正的差速小车模型、控制器、世界文件可以后续替换为开源项目

## 当前目录结构

```text
px4_ros2_ws/src/
├── my_px4_offboard/                  # 现有 PX4 Offboard 任务包
│   ├── my_px4_offboard/
│   ├── config/
│   └── launch/
├── air_ground_playground/            # 本包：最小空地平台
│   ├── air_ground_playground/
│   │   └── ground_robot_commander.py
│   ├── config/
│   │   ├── rover_square.yaml
│   │   └── rover_out_and_back.yaml
│   ├── launch/
│   │   ├── air_ground_minimal.launch.py
│   │   ├── vendor_diffbot_only.launch.py      # 单独启动DiffBot
│   │   └── air_ground_with_vendor_diffbot.launch.py  # 空地协同
│   ├── scripts/
│   │   └── fetch_vendor_diffbot.sh            # 拉取外部依赖脚本
│   └── README_minimal_platform.md
└── external/                         # 外部依赖（通过vcs管理）
    ├── ugv_open_source.repos         # vcs导入配置
    └── README_external_dependencies.md
    ├── gz_ros2_control/              # ros2_control Gazebo集成
    └── ros2_control_demos/           # 包含DiffBot示例
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

## 外部依赖接入（DiffBot）

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
./fetch_vendor_diffbot.sh

# 方式2：手动拉取
cd ~/PX4_pro/px4_ros2_ws/src
vcs import . < external/ugv_open_source.repos
```

这将拉取：
- `gz_ros2_control`: Modern Gazebo与ros2_control的官方集成
- `ros2_control_demos`: 包含DiffBot差速小车完整示例

### DiffBot关键文件位置

```
ros2_control_demos/example_2/
├── bringup/
│   ├── launch/diffbot.launch.py
│   └── config/diffbot_controllers.yaml
├── description/
│   └── urdf/diffbot.urdf.xacro
└── ...
```

## 运行方式

### 1. 构建工作空间

```bash
cd ~/PX4_pro/px4_ros2_ws
colcon build --symlink-install
source install/setup.bash
```

### 2. 单独测试DiffBot

```bash
ros2 launch air_ground_playground vendor_diffbot_only.launch.py
```

### 3. 单独测试地面机器人指挥官

```bash
ros2 run air_ground_playground ground_robot_commander \
    --ros-args --params-file config/rover_out_and_back.yaml
```

### 4. 空地协同（UAV + UGV）

```bash
# 基础版本（使用虚拟小车）
ros2 launch air_ground_playground air_ground_minimal.launch.py

# 接入真实DiffBot版本
ros2 launch air_ground_playground air_ground_with_vendor_diffbot.launch.py

# 指定不同轨迹
ros2 launch air_ground_playground air_ground_with_vendor_diffbot.launch.py \
    ugv_config:=config/rover_square.yaml
```

### 5. 通过start.sh启动

修改 `px4sh/config.env`：

```bash
# 空地协同（UAV方形轨迹 + UGV往返轨迹）
OFFBOARD_CMD="ros2 launch air_ground_playground air_ground_with_vendor_diffbot.launch.py ugv_config:=/home/tz/PX4_pro/px4_ros2_ws/install/air_ground_playground/share/air_ground_playground/config/rover_out_and_back.yaml"
```

然后运行：
```bash
cd ~/PX4_pro/px4sh
./start.sh
```

## 下一步建议

### 开源小车接入

当前已接入 `ros2_control_demos` 的DiffBot，特征：

- ✅ 现代 Gazebo / `gz_ros2_control`
- ✅ `diff_drive_controller`
- ✅ `cmd_vel` 控制接口
- ✅ `odom` / `tf` 输出

如需替换为其他开源小车，保持以上接口兼容即可。

### 机械臂扩展

机械臂不要一开始就和 PX4 飞行控制强耦合。建议顺序：

1. 先在同一个 world 中加入固定机械臂
2. 用独立 ROS 2 包控制机械臂
3. 再做无人机与机械臂任务协同
4. 最后才考虑空中机械臂耦合

## 参考文档

- [gz_ros2_control 文档](https://control.ros.org/jazzy/doc/gz_ros2_control/doc/index.html)
- [ros2_control_demos](https://github.com/ros-controls/ros2_control_demos)
- [ros2_control 官方文档](https://control.ros.org/jazzy/)
