#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

load_config

log "[INFO] stopping session: $SESSION_NAME"
log "[INFO] QGC is NOT managed by this script"

if session_exists; then
  tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true
fi

cleanup_pattern "ROS offboard app" "offboard_trajectory|offboard_takeoff_hover|ros2 run my_px4_offboard"
cleanup_pattern "Micro XRCE-DDS Agent" "MicroXRCEAgent|micro-xrce-dds-agent"
cleanup_pattern "PX4" "px4_sitl_default/bin/px4|[ /]px4([[:space:]]|$)"
cleanup_pattern "Gazebo GUI" "gz[[:space:]]+sim[[:space:]]+-g|gz[[:space:]]+gui|gzclient"
cleanup_pattern "Gazebo server" "gz[[:space:]]+sim|gzserver|ign[[:space:]]+gazebo"

log "[OK] stop sequence finished"