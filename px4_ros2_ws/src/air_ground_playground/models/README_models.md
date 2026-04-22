# Models 目录

此目录用于存放自定义机器人模型文件。

## 当前状态

当前使用各 vendor 自带的模型：
- **DiffBot**: `gz_ros2_control_demos` 的 `test_diff_drive.xacro`
- **BCR Bot**: `bcr_bot` 的 `bcr_bot` 模型

## 未来规划

如需自定义模型（如修改 BCR Bot 的外观或添加新传感器），可在此目录添加：

```
models/
├── README_models.md           # 本文件
├── my_custom_robot/
│   ├── model.sdf              # SDF 模型文件
│   ├── model.config           # 模型配置
│   └── meshes/                # 网格文件
└── my_custom_uav/
    └── ...
```

## 使用方法

在 launch 文件中引用自定义模型：

```python
Node(
    package="ros_gz_sim",
    executable="create",
    arguments=["-file", PathJoinSubstitution([
        FindPackageShare("air_ground_playground"),
        "models/my_custom_robot/model.sdf"
    ]), "-name", "my_robot"],
)
```

## 参考

- [Gazebo Model 教程](https://gazebosim.org/docs/latest/actors/)
- [SDF 格式](http://sdformat.org/)
