#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CMD="${1:-help}"
case "$CMD" in
  start)   exec "$SCRIPT_DIR/start.sh" ;;
  pause)   exec "$SCRIPT_DIR/pause.sh" ;;
  restart) exec "$SCRIPT_DIR/restart.sh" ;;
  stop)    exec "$SCRIPT_DIR/stop.sh" ;;
  clean)   shift || true; exec "$SCRIPT_DIR/clean_cache.sh" "$@" ;;
  status)  exec "$SCRIPT_DIR/status.sh" ;;
  help|*)
    cat <<USAGE
Usage:
  ./px4ctl.sh start
  ./px4ctl.sh pause
  ./px4ctl.sh restart
  ./px4ctl.sh stop
  ./px4ctl.sh clean [--deep]
  ./px4ctl.sh status

Aliases:
  ./start.sh
  ./pause.sh
  ./restart.sh
  ./stop.sh
  ./clean_cache.sh [--deep]
  ./status.sh
USAGE
    ;;
esac
