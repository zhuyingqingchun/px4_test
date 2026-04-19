# 成功飞行基线

> 由 `px4sh/record_success_baseline.sh` 自动生成。

## 1. 生成信息

- 生成时间：2026-04-19 16:37:59 +0800
- 分支：`main`
- Commit：`04b1aa2` / `04b1aa25e6b8085d61e47c684cd46cc5259d202a`
- 工作区状态：`clean`

## 2. 本次运行配置

- SESSION_NAME：`px4_stack`
- PX4_DIR：`/home/tz/PX4-Autopilot`
- ROS_WS：`/home/tz/PX4_pro/px4_ros2_ws`
- ROS_DISTRO：`jazzy`
- PX4_TARGET：`gz_x500`
- GZ_MODE：`未设置`
- HEADLESS：`0`
- ENABLE_QGC：`0`
- ENABLE_ROS：`1`
- AGENT_ARGS：`udp4 -p 8888`
- OFFBOARD_CMD：`ros2 run my_px4_offboard offboard_trajectory`

## 3. 成功飞行判据

请人工补充本次成功飞行是否满足以下条件：

- [ ] PX4 正常 ready
- [ ] Agent 正常连通
- [ ] QGC 正常连接
- [ ] ROS 话题正常
- [ ] Offboard 正常进入
- [ ] 正常解锁 / 起飞 / 悬停 / 降落 / 上锁
- [ ] 第二次启动仍可复现

## 4. 日志归档位置

建议在成功飞行后立刻执行：

`./px4sh/archive_success_log.sh`

归档目录示例：`logs/archive/<timestamp>_success/`

## 5. 人工补充记录

### 5.1 启动命令

- 

### 5.2 使用的 offboard 节点

- 

### 5.3 成功日志要点

- 

### 5.4 当前已知红字（先判断是否阻塞）

- 

### 5.5 回退策略

- 可回退分支：
- 可回退 commit：
- 可复用日志归档：
