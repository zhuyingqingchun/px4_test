# UGV Vendor 策略说明

本文档说明 `air_ground_playground` 包的 UGV vendor 接入策略。

## 设计原则

### 1. 分层架构

```
┌─────────────────────────────────────┐
│  任务层: ground_robot_commander     │  ← 轨迹规划，与 vendor 无关
├─────────────────────────────────────┤
│  接口层: launch 文件                 │  ← 适配不同 vendor 的启动方式
├─────────────────────────────────────┤
│  Vendor 层:                         │
│  - gz_ros2_control_demos (DiffBot) │  ← 教学/调试
│  - BCR Bot                          │  ← 正式平台
└─────────────────────────────────────┘
```

### 2. 统一接口

所有 vendor 都通过 `cmd_vel` 话题接收速度指令：
- **DiffBot**: `/cmd_vel` (TwistStamped)
- **BCR Bot**: `/cmd_vel` (Twist)

任务层 `ground_robot_commander` 通过 remapping 适配不同 vendor。

---

## Vendor 详细说明

### DiffBot (gz_ros2_control_demos)

**适用场景**：
- 快速验证 ros2_control 链路
- 测试空地协同框架
- 最小化依赖

**文件位置**：
- Launch: `launch/vendor_gz_diffbot_only.launch.py`
- Launch: `launch/air_ground_with_gz_diffbot.launch.py`
- Repos: `external/ugv_open_source.repos`

**特点**：
- 模型简单（方块+两轮）
- 启动快速
- 适合调试

---

### BCR Bot

**适用场景**：
- 正式演示
- 需要传感器数据（相机、LiDAR）
- 导航算法开发（Nav2、SLAM）

**文件位置**：
- Launch: `launch/vendor_bcr_only.launch.py`
- Launch: `launch/air_ground_with_bcr.launch.py`
- Repos: `external/ugv_bcr.repos`

**特点**：
- 真实机器人模型
- 完整传感器配置
- 支持 ROS 2 Jazzy + Gazebo Harmonic

**传感器**：
- IMU
- 深度相机
- 双目相机（可选）
- 2D LiDAR（可选）

---

## 切换 Vendor

### 修改 config.env

```bash
# 编辑 ~/PX4_pro/px4sh/config.env

# DiffBot
OFFBOARD_CMD="ros2 launch air_ground_playground air_ground_with_gz_diffbot.launch.py"

# BCR Bot
OFFBOARD_CMD="ros2 launch air_ground_playground air_ground_with_bcr.launch.py"
```

### 安装依赖

**DiffBot**（已安装）：
```bash
cd ~/PX4_pro/px4_ros2_ws/src
vcs import . < external/ugv_open_source.repos
colcon build --packages-select gz_ros2_control_demos
```

**BCR Bot**：
```bash
cd ~/PX4_pro/px4_ros2_ws/src
vcs import . < external/ugv_bcr.repos
rosdep install --from-paths src --ignore-src -r -y
colcon build --packages-select bcr_bot
```

---

## 未来扩展

如需添加新的 vendor：

1. **创建 repos 文件**：`external/ugv_<vendor>.repos`
2. **创建 launch 文件**：
   - `launch/vendor_<vendor>_only.launch.py`（单独启动）
   - `launch/air_ground_with_<vendor>.launch.py`（空地协同）
3. **更新文档**：
   - `external/README_ugv_vendor.md`
   - 本文档
4. **测试**：验证 `cmd_vel` 接口和 `odom` 输出

---

## 参考

- [BCR Bot 文档](https://docs.ros.org/en/jazzy/p/bcr_bot)
- [gz_ros2_control 文档](https://control.ros.org/jazzy/doc/gz_ros2_control/doc/index.html)
