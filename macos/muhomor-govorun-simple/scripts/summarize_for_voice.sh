#!/bin/zsh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/runtime_env.sh"
write_status() {
  if [ -n "${VOICE_STATUS_FILE:-}" ]; then
    printf '%s\n' "$1" > "$VOICE_STATUS_FILE"
  fi
}

run_codex_summary() {
  python3 - <<'PY' "$ROOT" "$TMP_PROMPT" "$TMP_RAW" "$TMP_LOG"
from pathlib import Path
import subprocess
import sys

root, prompt_path, out_path, log_path = sys.argv[1:5]
prompt = Path(prompt_path).read_text()
cmd = [
    "codex", "exec",
    "--skip-git-repo-check",
    "--sandbox", "read-only",
    "--ephemeral",
    "-C", root,
    "-m", "gpt-5.5",
    "-o", out_path,
    "-"
]
with open(log_path, "w") as logf:
    try:
        subprocess.run(cmd, input=prompt, text=True, stdout=logf, stderr=subprocess.STDOUT, timeout=28, check=True)
    except subprocess.TimeoutExpired:
        print("SUMMARY_CODEX_TIMEOUT")
        raise SystemExit(124)
    except subprocess.CalledProcessError as exc:
        raise SystemExit(exc.returncode)
PY
}

get_summary_backend() {
  python3 - <<'PY' "$SETTINGS_FILE"
from pathlib import Path
import json
import sys

path = Path(sys.argv[1])
default = "gigachat_api"
if not path.exists():
    print(default)
    raise SystemExit
try:
    data = json.loads(path.read_text())
except Exception:
    print(default)
    raise SystemExit
print(data.get("summary_backend", default))
PY
}

get_summary_style() {
  python3 - <<'PY' "$SETTINGS_FILE"
from pathlib import Path
import json
import sys

path = Path(sys.argv[1])
default = "balanced"
if not path.exists():
    print(default)
    raise SystemExit
try:
    data = json.loads(path.read_text())
except Exception:
    print(default)
    raise SystemExit
print(data.get("summary_style", default))
PY
}

gigachat_summary() {
  if [ ! -f "$GIGACHAT_ENV_FILE" ]; then
    echo "SUMMARY_GIGACHAT_ENV_MISSING"
    return 1
  fi

  set -a
  source "$GIGACHAT_ENV_FILE"
  set +a

  if [ -z "${GIGACHAT_AUTH_KEY:-}" ]; then
    echo "SUMMARY_GIGACHAT_AUTH_MISSING"
    return 1
  fi

  local ca_bundle
  local curl_tls_args=()
  local curl_exit
  ca_bundle="${GIGACHAT_CA_BUNDLE:-$SBER_CA_BUNDLE}"
  if [ -f "$ca_bundle" ]; then
    curl_tls_args=(--cacert "$ca_bundle")
  elif [ "${GIGACHAT_CURL_INSECURE:-0}" = "1" ]; then
    curl_tls_args=(--insecure)
  fi

  local token_cache token_resp token request_id
  token_cache="$(mktemp)"
  token_resp="$(mktemp)"
  request_id="$(python3 - <<'PY'
import uuid
print(uuid.uuid4())
PY
)"

  write_status "Получаю токен GigaChat"
  curl --silent --show-error --fail \
    --connect-timeout 8 \
    --max-time 15 \
    "${curl_tls_args[@]}" \
    --request POST 'https://ngw.devices.sberbank.ru:9443/api/v2/oauth' \
    --header "Authorization: Basic ${GIGACHAT_AUTH_KEY}" \
    --header 'Content-Type: application/x-www-form-urlencoded' \
    --header 'Accept: application/json' \
    --header "RqUID: ${request_id}" \
    --data-urlencode "scope=${GIGACHAT_SCOPE:-GIGACHAT_API_PERS}" > "$token_cache" || {
      curl_exit=$?
      rm -f "$token_cache" "$token_resp"
      if [ "$curl_exit" = "28" ]; then
        echo "SUMMARY_GIGACHAT_TIMEOUT"
      else
        echo "SUMMARY_GIGACHAT_TOKEN_FAILED"
      fi
      return 1
    }

  token="$(python3 - <<'PY' "$token_cache"
