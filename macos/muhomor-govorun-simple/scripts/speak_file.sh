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

append_history() {
  if [ -n "${VOICE_HISTORY_FILE:-}" ]; then
    python3 - <<'PY' "$VOICE_HISTORY_FILE" "$1" "${VOICE_HISTORY_MODE:-Озвучка}"
from pathlib import Path
import json
import sys
from datetime import datetime

path = Path(sys.argv[1])
text = sys.argv[2]
mode = sys.argv[3]
payload = {
    "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    "mode": mode,
    "chars": len(text),
    "text": text,
}
with path.open("a") as handle:
    handle.write(json.dumps(payload, ensure_ascii=False) + "\n")
PY
  fi
}

get_tts_backend() {
  python3 - <<'PY' "$SETTINGS_FILE"
from pathlib import Path
import json
import sys

path = Path(sys.argv[1])
default = "local_fast"
if not path.exists():
    print(default)
    raise SystemExit
try:
    data = json.loads(path.read_text())
except Exception:
    print(default)
    raise SystemExit
print(data.get("tts_backend", default))
PY
}

if [ $# -lt 1 ]; then
  echo "usage: speak_file.sh <file>"
  exit 1
fi
FILE="$1"
ROOT="$APP_ROOT"
write_status "Готовлю текст"
TEXT=$(python3 "$ROOT/local-ai-tools/bin/clean_for_voice.py" "$FILE" | python3 "$ROOT/local-ai-tools/bin/prepare_natural_tts_text.py")
if [ -z "${TEXT:-}" ]; then
  echo "No readable text after cleaning"
  exit 1
fi
if is_stopped; then
  exit 0
fi
append_history "$TEXT"

write_status "Генерирую аудио"
TTS_BACKEND=$(get_tts_backend)
case "$TTS_BACKEND" in
  local_fast|local_tts|say|macos_local)
    TTS_SCRIPT="$ROOT/local-ai-tools/bin/local_fast_tts_file.sh"
    ;;
  salute_tts)
    TTS_SCRIPT="$ROOT/local-ai-tools/bin/salute_tts_file.sh"
    ;;
  elevenlabs_tts|elevenlabs|beautiful_voice)
    TTS_SCRIPT="$ROOT/local-ai-tools/bin/elevenlabs_tts_file.sh"
    ;;
  *)
    TTS_SCRIPT="$ROOT/local-ai-tools/bin/local_fast_tts_file.sh"
    ;;
esac
if "$TTS_SCRIPT" "$FILE"; then
  exit 0
fi
if is_stopped; then
  exit 0
fi
write_status "Ошибка озвучки"
if [ "$TTS_SCRIPT" = "$ROOT/local-ai-tools/bin/salute_tts_file.sh" ]; then
  echo "SALUTE_TTS_FAILED"
elif [ "$TTS_SCRIPT" = "$ROOT/local-ai-tools/bin/elevenlabs_tts_file.sh" ]; then
  echo "ELEVENLABS_TTS_FAILED"
else
  echo "LOCAL_TTS_FAILED"
fi
exit 10
