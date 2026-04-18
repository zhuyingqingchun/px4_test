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
    echo "Create it first. A working minimal version is provided with these generated files." >&2
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
}

log() {
  printf '[%s] %s\n' "$(date +'%H:%M:%S')" "$*"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    log "[ERROR] command not found: $1"
    exit 1
  }
}

session_exists() {
  tmux has-session -t "${SESSION_NAME:-px4_stack}" 2>/dev/null
}

resolve_agent_cmd() {
  local resolved=""

  if [[ -n "${AGENT_CMD:-}" ]]; then
    if [[ "$AGENT_CMD" == */* ]]; then
      [[ -x "$AGENT_CMD" ]] && resolved="$AGENT_CMD"
    else
      command -v "$AGENT_CMD" >/dev/null 2>&1 && resolved="$(command -v "$AGENT_CMD")"
    fi
  fi

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
        [[ -x "$c" ]] && resolved="$c" && break
      else
        command -v "$c" >/dev/null 2>&1 && resolved="$(command -v "$c")" && break
      fi
    done
  fi

  [[ -n "$resolved" ]] || return 1
  AGENT_CMD="$resolved"
  export AGENT_CMD
  return 0
}

ensure_prereqs() {
  require_cmd tmux
  require_cmd bash
  require_cmd make

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
      log "[ERROR] Agent command not found"
      exit 1
    fi
    log "[INFO] Using Agent command: $AGENT_CMD"
  fi

  if [[ "${ENABLE_QGC:-0}" == "1" && ! -x "${QGC_APPIMAGE:-}" ]]; then
    log "[WARN] QGC AppImage missing or not executable: ${QGC_APPIMAGE:-}"
  fi
}

write_runtime_meta() {
  cat > "$RUNTIME_DIR/session.meta" <<META
SESSION_NAME="${SESSION_NAME:-px4_stack}"
PX4_DIR="$PX4_DIR"
ROS_WS="$ROS_WS"
QGC_APPIMAGE="$QGC_APPIMAGE"
PX4_TARGET="${PX4_TARGET:-}"
LOG_DIR="$LOG_DIR"
SESSION_STAMP="$1"
AGENT_CMD="${AGENT_CMD:-}"
META
}

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
