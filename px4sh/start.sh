#!/usr/bin/env bash
set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
load_config
ensure_prereqs

# -----------------------------
# 用户可配参数（可在 common.sh / config 覆盖）
# -----------------------------
SESSION_NAME="${SESSION_NAME:-px4_stack}"
TMUX_LAYOUT="${TMUX_LAYOUT:-windows}"     # 当前版本只实现 windows，优先稳定性
LOG_TERMINAL_MODE="${LOG_TERMINAL_MODE:-concise}"

# Gazebo 启动模式：
#   managed    -> 由 `make px4_sitl ...` 管理 Gazebo
#   standalone -> 由你单独提供 GZ_SERVER_CMD 启动 Gazebo，PX4 用 PX4_GZ_STANDALONE=1 连接
GZ_MODE="${GZ_MODE:-managed}"

# Gazebo 进程防呆：
# 在 managed 模式下，如果系统里已经有 Gazebo / gz sim / ign gazebo 相关进程，
# 默认直接报错退出，防止"手动起了一次，PX4 又再起一次"。
DETECT_EXISTING_GZ="${DETECT_EXISTING_GZ:-1}"
FAIL_ON_EXISTING_GZ_IN_MANAGED="${FAIL_ON_EXISTING_GZ_IN_MANAGED:-1}"

# 仅用于日志展示，方便排查当前到底是谁负责起 Gazebo
GZ_OWNER_DESC=""

# managed 模式下：
#   HEADLESS=0 -> PX4 自己拉起带 GUI 的 Gazebo
#   HEADLESS=1 -> PX4 自己拉起无 GUI 的 Gazebo
HEADLESS="${HEADLESS:-1}"

ENABLE_AGENT="${ENABLE_AGENT:-1}"         # 例如 Micro XRCE-DDS Agent
ENABLE_QGC="${ENABLE_QGC:-1}"
ENABLE_ROS="${ENABLE_ROS:-1}"

PX4_READY_TIMEOUT="${PX4_READY_TIMEOUT:-120}"
QGC_SETTLE_SECONDS="${QGC_SETTLE_SECONDS:-6}"
ROS_TOPIC_WAIT_SECONDS="${ROS_TOPIC_WAIT_SECONDS:-30}"
WAIT_FOR_FMU_TOPICS="${WAIT_FOR_FMU_TOPICS:-1}"

# 你自己的工程变量（通常来自 common.sh）
: "${PX4_DIR:?PX4_DIR is required}"
: "${PX4_TARGET:?PX4_TARGET is required}"
: "${LOG_DIR:?LOG_DIR is required}"
: "${SCRIPT_DIR:?SCRIPT_DIR is required}"

STREAM_FILTER="${SCRIPT_DIR}/stream_log.sh"

# standalone 模式下必须提供：
# 例：
#   GZ_SERVER_CMD="python3 /path/to/simulation-gazebo"
# 官方 standalone 示例就是 PX4_GZ_STANDALONE=1 + 单独启动 simulation-gazebo
# 如果你不用 standalone，可忽略这个变量。
GZ_SERVER_CMD="${GZ_SERVER_CMD:-}"

# DDS/ROS
AGENT_CMD="${AGENT_CMD:-}"
AGENT_ARGS="${AGENT_ARGS:-}"

ROS_DISTRO="${ROS_DISTRO:-humble}"
ROS_WS="${ROS_WS:-}"
ROS_SETUP_EXTRA="${ROS_SETUP_EXTRA:-}"
OFFBOARD_CMD="${OFFBOARD_CMD:-}"

# QGC
QGC_APPIMAGE="${QGC_APPIMAGE:-}"
QGC_ENV="${QGC_ENV:-}"

# PX4 ready 的宽松匹配，适配不同版本日志
PX4_READY_REGEX="${PX4_READY_REGEX:-Ready for takeoff|Startup script returned successfully|home set}"

# -----------------------------
# 基础函数
# -----------------------------
if session_exists; then
  log "tmux session already exists: $SESSION_NAME"
  exec tmux attach -t "$SESSION_NAME"
fi

STAMP="$(date +%F_%H-%M-%S)"
THIS_LOG_DIR="$LOG_DIR/$STAMP"
mkdir -p "$THIS_LOG_DIR"
write_runtime_meta "$STAMP"

