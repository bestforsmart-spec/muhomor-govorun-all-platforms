#!/bin/zsh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/runtime_env.sh"

if [ $# -lt 1 ]; then
  echo "usage: local_fast_tts_file.sh <file>"
  exit 1
fi

INPUT_FILE="$1"
ROOT="$APP_ROOT"
TMPDIR_RUN=$(mktemp -d)
TMP_TEXT="$TMPDIR_RUN/input.txt"

cleanup() {
  rm -rf "$TMPDIR_RUN"
}
trap cleanup EXIT

is_stopped() {
  [ -n "${VOICE_STOP_FILE:-}" ] && [ -f "${VOICE_STOP_FILE}" ]
}

load_local_settings() {
  python3 - <<'PY' "$SETTINGS_FILE"
from pathlib import Path
import json
import shlex
import sys

path = Path(sys.argv[1])
voice = "Milena"
if path.exists():
    try:
        data = json.loads(path.read_text())
        voice = data.get("local_tts_voice") or voice
    except Exception:
        pass
print(f"LOCAL_TTS_VOICE={shlex.quote(str(voice))}")
PY
}

TEXT=$(python3 "$ROOT/local-ai-tools/bin/clean_for_voice.py" "$INPUT_FILE" | python3 "$ROOT/local-ai-tools/bin/prepare_natural_tts_text.py" | python3 -c 'import sys; print(sys.stdin.read().strip())')
if [ -z "${TEXT:-}" ]; then
  echo "LOCAL_TTS_EMPTY_TEXT"
  exit 4
fi
printf '%s' "$TEXT" > "$TMP_TEXT"

if is_stopped; then
  exit 0
fi

eval "$(load_local_settings)"
VOICE="${LOCAL_TTS_VOICE:-Milena}"
if [ "${LOCAL_TTS_SKIP_PLAY:-0}" = "1" ] || [ "${SALUTE_SKIP_PLAY:-0}" = "1" ]; then
  echo "LOCAL_TTS_OK"
  exit 0
fi

if say -v "$VOICE" -r 172 -f "$TMP_TEXT"; then
  exit 0
fi

if [ "$VOICE" != "Milena" ] && say -v Milena -r 172 -f "$TMP_TEXT"; then
  echo "LOCAL_TTS_FALLBACK_MILENA"
  exit 0
fi

echo "LOCAL_TTS_PLAY_FAILED"
exit 9
