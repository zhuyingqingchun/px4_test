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

# Long-run safety defaults:
# - Disable PX4 full text log by default. PX4 can emit extremely repetitive errors for hours,
#   and full stdout/stderr mirroring can grow to multi-GB files and stall the machine.
# - Keep alert/summary logs, but rate-limit similar alerts and cap file sizes.
#
# Optional overrides:
#   PX4_DISABLE_FULL_LOG=0                # re-enable px4 full_log if really needed
#   STREAM_LOG_MAX_FULL_MB=100
#   STREAM_LOG_MAX_ALERT_MB=50
#   STREAM_LOG_MAX_SUMMARY_MB=20
#   STREAM_LOG_ALERT_RATE_LIMIT_SEC=5
#
# Only exported environment variables are inherited by this script.
if [[ "$component" == "px4" ]]; then
  disable_full_log="${PX4_DISABLE_FULL_LOG:-1}"
else
  disable_full_log="${STREAM_LOG_DISABLE_FULL_LOG:-0}"
fi

max_full_mb="${STREAM_LOG_MAX_FULL_MB:-100}"
max_alert_mb="${STREAM_LOG_MAX_ALERT_MB:-50}"
max_summary_mb="${STREAM_LOG_MAX_SUMMARY_MB:-20}"
alert_rate_limit_sec="${STREAM_LOG_ALERT_RATE_LIMIT_SEC:-5}"

: > "$full_log"
: > "$alert_log"
: > "$summary_log"

awk \
  -v full_log="$full_log" \
  -v alert_log="$alert_log" \
  -v summary_log="$summary_log" \
  -v mode="$mode" \
  -v component="$component" \
  -v disable_full_log="$disable_full_log" \
  -v max_full_bytes="$(( max_full_mb * 1024 * 1024 ))" \
  -v max_alert_bytes="$(( max_alert_mb * 1024 * 1024 ))" \
  -v max_summary_bytes="$(( max_summary_mb * 1024 * 1024 ))" \
  -v alert_rate_limit_sec="$alert_rate_limit_sec" '
BEGIN {
  alert_re = "(WARN|ERROR|CRITICAL|FATAL|FAIL|Traceback|Exception|critical:|error:|warning:)"
  success_re = "(Startup script returned successfully|Gazebo world is ready|Spawning Gazebo model|Ready for takeoff!|logger started|Opened full log file|session established|participant created|create_client|synchronized with time offset|node started|Sent command:|home set|init UDP agent IP)"
  summary_re = "(Startup script returned successfully|Gazebo world is ready|Spawning Gazebo model|Ready for takeoff!|logger started|Opened full log file|session established|participant created|create_client|synchronized with time offset|node started|Sent command:|home set|ARM|OFFBOARD|takeoff|land|connected|partner IP|nav_state changed|arming_state changed|vehicle command accepted|entering takeoff hold|starting trajectory)"

  full_written = 0
  alert_written = 0
  summary_written = 0
  full_truncated = 0
  alert_truncated = 0
  summary_truncated = 0

  if (disable_full_log == "1") {
    note = "[stream_log] full log disabled for this component"
    write_limited("full", note)
  }
}

