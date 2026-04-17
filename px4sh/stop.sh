#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
load_config

session_was_running=0
if session_exists; then
  session_was_running=1
  log "Killing tmux session: $SESSION_NAME"
  tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true
else
  log "No tmux session running: $SESSION_NAME (will still clean remaining processes)"
fi

cleanup_pattern() {
  local name="$1"
  local pattern="$2"

  if pgrep -fa "$pattern" >/dev/null 2>&1; then
    log "Stopping $name ..."
    pkill -TERM -f "$pattern" 2>/dev/null || true

    for _ in 1 2 3 4 5; do
      if ! pgrep -fa "$pattern" >/dev/null 2>&1; then
        return 0
      fi
      sleep 1
    done

    log "[WARN] $name still running after SIGTERM, sending SIGKILL"
    pkill -KILL -f "$pattern" 2>/dev/null || true
  fi
}

# Kill Gazebo / PX4 / Agent / QGC processes even when tmux session is gone.
# This is important for restart flows: a missing tmux session should not skip cleanup.
cleanup_pattern "Gazebo GUI" "gz sim -g|gz gui|gzclient"
cleanup_pattern "Gazebo server" "gz sim|gzserver|ign gazebo"
cleanup_pattern "PX4" "px4_sitl_default/bin/px4|[ /]px4([[:space:]]|$)"
cleanup_pattern "Micro XRCE-DDS Agent" "MicroXRCEAgent|micro-xrce-dds-agent"
cleanup_pattern "QGroundControl" "QGroundControl"

# Clear any stale runtime metadata from a dead session.
if [[ "$session_was_running" == "0" && -f "$RUNTIME_DIR/session.meta" ]]; then
  rm -f "$RUNTIME_DIR/session.meta" 2>/dev/null || true
fi

echo "Stopped PX4/Agent/QGC/ROS session."
