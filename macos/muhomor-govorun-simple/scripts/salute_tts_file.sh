#!/bin/zsh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/runtime_env.sh"

if [ $# -lt 1 ]; then
  echo "usage: salute_tts_file.sh <file>"
  exit 1
fi

INPUT_FILE="$1"
ROOT="$APP_ROOT"
ENV_FILE="$SALUTE_ENV_FILE"
TOKEN_CACHE="$CONFIG_DIR/salute_speech_token.json"
TMPDIR_RUN=$(mktemp -d)
TMP_TEXT="$TMPDIR_RUN/input.txt"
TMP_WAV="$TMPDIR_RUN/salute-tts.wav"
TMP_RESP="$TMPDIR_RUN/salute-token.json"
TMP_META="$TMPDIR_RUN/audio-meta.txt"

cleanup() {
  rm -rf "$TMPDIR_RUN"
}
trap cleanup EXIT

if [ ! -f "$ENV_FILE" ]; then
  echo "SALUTE_TTS_ENV_MISSING"
  exit 2
fi

set -a
source "$ENV_FILE"
set +a

is_stopped() {
  [ -n "${VOICE_STOP_FILE:-}" ] && [ -f "${VOICE_STOP_FILE}" ]
}

if [ -z "${SALUTE_AUTH_KEY:-}" ]; then
  echo "SALUTE_TTS_AUTH_KEY_MISSING"
  exit 3
fi

SCOPE="${SALUTE_SCOPE:-SALUTE_SPEECH_PERS}"
VOICE="${SALUTE_VOICE:-Nec_24000}"
FORMAT="${SALUTE_FORMAT:-wav16}"
CA_BUNDLE="${SALUTE_CA_BUNDLE:-$SBER_CA_BUNDLE}"
CURL_TLS_ARGS=()
if [ -f "$CA_BUNDLE" ]; then
  CURL_TLS_ARGS=(--cacert "$CA_BUNDLE")
elif [ "${SALUTE_CURL_INSECURE:-0}" = "1" ]; then
  CURL_TLS_ARGS=(--insecure)
fi

TEXT=$(python3 "$ROOT/local-ai-tools/bin/clean_for_voice.py" "$INPUT_FILE" | python3 "$ROOT/local-ai-tools/bin/prepare_natural_tts_text.py" | python3 -c 'import sys; print(sys.stdin.read().strip())')
if [ -z "${TEXT:-}" ]; then
  echo "NO_READABLE_TEXT"
  exit 4
fi
printf '%s' "$TEXT" > "$TMP_TEXT"

get_cached_token() {
  python3 - <<'PY' "$TOKEN_CACHE"
from pathlib import Path
import json
import sys
import time

path = Path(sys.argv[1])
if not path.exists():
    raise SystemExit(1)
try:
    data = json.loads(path.read_text())
except Exception:
    raise SystemExit(1)
token = data.get("access_token")
expires_at = data.get("expires_at", 0)
if not token or not isinstance(expires_at, (int, float)):
    raise SystemExit(1)
if expires_at - time.time() < 60:
    raise SystemExit(1)
print(token)
PY
}

fetch_new_token() {
  mkdir -p "$CONFIG_DIR"
  local rq_uid
  rq_uid="$(python3 - <<'PY'
import uuid
print(uuid.uuid4())
PY
)"
  curl --silent --show-error --fail \
    --connect-timeout 8 \
    --max-time 20 \
    "${CURL_TLS_ARGS[@]}" \
    --request POST 'https://ngw.devices.sberbank.ru:9443/api/v2/oauth' \
    --header "Authorization: Basic ${SALUTE_AUTH_KEY}" \
    --header 'Content-Type: application/x-www-form-urlencoded' \
    --header 'Accept: application/json' \
    --header "RqUID: ${rq_uid}" \
    --data-urlencode "scope=${SCOPE}" > "$TMP_RESP"

  python3 - <<'PY' "$TMP_RESP" "$TOKEN_CACHE"
from pathlib import Path
import json
import sys
import time

resp_path = Path(sys.argv[1])
cache_path = Path(sys.argv[2])
data = json.loads(resp_path.read_text())
token = data.get("access_token")
expires_at_ms = data.get("expires_at", 0)
if not token or not expires_at_ms:
    raise SystemExit(1)
cache = {
    "access_token": token,
    "expires_at": float(expires_at_ms) / 1000.0,
    "stored_at": time.time(),
}
cache_path.write_text(json.dumps(cache, ensure_ascii=False, indent=2))
print(token)
PY
}

if TOKEN="$(get_cached_token 2>/dev/null)"; then
  :
else
  TOKEN="$(fetch_new_token)" || {
    echo "SALUTE_TTS_TOKEN_FAILED"
    exit 5
  }
fi

if is_stopped; then
  exit 0
fi

curl --silent --show-error --fail \
  --connect-timeout 8 \
  --max-time 45 \
  "${CURL_TLS_ARGS[@]}" \
  --request POST "https://smartspeech.sber.ru/rest/v1/text:synthesize?format=${FORMAT}&voice=${VOICE}" \
  --header "Authorization: Bearer ${TOKEN}" \
  --header 'Content-Type: application/text' \
  --header 'Accept: audio/wav' \
  --data-binary "@${TMP_TEXT}" > "$TMP_WAV" || {
  echo "SALUTE_TTS_SYNTH_FAILED"
  exit 6
  }

if [ ! -f "$TMP_WAV" ] || [ ! -s "$TMP_WAV" ]; then
  echo "SALUTE_TTS_NO_WAV"
  exit 7
fi

if ! python3 - <<'PY' "$TMP_WAV" > "$TMP_META"
from pathlib import Path
import sys
import wave

path = Path(sys.argv[1])
size = path.stat().st_size
if size < 2048:
    raise SystemExit(1)

with wave.open(str(path), "rb") as wav:
    frames = wav.getnframes()
    rate = wav.getframerate()
    duration = (frames / float(rate)) if rate else 0.0

if duration < 0.12:
    raise SystemExit(1)

print(f"{duration:.3f}")
PY
then
  echo "SALUTE_TTS_INVALID_WAV"
  exit 8
fi

if [ "${SALUTE_SKIP_PLAY:-0}" = "1" ]; then
  echo "SALUTE_TTS_OK"
  exit 0
fi

if is_stopped; then
  exit 0
fi

if ! afplay "$TMP_WAV"; then
  echo "SALUTE_TTS_PLAY_FAILED"
  exit 9
fi
