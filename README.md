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

## Repository Structure

```
~/PX4_pro/
├── .git/                          # Git repository
├── .gitignore
├── LICENSE
├── README.md
├── PROJECT_STRUCTURE.md           # This file
│
├── px4_ros2_ws/                  # ROS 2 workspace
│   └── src/
│       └── my_px4_offboard/      # Custom offboard control package
│           ├── my_px4_offboard/
│           │   ├── __init__.py
│           │   ├── offboard_takeoff_hover.py   # Takeoff & hover control
│           │   └── offboard_trajectory.py      # Trajectory following control
│           └── package.xml
│
├── px4sh/                        # Session management scripts
│   ├── start.sh                  # Start full simulation session
│   ├── stop.sh                   # Stop all services
│   ├── restart.sh                # Restart services
│   ├── status.sh                 # Check running services
│   ├── status_check.sh           # Detailed status check
│   ├── common.sh                 # Shared functions & path resolution
│   ├── stream_log.sh             # Log streaming & filtering
│   ├── read_logs.sh              # Read session logs
│   ├── show_alert_context.sh     # Show alert context
│   ├── clean_cache.sh            # Clean caches
│   ├── px4ctl.sh                 # PX4 control utility
│   ├── px4_live_position_plotter.py  # 3D trajectory visualization
│   ├── config.env                 # Local configuration (not committed)
│   ├── config.env.example        # Configuration template
│   ├── docs/                     # Documentation
│   ├── README.md                 # Scripts documentation
│   └── 会话.md                   # Chinese documentation
│
├── px4_session_logs/             # Session logs (committed)
│   └── YYYY-MM-DD_HH-MM-SS/     # Timestamped session directories
│       ├── px4.log               # PX4 full log
│       ├── px4.alerts.log        # PX4 alerts
│       ├── px4.summary.log       # PX4 summary
│       ├── agent.log             # DDS Agent log
│       ├── agent.alerts.log      # Agent alerts
│       ├── agent.summary.log     # Agent summary
│       ├── qgc.log               # QGC log
│       ├── qgc.alerts.log        # QGC alerts
│       ├── qgc.summary.log       # QGC summary
│       ├── ros_app.log           # ROS app log
│       ├── ros_app.alerts.log    # ROS app alerts
│       └── ros_app.summary.log   # ROS app summary
│
├── .px4_one_click/               # Runtime metadata
├── patch/                        # Patches for reference
├── Micro-XRCE-DDS-Agent/         # External DDS agent (cloned)
└── Documents/                    # QGroundControl data
    └── QGroundControl/
        ├── CrashLogs/
        ├── Logs/
        ├── Missions/
        ├── Parameters/
        ├── Photo/
        └── Telemetry/
```

## Quick Start

### 1. Setup Environment

Copy the configuration template:
```bash
cp px4sh/config.env.example px4sh/config.env
```

Edit `px4sh/config.env` to match your local paths:
- `PX4_DIR`: Path to your PX4-Autopilot repository (e.g., `~/PX4-Autopilot`)
- `ROS_WS`: Path to your ROS 2 workspace (e.g., `~/PX4_pro/px4_ros2_ws`)
- Adjust any other paths as needed

### 2. Build ROS 2 Package

```bash
cd px4_ros2_ws
colcon build
source install/local_setup.bash
```

### 3. Start Session

Run the startup script:
```bash
./px4sh/start.sh
```

This will start:
1. Micro-XRCE-DDS Agent
2. PX4 with Gazebo simulation
3. QGroundControl
4. ROS 2 offboard control node

### 4. Stop Session

```bash
./px4sh/stop.sh
```

## Available Scripts

### px4sh/start.sh
Starts the complete simulation session with all services (MicroXRCEAgent → PX4/Gazebo → QGC → ROS).

### px4sh/stop.sh
Stops all running services and cleans up the session.

### px4sh/restart.sh
Restarts the simulation session.

### px4sh/status.sh
Checks the status of all running services.

### px4sh/read_logs.sh
Reads and displays session logs.

### px4sh/show_alert_context.sh
Shows context around alerts in logs.

### px4sh/stream_log.sh
Streams live logs from the session.

### px4sh/clean_cache.sh
Cleans up temporary files and caches.

## Configuration

Edit `px4sh/config.env` to customize:
- Session name and paths
- Simulator settings (HEADLESS, Gazebo GUI)
- ROS 2 settings (ROS_DISTRO, OFFBOARD_CMD)
- Timing delays between service starts
- Log directories and cleanup behavior

## Custom Offboard Control

The `my_px4_offboard` package contains example offboard control implementations:
- `offboard_takeoff_hover.py`: Basic takeoff and hover control
- `offboard_trajectory.py`: Trajectory following control

## License

This project is provided as-is for educational and development purposes.

## Contributing

When contributing:
1. Keep the repository focused on your custom code
2. Do not include third-party dependencies (px4_msgs, px4_ros_com, etc.)
3. Document any new scripts in px4sh/
4. Update config.env.example if adding new configuration options