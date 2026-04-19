#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"
OUT_DIR="$REPO_ROOT/docs/goal_records"

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

goal="${1:-trajectory}"
case "$goal" in
  closed_loop|trajectory|stability|state_machine)
    ;;
  *)
    echo "[ERROR] 不支持的目标：$goal" >&2
    echo "用法：./px4sh/create_goal_record.sh [closed_loop|trajectory|stability|state_machine]" >&2
    exit 1
    ;;
esac

mkdir -p "$OUT_DIR"

branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
commit="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
stamp="$(date '+%Y%m%d_%H%M%S')"
out_file="$OUT_DIR/${stamp}_${goal}.md"

cat > "$out_file" <<MARKDOWN
# 目标验证记录：${goal}

- 生成时间：$(date '+%F %T %z')
- 分支：\`${branch}\`
- Commit：\`${commit}\`
- SESSION_NAME：\`${SESSION_NAME:-未设置}\`
- PX4_TARGET：\`${PX4_TARGET:-未设置}\`
- GZ_MODE：\`${GZ_MODE:-未设置}\`
- HEADLESS：\`${HEADLESS:-未设置}\`
- ENABLE_QGC：\`${ENABLE_QGC:-未设置}\`
- ENABLE_ROS：\`${ENABLE_ROS:-未设置}\`
- OFFBOARD_CMD：\`${OFFBOARD_CMD:-未设置}\`

## 1. 目标说明

- 当前目标：${goal}
- 本轮是否基于“起飞悬停已稳定成功”：是 / 否
- 本轮测试前是否完成日志归档：是 / 否

## 2. 本轮判据

- [ ] Agent / DDS 正常
- [ ] PX4 ready
- [ ] ROS 2 topic 正常
- [ ] Offboard 稳定进入
- [ ] 解锁成功
- [ ] 当前目标执行成功
- [ ] 降落和退出正常

## 3. 本轮结果

- 本轮是否成功：
- 是否有红字：
- 红字是否阻塞：
- 是否建议复测：

## 4. 关键现象

- 

## 5. 后续动作

- 
MARKDOWN

echo "[OK] 已生成 $out_file"
