#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 极简语义：pause 等价于停掉当前会话。
# 配合 restart/start 使用，避免额外维护半暂停状态。
exec "$SCRIPT_DIR/stop.sh"
