#!/usr/bin/env bash
set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
load_config
ensure_prereqs

SESSION_NAME="${SESSION_NAME:-px4_stack}"
LOG_TERMINAL_MODE="${LOG_TERMINAL_MODE:-concise}"
GZ_MODE="${GZ_MODE:-managed}"
HEADLESS="${HEADLESS:-0}"
ENABLE_AGENT="${ENABLE_AGENT:-1}"
ENABLE_QGC="${ENABLE_QGC:-0}"
ENABLE_ROS="${ENABLE_ROS:-1}"
PX4_READY_TIMEOUT="${PX4_READY_TIMEOUT:-120}"
AGENT_START_WAIT_SECONDS="${AGENT_START_WAIT_SECONDS:-2}"
QGC_SETTLE_SECONDS="${QGC_SETTLE_SECONDS:-4}"
DEFAULT_ATTACH_WINDOW="${DEFAULT_ATTACH_WINDOW:-px4}"
PX4_STDIN_MODE="${PX4_STDIN_MODE:-null}"
DETECT_EXISTING_GZ="${DETECT_EXISTING_GZ:-1}"
FAIL_ON_EXISTING_GZ_IN_MANAGED="${FAIL_ON_EXISTING_GZ_IN_MANAGED:-1}"

: "${PX4_DIR:?PX4_DIR is required}"
: "${PX4_TARGET:?PX4_TARGET is required}"
: "${LOG_DIR:?LOG_DIR is required}"
: "${SCRIPT_DIR:?SCRIPT_DIR is required}"

STREAM_FILTER="${SCRIPT_DIR}/stream_log.sh"
PX4_READY_REGEX="${PX4_READY_REGEX:-Ready for takeoff|Startup script returned successfully|home set}"

if session_exists; then
  log "tmux session already exists: $SESSION_NAME"
  exec tmux attach -t "$SESSION_NAME"
fi

gz_process_running() {
  pgrep -fa '(^|/)(gz|gazebo)([[:space:]]|$)|ign[[:space:]]+gazebo|gz[[:space:]]+sim' >/dev/null 2>&1
}

show_existing_gz_processes() {
  pgrep -fa '(^|/)(gz|gazebo)([[:space:]]|$)|ign[[:space:]]+gazebo|gz[[:space:]]+sim' || true
}

preflight_check_gz_mode() {
  if [[ "$DETECT_EXISTING_GZ" != "1" ]]; then
    return 0
  fi

  if [[ "$GZ_MODE" == "managed" ]] && gz_process_running; then
    log "[WARN] Detected existing Gazebo-related process(es) before startup:"
    show_existing_gz_processes
    if [[ "$FAIL_ON_EXISTING_GZ_IN_MANAGED" == "1" ]]; then
      log "[ERROR] GZ_MODE=managed means PX4 will manage Gazebo itself."
      log "[ERROR] Stop the existing Gazebo first, or switch to GZ_MODE=standalone."
      exit 1
    fi
  fi
}

make_wrapped_cmd() {
  local tag="$1"
  local raw="$2"
  local logfile="$3"
  local alertfile="$4"
  local summaryfile="$5"
  local stdin_mode="${6:-inherit}"
  local shell_cmd="$raw 2>&1 | '$STREAM_FILTER' '$tag' '$logfile' '$alertfile' '$summaryfile' '$LOG_TERMINAL_MODE'"

  if [[ "$stdin_mode" == "null" ]]; then
    shell_cmd="$raw </dev/null 2>&1 | '$STREAM_FILTER' '$tag' '$logfile' '$alertfile' '$summaryfile' '$LOG_TERMINAL_MODE'"
  fi

  printf 'bash -lc %q' "$shell_cmd"
}

wait_for_pattern() {
  local file="$1"
  local regex="$2"
  local timeout="${3:-60}"
  local label="${4:-$file}"

  local start_ts now_ts
  start_ts="$(date +%s)"

  while true; do
    if [[ -f "$file" ]] && grep -Eq "$regex" "$file"; then
      log "[OK] $label"
      return 0
    fi

    now_ts="$(date +%s)"
    if (( now_ts - start_ts > timeout )); then
      log "[ERROR] Timeout waiting for: $label"
      log "[ERROR] file=$file regex=$regex"
      return 1
    fi
    sleep 1
  done
}

tmux_new_or_select_window() {
  local name="$1"
  if tmux list-windows -t "$SESSION_NAME" -F '#W' | grep -qx "$name"; then
    tmux select-window -t "$SESSION_NAME:$name"
  else
    tmux new-window -t "$SESSION_NAME" -n "$name"
  fi
}

tmux_run_in_window() {
  local name="$1"
  local cmd="$2"
  tmux_new_or_select_window "$name"
  tmux send-keys -t "$SESSION_NAME:$name" "$cmd" C-m
}

preflight_check_gz_mode

STAMP="$(date +%F_%H-%M-%S)"
THIS_LOG_DIR="$LOG_DIR/$STAMP"
mkdir -p "$THIS_LOG_DIR"
write_runtime_meta "$STAMP"

PX4_BASE_CMD="cd '$PX4_DIR' && "
GZ_OWNER_DESC=""

