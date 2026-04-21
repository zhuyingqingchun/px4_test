# 外部依赖说明

本目录包含接入真实开源差速小车模型所需的外部依赖。

## 依赖列表

### 1. gz_ros2_control
- **用途**: Modern Gazebo 与 ros2_control 的官方集成
- **版本**: Jazzy
- **镜像源**: ghproxy.com 加速

### 2. ros2_control_demos
- **用途**: 包含 DiffBot 差速小车示例
- **版本**: Jazzy
- **镜像源**: ghproxy.com 加速

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

## DiffBot 关键文件位置

拉取后，DiffBot 相关文件位于:
- `ros2_control_demos/example_2/`: DiffBot 描述和配置
- `ros2_control_demos/example_2/bringup/launch/`: 启动文件
- `ros2_control_demos/example_2/bringup/config/`: 控制器配置
- `ros2_control_demos/example_2/description/urdf/`: URDF/Xacro 模型

## 参考文档

- [gz_ros2_control 文档](https://control.ros.org/jazzy/doc/gz_ros2_control/doc/index.html)
- [ros2_control_demos](https://github.com/ros-controls/ros2_control_demos)
