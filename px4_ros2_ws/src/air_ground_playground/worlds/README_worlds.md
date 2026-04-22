# Worlds 目录

此目录用于存放 Gazebo 世界文件。

## 当前状态

当前使用各 vendor 自带的世界文件：
- **DiffBot**: `gz_ros2_control_demos` 的 `empty.sdf`
- **BCR Bot**: `bcr_bot` 的 `small_warehouse.sdf`

## 未来规划

如需自定义世界文件（如包含 UAV 和 UGV 的联合场景），可在此目录添加：

```
worlds/
├── README_worlds.md          # 本文件
├── air_ground_empty.sdf      # 空地协同 - 空场景
├── air_ground_warehouse.sdf  # 空地协同 - 仓库场景
└── air_ground_outdoor.sdf    # 空地协同 - 室外场景
```

## 使用方法

在 launch 文件中指定自定义 world：

```python
launch_arguments={
    "world_file": "/path/to/air_ground_playground/worlds/air_ground_warehouse.sdf",
}
```

## 参考

- [Gazebo SDF 格式](http://sdformat.org/)
- [Gazebo Worlds 教程](https://gazebosim.org/docs/latest/sdf_worlds/)
