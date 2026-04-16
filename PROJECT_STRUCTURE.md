# 项目结构

## 已提交内容 (29 个文件)

### px4sh/ - 会话管理脚本 (15 个)
- **核心**：start.sh, stop.sh, restart.sh, status.sh, common.sh
- **辅助**：px4ctl.sh, read_logs.sh, stream_log.sh, show_alert_context.sh, status_check.sh, clean_cache.sh
- **配置**：config.env.example
- **文档**：README.md, 会话.md

### px4_ros2_ws/src/my_px4_offboard/ - offboard 控制 (7 个)
- Python 模块：__init__.py, offboard_takeoff_hover.py, offboard_trajectory.py
- 配置：package.xml, setup.cfg, setup.py
- 资源：resource/my_px4_offboard

### 根目录 (3 个)
- README.md, LICENSE, .gitignore

## 未提交内容

### px4_ros2_ws/ - ROS2 工作区
- build/, install/, log/ - 构建文件
- src/px4_msgs/, src/px4_ros_com/ - 第三方依赖

### 其他
- px4_session_logs/ - 会话日志
- Micro-XRCE-DDS-Agent/ - DDS 代理
- Documents/ - QGroundControl 文档
- PX4-Autopilot/ - PX4 源码

## 依赖说明

外部依赖（需用户自行配置）：
1. PX4-Autopilot/ - PX4 飞控
2. px4_msgs/ - 消息定义
3. px4_ros_com/ - 通信示例
4. Micro-XRCE-DDS-Agent - DDS 代理

## 启动流程

```
1. Micro-XRCE-DDS Agent
2. PX4 + Gazebo
3. QGroundControl
4. ROS 2 / offboard control
```

运行 `./px4sh/start.sh` 启动全部服务。
