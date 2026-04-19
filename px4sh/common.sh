#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"

log() {
  printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"
}

expand_path() {
  local p="${1:-}"
  if [[ -z "$p" ]]; then
    return 0
  fi
  if [[ "$p" == "~" ]]; then
    printf '%s\n' "$HOME"
    return 0
  fi
  if [[ "$p" == ~/* ]]; then
    printf '%s\n' "$HOME/${p#~/}"
    return 0
  fi
  if [[ "$p" == /* ]]; then
    printf '%s\n' "$p"
    return 0
  fi
  printf '%s\n' "$PROJECT_ROOT/$p"
}

load_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "[ERROR] Missing config file: $CONFIG_FILE" >&2
    exit 1
  fi

  # shellcheck disable=SC1090
  source "$CONFIG_FILE"

  SESSION_NAME="${SESSION_NAME:-px4_stack}"
  PX4_DIR="$(expand_path "${PX4_DIR:-}")"
  ROS_WS="$(expand_path "${ROS_WS:-}")"
  QGC_APPIMAGE="$(expand_path "${QGC_APPIMAGE:-}")"

  PX4_TARGET="${PX4_TARGET:-gz_x500}"
  HEADLESS="${HEADLESS:-0}"

  ENABLE_AGENT="${ENABLE_AGENT:-1}"
  AGENT_CMD="${AGENT_CMD:-/usr/local/bin/MicroXRCEAgent}"
  AGENT_ARGS="${AGENT_ARGS:-udp4 -p 8888}"
  AGENT_START_WAIT_SECONDS="${AGENT_START_WAIT_SECONDS:-2}"

  ENABLE_QGC="${ENABLE_QGC:-1}"
  QGC_ENV="${QGC_ENV:-}"
  QGC_START_WAIT_SECONDS="${QGC_START_WAIT_SECONDS:-3}"

  ENABLE_ROS="${ENABLE_ROS:-1}"
  ROS_DISTRO="${ROS_DISTRO:-jazzy}"
  ROS_SETUP_EXTRA="${ROS_SETUP_EXTRA:-}"
  OFFBOARD_CMD="${OFFBOARD_CMD:-ros2 run my_px4_offboard offboard_trajectory}"
  ROS_START_WAIT_SECONDS="${ROS_START_WAIT_SECONDS:-2}"

  PX4_PROCESS_WAIT_SECONDS="${PX4_PROCESS_WAIT_SECONDS:-25}"
  GZ_PROCESS_WAIT_SECONDS="${GZ_PROCESS_WAIT_SECONDS:-25}"
  PX4_STABILIZE_WAIT_SECONDS="${PX4_STABILIZE_WAIT_SECONDS:-18}"
  DEFAULT_ATTACH_WINDOW="${DEFAULT_ATTACH_WINDOW:-px4}"
}

ensure_prereqs() {
  command -v tmux >/dev/null 2>&1 || {
    echo "[ERROR] tmux is not installed" >&2
    exit 1
  }

  [[ -d "$PX4_DIR" ]] || {
    echo "[ERROR] PX4_DIR not found: $PX4_DIR" >&2
    exit 1
  }

  if [[ "$ENABLE_AGENT" == "1" ]]; then
    command -v "${AGENT_CMD%% *}" >/dev/null 2>&1 || {
      echo "[ERROR] Agent command not found: $AGENT_CMD" >&2
      exit 1
    }
  fi

  if [[ "$ENABLE_QGC" == "1" ]]; then
    [[ -x "$QGC_APPIMAGE" ]] || {
      echo "[ERROR] QGC_APPIMAGE not executable: $QGC_APPIMAGE" >&2
      exit 1
    }
  fi

  if [[ "$ENABLE_ROS" == "1" ]]; then
    [[ -d "$ROS_WS" ]] || {
      echo "[ERROR] ROS_WS not found: $ROS_WS" >&2
      exit 1
    }
    [[ -f "/opt/ros/$ROS_DISTRO/setup.bash" ]] || {
      echo "[ERROR] ROS setup not found: /opt/ros/$ROS_DISTRO/setup.bash" >&2
      exit 1
    }
    if [[ ! -f "$ROS_WS/install/setup.bash" && ! -f "$ROS_WS/install/local_setup.bash" ]]; then
      echo "[ERROR] ROS workspace install setup not found under: $ROS_WS/install" >&2
      exit 1
    fi
  fi
}

session_exists() {
  tmux has-session -t "$SESSION_NAME" 2>/dev/null
}

tmux_window_exists() {
  local name="$1"
  tmux list-windows -t "$SESSION_NAME" -F '#W' | grep -qx "$name"
}

tmux_new_or_select_window() {
  local name="$1"
  if tmux_window_exists "$name"; then
    tmux select-window -t "$SESSION_NAME:$name"
  else
    tmux new-window -t "$SESSION_NAME" -n "$name" >/dev/null
  fi
}

tmux_run_in_window() {
  local name="$1"
  local cmd="$2"
  tmux_new_or_select_window "$name"
  tmux send-keys -t "$SESSION_NAME:$name" C-c
  tmux send-keys -t "$SESSION_NAME:$name" "$cmd" C-m
}

wait_for_process() {
  local pattern="$1"
  local timeout="$2"
  local label="$3"
  local start_ts now_ts
  start_ts="$(date +%s)"
  while true; do
    if pgrep -fa "$pattern" >/dev/null 2>&1; then
      log "[OK] $label"
      return 0
    fi
    now_ts="$(date +%s)"
    if (( now_ts - start_ts >= timeout )); then
      log "[ERROR] Timeout waiting for $label"
      log "[ERROR] pattern=$pattern"
      return 1
    fi
    sleep 1
  done
}

cleanup_pattern() {
  local label="$1"
  local pattern="$2"
  if pgrep -fa "$pattern" >/dev/null 2>&1; then
    log "[INFO] stopping $label"
    pkill -f "$pattern" 2>/dev/null || true
    sleep 1
    pkill -9 -f "$pattern" 2>/dev/null || true
  fi
}
