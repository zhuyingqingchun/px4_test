#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
load_config

if session_exists; then
  log "tmux session is running: $SESSION_NAME"
  tmux list-windows -t "$SESSION_NAME"
else
  log "tmux session is not running: $SESSION_NAME"
fi

if [[ -f "$RUNTIME_DIR/session.meta" ]]; then
  echo
  echo "Session metadata:"
  cat "$RUNTIME_DIR/session.meta"
fi

LOG_PATH="$(current_log_dir)"
echo
if [[ -d "$LOG_PATH" ]]; then
  echo "Latest log dir: $LOG_PATH"
  ls -lah "$LOG_PATH"
else
  echo "No current log dir found."
fi
