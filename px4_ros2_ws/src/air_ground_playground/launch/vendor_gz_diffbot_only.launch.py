#!/usr/bin/env python3
"""Launch the official Gazebo-visible DiffBot demo from gz_ros2_control_demos.

This version allows running without launching a new Gazebo instance,
for use when Gazebo is already running (e.g., from PX4).
"""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription, OpaqueFunction
from launch.actions import RegisterEventHandler, TimerAction
from launch.conditions import IfCondition, UnlessCondition
from launch.event_handlers import OnProcessExit
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import Command, FindExecutable, LaunchConfiguration, PathJoinSubstitution

from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare


def generate_launch_description():
    # Launch Arguments
    use_sim_time = LaunchConfiguration('use_sim_time', default=True)
    description_format = LaunchConfiguration('description_format')
    use_gz = LaunchConfiguration('use_gz', default='true')  # Whether to launch Gazebo

    def robot_state_publisher(context):
        performed_description_format = LaunchConfiguration('description_format').perform(context)
        # Get URDF or SDF via xacro
        robot_description_content = Command(
            [
                PathJoinSubstitution([FindExecutable(name='xacro')]),
                ' ',
                PathJoinSubstitution([
                    FindPackageShare('gz_ros2_control_demos'),
                    performed_description_format,
                    f'test_diff_drive.xacro.{performed_description_format}'
                ]),
            ]
        )
        robot_description = {'robot_description': robot_description_content}
        node_robot_state_publisher = Node(
            package='robot_state_publisher',
            executable='robot_state_publisher',
            output='screen',
            parameters=[robot_description]
        )
        return [node_robot_state_publisher]

    robot_controllers = PathJoinSubstitution(
        [
            FindPackageShare('gz_ros2_control_demos'),
            'config',
            'diff_drive_controller.yaml',
        ]
    )

    # Spawn entity when launching Gazebo ourselves (use_gz=true)
    gz_spawn_entity = Node(
        package='ros_gz_sim',
        executable='create',
        output='screen',
        arguments=['-topic', 'robot_description', '-name',
                   'diff_drive', '-allow_renaming', 'true'],
        condition=IfCondition(use_gz),
    )

    # Spawn entity when Gazebo is already running (use_gz=false) - delayed
    gz_spawn_entity_delayed = Node(
        package='ros_gz_sim',
        executable='create',
        output='screen',
        arguments=['-topic', 'robot_description', '-name',
                   'diff_drive', '-allow_renaming', 'true'],
        condition=UnlessCondition(use_gz),
    )

    # Controller spawners - version for when we launch Gazebo (triggered by spawn)
    joint_state_broadcaster_spawner_triggered = Node(
        package='controller_manager',
        executable='spawner',
        arguments=['joint_state_broadcaster'],
    )
    diff_drive_base_controller_spawner_triggered = Node(
        package='controller_manager',
        executable='spawner',
        arguments=[
            'diff_drive_base_controller',
            '--param-file',
            robot_controllers,
        ],
    )

    # Controller spawners - version for when Gazebo is already running (delayed start)
    joint_state_broadcaster_spawner_delayed = Node(
        package='controller_manager',
        executable='spawner',
        arguments=['joint_state_broadcaster'],
        condition=UnlessCondition(use_gz),
    )
    diff_drive_base_controller_spawner_delayed = Node(
        package='controller_manager',
        executable='spawner',
        arguments=[
            'diff_drive_base_controller',
            '--param-file',
            robot_controllers,
        ],
        condition=UnlessCondition(use_gz),
    )

    # Bridge - only when we launch Gazebo
    bridge = Node(
        package='ros_gz_bridge',
        executable='parameter_bridge',
        arguments=['/clock@rosgraph_msgs/msg/Clock[gz.msgs.Clock'],
        output='screen',
        condition=IfCondition(use_gz),
    )

    # Gazebo launch (conditional)
    gz_launch = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            [PathJoinSubstitution([FindPackageShare('ros_gz_sim'),
                                   'launch',
                                   'gz_sim.launch.py'])]),
        launch_arguments=[('gz_args', [' -r -v 1 empty.sdf'])],
        condition=IfCondition(use_gz)
    )

    ld = LaunchDescription([
        # Launch gazebo environment (optional)
        gz_launch,
        # Bridge (only when launching Gazebo)
        bridge,
        # Spawn entity (when launching Gazebo ourselves)
        gz_spawn_entity,
        # Controller spawners - triggered by gz_spawn_entity completion (when use_gz=true)
        RegisterEventHandler(
            event_handler=OnProcessExit(
                target_action=gz_spawn_entity,
                on_exit=[joint_state_broadcaster_spawner_triggered],
            )
        ),
        RegisterEventHandler(
            event_handler=OnProcessExit(
                target_action=joint_state_broadcaster_spawner_triggered,
                on_exit=[diff_drive_base_controller_spawner_triggered],
            )
        ),
        # Spawn entity + Controller spawners - delayed start (when use_gz=false)
        # Use TimerAction to give time for Gazebo and robot_state_publisher to be ready
        TimerAction(
            period=2.0,
            actions=[
                gz_spawn_entity_delayed,
            ],
            condition=UnlessCondition(use_gz),
        ),
        TimerAction(
            period=4.0,
            actions=[
                joint_state_broadcaster_spawner_delayed,
            ],
            condition=UnlessCondition(use_gz),
        ),
        TimerAction(
            period=6.0,
            actions=[
                diff_drive_base_controller_spawner_delayed,
            ],
            condition=UnlessCondition(use_gz),
        ),
        # Launch Arguments
        DeclareLaunchArgument(
            'use_sim_time',
            default_value=use_sim_time,
            description='If true, use simulated clock'),
        DeclareLaunchArgument(
            'description_format',
            default_value='urdf',
            description='Robot description format to use, urdf or sdf'),
        DeclareLaunchArgument(
            'use_gz',
            default_value='true',
            description='If true, launch Gazebo. Set to false when Gazebo is already running.'),
    ])
    ld.add_action(OpaqueFunction(function=robot_state_publisher))
    return ld