make_wrapped_cmd() {
  local tag="$1"
  local raw="$2"
  local logfile="$3"
  local alertfile="$4"
  local summaryfile="$5"

  printf 'bash -lc %q' \
    "$raw 2>&1 | '$STREAM_FILTER' '$tag' '$logfile' '$alertfile' '$summaryfile' '$LOG_TERMINAL_MODE'"
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

wait_for_cmd() {
  local cmd="$1"
  local timeout="${2:-60}"
  local label="${3:-command}"

  local start_ts now_ts
  start_ts="$(date +%s)"

  while true; do
    if bash -lc "$cmd" >/dev/null 2>&1; then
      log "[OK] $label"
      return 0
    fi

    now_ts="$(date +%s)"
    if (( now_ts - start_ts > timeout )); then
      log "[ERROR] Timeout waiting for: $label"
      log "[ERROR] cmd=$cmd"
      return 1
    fi
    sleep 1
  done
}

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

# -----------------------------
# 组装命令
# -----------------------------
PX4_BASE_CMD="cd '$PX4_DIR' && "

if [[ "$GZ_MODE" == "managed" ]]; then
  # managed 模式下由 `make px4_sitl gz_xxx` 自己拉起 Gazebo
  GZ_SERVER_CMD=""
fi

case "$GZ_MODE" in
  managed)
    if [[ "$HEADLESS" == "1" ]]; then
      PX4_BASE_CMD+="HEADLESS=1 "
    fi
    PX4_BASE_CMD+="make px4_sitl $PX4_TARGET"
    GZ_OWNER_DESC="PX4 managed (make px4_sitl $PX4_TARGET)"
    ;;
  standalone)
    if [[ -z "$GZ_SERVER_CMD" ]]; then
      log "[ERROR] GZ_MODE=standalone 时必须提供 GZ_SERVER_CMD"
      exit 1
    fi

    if pgrep -f "gz sim" >/dev/null 2>&1; then
      log "[WARN] Gazebo already running, skip standalone Gazebo launch"
      GZ_SERVER_CMD=""
    fi

    PX4_BASE_CMD+="PX4_GZ_STANDALONE=1 make px4_sitl $PX4_TARGET"
    GZ_OWNER_DESC="external standalone command"
    ;;
  *)
    log "[ERROR] Unsupported GZ_MODE: $GZ_MODE (expected: managed or standalone)"
    exit 1
    ;;
esac

PX4_CMD_LINE="$(make_wrapped_cmd \
  "px4" \
  "$PX4_BASE_CMD" \
  "$THIS_LOG_DIR/px4.log" \
  "$THIS_LOG_DIR/px4.alerts.log" \
  "$THIS_LOG_DIR/px4.summary.log")"

AGENT_CMD_LINE=""
if [[ "$ENABLE_AGENT" == "1" && -n "$AGENT_CMD" ]]; then
  AGENT_CMD_LINE="$(make_wrapped_cmd \
    "agent" \
    "$AGENT_CMD $AGENT_ARGS" \
    "$THIS_LOG_DIR/agent.log" \
    "$THIS_LOG_DIR/agent.alerts.log" \
    "$THIS_LOG_DIR/agent.summary.log")"
fi

GZ_SERVER_CMD_LINE=""
if [[ "$GZ_MODE" == "standalone" ]]; then
  GZ_SERVER_CMD_LINE="$(make_wrapped_cmd \
    "gz" \
    "$GZ_SERVER_CMD" \
    "$THIS_LOG_DIR/gz.log" \
    "$THIS_LOG_DIR/gz.alerts.log" \
    "$THIS_LOG_DIR/gz.summary.log")"
fi

ROS_ENV_CMD="source '/opt/ros/${ROS_DISTRO}/setup.bash'"
if [[ -n "$ROS_SETUP_EXTRA" ]]; then
  ROS_ENV_CMD+=" && ${ROS_SETUP_EXTRA}"
fi
if [[ -n "$ROS_WS" && -f "$ROS_WS/install/setup.bash" ]]; then
  ROS_ENV_CMD+=" && source '$ROS_WS/install/setup.bash'"
elif [[ -n "$ROS_WS" && -f "$ROS_WS/install/local_setup.bash" ]]; then
  ROS_ENV_CMD+=" && source '$ROS_WS/install/local_setup.bash'"
elif [[ "$ENABLE_ROS" == "1" ]]; then
  log "[WARN] ROS workspace setup not found under: $ROS_WS/install"
fi

