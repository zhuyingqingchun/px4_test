# 外部依赖说明

本目录包含“**Gazebo 里可见的小车模型**”所需的最小外部依赖。

## 依赖列表

### 1. gz_ros2_control 仓库
- **用途**: Modern Gazebo 与 ros2_control 的官方集成
- **版本**: Jazzy
- **包含内容**:
  - `gz_ros2_control`
  - `gz_ros2_control_demos`（内含 Gazebo 可见的 DiffBot / Tricycle / Ackermann / Mecanum 示例）

> 注意：`gz_ros2_control_demos` **不需要单独再克隆仓库**，它就在 `gz_ros2_control` 这个仓库里。

## 系统依赖安装

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

## 拉取外部代码

```bash
cd ~/PX4_pro/px4_ros2_ws/src
vcs import . < external/ugv_open_source.repos
```

或者使用工作空间内脚本：

```bash
cd ~/PX4_pro/px4_ros2_ws/src/air_ground_playground/scripts
./fetch_vendor_gz_diffbot.sh
```

## Gazebo 可见 DiffBot 关键文件位置

拉取后，DiffBot 相关文件位于：

- `gz_ros2_control/gz_ros2_control_demos/launch/diff_drive_example.launch.py`
- `gz_ros2_control/gz_ros2_control_demos/config/diff_drive_controller.yaml`
- `gz_ros2_control/gz_ros2_control_demos/urdf/test_diff_drive.xacro`

这些文件才是“**Gazebo 世界里能真正看到小车**”的最小官方示例入口。

## 参考文档

- [gz_ros2_control 文档](https://control.ros.org/jazzy/doc/gz_ros2_control/doc/index.html)
- [gz_ros2_control GitHub 仓库](https://github.com/ros-controls/gz_ros2_control)
