#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"
DOCS_DIR="$REPO_ROOT/docs"
OUT_FILE="$DOCS_DIR/success_baseline.md"

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

mkdir -p "$DOCS_DIR"

branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
commit="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
commit_short="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
dirty="clean"
if ! git -C "$REPO_ROOT" diff --quiet 2>/dev/null; then
  dirty="dirty"
fi

timestamp="$(date '+%F %T %z')"

cat > "$OUT_FILE" <<MARKDOWN
# 成功飞行基线

> 由 \`px4sh/record_success_baseline.sh\` 自动生成。

## 1. 生成信息

- 生成时间：${timestamp}
- 分支：\`${branch}\`
- Commit：\`${commit_short}\` / \`${commit}\`
- 工作区状态：\`${dirty}\`

## 2. 本次运行配置

- SESSION_NAME：\`${SESSION_NAME:-未设置}\`
- PX4_DIR：\`${PX4_DIR:-未设置}\`
- ROS_WS：\`${ROS_WS:-未设置}\`
- ROS_DISTRO：\`${ROS_DISTRO:-未设置}\`
- PX4_TARGET：\`${PX4_TARGET:-未设置}\`
- GZ_MODE：\`${GZ_MODE:-未设置}\`
- HEADLESS：\`${HEADLESS:-未设置}\`
- ENABLE_QGC：\`${ENABLE_QGC:-未设置}\`
- ENABLE_ROS：\`${ENABLE_ROS:-未设置}\`
- AGENT_ARGS：\`${AGENT_ARGS:-未设置}\`
- OFFBOARD_CMD：\`${OFFBOARD_CMD:-未设置}\`

## 3. 成功飞行判据

请人工补充本次成功飞行是否满足以下条件：

- [ ] PX4 正常 ready
- [ ] Agent 正常连通
- [ ] QGC 正常连接
- [ ] ROS 话题正常
- [ ] Offboard 正常进入
- [ ] 正常解锁 / 起飞 / 悬停 / 降落 / 上锁
- [ ] 第二次启动仍可复现

## 4. 日志归档位置

建议在成功飞行后立刻执行：

\`./px4sh/archive_success_log.sh\`

归档目录示例：\`logs/archive/<timestamp>_success/\`

## 5. 人工补充记录

### 5.1 启动命令

- 

### 5.2 使用的 offboard 节点

- 

### 5.3 成功日志要点

- 

### 5.4 当前已知红字（先判断是否阻塞）

- 

### 5.5 回退策略

- 可回退分支：
- 可回退 commit：
- 可复用日志归档：
MARKDOWN

echo "[OK] 已生成 $OUT_FILE"
