#!/bin/zsh
set -euo pipefail

LOCK_DIR="/tmp/muhomor_govorun_voice.lock"
PID_FILE="$LOCK_DIR/pid"

is_pid_alive() {
  local pid="$1"
  if [ -z "$pid" ]; then
    return 1
  fi
  kill -0 "$pid" >/dev/null 2>&1
}

cleanup_lock() {
  if [ -f "$PID_FILE" ]; then
    local owner_pid
    owner_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [ "$owner_pid" = "$$" ]; then
      rm -rf "$LOCK_DIR"
    fi
  fi
}

if mkdir "$LOCK_DIR" 2>/dev/null; then
  printf '%s\n' "$$" > "$PID_FILE"
else
  existing_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if is_pid_alive "$existing_pid"; then
    echo "VOICE_ALREADY_RUNNING"
    exit 9
  fi
  rm -rf "$LOCK_DIR"
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    printf '%s\n' "$$" > "$PID_FILE"
  else
    echo "VOICE_ALREADY_RUNNING"
    exit 9
  fi
fi

trap cleanup_lock EXIT INT TERM

if [ $# -lt 1 ]; then
  echo "usage: voice_single_run.sh <command> [args...]"
  exit 1
fi

"$@"
