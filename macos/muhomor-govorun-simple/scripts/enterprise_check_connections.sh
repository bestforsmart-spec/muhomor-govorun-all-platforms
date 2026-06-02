#!/bin/zsh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/runtime_env.sh"

ROOT="$RUNTIME_ROOT"
SALUTE_SCRIPT="$ROOT/bin/salute_tts_file.sh"
LOCAL_SCRIPT="$ROOT/bin/local_fast_tts_file.sh"
ELEVENLABS_SCRIPT="$ROOT/bin/elevenlabs_tts_file.sh"
SUMMARY_SCRIPT="$ROOT/bin/summarize_for_voice.sh"
SEARCH_EXPLAIN_SCRIPT="$ROOT/bin/search_explain_for_voice.sh"
SETTINGS="$ROOT/config/voice_extension_settings.json"
BRAVE_ENV="$ROOT/config/brave_search.env"

status_line() {
  printf '%s: %s\n' "$1" "$2"
}

test_salute() {
  local tmp
  tmp=$(mktemp)
  printf 'Проверка подключения.' > "$tmp"
  if SALUTE_SKIP_PLAY=1 "$SALUTE_SCRIPT" "$tmp" >/dev/null 2>&1; then
    status_line "SaluteSpeech" "OK"
  else
    status_line "SaluteSpeech" "Ошибка"
  fi
  rm -f "$tmp"
}

test_gigachat() {
  local backup tmp
  backup=$(mktemp)
  cp "$SETTINGS" "$backup" 2>/dev/null || true
  cat > "$SETTINGS" <<'JSON'
{
  "summary_backend" : "gigachat_api",
  "search_explain_backend" : "gigachat_api",
  "summary_style" : "balanced",
  "tts_backend" : "local_fast",
  "local_tts_voice" : "Milena",
  "voice_label" : "Локальный быстрый голос",
  "voice_style" : "local_fast"
}
JSON
  tmp=$(mktemp)
  printf 'Проверка GigaChat summary.' > "$tmp"
  if "$SUMMARY_SCRIPT" "$tmp" >/dev/null 2>&1; then
    status_line "GigaChat" "OK"
  else
    status_line "GigaChat" "Ошибка"
  fi
  rm -f "$tmp"
  if [ -s "$backup" ]; then
    cp "$backup" "$SETTINGS"
  fi
  rm -f "$backup"
}

test_brave_key() {
  if [ -f "$BRAVE_ENV" ] && grep -q '^BRAVE_SEARCH_API_KEY=.' "$BRAVE_ENV"; then
    status_line "Brave Search" "Ключ сохранён"
  else
    status_line "Brave Search" "Не задан"
  fi
}

test_local_tts() {
  local tmp
  tmp=$(mktemp)
  printf 'Проверка локального голоса.' > "$tmp"
  if LOCAL_TTS_SKIP_PLAY=1 "$LOCAL_SCRIPT" "$tmp" >/dev/null 2>&1; then
    status_line "Локальный быстрый голос" "OK"
  else
    status_line "Локальный быстрый голос" "Ошибка"
  fi
  rm -f "$tmp"
}

test_elevenlabs_tts() {
  local tmp
  tmp=$(mktemp)
  printf 'Проверка красивого голоса.' > "$tmp"
  if ELEVENLABS_TTS_SKIP_PLAY=1 "$ELEVENLABS_SCRIPT" "$tmp" >/dev/null 2>&1; then
    status_line "ElevenLabs" "OK"
  else
    status_line "ElevenLabs" "Ошибка или ключ не задан"
  fi
  rm -f "$tmp"
}

test_local_tts
test_salute
test_elevenlabs_tts
test_gigachat
test_brave_key
