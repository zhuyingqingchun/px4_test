# Offboard 状态机草案

适用场景：当前仓库已经能正常起飞悬停，准备把节点从“单文件流程脚本”推进到“可排障、可扩展的工程状态机”。

## 1. 推荐状态

```text
INIT
  -> WAIT_FOR_CONNECTION
  -> WAIT_FOR_OFFBOARD_READY
  -> ARMING
  -> TAKEOFF
  -> HOVER
  -> TRAJECTORY
  -> RETURN
  -> LAND
  -> DISARM
  -> FINISH
  -> ERROR
```

## 2. 每个状态建议职责

### INIT
- 初始化参数
- 初始化 publisher / subscriber / timer
- 清空内部标志位

### WAIT_FOR_CONNECTION
- 等待 PX4 / DDS / ROS 2 数据链路可用
- 检查关键 topic 是否存在

### WAIT_FOR_OFFBOARD_READY
- 连续发送必要的 offboard 心跳 / setpoint
- 满足条件后才允许切 Offboard

### ARMING
- 发送 arm 请求
- 等待状态反馈确认

### TAKEOFF
- 上升到目标高度
- 达到阈值后切到 HOVER

### HOVER
- 保持若干秒稳定悬停
- 判断是否进入 TRAJECTORY 或 RETURN

### TRAJECTORY
- 执行航点或轨迹段
- 检查偏差、超时、越界

### RETURN
- 返回原点或安全点

### LAND
- 执行降落逻辑
- 等待落地稳定

### DISARM
- 发送 disarm 请求

### FINISH
- 输出成功总结
- 进入安全退出

### ERROR
- 记录失败阶段
- 执行安全退出或降级策略

## 3. 最小判据建议

- 高度达到阈值才算起飞成功
- 悬停稳定若干秒才允许进入轨迹
- 偏差过大时自动转 ERROR 或 RETURN
- 连接丢失时禁止继续推进状态
- 降落完成后才允许进入 DISARM

## 4. 当前最小推进建议

如果你暂时不想大改节点结构，可以先只做两件事：

1. 给现有流程补 `current_state` 日志；
2. 给每个阶段补“进入条件 / 退出条件 / 失败条件”。

这样即使还没完全重构成状态机，也能先把排障粒度提升起来。
