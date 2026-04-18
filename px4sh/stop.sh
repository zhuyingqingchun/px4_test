#!/usr/bin/env bash
set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
load_config

SESSION_NAME="${SESSION_NAME:-px4_stack}"

session_was_running=0
if session_exists; then
  session_was_running=1
  log "Killing tmux session: $SESSION_NAME"
  tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true
else
  log "No tmux session running: $SESSION_NAME (will still clean remaining processes)"
fi

if [[ -f "$RUNTIME_DIR/qgc.pid" ]]; then
  kill "$(cat "$RUNTIME_DIR/qgc.pid")" 2>/dev/null || true
  rm -f "$RUNTIME_DIR/qgc.pid" 2>/dev/null || true
fi

cleanup_pattern "Gazebo GUI" "gz sim -g|gz gui|gzclient"
cleanup_pattern "Gazebo server" "gz sim|gzserver|ign gazebo"
cleanup_pattern "PX4" "px4_sitl_default/bin/px4|[ /]px4([[:space:]]|$)"
cleanup_pattern "Micro XRCE-DDS Agent" "MicroXRCEAgent|micro-xrce-dds-agent"
cleanup_pattern "QGroundControl" "QGroundControl"
cleanup_pattern "ROS offboard app" "my_px4_offboard|offboard_takeoff_hover|offboard_trajectory"

if [[ "$session_was_running" == "0" && -f "$RUNTIME_DIR/session.meta" ]]; then
  rm -f "$RUNTIME_DIR/session.meta" 2>/dev/null || true
fi

echo "Stopped PX4 / Agent / ROS / QGC session."