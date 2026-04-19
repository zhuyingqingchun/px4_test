#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

load_config
ensure_prereqs

if session_exists; then
  log "[WARN] tmux session already exists: $SESSION_NAME"
  exec tmux attach -t "$SESSION_NAME"
fi

log "[INFO] Project root: $PROJECT_ROOT"
log "[INFO] PX4_DIR: $PX4_DIR"
log "[INFO] ROS_WS: $ROS_WS"
log "[INFO] Session: $SESSION_NAME"
log "[INFO] QGC is NOT managed by this script"

tmux new-session -d -s "$SESSION_NAME" -n shell
tmux set-option -t "$SESSION_NAME" remain-on-exit on >/dev/null
tmux set-option -t "$SESSION_NAME" history-limit 50000 >/dev/null
tmux set-option -t "$SESSION_NAME" mouse on >/dev/null

if [[ "$ENABLE_AGENT" == "1" ]]; then
  tmux_run_in_window "agent" "cd '$PROJECT_ROOT' && exec '$AGENT_CMD' ${AGENT_ARGS}"
  sleep "$AGENT_START_WAIT_SECONDS"
fi

PX4_CMD="cd '$PX4_DIR' && "
if [[ "$HEADLESS" == "1" ]]; then
  PX4_CMD+="HEADLESS=1 "
fi
PX4_CMD+="exec make px4_sitl '$PX4_TARGET'"
tmux_run_in_window "px4" "$PX4_CMD"

wait_for_process 'px4_sitl_default/bin/px4|[ /]px4([[:space:]]|$)' "$PX4_PROCESS_WAIT_SECONDS" "PX4 process"
wait_for_process 'gz[[:space:]]+sim|gzserver|ign[[:space:]]+gazebo' "$GZ_PROCESS_WAIT_SECONDS" "Gazebo process"

sleep "$PX4_STABILIZE_WAIT_SECONDS"

if [[ "$ENABLE_ROS" == "1" ]]; then
  ROS_CMD="source '/opt/ros/$ROS_DISTRO/setup.bash'"
  if [[ -n "$ROS_SETUP_EXTRA" ]]; then
    ROS_CMD+=" && $ROS_SETUP_EXTRA"
  fi
  if [[ -f "$ROS_WS/install/setup.bash" ]]; then
    ROS_CMD+=" && source '$ROS_WS/install/setup.bash'"
  else
    ROS_CMD+=" && source '$ROS_WS/install/local_setup.bash'"
  fi
  ROS_CMD+=" && exec $OFFBOARD_CMD"
  tmux_run_in_window "ros" "$ROS_CMD"
  sleep "$ROS_START_WAIT_SECONDS"
fi

if tmux_window_exists "$DEFAULT_ATTACH_WINDOW"; then
  tmux select-window -t "$SESSION_NAME:$DEFAULT_ATTACH_WINDOW"
fi

log "[OK] start sequence finished"
exec tmux attach -t "$SESSION_NAME"