#!/usr/bin/env python3
"""Launch UAV standard mission together with BCR Bot in shared Gazebo (empty world).

This launch file:
1. Assumes PX4 has already started Gazebo with empty world (via start.sh)
2. Spawns BCR Bot into the existing Gazebo instance
3. Starts UAV standard mission
4. Starts UGV commander node
"""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, TimerAction
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
            default_value="3.0",
            description="BCR Bot initial X position in world (meters).",
        ),
        DeclareLaunchArgument(
            "bcr_position_y",
            default_value="3.0",
            description="BCR Bot initial Y position in world (meters).",
        ),
        DeclareLaunchArgument(
            "bcr_orientation_yaw",
            default_value="0.0",
            description="BCR Bot initial yaw orientation (radians).",
        ),
    ]

    uav_config = LaunchConfiguration("uav_config")
    ugv_config = LaunchConfiguration("ugv_config")
    bcr_position_x = LaunchConfiguration("bcr_position_x")
    bcr_position_y = LaunchConfiguration("bcr_position_y")
    bcr_orientation_yaw = LaunchConfiguration("bcr_orientation_yaw")

    # Spawn BCR Bot into existing Gazebo (spawn only, don't launch Gazebo)
    # Using ros_gz_sim create to spawn the robot
    bcr_spawn = Node(
        package="ros_gz_sim",
        executable="create",
        output="screen",
        arguments=[
            "-name", "bcr_bot",
            "-x", bcr_position_x,
            "-y", bcr_position_y,
            "-z", "0.1",
            "-Y", bcr_orientation_yaw,
            "-topic", "/bcr_bot/robot_description",
        ],
    )

    # Robot state publisher for BCR Bot
    bcr_robot_state_publisher = Node(
        package="robot_state_publisher",
        executable="robot_state_publisher",
        name="bcr_bot_robot_state_publisher",
        output="screen",
        parameters=[{
            "robot_description": PathJoinSubstitution([
                FindPackageShare("bcr_bot"),
                "urdf",
                "bcr_bot.xacro",
            ]),
            "use_sim_time": True,
        }],
        remappings=[("/robot_description", "/bcr_bot/robot_description")],
    )

    # Delay BCR Bot spawn to allow PX4 Gazebo to be ready
    bcr_spawn_delayed = TimerAction(
        period=5.0,
        actions=[bcr_spawn],
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
        declared_arguments + [
            bcr_robot_state_publisher,
            bcr_spawn_delayed,
            uav_node,
            ugv_commander_node,
        ]
    )
