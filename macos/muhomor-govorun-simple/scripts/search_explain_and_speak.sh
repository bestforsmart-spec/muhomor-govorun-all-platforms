#!/bin/zsh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/runtime_env.sh"

write_status() {
  if [ -n "${VOICE_STATUS_FILE:-}" ]; then
    printf '%s\n' "$1" > "$VOICE_STATUS_FILE"
  fi
}

if [ $# -lt 1 ]; then
  echo "usage: search_explain_and_speak.sh <file>"
  exit 1
fi

ROOT="$APP_ROOT"
export VOICE_HISTORY_MODE="Поиск и пояснение"
write_status "Готовлю поиск"
TMP_RESULT=$(mktemp)
cleanup() {
  rm -f "$TMP_RESULT"
}
trap cleanup EXIT

if ! $ROOT/local-ai-tools/bin/search_explain_for_voice.sh "$1" > "$TMP_RESULT" 2>&1; then
  cat "$TMP_RESULT"
  exit 3
fi

RESULT="$(cat "$TMP_RESULT")"
echo "$RESULT"
OUT=$(echo "$RESULT" | grep 'SEARCH_EXPLAIN_SAVED_TO=' | tail -n 1 | cut -d= -f2-)
if [ -n "$OUT" ]; then
  write_status "Озвучиваю объяснение"
  $ROOT/local-ai-tools/bin/speak_chunks_file.sh "$OUT"
fi
