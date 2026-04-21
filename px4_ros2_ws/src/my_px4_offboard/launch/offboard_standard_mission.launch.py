from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare


def generate_launch_description():
    mission_config = LaunchConfiguration("mission_config")

    return LaunchDescription(
        [
            DeclareLaunchArgument(
                "mission_config",
                default_value=PathJoinSubstitution(
                    [FindPackageShare("my_px4_offboard"), "config", "hover.yaml"]
                ),
                description="Absolute path to a mission parameter file.",
            ),
            Node(
                package="my_px4_offboard",
                executable="standard_mission",
                name="standard_mission",
                output="screen",
                parameters=[mission_config],
            ),
        ]
    )