ROS_CMD_LINE=""
if [[ "$ENABLE_ROS" == "1" ]]; then
  if [[ -n "$OFFBOARD_CMD" ]]; then
    ROS_CMD_LINE="$(make_wrapped_cmd \
      "ros" \
      "$ROS_ENV_CMD && $OFFBOARD_CMD" \
      "$THIS_LOG_DIR/ros_app.log" \
      "$THIS_LOG_DIR/ros_app.alerts.log" \
      "$THIS_LOG_DIR/ros_app.summary.log")"
  else
    ROS_CMD_LINE="bash -lc 'echo \"ROS enabled but OFFBOARD_CMD is empty.\"; bash'"
  fi
fi

QGC_CMD_LINE=""
if [[ "$ENABLE_QGC" == "1" ]]; then
  if [[ -n "$QGC_APPIMAGE" && -x "$QGC_APPIMAGE" ]]; then
    QGC_CMD_LINE="$(make_wrapped_cmd \
      "qgc" \
      "${QGC_ENV:-} '$QGC_APPIMAGE'" \
      "$THIS_LOG_DIR/qgc.log" \
      "$THIS_LOG_DIR/qgc.alerts.log" \
      "$THIS_LOG_DIR/qgc.summary.log")"
  else
    QGC_CMD_LINE="bash -lc 'echo \"ENABLE_QGC=1, but QGC_APPIMAGE is missing or not executable.\"; bash'"
  fi
fi

LOGS_CMD_LINE="bash -lc 'echo \"Logs: $THIS_LOG_DIR\"; ls -lah \"$THIS_LOG_DIR\"; bash'"

# -----------------------------
# 创建 tmux session
# -----------------------------

preflight_check_gz_mode
log "[INFO] Gazebo startup mode: $GZ_MODE"
log "[INFO] Gazebo owner: $GZ_OWNER_DESC"

tmux new-session -d -s "$SESSION_NAME" -n px4
tmux set-option -t "$SESSION_NAME" remain-on-exit on >/dev/null
tmux set-option -t "$SESSION_NAME" mouse on >/dev/null
tmux set-option -t "$SESSION_NAME" history-limit 50000 >/dev/null
tmux set-option -t "$SESSION_NAME" mode-keys vi >/dev/null

tmux_run_in_window "logs" "$LOGS_CMD_LINE"

# 1) 先起 DDS Agent（如果你走 ROS2/uXRCE-DDS，这一步先起最稳）
if [[ -n "$AGENT_CMD_LINE" ]]; then
  tmux_run_in_window "agent" "$AGENT_CMD_LINE"
fi

# 2) standalone 模式才单独启动 Gazebo。
#    managed 模式下绝不在这里额外起 Gazebo，避免与 `make px4_sitl` 重复。
if [[ -n "$GZ_SERVER_CMD_LINE" ]]; then
  tmux_run_in_window "gz" "$GZ_SERVER_CMD_LINE"
  sleep 3
fi

# 3) 启动 PX4
tmux_run_in_window "px4" "$PX4_CMD_LINE"

# 4) 等 PX4 ready
wait_for_pattern "$THIS_LOG_DIR/px4.log" "$PX4_READY_REGEX" "$PX4_READY_TIMEOUT" "PX4 ready"

# 5) 启动 QGC
if [[ -n "$QGC_CMD_LINE" ]]; then
  tmux_run_in_window "qgc" "$QGC_CMD_LINE"
  sleep "$QGC_SETTLE_SECONDS"
fi

# 6) 启动 ROS/offboard
if [[ "$ENABLE_ROS" == "1" ]]; then
  if [[ "$WAIT_FOR_FMU_TOPICS" == "1" ]]; then
    wait_for_cmd \
      "$ROS_ENV_CMD && ros2 topic list 2>/dev/null | grep -q '^/fmu/'" \
      "$ROS_TOPIC_WAIT_SECONDS" \
      "ROS /fmu topics available"
  fi
  tmux_run_in_window "ros" "$ROS_CMD_LINE"
fi

tmux select-window -t "$SESSION_NAME:px4"

log "Session created: $SESSION_NAME"
log "Logs: $THIS_LOG_DIR"
log "Gazebo mode: $GZ_MODE"
log "Gazebo owner: $GZ_OWNER_DESC"
log "HEADLESS: $HEADLESS"

exec tmux attach -t "$SESSION_NAME"