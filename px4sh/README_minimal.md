Minimal tmux-based PX4 scripts, no custom logging system.

Files:
- start.sh
- stop.sh
- restart.sh
- common.sh
- config.env

Default behavior:
- Agent ON
- QGC ON
- ROS offboard ON

Startup order:
1. Agent
2. PX4 + Gazebo
3. Wait for PX4 and Gazebo processes
4. Stabilization delay
5. QGC
6. ROS offboard

Usage:
  cd ~/PX4_pro/px4sh
  ./start.sh
  ./stop.sh
  ./restart.sh

tmux tips:
- Reattach later: tmux attach -t px4_stack
- Switch windows: Ctrl-b then window number / n / p
- Scrollback: Ctrl-b then [ , then use arrows/PageUp, press q to quit
