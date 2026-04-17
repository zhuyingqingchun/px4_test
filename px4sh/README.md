# PX4 / Gazebo / QGC / ROS 2 tmux 运维脚本

这套脚本用于统一启动和管理：
- PX4 SITL
- Gazebo
- QGroundControl
- Micro XRCE-DDS Agent
- ROS 2 Offboard 节点

## 快速开始

```bash
cp config.env.example config.env
chmod +x *.sh
./start.sh
```

常用命令：
- 启动：`./start.sh` 或 `./px4ctl.sh start`
- 停止：`./stop.sh` 或 `./px4ctl.sh stop`
- 重启：`./restart.sh` 或 `./px4ctl.sh restart`
- 状态：`./status.sh` 或 `./px4ctl.sh status`
- 读摘要日志：`./read_logs.sh`

## 文档导航

- [启动与运维](./docs/operations.md)
- [日志读取说明](./docs/logging.md)
- [日志代码规范](./docs/logging_code_style.md)

## 建议

- 日常优先看 `read_logs.sh`
- 只有异常时再看告警上下文和完整日志
