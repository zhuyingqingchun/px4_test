#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -lt 5 ]]; then
  echo "Usage: $0 <component> <full_log> <alert_log> <summary_log> <mode>" >&2
  exit 1
fi

component="$1"
full_log="$2"
alert_log="$3"
summary_log="$4"
mode="$5"

mkdir -p "$(dirname "$full_log")" "$(dirname "$alert_log")" "$(dirname "$summary_log")"

: > "$full_log"
: > "$alert_log"
: > "$summary_log"

alert_re='WARN|ERROR|CRITICAL|FATAL|FAIL|Traceback|Exception|critical:|error:|warning:'
success_re='Ready for takeoff|Startup script returned successfully|home set|session established|participant created|trajectory node started|locked home XY|vehicle command accepted|entering takeoff hold|starting trajectory'
summary_re='Ready for takeoff|Startup script returned successfully|home set|session established|participant created|trajectory node started|locked home XY|vehicle command accepted|entering takeoff hold|starting trajectory|WARN|ERROR|CRITICAL|FATAL|FAIL|Traceback|Exception|critical:|error:|warning:'

while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line//$'\r'/}"

  if [[ "$line" =~ ^[[:space:]]*pxh\>([[:space:]]*pxh\>)*[[:space:]]*$ ]]; then
    continue
  fi

  printf '%s\n' "$line" >> "$full_log"

  if [[ "$line" =~ $alert_re ]]; then
    printf '%s\n' "$line" >> "$alert_log"
  fi

  if [[ "$line" =~ $summary_re ]]; then
    printf '%s\n' "$line" >> "$summary_log"
  fi

  case "$mode" in
    full)
      printf '[%s] %s\n' "$component" "$line"
      ;;
    concise|*)
      if [[ "$line" =~ $alert_re ]]; then
        printf '[%s][ALERT] %s\n' "$component" "$line"
      elif [[ "$line" =~ $success_re ]]; then
        printf '[%s][OK] %s\n' "$component" "$line"
      fi
      ;;
  esac
done
