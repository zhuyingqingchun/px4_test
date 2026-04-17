#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"

resolve_path() {
  local value="${1:-}"
  local base="${2:-$PROJECT_ROOT}"

  [[ -z "$value" ]] && return 0

  case "$value" in
    ~/*)
      printf '%s\n' "${HOME}/${value#~/}"
      ;;
    /*)
      printf '%s\n' "$value"
      ;;
    *)
      printf '%s\n' "$(cd "$base" && pwd)/$value"
      ;;
  esac
}

load_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "[ERROR] Missing ${CONFIG_FILE}" >&2
    echo "Copy config.env.example to config.env first:" >&2
    echo "  cp ${SCRIPT_DIR}/config.env.example ${SCRIPT_DIR}/config.env" >&2
    exit 1
  fi
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"

  PX4_DIR="$(resolve_path "${PX4_DIR:-}")"
  ROS_WS="$(resolve_path "${ROS_WS:-}")"
  QGC_APPIMAGE="$(resolve_path "${QGC_APPIMAGE:-}")"
  LOG_DIR="$(resolve_path "${LOG_DIR:-px4_session_logs}")"
  RUNTIME_DIR="$(resolve_path "${RUNTIME_DIR:-.px4_one_click}")"

  export SCRIPT_DIR PROJECT_ROOT PX4_DIR ROS_WS QGC_APPIMAGE LOG_DIR RUNTIME_DIR

  mkdir -p "$LOG_DIR" "$RUNTIME_DIR"
  SESSION_DIR="${RUNTIME_DIR}/current"
  mkdir -p "$SESSION_DIR"
}

log() {
  printf '[%s] %s
' "$(date +'%H:%M:%S')" "$*"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { log "[ERROR] command not found: $1"; exit 1; }
}

session_exists() {
  tmux has-session -t "$SESSION_NAME" 2>/dev/null
}

resolve_agent_cmd() {
  local resolved=""

  # 1) Respect AGENT_CMD if it is already valid.
  if [[ -n "${AGENT_CMD:-}" ]]; then
    if [[ "$AGENT_CMD" == */* ]]; then
      if [[ -x "$AGENT_CMD" ]]; then
        resolved="$AGENT_CMD"
      fi
    else
      if command -v "$AGENT_CMD" >/dev/null 2>&1; then
        resolved="$(command -v "$AGENT_CMD")"
      fi
    fi
  fi

  # 2) Fallback order requested by user.
  if [[ -z "$resolved" ]]; then
    local candidates=(
      "/usr/local/bin/MicroXRCEAgent"
      "MicroXRCEAgent"
      "/snap/bin/micro-xrce-dds-agent"
      "micro-xrce-dds-agent"
    )
    local c=""
    for c in "${candidates[@]}"; do
      if [[ "$c" == */* ]]; then
        if [[ -x "$c" ]]; then
          resolved="$c"
          break
        fi
      else
        if command -v "$c" >/dev/null 2>&1; then
          resolved="$(command -v "$c")"
          break
        fi
      fi
    done
  fi

  if [[ -z "$resolved" ]]; then
    return 1
  fi

  AGENT_CMD="$resolved"
  export AGENT_CMD
  return 0
}

ensure_prereqs() {
  require_cmd tmux
  require_cmd make
  require_cmd bash
  if [[ ! -d "$PX4_DIR" ]]; then
    log "[ERROR] PX4_DIR not found: $PX4_DIR"
    exit 1
  fi
  if [[ "${ENABLE_ROS:-1}" == "1" && ! -f "/opt/ros/${ROS_DISTRO:-jazzy}/setup.bash" ]]; then
    log "[ERROR] ROS not found: /opt/ros/${ROS_DISTRO:-jazzy}/setup.bash"
    exit 1
  fi
  if [[ "${ENABLE_AGENT:-1}" == "1" ]]; then
    if ! resolve_agent_cmd; then
      log "[ERROR] Agent command not found.
Tried, in order: /usr/local/bin/MicroXRCEAgent, MicroXRCEAgent, /snap/bin/micro-xrce-dds-agent, micro-xrce-dds-agent"
      exit 1
    fi

    log "[INFO] Using Agent command: $AGENT_CMD"
  fi
  if [[ "${ENABLE_QGC:-1}" == "1" && ! -x "${QGC_APPIMAGE:-}" ]]; then
    log "[WARN] QGC AppImage missing or not executable: ${QGC_APPIMAGE:-}"
  fi
}

write_runtime_meta() {
  cat > "$RUNTIME_DIR/session.meta" <<META
SESSION_NAME="$SESSION_NAME"
PX4_DIR="$PX4_DIR"
ROS_WS="$ROS_WS"
QGC_APPIMAGE="$QGC_APPIMAGE"
PX4_TARGET="$PX4_TARGET"
LOG_DIR="$LOG_DIR"
SESSION_STAMP="$1"
AGENT_CMD="$AGENT_CMD"
META
}

runtime_stamp() {
  if [[ -f "$RUNTIME_DIR/session.meta" ]]; then
    # shellcheck disable=SC1090
    source "$RUNTIME_DIR/session.meta"
    printf '%s' "${SESSION_STAMP:-}"
  fi
}

find_ros_setup_script() {
  local ws="${1:-$ROS_WS}"

  if [[ -f "$ws/install/local_setup.bash" ]]; then
    printf '%s\n' "$ws/install/local_setup.bash"
  elif [[ -f "$ws/install/setup.bash" ]]; then
    printf '%s\n' "$ws/install/setup.bash"
  else
    return 1
  fi
}

build_ros_env_cmd() {
  local ws="${1:-$ROS_WS}"
  local ros_setup=""
  local cmd="source '/opt/ros/${ROS_DISTRO:-jazzy}/setup.bash'"

  if [[ -n "${ROS_SETUP_EXTRA:-}" ]]; then
    cmd+=" && ${ROS_SETUP_EXTRA}"
  fi

  ros_setup="$(find_ros_setup_script "$ws" || true)"
  if [[ -n "$ros_setup" ]]; then
    cmd+=" && source '$ros_setup'"
  fi

  printf '%s\n' "$cmd"
}

current_log_dir() {
  local stamp
  stamp="$(runtime_stamp || true)"
  if [[ -n "$stamp" ]]; then
    printf '%s' "$LOG_DIR/$stamp"
  else
    printf '%s' "$LOG_DIR"
  fi
}