function trim_ansi(text,    out) {
  out = text
  gsub(/\033\[[0-9;]*[A-Za-z]/, "", out)
  gsub(/\r/, "", out)
  return out
}

function is_noisy_success(component, text) {
  if (component == "ros") {
    if (text ~ /APP_OK: sent OFFBOARD mode command/) return 1
    if (text ~ /APP_OK: sent ARM command/) return 1
  }
  return 0
}

function normalize_alert_key(text,    out) {
  out = text
  gsub(/-?[0-9]+\.[0-9]+/, "<num>", out)
  gsub(/-?[0-9]+/, "<num>", out)
  gsub(/[[:space:]]+/, " ", out)
  return out
}

function is_prompt_only(text) {
  if (text ~ /^[[:space:]]*pxh>([[:space:]]*pxh>)*[[:space:]]*$/) return 1
  if (text ~ /^[[:space:]]*pxh>[[:space:]]*$/) return 1
  return 0
}

function write_limited(kind, line,    bytes, marker) {
  bytes = length(line) + 1

  if (kind == "full") {
    if (disable_full_log == "1") {
      return
    }
    if (full_truncated) {
      return
    }
    if (full_written + bytes > max_full_bytes) {
      marker = sprintf("[stream_log] full log truncated at %d bytes", max_full_bytes)
      print marker >> full_log
      fflush(full_log)
      full_truncated = 1
      full_written += length(marker) + 1
      return
    }
    print line >> full_log
    fflush(full_log)
    full_written += bytes
    return
  }

  if (kind == "alert") {
    if (alert_truncated) {
      return
    }
    if (alert_written + bytes > max_alert_bytes) {
      marker = sprintf("[stream_log] alert log truncated at %d bytes", max_alert_bytes)
      print marker >> alert_log
      fflush(alert_log)
      alert_truncated = 1
      alert_written += length(marker) + 1
      return
    }
    print line >> alert_log
    fflush(alert_log)
    alert_written += bytes
    return
  }

  if (kind == "summary") {
    if (summary_truncated) {
      return
    }
    if (summary_written + bytes > max_summary_bytes) {
      marker = sprintf("[stream_log] summary log truncated at %d bytes", max_summary_bytes)
      print marker >> summary_log
      fflush(summary_log)
      summary_truncated = 1
      summary_written += length(marker) + 1
      return
    }
    print line >> summary_log
    fflush(summary_log)
    summary_written += bytes
    return
  }
}

function emit_alert(line_no, clean_line, now_ts,    key, msg, suppressed) {
  key = normalize_alert_key(clean_line)
  suppressed = suppressed_alert_count[key]

  if (suppressed > 0) {
    msg = sprintf("%s [suppressed %d similar lines]", clean_line, suppressed)
  } else {
    msg = clean_line
  }

  write_limited("alert", sprintf("%d:%s", line_no, msg))
  write_limited("summary", msg)
  printf("[%s][ALERT] %s\n", component, msg)
  fflush()

  suppressed_alert_count[key] = 0
  last_alert_emit[key] = now_ts
}

function flush_suppressed_alerts(now_ts,    key, msg) {
  for (key in suppressed_alert_count) {
    if (suppressed_alert_count[key] > 0 && (!(key in last_alert_emit) || now_ts - last_alert_emit[key] >= alert_rate_limit_sec)) {
      msg = sprintf("%s [suppressed %d similar lines]", last_alert_original[key], suppressed_alert_count[key])
      write_limited("alert", sprintf("%d:%s", NR, msg))
      write_limited("summary", msg)
      if (mode == "concise") {
        printf("[%s][ALERT] %s\n", component, msg)
        fflush()
      }
      suppressed_alert_count[key] = 0
      last_alert_emit[key] = now_ts
    }
  }
}

{
  clean_line = trim_ansi($0)

  if (is_prompt_only(clean_line)) {
    next
  }

  if (is_noisy_success(component, clean_line)) {
    next
  }

  write_limited("full", clean_line)

  is_alert = ($0 ~ alert_re)
  is_success = ($0 ~ success_re)
  is_summary = ($0 ~ summary_re)

  now_ts = systime()

  if (is_alert) {
    key = normalize_alert_key(clean_line)
    last_alert_original[key] = clean_line

    if (!(key in last_alert_emit) || now_ts - last_alert_emit[key] >= alert_rate_limit_sec) {
      emit_alert(NR, clean_line, now_ts)
    } else {
      suppressed_alert_count[key]++
    }
  } else if (mode == "full") {
    flush_suppressed_alerts(now_ts)
    printf("[%s] %s\n", component, clean_line)
    fflush()
  } else {
    flush_suppressed_alerts(now_ts)

    if (is_summary) {
      write_limited("summary", clean_line)
    }
    if (mode == "concise" && is_success) {
      printf("[%s][OK] %s\n", component, clean_line)
      fflush()
    }
  }
}
END {
  flush_suppressed_alerts(systime())
}
' 
