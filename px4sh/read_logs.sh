#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
load_config

LOG_PATH="${1:-$(current_log_dir)}"
MODE="${2:-summary}"
TAIL_LINES="${3:-${READ_LOG_LINES:-200}}"

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
        tail -n "$TAIL_LINES" "$f"
      else
        echo "(empty)"
      fi
      echo
    done
    ;;
  alerts)
    "$SCRIPT_DIR/show_alert_context.sh" "$LOG_PATH"
    ;;
  full)
    shopt -s nullglob
    full_logs=("$LOG_PATH"/*.log)
    found_any=0
    for f in "${full_logs[@]}"; do
      case "$f" in
        *.alerts.log|*.summary.log)
          continue
          ;;
      esac
      found_any=1
      echo "===== $(basename "$f" .log) ====="
      if [[ -s "$f" ]]; then
        tail -n "$TAIL_LINES" "$f"
      else
        echo "(empty)"
      fi
      echo
    done
    if [[ "$found_any" == "0" ]]; then
      echo "No full logs found in $LOG_PATH"
      exit 0
    fi
    ;;
  *)
    echo "Usage: $0 [log_dir] [summary|alerts|full] [tail_lines]" >&2
    exit 1
    ;;
esac
