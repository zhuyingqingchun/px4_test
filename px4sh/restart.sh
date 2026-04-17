#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/stop.sh" || true

wait_process_gone() {
  local pattern="$1"
  local timeout="${2:-10}"

  for ((i=0; i<timeout; ++i)); do
    if ! pgrep -fa "$pattern" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

# Give Gazebo / PX4 a chance to exit fully before starting again.
wait_process_gone "gz sim|gzserver|ign gazebo" 10 || true
wait_process_gone "px4_sitl_default/bin/px4|[ /]px4([[:space:]]|$)" 10 || true
wait_process_gone "MicroXRCEAgent|micro-xrce-dds-agent" 10 || true
wait_process_gone "QGroundControl" 5 || true

# Small final settle delay for child-process teardown.
sleep 1

exec "$SCRIPT_DIR/start.sh"
