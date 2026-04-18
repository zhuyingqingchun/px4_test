# PX4 快速启动指南

## 基础命令

### 启动会话
```bash
cd /home/tz/PX4_pro/px4sh
./px4ctl.sh start
```

### 停止会话
```bash
cd /home/tz/PX4_pro/px4sh
./px4ctl.sh stop
```

### 重启会话
```bash
cd /home/tz/PX4_pro/px4sh
./px4ctl.sh restart
```

### 暂停（等价于 stop）
```bash
cd /home/tz/PX4_pro/px4sh
./px4ctl.sh pause
```

### 查看状态
```bash
cd /home/tz/PX4_pro/px4sh
./px4ctl.sh status
```

## 日志查看

### 查看摘要日志
```bash
cd /home/tz/PX4_pro/px4sh
./read_logs.sh
```

### 查看完整日志
```bash
cd /home/tz/PX4_pro/px4sh
./read_logs.sh "<日志目录>" full
```

### 查看告警日志
```bash
cd /home/tz/PX4_pro/px4sh
./read_logs.sh "<日志目录>" alerts
```

### 指定日志目录和行数
```bash
cd /home/tz/PX4_pro/px4sh
./read_logs.sh "<日志目录>" summary 100
```

## 推荐测试流程

```bash
cd /home/tz/PX4_pro/px4sh

# 1. 启动
./px4ctl.sh start

# 2. 检查状态
./px4ctl.sh status

# 3. 停止
./px4ctl.sh stop

# 4. 重启
./px4ctl.sh restart
```

## 日志目录位置

日志默认保存在 `px4_session_logs/` 目录下，按时间戳组织：

```
px4_session_logs/
└── 2026-04-18_22-22-58/
    ├── agent.alerts.log
    ├── agent.log
    ├── agent.summary.log
    ├── px4.alerts.log
    ├── px4.log
    ├── px4.summary.log
    ├── qgc.alerts.log
    ├── qgc.log
    ├── qgc.summary.log
    ├── ros_app.alerts.log
    ├── ros_app.log
    └── ros_app.summary.log
```

## 组件说明

- **px4**: PX4 自动驾驶仪日志
- **ros_app**: ROS 2 offboard 控制节点日志
- **agent**: MicroXRCEAgent 日志
- **qgc**: QGroundControl 日志

## 故障排查

如果启动后卡住，查看最新日志：

```bash
# 查看 ROS 应用日志
cat /home/tz/PX4_pro/px4_session_logs/<最新目录>/ros_app.log

# 查看告警
cat /home/tz/PX4_pro/px4_session_logs/<最新目录>/ros_app.alerts.log
```
