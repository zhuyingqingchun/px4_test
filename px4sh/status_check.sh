#!/usr/bin/env bash
set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
load_config

echo "=== PX4 Session Health Check ==="

PASS=0
WARN=0
FAIL=0
HEADLESS="${HEADLESS:-0}"

is_wsl() {
  [[ -f "/proc/version" ]] && grep -qi microsoft /proc/version
}

check_tmux() {
  if session_exists; then
    echo "[PASS] tmux session exists: $SESSION_NAME"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] tmux session not found: $SESSION_NAME"
    FAIL=$((FAIL + 1))
  fi
}

check_px4() {
  if pgrep -f "px4_sitl_default/bin/px4" >/dev/null 2>&1; then
    echo "[PASS] PX4 is running"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] PX4 process not found"
    FAIL=$((FAIL + 1))
  fi
}

check_agent() {
  if [[ "${ENABLE_AGENT:-1}" != "1" ]]; then
    echo "[WARN] Agent disabled in config (ENABLE_AGENT=0)"
    WARN=$((WARN + 1))
    return
  fi

  if pgrep -fa "MicroXRCEAgent|micro-xrce-dds-agent" >/dev/null 2>&1; then
    echo "[PASS] Agent is running"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] Agent process not found"
    FAIL=$((FAIL + 1))
  fi
}

check_gazebo_server() {
  if pgrep -fa '(^|/)(gz|gazebo)([[:space:]]|$)|ign[[:space:]]+gazebo|gz[[:space:]]+sim' >/dev/null 2>&1; then
    echo "[PASS] Gazebo-related process exists"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] Gazebo process not found"
    FAIL=$((FAIL + 1))
  fi
}

check_gazebo_gui() {
  if [[ "$HEADLESS" == "1" ]]; then
    echo "[WARN] Gazebo GUI not expected in headless mode (HEADLESS=1)"
    WARN=$((WARN + 1))
    return
  fi

  if pgrep -f "gz sim -g|gz gui" >/dev/null 2>&1; then
    echo "[PASS] Gazebo GUI exists"
    PASS=$((PASS + 1))
  else
    if is_wsl; then
      echo "[WARN] Gazebo GUI not running (WSL environment - GUI may require X server)"
      WARN=$((WARN + 1))
    else
      echo "[FAIL] Gazebo GUI process not found"
      FAIL=$((FAIL + 1))
    fi
  fi
}

check_qgc() {
  if [[ "${ENABLE_QGC:-1}" != "1" ]]; then
    echo "[WARN] QGroundControl disabled in config (ENABLE_QGC=0)"
    WARN=$((WARN + 1))
    return
  fi

  if pgrep -f "QGroundControl" >/dev/null 2>&1; then
    echo "[PASS] QGroundControl exists"
    PASS=$((PASS + 1))
  else
    if is_wsl; then
      echo "[WARN] QGroundControl not running (WSL environment - GUI may require X server)"
      WARN=$((WARN + 1))
    else
      echo "[FAIL] QGroundControl process not found"
      FAIL=$((FAIL + 1))
    fi
  fi
}

check_ros() {
  local ros_setup=""
  local ros_env_cmd=""

  if [[ "${ENABLE_ROS:-1}" != "1" ]]; then
    echo "[WARN] ROS auto-run disabled in config (ENABLE_ROS=0)"
    WARN=$((WARN + 1))
    return
  fi

  ros_setup="$(find_ros_setup_script "$ROS_WS" || true)"
  if [[ -z "$ros_setup" ]]; then
    echo "[FAIL] ROS workspace setup not found under: $ROS_WS/install"
    FAIL=$((FAIL + 1))
    return
  fi

  ros_env_cmd="$(build_ros_env_cmd "$ROS_WS")"
  if bash -lc "$ros_env_cmd && ros2 topic list >/dev/null 2>&1"; then
    echo "[PASS] ROS 2 environment is usable"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] ROS 2 environment not usable or topic list failed"
    FAIL=$((FAIL + 1))
  fi
}

check_tmux
check_px4
check_agent
check_gazebo_server
check_gazebo_gui
check_qgc
check_ros

echo ""
echo "summary: $PASS pass, $WARN warn, $FAIL fail"

if [[ $FAIL -gt 0 ]]; then
  exit 1
else
  exit 0
fi
