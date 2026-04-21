# standard_mission 最小入口说明

## 推荐通过 launch 运行

```bash
ros2 launch my_px4_offboard offboard_standard_mission.launch.py
```

## 指定方形轨迹任务

```bash
ros2 launch my_px4_offboard offboard_standard_mission.launch.py \
  mission_config:=/absolute/path/to/square.yaml
```

## 直接通过 ros2 run 运行

```bash
ros2 run my_px4_offboard standard_mission \
  --ros-args --params-file /absolute/path/to/hover.yaml
```
