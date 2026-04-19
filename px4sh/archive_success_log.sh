#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

find_log_dir() {
  local candidates=()
  [[ -n "${LOG_DIR:-}" ]] && candidates+=("$LOG_DIR")
  candidates+=(
    "$SCRIPT_DIR/logs"
    "$REPO_ROOT/logs"
    "$REPO_ROOT/px4sh/logs"
  )

  local d
  for d in "${candidates[@]}"; do
    if [[ -d "$d" ]]; then
      printf '%s\n' "$d"
      return 0
    fi
  done
  return 1
}

LOG_BASE="$(find_log_dir || true)"
if [[ -z "$LOG_BASE" ]]; then
  echo "[ERROR] 未找到日志目录。请检查 LOG_DIR 或现有日志路径。" >&2
  exit 1
fi

stamp="$(date '+%Y%m%d_%H%M%S')"
ARCHIVE_DIR="$LOG_BASE/archive/${stamp}_success"
mkdir -p "$ARCHIVE_DIR"

copied=0
shopt -s nullglob
for f in "$LOG_BASE"/*.log "$LOG_BASE"/session.meta "$LOG_BASE"/*.ulg; do
  if [[ -f "$f" ]]; then
    cp -a "$f" "$ARCHIVE_DIR/"
    copied=1
  fi
done
shopt -u nullglob

if [[ "$copied" -eq 0 ]]; then
  echo "[WARN] 在 $LOG_BASE 下没有找到可归档的 *.log / session.meta / *.ulg 文件。" >&2
fi

branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
commit="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
created_at="$(date '+%F %T %z')"

cat > "$ARCHIVE_DIR/manifest.md" <<MARKDOWN
# 成功飞行日志归档

- 归档时间：${created_at}
- 仓库分支：\`${branch}\`
- 仓库提交：\`${commit}\`
- 日志来源目录：\`${LOG_BASE}\`
- 归档目录：\`${ARCHIVE_DIR}\`

## 当前配置快照

- SESSION_NAME：\`${SESSION_NAME:-未设置}\`
- PX4_TARGET：\`${PX4_TARGET:-未设置}\`
- GZ_MODE：\`${GZ_MODE:-未设置}\`
- HEADLESS：\`${HEADLESS:-未设置}\`
- ENABLE_QGC：\`${ENABLE_QGC:-未设置}\`
- ENABLE_ROS：\`${ENABLE_ROS:-未设置}\`
- AGENT_ARGS：\`${AGENT_ARGS:-未设置}\`
- OFFBOARD_CMD：\`${OFFBOARD_CMD:-未设置}\`

## 建议人工补充

- 本次是否正常解锁：
- 本次是否正常进入 Offboard：
- 本次是否正常起飞 / 悬停 / 降落：
- 本次红字是否影响飞行：
MARKDOWN

echo "[OK] 日志已归档到 $ARCHIVE_DIR"
