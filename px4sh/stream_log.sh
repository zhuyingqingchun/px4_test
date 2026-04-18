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
  -v component="$component" \
  -v full_log="$full_log" \
  -v alert_log="$alert_log" \
  -v summary_log="$summary_log" \
  -v mode="$mode" '
BEGIN {
  alert_re = "(WARN|ERROR|CRITICAL|FATAL|FAIL|Traceback|Exception|critical:|error:|warning:)"
  success_re = "(Ready for takeoff|Startup script returned successfully|home set|session established|participant created|trajectory node started|locked home XY|vehicle command accepted|entering takeoff hold|starting trajectory|nav_state changed|arming_state changed)"
  summary_re = "(Ready for takeoff|Startup script returned successfully|home set|session established|participant created|trajectory node started|locked home XY|vehicle command accepted|entering takeoff hold|starting trajectory|nav_state changed|arming_state changed|WARN|ERROR|CRITICAL|FATAL|FAIL|Traceback|Exception|critical:|error:|warning:)"
}

function trim_copy(s,   t) {
  t = s
  sub(/^[[:space:]]+/, "", t)
  sub(/[[:space:]]+$/, "", t)
  return t
}

function strip_ansi(s,   t) {
  t = s
  gsub(/\r/, "", t)
  gsub(/\033\[[0-9;?]*[ -\/]*[@-~]/, "", t)
  gsub(/\033\][^\a]*(\a|\033\\)/, "", t)
  gsub(/\033[@-_]/, "", t)
  gsub(/[\001-\010\013\014\016-\037\177]/, "", t)
  sub(/[[:space:]]+$/, "", t)
  return t
}

function is_prompt_only(s,   t) {
  t = trim_copy(s)
  return (t ~ /^(pxh>[[:space:]]*)+$/)
}

function is_alert(s) {
  return (s ~ alert_re)
}

function is_success(s) {
  return (s ~ success_re)
}

function is_summary(s) {
  return (s ~ summary_re)
}

function write_terminal(kind, s) {
  if (mode == "full") {
    print "[" component "] " s
    fflush()
    return
  }

  if (kind == "alert") {
    print "[" component "][ALERT] " s
    fflush()
    return
  }

  if (kind == "ok") {
    print "[" component "][OK] " s
    fflush()
  }
}

function write_logs(s) {
  print s >> full_log
  fflush(full_log)

  if (is_alert(s)) {
    print s >> alert_log
    fflush(alert_log)
  }

  if (is_summary(s)) {
    print s >> summary_log
    fflush(summary_log)
  }
}

function emit_record(s, suppressed,   suppression_line) {
  if (s == "") {
    return
  }

  write_logs(s)

  if (is_alert(s)) {
    write_terminal("alert", s)
  } else if (is_success(s)) {
    write_terminal("ok", s)
  }

  if (suppressed > 0) {
    suppression_line = "[suppressed " suppressed " similar lines]"
    print suppression_line >> full_log
    fflush(full_log)

    if (is_alert(s)) {
      print suppression_line >> alert_log
      fflush(alert_log)
      write_terminal("alert", suppression_line)
    }

    if (is_summary(s)) {
      print suppression_line >> summary_log
      fflush(summary_log)
      if (!is_alert(s) && is_success(s)) {
        write_terminal("ok", suppression_line)
      }
    }
  }
}

{
  line = strip_ansi($0)

  if (line == "" || is_prompt_only(line)) {
    next
  }

  if (line == previous_line) {
    duplicate_count += 1
    next
  }

  emit_record(previous_line, duplicate_count)
  previous_line = line
  duplicate_count = 0
}

END {
  emit_record(previous_line, duplicate_count)
}
'
