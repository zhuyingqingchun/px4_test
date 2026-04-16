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

awk \
  -v full_log="$full_log" \
  -v alert_log="$alert_log" \
  -v summary_log="$summary_log" \
  -v mode="$mode" \
  -v component="$component" '
BEGIN {
  alert_re = "(WARN|ERROR|CRITICAL|FATAL|FAIL|Traceback|Exception|critical:|error:|warning:)"
  success_re = "(Startup script returned successfully|Gazebo world is ready|Spawning Gazebo model|Ready for takeoff!|logger started|Opened full log file|session established|participant created|create_client|synchronized with time offset|node started|Sent command:|home set|init UDP agent IP)"
  summary_re = "(Startup script returned successfully|Gazebo world is ready|Spawning Gazebo model|Ready for takeoff!|logger started|Opened full log file|session established|participant created|create_client|synchronized with time offset|node started|Sent command:|ARM|OFFBOARD|takeoff|land|connected|partner IP)"
  repeated_alert = ""
  repeated_count = 0
}

function emit_repeated_alert_summary() {
  if (repeated_count > 1) {
    msg = sprintf("repeated previous alert %d times", repeated_count - 1)
    print msg >> summary_log
    fflush(summary_log)
    if (mode == "concise") {
      printf("[%s][ALERT] %s\n", component, msg)
      fflush()
    }
  }
  repeated_alert = ""
  repeated_count = 0
}

function trim_ansi(text,    out) {
  out = text
  gsub(/\033\[[0-9;]*[A-Za-z]/, "", out)
  return out
}
{
  print $0 >> full_log
  fflush(full_log)

  is_alert = ($0 ~ alert_re)
  is_success = ($0 ~ success_re)
  is_summary = ($0 ~ summary_re)
  clean_line = trim_ansi($0)

  if (is_alert) {
    if (clean_line == repeated_alert) {
      repeated_count++
    } else {
      emit_repeated_alert_summary()
      repeated_alert = clean_line
      repeated_count = 1
      printf("%d:%s\n", NR, clean_line) >> alert_log
      fflush(alert_log)
      print clean_line >> summary_log
      fflush(summary_log)
      printf("[%s][ALERT] %s\n", component, clean_line)
      fflush()
    }
  } else if (mode == "full") {
    emit_repeated_alert_summary()
    printf("[%s] %s\n", component, $0)
    fflush()
  } else {
    emit_repeated_alert_summary()
    if (is_summary) {
      print clean_line >> summary_log
      fflush(summary_log)
    }
    if (mode == "concise" && is_success) {
      printf("[%s][OK] %s\n", component, clean_line)
      fflush()
    }
  }
}
END {
  emit_repeated_alert_summary()
}
' 
