#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
load_config

LOG_PATH="${1:-$(current_log_dir)}"
TAIL_LINES="${2:-${READ_LOG_LINES:-200}}"

if [[ ! -d "$LOG_PATH" ]]; then
  echo "[ERROR] Log dir not found: $LOG_PATH" >&2
  exit 1
fi

shopt -s nullglob
alert_logs=("$LOG_PATH"/*.alerts.log)

if [[ ${#alert_logs[@]} -eq 0 ]]; then
  echo "No alert logs found in $LOG_PATH"
  exit 0
fi

for alert_log in "${alert_logs[@]}"; do
  base_name="$(basename "$alert_log" .alerts.log)"

  echo "===== ${base_name} ====="

  if [[ -s "$alert_log" ]]; then
    tail -n "$TAIL_LINES" "$alert_log"
  else
    echo "(empty)"
  fi
  echo
done
