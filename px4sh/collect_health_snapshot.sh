#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"
OUT_DIR="$REPO_ROOT/docs/health_snapshots"

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

mkdir -p "$OUT_DIR"

branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
commit="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
stamp="$(date '+%Y%m%d_%H%M%S')"
out_file="$OUT_DIR/${stamp}_health_snapshot.md"

check_proc() {
  local label="$1"
  shift
  if pgrep -fa "$*" >/tmp/px4_health_proc.$$ 2>/dev/null; then
    echo "- ${label}：存在"
    sed 's/^/  - /' /tmp/px4_health_proc.$$ || true
  else
    echo "- ${label}：未发现"
  fi
  rm -f /tmp/px4_health_proc.$$ || true
}

ros2_available="no"
ros2_topics="(ros2 不可用或未 source 环境)"
if command -v ros2 >/dev/null 2>&1; then
  ros2_available="yes"
  if ros2 topic list >/tmp/px4_health_topics.$$ 2>/dev/null; then
    ros2_topics="$(grep -E '^/fmu/' /tmp/px4_health_topics.$$ || true)"
    [[ -n "$ros2_topics" ]] || ros2_topics="(未发现 /fmu/* topic)"
  fi
  rm -f /tmp/px4_health_topics.$$ || true
fi

cat > "$out_file" <<MARKDOWN
# 健康快照

- 生成时间：$(date '+%F %T %z')
- 分支：\`${branch}\`
- Commit：\`${commit}\`
- SESSION_NAME：\`${SESSION_NAME:-未设置}\`
- PX4_TARGET：\`${PX4_TARGET:-未设置}\`
- OFFBOARD_CMD：\`${OFFBOARD_CMD:-未设置}\`

## 1. 关键进程
MARKDOWN

{
  check_proc "PX4" "px4"
  check_proc "Gazebo" "gz sim|gazebo|ign gazebo"
  check_proc "Agent" "MicroXRCEAgent|micrortps_agent"
  check_proc "QGroundControl" "QGroundControl"
  check_proc "ROS 2 offboard" "my_px4_offboard|offboard_"
} >> "$out_file"

cat >> "$out_file" <<MARKDOWN

## 2. ROS 2 观测

- ros2 命令是否可用：\`${ros2_available}\`

### /fmu/* 话题快照

${ros2_topics}

## 3. 人工结论

- 当前系统是否健康：
- 当前是否适合直接起飞：
- 当前最可疑的问题层级：连接 / 时序 / 控制 / 环境
MARKDOWN

echo "[OK] 已生成 $out_file"