case "$GZ_MODE" in
  managed)
    if [[ "$HEADLESS" == "1" ]]; then
      PX4_BASE_CMD+="HEADLESS=1 "
    fi
    PX4_BASE_CMD+="make px4_sitl $PX4_TARGET"
    GZ_OWNER_DESC="PX4 managed (make px4_sitl $PX4_TARGET)"
    GZ_SERVER_CMD_LINE=""
    ;;
  standalone)
    GZ_SERVER_CMD="${GZ_SERVER_CMD:-}"
    if [[ -z "$GZ_SERVER_CMD" ]]; then
      log "[ERROR] GZ_MODE=standalone requires GZ_SERVER_CMD"
      exit 1
    fi
    PX4_BASE_CMD+="PX4_GZ_STANDALONE=1 make px4_sitl $PX4_TARGET"
    GZ_OWNER_DESC="external standalone command"
    GZ_SERVER_CMD_LINE="$(make_wrapped_cmd \
      "gz" \
      "$GZ_SERVER_CMD" \
      "$THIS_LOG_DIR/gz.log" \
      "$THIS_LOG_DIR/gz.alerts.log" \
      "$THIS_LOG_DIR/gz.summary.log")"
    ;;
  *)
    log "[ERROR] Unsupported GZ_MODE: $GZ_MODE"
    exit 1
    ;;
esac

PX4_CMD_LINE="$(make_wrapped_cmd \
  "px4" \
  "$PX4_BASE_CMD" \
  "$THIS_LOG_DIR/px4.log" \
  "$THIS_LOG_DIR/px4.alerts.log" \
  "$THIS_LOG_DIR/px4.summary.log" \
  "$PX4_STDIN_MODE")"

AGENT_CMD_LINE=""
if [[ "$ENABLE_AGENT" == "1" && -n "${AGENT_CMD:-}" ]]; then
  AGENT_CMD_LINE="$(make_wrapped_cmd \
    "agent" \
    "$AGENT_CMD ${AGENT_ARGS:-}" \
    "$THIS_LOG_DIR/agent.log" \
    "$THIS_LOG_DIR/agent.alerts.log" \
    "$THIS_LOG_DIR/agent.summary.log")"
fi

ROS_ENV_CMD="source '/opt/ros/${ROS_DISTRO:-jazzy}/setup.bash'"
if [[ -n "${ROS_SETUP_EXTRA:-}" ]]; then
  ROS_ENV_CMD+=" && ${ROS_SETUP_EXTRA}"
fi
if [[ -f "$ROS_WS/install/setup.bash" ]]; then
  ROS_ENV_CMD+=" && source '$ROS_WS/install/setup.bash'"
elif [[ -f "$ROS_WS/install/local_setup.bash" ]]; then
  ROS_ENV_CMD+=" && source '$ROS_WS/install/local_setup.bash'"
elif [[ "$ENABLE_ROS" == "1" ]]; then
  log "[WARN] ROS workspace setup not found under: $ROS_WS/install"
fi

ROS_CMD_LINE=""
if [[ "$ENABLE_ROS" == "1" && -n "${OFFBOARD_CMD:-}" ]]; then
  ROS_CMD_LINE="$(make_wrapped_cmd \
    "ros" \
    "$ROS_ENV_CMD && ${OFFBOARD_CMD}" \
    "$THIS_LOG_DIR/ros_app.log" \
    "$THIS_LOG_DIR/ros_app.alerts.log" \
    "$THIS_LOG_DIR/ros_app.summary.log")"
fi

QGC_CMD_LINE=""
if [[ "$ENABLE_QGC" == "1" ]]; then
  if [[ -n "${QGC_APPIMAGE:-}" && -x "$QGC_APPIMAGE" ]]; then
    QGC_CMD_LINE="$(make_wrapped_cmd \
      "qgc" \
      "${QGC_ENV:-} '$QGC_APPIMAGE'" \
      "$THIS_LOG_DIR/qgc.log" \
      "$THIS_LOG_DIR/qgc.alerts.log" \
      "$THIS_LOG_DIR/qgc.summary.log")"
  else
    log "[WARN] ENABLE_QGC=1 but QGC_APPIMAGE is missing or not executable"
  fi
fi

log "[INFO] Project root: $PROJECT_ROOT"
log "[INFO] Resolved PX4_DIR: $PX4_DIR"
log "[INFO] Resolved ROS_WS: $ROS_WS"
log "[INFO] Logs dir: $LOG_DIR"
log "[INFO] Gazebo startup mode: $GZ_MODE"
log "[INFO] Gazebo owner: $GZ_OWNER_DESC"

tmux new-session -d -s "$SESSION_NAME" -n px4
tmux set-option -t "$SESSION_NAME" remain-on-exit on >/dev/null
tmux set-option -t "$SESSION_NAME" history-limit 20000 >/dev/null

if [[ -n "$AGENT_CMD_LINE" ]]; then
  tmux_run_in_window "agent" "$AGENT_CMD_LINE"
  if (( AGENT_START_WAIT_SECONDS > 0 )); then
    sleep "$AGENT_START_WAIT_SECONDS"
  fi
fi

if [[ -n "$GZ_SERVER_CMD_LINE" ]]; then
  tmux_run_in_window "gz" "$GZ_SERVER_CMD_LINE"
  sleep 2
fi

tmux_run_in_window "px4" "$PX4_CMD_LINE"
wait_for_pattern "$THIS_LOG_DIR/px4.summary.log" "$PX4_READY_REGEX" "$PX4_READY_TIMEOUT" "PX4 ready"

if [[ -n "$QGC_CMD_LINE" ]]; then
  tmux_run_in_window "qgc" "$QGC_CMD_LINE"
  sleep "$QGC_SETTLE_SECONDS"
fi

if [[ -n "$ROS_CMD_LINE" ]]; then
  tmux_run_in_window "ros" "$ROS_CMD_LINE"
fi

if tmux list-windows -t "$SESSION_NAME" -F '#W' | grep -qx "$DEFAULT_ATTACH_WINDOW"; then
  tmux select-window -t "$SESSION_NAME:$DEFAULT_ATTACH_WINDOW"
else
  tmux select-window -t "$SESSION_NAME:px4"
fi

log "Session created: $SESSION_NAME"
log "Logs: $THIS_LOG_DIR"
exec tmux attach -t "$SESSION_NAME"
