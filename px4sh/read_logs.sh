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

print_grouped_logs() {
  local pattern="$1"
  local suffix="$2"
  local empty_msg="$3"

  shopt -s nullglob
  local logs=($pattern)
  if [[ ${#logs[@]} -eq 0 ]]; then
    echo "$empty_msg"
    return 0
  fi

  for f in "${logs[@]}"; do
    echo "===== $(basename "$f" "$suffix") ====="
    if [[ -s "$f" ]]; then
      tail -n "$TAIL_LINES" "$f"
    else
      echo "(empty)"
    fi
    echo
  done
}

case "$MODE" in
  summary)
    print_grouped_logs "$LOG_PATH/*.summary.log" ".summary.log" "No summary logs found in $LOG_PATH"
    ;;
  alerts)
    print_grouped_logs "$LOG_PATH/*.alerts.log" ".alerts.log" "No alert logs found in $LOG_PATH"
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
