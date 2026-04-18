#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
load_config

LOG_PATH="${1:-$(current_log_dir)}"
CONTEXT_LINES="${2:-${ALERT_CONTEXT_LINES:-6}}"

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
  full_log="$LOG_PATH/${base_name}.log"

  echo "===== ${base_name} ====="

  if [[ ! -s "$alert_log" ]]; then
    echo "(no alerts)"
    echo
    continue
  fi

  if [[ ! -f "$full_log" || ! -s "$full_log" ]]; then
    echo "(full log missing or empty; showing alert lines only)"
    cat "$alert_log"
    echo
    continue
  fi

  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    line_no="${entry%%:*}"
    start=$(( line_no > CONTEXT_LINES ? line_no - CONTEXT_LINES : 1 ))
    end=$(( line_no + CONTEXT_LINES ))
    echo "--- alert at ${base_name}.log:${line_no} ---"
    sed -n "${start},${end}p" "$full_log"
    echo
  done < "$alert_log"
done