from pathlib import Path
import json
import sys
data = json.loads(Path(sys.argv[1]).read_text())
print(data.get("access_token", ""))
PY
)"

  if [ -z "${token:-}" ]; then
    rm -f "$token_cache" "$token_resp"
    echo "SUMMARY_GIGACHAT_TOKEN_FAILED"
    return 1
  fi

  python3 - <<'PY' "$PROMPT" "${GIGACHAT_MODEL:-GigaChat-2-Pro}" > "$TMP_LOG"
import json
import sys

prompt = sys.argv[1]
model = sys.argv[2]
payload = {
    "model": model,
    "messages": [
        {
            "role": "system",
            "content": "Ты делаешь ясный пересказ текста для последующей озвучки голосом."
        },
        {
            "role": "user",
            "content": prompt
        }
    ],
    "stream": False,
    "temperature": 0.2,
}
print(json.dumps(payload, ensure_ascii=False))
PY

  write_status "Жду ответ GigaChat"
  curl --silent --show-error --fail \
    --connect-timeout 8 \
    --max-time 35 \
    "${curl_tls_args[@]}" \
    --request POST 'https://gigachat.devices.sberbank.ru/api/v1/chat/completions' \
    --header 'Content-Type: application/json' \
    --header 'Accept: application/json' \
    --header "Authorization: Bearer ${token}" \
    --data "@${TMP_LOG}" > "$token_resp" || {
      curl_exit=$?
      rm -f "$token_cache" "$token_resp"
      if [ "$curl_exit" = "28" ]; then
        echo "SUMMARY_GIGACHAT_TIMEOUT"
      else
        echo "SUMMARY_GIGACHAT_FAILED"
      fi
      return 1
    }

  python3 - <<'PY' "$token_resp" > "$TMP_RAW"
from pathlib import Path
import json
import sys

data = json.loads(Path(sys.argv[1]).read_text())
choices = data.get("choices") or []
message = (choices[0].get("message") or {}) if choices else {}
content = message.get("content", "")
print(content.strip())
PY

  rm -f "$token_cache" "$token_resp"
}

