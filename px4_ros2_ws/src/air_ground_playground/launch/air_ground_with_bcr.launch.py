#!/usr/bin/env python3
"""Launch UAV standard mission together with BCR Bot in shared Gazebo.

This launch file:
1. Assumes PX4 has already started Gazebo (via start.sh)
2. Spawns BCR Bot into the existing Gazebo instance
3. Starts UAV standard mission
4. Starts UGV commander node

BCR Bot parameters reference:
- camera_enabled: Enable depth camera
- stereo_camera_enabled: Enable stereo camera
- two_d_lidar_enabled: Enable 2D LiDAR
- position_x, position_y: Initial position in world
- orientation_yaw: Initial orientation
- world_file: Gazebo world file (not used when spawning into existing Gazebo)
"""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription, TimerAction
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare


def generate_launch_description():
    declared_arguments = [
        DeclareLaunchArgument(
            "uav_config",
            default_value=PathJoinSubstitution(
                [FindPackageShare("my_px4_offboard"), "config", "square.yaml"]
            ),
            description="UAV mission configuration file.",
        ),
        DeclareLaunchArgument(
            "ugv_config",
            default_value=PathJoinSubstitution(
                [FindPackageShare("air_ground_playground"), "config", "rover_out_and_back.yaml"]
            ),
            description="UGV mission configuration file.",
        ),
        DeclareLaunchArgument(
            "bcr_position_x",
            default_value="2.0",
            description="BCR Bot initial X position in world.",
        ),
        DeclareLaunchArgument(
            "bcr_position_y",
            default_value="2.0",
            description="BCR Bot initial Y position in world.",
        ),
        DeclareLaunchArgument(
            "bcr_orientation_yaw",
            default_value="0.0",
            description="BCR Bot initial yaw orientation.",
        ),
    ]

    uav_config = LaunchConfiguration("uav_config")
    ugv_config = LaunchConfiguration("ugv_config")
    bcr_position_x = LaunchConfiguration("bcr_position_x")
    bcr_position_y = LaunchConfiguration("bcr_position_y")
    bcr_orientation_yaw = LaunchConfiguration("bcr_orientation_yaw")

    # BCR Bot launch - spawn into existing Gazebo (no world_file)
    # Note: BCR Bot's gz.launch.py will still try to launch Gazebo,
    # but we can use a custom spawn launch or directly spawn the robot
    # For now, we use a TimerAction to delay BCR Bot spawn after PX4 Gazebo is ready
    bcr_launch = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            PathJoinSubstitution(
                [
                    FindPackageShare("bcr_bot"),
                    "launch",
                    "gz.launch.py",
                ]
            )
        ),
        launch_arguments={
            "camera_enabled": "True",
            "stereo_camera_enabled": "False",
            "two_d_lidar_enabled": "True",
            "position_x": bcr_position_x,
            "position_y": bcr_position_y,
            "orientation_yaw": bcr_orientation_yaw,
            "odometry_source": "world",
            # Note: When spawning into existing Gazebo, world_file is ignored
            "world_file": "small_warehouse.sdf",
        }.items(),
    )

    # Delay BCR Bot launch to allow PX4 Gazebo to be ready
    bcr_launch_delayed = TimerAction(
        period=10.0,  # Wait for PX4 Gazebo to be fully ready
        actions=[bcr_launch],
    )

    # UAV node
    uav_node = Node(
        package="my_px4_offboard",
        executable="standard_mission",
        name="uav_standard_mission",
        output="screen",
        parameters=[uav_config],
    )

    # UGV commander node - publishes to /cmd_vel (BCR Bot uses this directly)
    ugv_commander_node = Node(
        package="air_ground_playground",
        executable="ground_robot_commander",
        name="ugv_commander",
        output="screen",
        parameters=[ugv_config],
        remappings=[("/ugv/cmd_vel", "/cmd_vel")],  # BCR Bot uses /cmd_vel directly
    )

    return LaunchDescription(
        declared_arguments + [uav_node, ugv_commander_node, bcr_launch_delayed]
    )
