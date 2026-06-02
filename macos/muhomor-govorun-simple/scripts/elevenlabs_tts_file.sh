#!/bin/zsh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/runtime_env.sh"

if [ $# -lt 1 ]; then
  echo "usage: elevenlabs_tts_file.sh <file>"
  exit 1
fi

INPUT_FILE="$1"
ROOT="$APP_ROOT"
TMPDIR_RUN=$(mktemp -d)
TMP_TEXT="$TMPDIR_RUN/input.txt"
TMP_AUDIO="$TMPDIR_RUN/elevenlabs-tts.mp3"

cleanup() {
  rm -rf "$TMPDIR_RUN"
}
trap cleanup EXIT

is_stopped() {
  [ -n "${VOICE_STOP_FILE:-}" ] && [ -f "${VOICE_STOP_FILE}" ]
}

TEXT=$(python3 "$ROOT/local-ai-tools/bin/clean_for_voice.py" "$INPUT_FILE" | python3 "$ROOT/local-ai-tools/bin/prepare_natural_tts_text.py" | python3 -c 'import sys; print(sys.stdin.read().strip())')
if [ -z "${TEXT:-}" ]; then
  echo "ELEVENLABS_TTS_EMPTY_TEXT"
  exit 4
fi
printf '%s' "$TEXT" > "$TMP_TEXT"

if is_stopped; then
  exit 0
fi

if ! python3 "$ROOT/local-ai-tools/bin/elevenlabs_tts_file.py" "$TMP_TEXT" "$TMP_AUDIO"; then
  echo "ELEVENLABS_TTS_SYNTH_FAILED"
  exit 6
fi

if [ ! -f "$TMP_AUDIO" ] || [ ! -s "$TMP_AUDIO" ]; then
  echo "ELEVENLABS_TTS_NO_AUDIO"
  exit 7
fi

if [ "${ELEVENLABS_TTS_SKIP_PLAY:-0}" = "1" ] || [ "${SALUTE_SKIP_PLAY:-0}" = "1" ]; then
  echo "ELEVENLABS_TTS_OK"
  exit 0
fi

if is_stopped; then
  exit 0
fi

if ! afplay "$TMP_AUDIO"; then
  echo "ELEVENLABS_TTS_PLAY_FAILED"
  exit 9
fi
