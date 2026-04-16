#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
load_config

DEEP=0
if [[ "${1:-}" == "--deep" ]]; then
  DEEP=1
fi

"$SCRIPT_DIR/stop.sh" || true

log "Removing runtime state: $RUNTIME_DIR"
rm -rf "$RUNTIME_DIR"

log "Removing session logs under: $LOG_DIR"
rm -rf "$LOG_DIR"

log "Removing temp logs"
rm -f /tmp/qgc_tmux.log /tmp/qgc*.log 2>/dev/null || true

if [[ "$REMOVE_PX4_BUILD" == "1" ]]; then
  log "Removing PX4 SITL build dir"
  rm -rf "$PX4_DIR/build/px4_sitl_default"
fi

if [[ "$DEEP" == "1" ]]; then
  log "Running deep clean"
  if [[ -d "$PX4_DIR" ]]; then
    (cd "$PX4_DIR" && make distclean) || true
  fi

  if [[ "$REMOVE_GZ_CACHE" == "1" ]]; then
    log "Removing Gazebo cache/config"
    rm -rf "$HOME/.gz" "$HOME/.ignition" "$HOME/.cache/gazebo" "$HOME/.cache/ignition" 2>/dev/null || true
  fi

  if [[ "$REMOVE_QGC_CACHE" == "1" ]]; then
    log "Removing QGroundControl cache/config"
    rm -rf "$HOME/.config/QGroundControl.org" "$HOME/.cache/QGroundControl.org" 2>/dev/null || true
  fi

  if [[ "$REMOVE_ROS_LOG" == "1" ]]; then
    log "Removing ROS logs"
    rm -rf "$HOME/.ros/log" 2>/dev/null || true
  fi
fi

log "Cache cleanup done. Use --deep for distclean and optional app caches."
