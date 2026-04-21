#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPOS_FILE_DEFAULT="$SCRIPT_DIR/../../external/ugv_open_source.repos"
REPOS_FILE="${1:-$REPOS_FILE_DEFAULT}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[ERROR] missing command: $1" >&2
    exit 1
  }
}

need_cmd git
need_cmd vcs

if [[ ! -f "$REPOS_FILE" ]]; then
  echo "[ERROR] repos file not found: $REPOS_FILE" >&2
  exit 1
fi

echo "[INFO] using repos file: $REPOS_FILE"
echo "[INFO] starting to fetch vendor dependencies..."
echo ""

# Change to workspace src directory
WS_SRC_DIR="$SCRIPT_DIR/../.."
cd "$WS_SRC_DIR"

echo "[INFO] current directory: $(pwd)"
echo "[INFO] importing repositories..."

# Import repositories using vcs
vcs import . < "$REPOS_FILE"

echo ""
echo "[OK] vendor dependencies fetched successfully!"
echo ""
echo "Fetched packages:"
echo "  - gz_ros2_control/"
echo "  - ros2_control_demos/ (contains DiffBot)"
echo ""
echo "Next steps:"
echo "  1. Install system dependencies:"
echo "     sudo apt install -y ros-jazzy-gz-ros2-control ros-jazzy-diff-drive-controller"
echo "  2. Build the workspace:"
echo "     cd ~/PX4_pro/px4_ros2_ws && colcon build --symlink-install"
echo "  3. Test DiffBot:"
echo "     ros2 launch ros2_control_demos example_2.launch.py"
