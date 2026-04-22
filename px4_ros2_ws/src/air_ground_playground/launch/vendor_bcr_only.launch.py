#!/usr/bin/env python3
"""Launch BCR Bot in standalone mode (with its own Gazebo).

This launch file wraps bcr_bot's gz.launch.py for standalone testing.
For use when you want to test BCR Bot independently of PX4.
"""

from launch import LaunchDescription
from launch.actions import IncludeLaunchDescription
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import PathJoinSubstitution
from launch_ros.substitutions import FindPackageShare


def generate_launch_description():
    # Include BCR Bot's own Gazebo launch
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
            "position_x": "2.0",
            "position_y": "2.0",
            "orientation_yaw": "0.0",
            "odometry_source": "world",
            "world_file": "small_warehouse.sdf",
        }.items(),
    )

    return LaunchDescription([bcr_launch])
