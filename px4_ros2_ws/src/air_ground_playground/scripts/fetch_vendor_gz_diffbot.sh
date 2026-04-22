#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

echo "[INFO] importing vendor repositories from: ${SRC_DIR}/external/ugv_open_source.repos"
cd "${SRC_DIR}"
vcs import . < external/ugv_open_source.repos

cat <<'EOF'
[INFO] next steps:
  1. sudo apt update
  2. sudo apt install -y \
       ros-jazzy-gz-ros2-control \
       ros-jazzy-gz-ros2-control-demos \
       ros-jazzy-diff-drive-controller \
       ros-jazzy-joint-state-broadcaster \
       ros-jazzy-robot-state-publisher \
       ros-jazzy-xacro \
       ros-jazzy-ros-gz-bridge \
       ros-jazzy-ros-gz-sim \
       python3-vcstool
  3. cd ~/PX4_pro/px4_ros2_ws
  4. colcon build --symlink-install --packages-select \
       gz_ros2_control_demos air_ground_playground my_px4_offboard
  5. source install/setup.bash
  6. ros2 launch air_ground_playground vendor_gz_diffbot_only.launch.py
EOF
