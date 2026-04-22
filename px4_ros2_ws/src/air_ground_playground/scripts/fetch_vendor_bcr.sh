#!/bin/bash
# Fetch BCR Bot vendor dependency

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_SRC="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

echo "[INFO] Fetching BCR Bot vendor dependency..."
echo "[INFO] Workspace src: ${WORKSPACE_SRC}"

cd "${WORKSPACE_SRC}"

# Check if already cloned
if [ -d "bcr_bot" ]; then
    echo "[INFO] bcr_bot already exists, pulling latest changes..."
    cd bcr_bot
    git pull origin ros2-jazzy
else
    echo "[INFO] Cloning bcr_bot..."
    git clone -b ros2-jazzy https://github.com/blackcoffeerobotics/bcr_bot.git
fi

echo "[OK] BCR Bot vendor dependency ready."
echo ""
echo "Next steps:"
echo "1. Install dependencies: rosdep install --from-paths src --ignore-src -r -y"
echo "2. Build: colcon build --packages-select bcr_bot"
echo "3. Test standalone: ros2 launch bcr_bot gz.launch.py"
echo "4. Test with UAV: ros2 launch air_ground_playground air_ground_with_bcr.launch.py"
