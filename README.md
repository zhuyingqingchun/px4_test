# PX4 Offboard Control with ROS 2

This repository contains custom PX4 offboard control implementations and session management scripts for PX4 + ROS 2 + Gazebo simulations.

## Prerequisites

### Required Software
- Ubuntu Linux (tested on 22.04/24.04)
- ROS 2 Jazzy (or compatible version)
- Gazebo (Ignition/Fortress)
- QGroundControl
- Micro-XRCE-DDS Agent

### External Dependencies (Must be cloned manually)

This repository **does not include** the following dependencies (as they are maintained separately):

1. **px4_msgs**: PX4 ROS 2 message definitions
   - Clone from: https://github.com/PX4/px4_msgs
   - Place in: `px4_ros2_ws/src/px4_msgs/`

2. **px4_ros_com**: PX4 ROS 2 communication examples
   - Clone from: https://github.com/PX4/px4_ros_com
   - Place in: `px4_ros2_ws/src/px4_ros_com/`

3. **PX4-Autopilot**: PX4 flight controller
   - Clone from: https://github.com/PX4/PX4-Autopilot
   - Place in: `~/PX4-Autopilot/` (or update `PX4_DIR` in config.env)

4. **gz_ros2_control**: Gazebo ROS 2 Control (for UGV simulation)
   - Clone from: https://github.com/ros-controls/gz_ros2_control.git (jazzy branch)
   - Place in: `px4_ros2_ws/src/gz_ros2_control/`

5. **ros2_control_demos**: ROS 2 Control Demos (for DiffBot)
   - Clone from: https://github.com/ros-controls/ros2_control_demos.git (jazzy branch)
   - Place in: `px4_ros2_ws/src/ros2_control_demos/`
   - Use `vcs import` with `patch/ugv_open_source.repos`

## Repository Structure

```
~/PX4_pro/
├── .git/                          # Git repository
├── .gitignore
├── LICENSE
├── README.md                      # This file
├── PROJECT_STRUCTURE.md           # Project structure documentation
│
├── px4_ros2_ws/                   # ROS 2 workspace
│   └── src/
│       ├── my_px4_offboard/       # UAV offboard control package
│       │   ├── my_px4_offboard/
│       │   │   ├── __init__.py
│       │   │   ├── standard_mission_node.py    # Main mission executor
│       │   │   ├── mission_executor.py         # Mission execution logic
│       │   │   ├── offboard_state_machine.py   # State machine implementation
│       │   │   ├── trajectory_library.py       # Trajectory generation
│       │   │   ├── px4_state_monitor.py        # PX4 state monitoring
│       │   │   ├── safety_guard.py             # Safety checks
│       │   │   ├── offboard_takeoff_hover.py   # Basic takeoff & hover
│       │   │   └── offboard_trajectory.py      # Trajectory following
│       │   ├── config/
│       │   │   ├── hover.yaml                  # Hover mission config
│       │   │   └── square.yaml                 # Square trajectory config
│       │   ├── launch/
│       │   │   └── offboard_standard_mission.launch.py
│       │   ├── test/
│       │   │   └── test_trajectory_library.py
│       │   ├── package.xml
│       │   ├── setup.py
│       │   └── README_standard_mission.md
│       │
│       ├── air_ground_playground/ # Air-ground coordination (UAV + UGV)
│       │   ├── air_ground_playground/
│       │   │   ├── __init__.py
│       │   │   └── ground_robot_commander.py   # UGV command publisher
│       │   ├── config/
│       │   │   ├── rover_square.yaml           # UGV square trajectory
│       │   │   └── rover_out_and_back.yaml     # UGV out-and-back trajectory
│       │   ├── launch/
│       │   │   ├── air_ground_minimal.launch.py         # UAV+UGV together
│       │   │   ├── vendor_diffbot_only.launch.py        # UGV only (mock)
│       │   │   └── air_ground_with_vendor_diffbot.launch.py
│       │   ├── scripts/
│       │   │   └── fetch_vendor_diffbot.sh     # Fetch external deps script
│       │   ├── resource/
│       │   ├── package.xml
│       │   ├── setup.py
│       │   └── README_minimal_platform.md
│       │
│       ├── external/              # External dependencies (not in git)
│       │   ├── ugv_open_source.repos           # vcs import manifest
│       │   └── README_external_dependencies.md
│       │
│       ├── gz_ros2_control/       # External: Gazebo ROS 2 Control
│       └── ros2_control_demos/    # External: ROS 2 Control Demos (DiffBot)
│
├── px4sh/                         # Session management scripts
│   ├── start.sh                   # Start simulation session
│   ├── stop.sh                    # Stop all services
│   ├── restart.sh                 # Restart services
│   ├── common.sh                  # Shared functions & tmux management
│   ├── config.env                 # Local configuration
│   ├── logs/                      # Session logs
│   │   └── archive/
│   └── README_minimal.md
│
├── patch/                         # Patch files and documentation
│   ├── ugv_open_source.repos
│   ├── fetch_vendor_diffbot.sh
│   ├── px4_test_第16轮_接入真实开源差速小车模型补丁方案.md
│   └── ...
│
├── px4_session_logs/              # Session logs (committed)
├── .px4_minimal_run/              # Runtime metadata
└── Micro-XRCE-DDS-Agent/          # External DDS agent (cloned)
```

