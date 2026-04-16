#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "[ERROR] Missing ${CONFIG_FILE}"
  echo "Copy config.env.example to config.env first:"
  echo "  cp ${SCRIPT_DIR}/config.env.example ${SCRIPT_DIR}/config.env"
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

echo "=== PX4 Session Health Check ==="

PASS=0
WARN=0
FAIL=0

check_tmux() {
  if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
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
  if ps aux | grep -E "MicroXRCEAgent|micro-xrce-dds-agent" | grep -v grep >/dev/null 2>&1; then
    echo "[PASS] Agent is running"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] Agent process not found"
    FAIL=$((FAIL + 1))
  fi
}

check_gazebo_server() {
  if pgrep -f "gz sim.*-s" >/dev/null 2>&1; then
    echo "[PASS] Gazebo server exists"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] Gazebo server process not found"
    FAIL=$((FAIL + 1))
  fi
}

check_gazebo_gui() {
  if [[ "${ENABLE_GZ_GUI:-0}" == "1" ]]; then
    if pgrep -f "gz sim -g\|gz gui" >/dev/null 2>&1; then
      echo "[PASS] Gazebo GUI exists"
      PASS=$((PASS + 1))
    else
      # Check if we're in WSL
      if [[ -f "/proc/version" && $(grep -i microsoft /proc/version) ]]; then
        echo "[WARN] Gazebo GUI not running (WSL environment - GUI may require X server)"
        WARN=$((WARN + 1))
      else
        echo "[FAIL] Gazebo GUI process not found"
        FAIL=$((FAIL + 1))
      fi
    fi
  else
    echo "[WARN] Gazebo GUI disabled in config (ENABLE_GZ_GUI=0)"
    WARN=$((WARN + 1))
  fi
}

check_qgc() {
  if [[ "$ENABLE_QGC" == "1" ]]; then
    if pgrep -f "QGroundControl" >/dev/null 2>&1; then
      echo "[PASS] QGroundControl exists"
      PASS=$((PASS + 1))
    else
      # Check if we're in WSL
      if [[ -f "/proc/version" && $(grep -i microsoft /proc/version) ]]; then
        echo "[WARN] QGroundControl not running (WSL environment - GUI may require X server)"
        WARN=$((WARN + 1))
      else
        echo "[FAIL] QGroundControl process not found"
        FAIL=$((FAIL + 1))
      fi
    fi
  else
    echo "[WARN] QGroundControl disabled in config (ENABLE_QGC=0)"
    WARN=$((WARN + 1))
  fi
}

check_ros() {
  if [[ "$ENABLE_ROS" == "1" ]]; then
    if command -v ros2 >/dev/null 2>&1; then
      if source "/opt/ros/${ROS_DISTRO}/setup.bash" 2>/dev/null && ros2 node list >/dev/null 2>&1; then
        echo "[PASS] ROS 2 is running"
        PASS=$((PASS + 1))
      else
        echo "[FAIL] ROS 2 not running or node list failed"
        FAIL=$((FAIL + 1))
      fi
    else
      echo "[FAIL] ROS 2 command not found"
      FAIL=$((FAIL + 1))
    fi
  else
    echo "[WARN] ROS auto-run disabled in config (ENABLE_ROS=0)"
    WARN=$((WARN + 1))
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