if [ $# -lt 1 ]; then
  echo "usage: summarize_for_voice.sh <file>"
  exit 1
fi
FILE="$1"
ROOT="$APP_ROOT"
OUTDIR="$RESPONSES_DIR"
STAMP=$(date +%Y%m%d-%H%M%S)
OUT="$OUTDIR/summary-$STAMP.txt"
TMP_INPUT=$(mktemp)
TMP_RAW=$(mktemp)
TMP_PROMPT=$(mktemp)
TMP_LOG=$(mktemp)
cleanup() {
  rm -f "$TMP_INPUT" "$TMP_RAW" "$TMP_PROMPT" "$TMP_LOG"
}
trap cleanup EXIT
TEXT=$(python3 "$ROOT/local-ai-tools/bin/clean_for_voice.py" "$FILE" | python3 -c 'import sys; print(sys.stdin.read()[:12000].strip())')
if [ -z "${TEXT:-}" ]; then
  echo "NO_READABLE_TEXT"
  exit 2
fi
printf '%s' "$TEXT" > "$TMP_INPUT"
write_status "Готовлю summary"
SUMMARY_STYLE=$(get_summary_style)
DETAIL_GUIDANCE="Сделай нормальный сбалансированный пересказ: понятный, живой и немного короче исходного текста."
if [ "$SUMMARY_STYLE" = "detailed" ]; then
  DETAIL_GUIDANCE="Сделай более подробный пересказ: не растягивай без нужды, но сохраняй больше полезных деталей и контекста."
elif [ "$SUMMARY_STYLE" = "short" ]; then
  DETAIL_GUIDANCE="Сделай более короткий пересказ: оставь только самое нужное, но не превращай текст в обрывки."
fi
PROMPT=$(cat <<EOF
Сделай живой, понятный и естественный пересказ для человека.
Этот текст сразу будет озвучен голосом, поэтому он должен легко восприниматься на слух и звучать по-человечески.

$DETAIL_GUIDANCE

Правила:
1. Пиши только по-русски.
2. Верни ответ в 3 или 4 отдельных строках.
3. Каждая строка должна быть естественной, понятной и законченной мыслью.
4. Не пытайся сделать текст слишком коротким. Лучше дай адекватный пересказ, который экономит время, но сохраняет смысл.
5. Пересказ должен быть немного подробнее, чем сухая выжимка, но всё ещё заметно короче исходного текста.
6. Пиши простыми словами, как если бы спокойно и умно объяснял человеку суть.
7. Можно использовать короткие связки вроде "суть в том, что", "важно, что", "получается, что", если это делает речь живее и понятнее.
8. Убирай повторы, канцелярит, ссылки, служебный мусор и слишком тяжёлые формулировки.
9. Если текст длинный, сократи его до удобного пересказа, но не выбрасывай важный смысл.
10. Если в тексте есть вывод, решение или совет, сформулируй это прямо и по-человечески.
11. Не используй списки, нумерацию, заголовки и слова вроде "итог", "кратко", "резюме".
12. Не объясняй, что ты делаешь. Просто дай хороший пересказ.

Пиши так, чтобы человек понял смысл с первого прослушивания и не чувствовал, что текст слишком обрублен.
Каждая строка будет озвучена отдельно, поэтому она должна хорошо звучать сама по себе.

Текст для выжимки:
$TEXT
EOF
)
printf '%s\n' "$PROMPT" > "$TMP_PROMPT"

SUMMARY_BACKEND=$(get_summary_backend)
if [ "$SUMMARY_BACKEND" = "gigachat_api" ]; then
  write_status "Отправляю в GigaChat"
  gigachat_summary || {
    echo "SUMMARY_GIGACHAT_FAILED"
    exit 3
  }
else
  write_status "Отправляю в OpenAI"
  if ! run_codex_summary; then
    code=$?
    cat "$TMP_LOG" >&2 || true
    if [ "$code" = "124" ]; then
      echo "SUMMARY_CODEX_TIMEOUT"
    else
      echo "SUMMARY_CODEX_FAILED"
    fi
    exit 3
  fi
fi

write_status "Нормализую текст"
python3 "$ROOT/local-ai-tools/bin/clean_text_stdin.py" < "$TMP_RAW" > "$TMP_PROMPT"
python3 - <<'PY' "$TMP_PROMPT" > "$TMP_RAW"
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text()
lines = []
for raw in text.splitlines():
    line = re.sub(r"\s+", " ", raw).strip()
    line = re.sub(r"^[\-\*\d\.\)\s]+", "", line).strip()
    if line:
        lines.append(line)

if not lines:
    text = re.sub(r"\s+", " ", text).strip()
    parts = re.split(r"(?<=[.!?])\s+", text)
    for part in parts:
        part = part.strip()
        if part:
            lines.append(part)

lines = lines[:4]
print("\n".join(lines).strip())
PY
python3 "$ROOT/local-ai-tools/bin/normalize_summary.py" "$TMP_INPUT" "$TMP_RAW" > "$TMP_PROMPT"
python3 - <<'PY' "$TMP_PROMPT" | tee "$OUT"
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text()
raw_lines = [re.sub(r"\s+", " ", line).strip() for line in text.splitlines() if line.strip()]

if not raw_lines:
    raw_lines = [re.sub(r"\s+", " ", part).strip() for part in re.split(r"(?<=[.!?])\s+", text) if part.strip()]

chunks = []
current = ""
for line in raw_lines:
    if not current:
        current = line
        continue
    candidate = f"{current} {line}".strip()
    if len(candidate) <= 190 and candidate.count(".") + candidate.count("!") + candidate.count("?") <= 3:
        current = candidate
    else:
        chunks.append(current)
        current = line

if current:
    chunks.append(current)

chunks = chunks[:4]
print("\n".join(chunks).strip())
PY
printf '\nSUMMARY_SAVED_TO=%s\n' "$OUT"