## Quick Start

### 1. Setup Environment

Edit `px4sh/config.env` to match your local paths:
- `PX4_DIR`: Path to your PX4-Autopilot repository (e.g., `~/PX4-Autopilot`)
- `ROS_WS`: Path to your ROS 2 workspace (e.g., `~/PX4_pro/px4_ros2_ws`)
- Adjust any other settings as needed

### 2. Build ROS 2 Package

```bash
cd px4_ros2_ws
colcon build
source install/local_setup.bash
```

### 3. Start QGroundControl (Manual)

Open QGroundControl once and keep it running:
```bash
~/QGroundControl-x86_64.AppImage
```

### 4. Start Simulation Session

Run the startup script:
```bash
./px4sh/start.sh
```

This will start in a tmux session:
1. Micro-XRCE-DDS Agent
2. PX4 with Gazebo simulation
3. ROS 2 offboard control node

### 5. Stop Session

```bash
./px4sh/stop.sh
```

## tmux Session Management

The scripts use tmux for terminal management:

### tmux Operations
- **Switch windows**: `Ctrl-b` + number (0 for shell, 1 for agent, 2 for px4, 3 for ros)
- **Mouse support**: Enabled by default
  - Click to switch windows
  - Scroll to view history
- **Reattach to session**: `tmux attach -t px4_stack`

## Available Scripts

### px4sh/start.sh
Starts the simulation session in a tmux session (Agent → PX4/Gazebo → ROS).

### px4sh/stop.sh
Stops all running services and cleans up the session.

### px4sh/restart.sh
Restarts the simulation session.

## Configuration

Edit `px4sh/config.env` to customize:
- Session name and paths
- Simulator settings (HEADLESS, Gazebo GUI)
- ROS 2 settings (ROS_DISTRO, OFFBOARD_CMD)
- Timing delays between service starts

Key configuration:
- `ENABLE_QGC=0` - QGC is not managed by scripts (run manually)
- `ENABLE_ROS=1` - ROS offboard control enabled by default
- `ENABLE_AGENT=1` - MicroXRCEAgent enabled by default

## Custom Offboard Control

The `my_px4_offboard` package contains example offboard control implementations:
- `offboard_takeoff_hover.py`: Basic takeoff and hover control
- `offboard_trajectory.py`: Trajectory following control
- `standard_mission_node.py`: Full mission executor with state machine

## Air-Ground Coordination

The `air_ground_playground` package provides multi-robot coordination:
- **UAV**: PX4-based drone with offboard control
- **UGV**: DiffBot differential drive robot with ros2_control

### Launch Options

```bash
# UAV + UGV together (default)
ros2 launch air_ground_playground air_ground_minimal.launch.py

# UGV only (DiffBot with ros2_control)
ros2 launch air_ground_playground vendor_diffbot_only.launch.py

# Custom UGV trajectory
ros2 launch air_ground_playground air_ground_minimal.launch.py ugv_config:=config/rover_square.yaml
```

## License

This project is provided as-is for educational and development purposes.

## Contributing

When contributing:
1. Keep the repository focused on your custom code
2. Do not include third-party dependencies (px4_msgs, px4_ros_com, etc.)
3. Document any new scripts in px4sh/
4. Update config.env if adding new configuration options