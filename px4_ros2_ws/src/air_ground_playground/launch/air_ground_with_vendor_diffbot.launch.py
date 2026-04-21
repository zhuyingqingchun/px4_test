#!/usr/bin/env python3
"""
Launch file for air-ground coordination with vendor DiffBot.
Launches both UAV (standard_mission) and UGV (DiffBot).
"""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare


def generate_launch_description():
    # Declare arguments
    declared_arguments = []
    declared_arguments.append(
        DeclareLaunchArgument(
            "uav_config",
            default_value=PathJoinSubstitution(
                [FindPackageShare("my_px4_offboard"), "config", "square.yaml"]
            ),
            description="UAV mission configuration file.",
        )
    )
    declared_arguments.append(
        DeclareLaunchArgument(
            "ugv_config",
            default_value=PathJoinSubstitution(
                [FindPackageShare("air_ground_playground"), "config", "rover_out_and_back.yaml"]
            ),
            description="UGV mission configuration file.",
        )
    )
    declared_arguments.append(
        DeclareLaunchArgument(
            "use_mock_hardware",
            default_value="false",
            description="Start UGV with mock hardware.",
        )
    )

    # Initialize Arguments
    uav_config = LaunchConfiguration("uav_config")
    ugv_config = LaunchConfiguration("ugv_config")
    use_mock_hardware = LaunchConfiguration("use_mock_hardware")

    # UAV Node (standard_mission from my_px4_offboard)
    uav_node = Node(
        package="my_px4_offboard",
        executable="standard_mission",
        name="uav_standard_mission",
        output="screen",
        parameters=[uav_config],
    )

    # UGV Commander Node (cmd_vel publisher)
    ugv_commander_node = Node(
        package="air_ground_playground",
        executable="ground_robot_commander",
        name="ugv_commander",
        output="screen",
        parameters=[ugv_config],
        remappings=[("/ugv/cmd_vel", "/diffbot_base_controller/cmd_vel_unstamped")],
    )

    # Include DiffBot launch
    diffbot_launch = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            PathJoinSubstitution(
                [FindPackageShare("air_ground_playground"), "launch", "vendor_diffbot_only.launch.py"]
            )
        ),
        launch_arguments={
            "use_mock_hardware": use_mock_hardware,
        }.items(),
    )

    nodes = [
        diffbot_launch,
        uav_node,
        ugv_commander_node,
    ]

    return LaunchDescription(declared_arguments + nodes)
