#!/usr/bin/env python3
"""Launch UAV standard mission together with the official Gazebo-visible DiffBot demo."""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription
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
            "description_format",
            default_value="urdf",
            description="Robot description format for the upstream Gazebo demo (urdf or sdf).",
        ),
    ]

    uav_config = LaunchConfiguration("uav_config")
    ugv_config = LaunchConfiguration("ugv_config")
    description_format = LaunchConfiguration("description_format")

    gz_diffbot = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            PathJoinSubstitution(
                [
                    FindPackageShare("air_ground_playground"),
                    "launch",
                    "vendor_gz_diffbot_only.launch.py",
                ]
            )
        ),
        launch_arguments={
            "description_format": description_format,
            "use_gz": "false",  # Don't launch Gazebo, PX4 already started it
        }.items(),
    )

    uav_node = Node(
        package="my_px4_offboard",
        executable="standard_mission",
        name="uav_standard_mission",
        output="screen",
        parameters=[uav_config],
    )

    ugv_commander_node = Node(
        package="air_ground_playground",
        executable="ground_robot_commander",
        name="ugv_commander",
        output="screen",
        parameters=[ugv_config],
        remappings=[("/ugv/cmd_vel", "/ugv/cmd_vel_unstamped")],
    )

    ugv_bridge_node = Node(
        package="air_ground_playground",
        executable="twist_to_twist_stamped_bridge",
        name="ugv_cmd_bridge",
        output="screen",
        parameters=[
            {
                "input_topic": "/ugv/cmd_vel_unstamped",
                "output_topic": "/cmd_vel",
                "frame_id": "base_link",
            }
        ],
    )

    return LaunchDescription(
        declared_arguments + [gz_diffbot, uav_node, ugv_commander_node, ugv_bridge_node]
    )
