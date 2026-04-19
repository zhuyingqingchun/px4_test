# 最小可运行流程

本文件只保留“真正必要”的步骤，目标是帮助你在换机器、重装环境或长时间不使用后，最快恢复到可飞状态。

## 1. 环境准备

1. 准备 PX4-Autopilot、`px4_msgs`、`px4_ros_com`。
2. 确认 `px4sh/config.env` 中的路径、机型、Agent 参数、ROS 发行版配置正确。
3. 完成 ROS 2 工作区构建并执行 `source install/local_setup.bash`。

## 2. 启动

```bash
./px4sh/start.sh
```

## 3. 成功标志

至少满足以下条件：

- PX4 ready
- Agent 已连接
- QGC 可见并已连接（若启用）
- ROS 话题正常
- Offboard 能进入
- 能完成解锁 / 起飞 / 悬停 / 降落

## 4. 常用命令

```bash
./px4sh/status.sh
./px4sh/read_logs.sh
./px4sh/show_alert_context.sh
./px4sh/archive_success_log.sh
./px4sh/record_success_baseline.sh
./px4sh/stop.sh
```

## 5. 出现红字时的判断顺序

1. 先判断是否阻塞飞行。
2. 若不影响解锁、起飞、悬停、降落，则先归类为非阻塞问题。
3. 先保住可重复飞行，再处理日志消噪。
