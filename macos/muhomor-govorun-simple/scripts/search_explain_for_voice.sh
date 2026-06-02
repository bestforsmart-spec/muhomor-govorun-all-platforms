#!/bin/zsh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/runtime_env.sh"

ROOT="$APP_ROOT"
OUTDIR="$RESPONSES_DIR"

write_status() {
  if [ -n "${VOICE_STATUS_FILE:-}" ]; then
    printf '%s\n' "$1" > "$VOICE_STATUS_FILE"
  fi
}

run_codex_search_explain() {
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
        print("SEARCH_EXPLAIN_CODEX_TIMEOUT")
        raise SystemExit(124)
    except subprocess.CalledProcessError as exc:
        raise SystemExit(exc.returncode)
PY
}

get_search_explain_backend() {
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
print(data.get("search_explain_backend", default))
PY
}

gigachat_search_explain() {
  if [ ! -f "$GIGACHAT_ENV_FILE" ]; then
    echo "SEARCH_EXPLAIN_GIGACHAT_ENV_MISSING"
    return 1
  fi

  set -a
  source "$GIGACHAT_ENV_FILE"
  set +a

  if [ -z "${GIGACHAT_AUTH_KEY:-}" ]; then
    echo "SEARCH_EXPLAIN_GIGACHAT_AUTH_MISSING"
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
        echo "SEARCH_EXPLAIN_GIGACHAT_TIMEOUT"
      else
        echo "SEARCH_EXPLAIN_GIGACHAT_TOKEN_FAILED"
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
    echo "SEARCH_EXPLAIN_GIGACHAT_TOKEN_FAILED"
    return 1
  fi

  python3 - <<'PY' "$TMP_PROMPT" "${GIGACHAT_EXPLAIN_MODEL:-GigaChat-2-Max}" > "$TMP_LOG"
from pathlib import Path
import json
import sys

prompt = Path(sys.argv[1]).read_text()
model = sys.argv[2]
payload = {
    "model": model,
    "messages": [
        {
            "role": "system",
            "content": "Ты умный исследователь и объясняющий помощник. Всегда отвечай только по-русски, естественно и понятно для озвучки."
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
    --max-time 40 \
    "${curl_tls_args[@]}" \
    --request POST 'https://gigachat.devices.sberbank.ru/api/v1/chat/completions' \
    --header 'Content-Type: application/json' \
    --header 'Accept: application/json' \
    --header "Authorization: Bearer ${token}" \
    --data "@${TMP_LOG}" > "$token_resp" || {
      curl_exit=$?
      rm -f "$token_cache" "$token_resp"
      if [ "$curl_exit" = "28" ]; then
        echo "SEARCH_EXPLAIN_GIGACHAT_TIMEOUT"
      else
        echo "SEARCH_EXPLAIN_GIGACHAT_FAILED"
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
  echo "usage: search_explain_for_voice.sh <file>"
  exit 1
fi

FILE="$1"
STAMP=$(date +%Y%m%d-%H%M%S)
OUT="$OUTDIR/search-explain-$STAMP.txt"
TMP_SOURCE=$(mktemp)
TMP_QUERY=$(mktemp)
TMP_SEARCH_JSON=$(mktemp)
TMP_RESULTS=$(mktemp)
TMP_PROMPT=$(mktemp)
TMP_RAW=$(mktemp)
TMP_LOG=$(mktemp)

cleanup() {
  rm -f "$TMP_SOURCE" "$TMP_QUERY" "$TMP_SEARCH_JSON" "$TMP_RESULTS" "$TMP_PROMPT" "$TMP_RAW" "$TMP_LOG"
}
trap cleanup EXIT

SOURCE_TEXT=$(python3 "$ROOT/local-ai-tools/bin/clean_for_voice.py" "$FILE" | python3 -c 'import sys; print(" ".join(sys.stdin.read().split())[:12000].strip())')
if [ -z "${SOURCE_TEXT:-}" ]; then
  echo "NO_READABLE_TEXT"
  exit 2
fi
printf '%s\n' "$SOURCE_TEXT" > "$TMP_SOURCE"

write_status "Готовлю поиск"
QUERY="$(python3 - <<'PY' "$TMP_SOURCE"
from pathlib import Path
import re
import sys
from collections import Counter

text = Path(sys.argv[1]).read_text().strip()
words = re.findall(r"\S+", text)
sentences = [s.strip() for s in re.split(r"(?<=[.!?])\s+", text) if s.strip()]

stopwords = {
    "и","в","во","на","по","с","со","к","ко","от","до","за","из","у","о","об","про","для","при","как","что",
    "это","этот","эта","эти","или","а","но","не","да","же","ли","бы","то","так","там","тут","уже","еще",
    "если","чтобы","когда","где","какой","какая","какие","какое","который","которая","которые","которое",
    "можно","нужно","надо","быть","есть","был","была","были","быть","его","ее","их","мы","вы","они","он","она",
}

def normalize(s: str) -> str:
    return re.sub(r"\s+", " ", s).strip(" ,.;:-")

if len(text) <= 700 and len(words) <= 120:
    print(normalize(text)[:500])
    raise SystemExit

tokens = re.findall(r"[A-Za-zА-Яа-я0-9_./:-]{4,}", text)
keywords = [t.lower() for t in tokens if t.lower() not in stopwords and not t.isdigit()]
freq = Counter(keywords)

scored = []
for sentence in sentences[:12]:
    sentence_tokens = re.findall(r"[A-Za-zА-Яа-я0-9_./:-]{4,}", sentence.lower())
    score = sum(freq.get(tok, 0) for tok in sentence_tokens)
    if sentence.endswith(":"):
        score -= 1
    scored.append((score, sentence))

best_sentences = []
for _, sentence in sorted(scored, key=lambda item: item[0], reverse=True):
    normalized = normalize(sentence)
    if normalized and normalized not in best_sentences:
        best_sentences.append(normalized)
    if len(best_sentences) == 2:
        break

top_keywords = []
for token, _ in freq.most_common(6):
    if token not in top_keywords:
        top_keywords.append(token)

parts = best_sentences[:]
if top_keywords:
    parts.append(" ".join(top_keywords[:4]))

query = normalize(" ; ".join(parts))
print(query[:320] if query else normalize(text[:320]))
PY
)"
printf '%s\n' "$QUERY" > "$TMP_QUERY"

if [ ! -f "$BRAVE_ENV_FILE" ]; then
  echo "BRAVE_ENV_MISSING"
  exit 3
fi

set -a
source "$BRAVE_ENV_FILE"
set +a

if [ -z "${BRAVE_SEARCH_API_KEY:-}" ]; then
  echo "BRAVE_AUTH_MISSING"
  exit 3
fi

write_status "Ищу в Brave"
if ! curl --silent --show-error --fail \
  --connect-timeout 8 \
  --max-time 20 \
  --get 'https://api.search.brave.com/res/v1/web/search' \
  --header "Accept: application/json" \
  --header "X-Subscription-Token: ${BRAVE_SEARCH_API_KEY}" \
  --data-urlencode "q=${QUERY}" \
  --data-urlencode "count=${BRAVE_SEARCH_COUNT:-8}" \
  --data-urlencode "extra_snippets=true" \
  --data-urlencode "text_decorations=false" \
  --data-urlencode "spellcheck=true" > "$TMP_SEARCH_JSON"; then
  curl_exit=$?
  if [ "$curl_exit" = "28" ]; then
    echo "BRAVE_SEARCH_TIMEOUT"
  else
    echo "BRAVE_SEARCH_FAILED"
  fi
  exit 3
fi

write_status "Собираю результаты"
python3 - <<'PY' "$TMP_SEARCH_JSON" > "$TMP_RESULTS"
from pathlib import Path
import json
import sys

data = json.loads(Path(sys.argv[1]).read_text())
results = ((data.get("web") or {}).get("results") or [])[:10]
lines = []
for idx, item in enumerate(results, start=1):
    title = " ".join(str(item.get("title", "")).split())
    url = item.get("url", "")
    description = " ".join(str(item.get("description", "")).split())
    extra = item.get("extra_snippets") or []
    snippet_bits = [description] if description else []
    for snippet in extra[:2]:
        snippet = " ".join(str(snippet).split())
        if snippet:
            snippet_bits.append(snippet)
    snippet_text = " ".join(part for part in snippet_bits if part).strip()
    if not title and not snippet_text:
        continue
    lines.append(f"{idx}. {title}\nURL: {url}\nФрагмент: {snippet_text}")

if not lines:
    raise SystemExit(1)

print("\n\n".join(lines))
PY

write_status "Отправляю в GPT-5.5"
cat > "$TMP_PROMPT" <<EOF
Ты умный исследователь и объясняющий помощник.
Ниже дан исходный запрос пользователя и результаты Brave Search по этой теме.
Сначала быстро соотнеси смысл запроса с найденными результатами, затем дай человеку понятное объяснение по-русски.

Важно:
- ответ будет сразу озвучен голосом;
- всегда отвечай только по-русски, даже если запрос или найденные материалы на другом языке;
- он должен звучать естественно и легко восприниматься на слух;
- опирайся на результаты поиска, а не только на общие знания;
- если в результатах есть расхождения, аккуратно скажи, в чём именно;
- если в выдаче есть очевидный практический ответ, сформулируй его прямо;
- не упоминай "результаты поиска", "источники" и не читай URL вслух;
- не используй markdown, списки с маркерами и служебные фразы.

Формат:
- верни до 4 отдельных смысловых блоков;
- каждый блок должен быть на 1-2 предложения;
- каждая строка должна быть законченной мыслью и хорошо звучать отдельно;
- объяснение должно быть мощным и точным, но без лишней затяжки;
- дай короткую суть, затем важный контекст, затем практический вывод;

Исходный запрос:
$QUERY

Исходный текст пользователя:
$(cat "$TMP_SOURCE" | python3 -c 'import sys; text=sys.stdin.read().strip(); print(text[:2500])')

Результаты Brave Search:
$(cat "$TMP_RESULTS")
EOF

if ! run_codex_search_explain; then
  code=$?
  cat "$TMP_LOG" >&2 || true
  if [ "$code" = "124" ]; then
    echo "SEARCH_EXPLAIN_CODEX_TIMEOUT"
  else
    echo "SEARCH_EXPLAIN_CODEX_FAILED"
  fi
  exit 3
fi

write_status "Нормализую текст"
python3 "$ROOT/local-ai-tools/bin/clean_text_stdin.py" < "$TMP_RAW" > "$TMP_PROMPT"
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
    if len(candidate) <= 260 and candidate.count(".") + candidate.count("!") + candidate.count("?") <= 4:
        current = candidate
    else:
        chunks.append(current)
        current = line

if current:
    chunks.append(current)

chunks = chunks[:4]
print("\n".join(chunks).strip())
PY

printf '\nSEARCH_EXPLAIN_SAVED_TO=%s\n' "$OUT"
