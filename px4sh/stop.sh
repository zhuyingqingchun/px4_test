#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
load_config

if ! session_exists; then
  log "No tmux session running: $SESSION_NAME"
  echo "Stopped PX4/Agent/QGC/ROS session."
  exit 0
fi

log "Killing tmux session: $SESSION_NAME"
tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true

# Kill Gazebo GUI processes
log "Killing Gazebo GUI processes..."
pkill -f "gz sim -g" 2>/dev/null || true
pkill -f "gz gui" 2>/dev/null || true

# Kill remaining PX4/Gazebo processes if any
pkill -f "px4_sitl_default/bin/px4" 2>/dev/null || true
pkill -f "gz sim.*-s" 2>/dev/null || true
pkill -f "gz sim" 2>/dev/null || true
pkill -f "ign gazebo" 2>/dev/null || true
pkill -f "MicroXRCEAgent" 2>/dev/null || true
pkill -f "micro-xrce-dds-agent" 2>/dev/null || true
pkill -f "QGroundControl" 2>/dev/null || true

echo "Stopped PX4/Agent/QGC/ROS session."
