# UGV Vendor 选型说明

本文档说明当前工作空间支持的 UGV (无人地面车辆) vendor 选项。

## 当前支持的 Vendor

### 1. 教学/调试基线：gz_ros2_control_demos (DiffBot)

**定位**：验证 Gazebo 可见实体、`cmd_vel` 到差速控制器的链路

**特点**：
- 极简模型（方块+两轮）
- 官方维护，文档完善
- 适合快速验证 ros2_control 链路

**启动方式**：
```bash
# 单独启动（带Gazebo）
ros2 launch air_ground_playground vendor_gz_diffbot_only.launch.py

# 与UAV协同（共享PX4的Gazebo）
ros2 launch air_ground_playground air_ground_with_gz_diffbot.launch.py
```

**依赖文件**：`external/ugv_open_source.repos`

---

### 2. 正式 Vendor：BCR Bot

**定位**：正式差速小车平台，带完整传感器配置

**特点**：
- 更真实的机器人模型
- 自带传感器：IMU、深度相机、双目相机、2D LiDAR
- 支持 Nav2 和 SLAM Toolbox
- 官方支持 ROS 2 Jazzy + Gazebo Harmonic

**启动方式**：
```bash
# 单独启动（带Gazebo）
ros2 launch air_ground_playground vendor_bcr_only.launch.py

# 与UAV协同（共享PX4的Gazebo）
ros2 launch air_ground_playground air_ground_with_bcr.launch.py
```

**依赖文件**：`external/ugv_bcr.repos`

**参考文档**：https://docs.ros.org/en/jazzy/p/bcr_bot

---

## Vendor 切换方法

### 方法1：修改 px4sh/config.env（推荐）

编辑 `~/PX4_pro/px4sh/config.env`：

```bash
# 使用 DiffBot
OFFBOARD_CMD="ros2 launch air_ground_playground air_ground_with_gz_diffbot.launch.py"

# 或使用 BCR Bot
OFFBOARD_CMD="ros2 launch air_ground_playground air_ground_with_bcr.launch.py"
```

### 方法2：手动启动

先启动 PX4（不带ROS）：
```bash
cd ~/PX4_pro/px4sh
./start.sh
```

然后在另一个终端启动 UGV：
```bash
source ~/PX4_pro/px4_ros2_ws/install/setup.bash
ros2 launch air_ground_playground air_ground_with_bcr.launch.py
```

---

## 添加新的 Vendor

如需添加新的 UGV vendor，需要：

1. 在 `external/` 创建新的 `.repos` 文件
2. 在 `air_ground_playground/launch/` 创建对应的 launch 文件
3. 更新本文档
4. 更新 `air_ground_playground/README_vendor_strategy.md`
