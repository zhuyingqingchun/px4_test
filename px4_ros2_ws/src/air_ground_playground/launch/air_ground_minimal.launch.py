from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare


def generate_launch_description():
    mission_config = LaunchConfiguration("mission_config")
    rover_config = LaunchConfiguration("rover_config")

    return LaunchDescription(
        [
            DeclareLaunchArgument(
                "mission_config",
                default_value=PathJoinSubstitution(
                    [FindPackageShare("my_px4_offboard"), "config", "square.yaml"]
                ),
                description="Absolute path to the drone mission parameter file.",
            ),
            DeclareLaunchArgument(
                "rover_config",
                default_value=PathJoinSubstitution(
                    [FindPackageShare("air_ground_playground"), "config", "rover_square.yaml"]
                ),
                description="Absolute path to the rover parameter file.",
            ),
            Node(
                package="my_px4_offboard",
                executable="standard_mission",
                name="standard_mission",
                output="screen",
                parameters=[mission_config],
            ),
            Node(
                package="air_ground_playground",
                executable="ground_robot_commander",
                name="ground_robot_commander",
                output="screen",
                parameters=[rover_config],
            ),
        ]
    )
