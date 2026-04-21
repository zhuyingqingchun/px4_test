from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def generate_launch_description() -> LaunchDescription:
    mission_config_arg = DeclareLaunchArgument(
        'mission_config',
        default_value='config/hover.yaml',
        description='Relative path to mission config inside the package share directory.',
    )

    use_sim_time_arg = DeclareLaunchArgument(
        'use_sim_time',
        default_value='true',
        description='Whether to use ROS 2 simulated time.',
    )

    standard_node = Node(
        package='my_px4_offboard',
        executable='standard_mission_node',
        name='standard_mission_node',
        output='screen',
        parameters=[
            {'use_sim_time': LaunchConfiguration('use_sim_time')},
            {'mission_config': LaunchConfiguration('mission_config')},
        ],
    )

    return LaunchDescription([
        mission_config_arg,
        use_sim_time_arg,
        standard_node,
    ])
