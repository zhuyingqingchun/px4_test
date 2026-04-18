#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
load_config

LOG_PATH="${1:-$(current_log_dir)}"
MODE="${2:-summary}"

if [[ ! -d "$LOG_PATH" ]]; then
  echo "[ERROR] Log dir not found: $LOG_PATH" >&2
  exit 1
fi

case "$MODE" in
  summary)
    shopt -s nullglob
    summary_logs=("$LOG_PATH"/*.summary.log)
    if [[ ${#summary_logs[@]} -eq 0 ]]; then
      echo "No summary logs found in $LOG_PATH"
      exit 0
    fi
    for f in "${summary_logs[@]}"; do
      echo "===== $(basename "$f" .summary.log) ====="
      if [[ -s "$f" ]]; then
        tail -n 200 "$f"
      else
        echo "(empty)"
      fi
      echo
    done
    ;;
  alerts)
    "$SCRIPT_DIR/show_alert_context.sh" "$LOG_PATH"
    ;;
  *)
    echo "Usage: $0 [log_dir] [summary|alerts]" >&2
    exit 1
    ;;
esac
