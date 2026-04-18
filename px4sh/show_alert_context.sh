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
  retained_tail_preview_lines=$(( CONTEXT_LINES * 2 + 1 ))
  has_original_line_prefix=0

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

  if grep -qE '^[0-9]+:' "$full_log"; then
    has_original_line_prefix=1
  fi

  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    line_no="${entry%%:*}"
    echo "--- alert at ${base_name}.log:${line_no} ---"

    if [[ "$has_original_line_prefix" == "1" ]]; then
      if ! awk -v target="$line_no" -v ctx="$CONTEXT_LINES" '
        {
          lines[NR] = $0
          if ($0 ~ ("^" target ":")) {
            hit = NR
          }
        }
        END {
          if (!hit) {
            exit 1
          }
          start = (hit > ctx ? hit - ctx : 1)
          end = hit + ctx
          for (i = start; i <= end && i <= NR; i++) {
            print lines[i]
          }
        }
      ' "$full_log"; then
        echo "(alert not present in retained full-log tail; showing latest retained context)"
        tail -n "$retained_tail_preview_lines" "$full_log"
      fi
    else
      if [[ "$line_no" =~ ^[0-9]+$ ]]; then
        start=$(( line_no > CONTEXT_LINES ? line_no - CONTEXT_LINES : 1 ))
        end=$(( line_no + CONTEXT_LINES ))
        sed -n "${start},${end}p" "$full_log"
      else
        echo "(alert line number is not numeric; showing alert line only)"
        echo "$entry"
      fi
    fi
    echo
  done < "$alert_log"
done
