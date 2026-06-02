#!/bin/zsh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/runtime_env.sh"

write_status() {
  if [ -n "${VOICE_STATUS_FILE:-}" ]; then
    printf '%s\n' "$1" > "$VOICE_STATUS_FILE"
  fi
}

is_stopped() {
  [ -n "${VOICE_STOP_FILE:-}" ] && [ -f "${VOICE_STOP_FILE}" ]
}

if [ $# -lt 1 ]; then
  echo "usage: speak_chunks_file.sh <file>"
  exit 1
fi

FILE="$1"
ROOT="$APP_ROOT"
TMPDIR_RUN=$(mktemp -d)
cleanup() {
  rm -rf "$TMPDIR_RUN"
}
trap cleanup EXIT

CHUNK_INDEX=0
while IFS= read -r line || [ -n "$line" ]; do
  if is_stopped; then
    exit 0
  fi
  chunk=$(printf '%s' "$line" | python3 -c 'import sys; print(sys.stdin.read().strip())')
  if [ -z "${chunk:-}" ]; then
    continue
  fi
  CHUNK_INDEX=$((CHUNK_INDEX + 1))
  CHUNK_FILE="$TMPDIR_RUN/chunk-$CHUNK_INDEX.txt"
  printf '%s\n' "$chunk" > "$CHUNK_FILE"
  write_status "Озвучиваю фрагмент $CHUNK_INDEX"
  "$ROOT/local-ai-tools/bin/speak_file.sh" "$CHUNK_FILE"
done < "$FILE"
