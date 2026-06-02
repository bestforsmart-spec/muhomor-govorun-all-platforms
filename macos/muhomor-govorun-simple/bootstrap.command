#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_SCRIPTS="$SCRIPT_DIR/scripts"
SRC_HAMMERSPOON="$SCRIPT_DIR/hammerspoon/init.lua"
BREWFILE="$SCRIPT_DIR/Brewfile"

DEST_ROOT="$HOME/.muhomor-govorun/local-ai-tools"
DEST_BIN="$DEST_ROOT/bin"
DEST_CONFIG="$DEST_ROOT/config"
DEST_RESPONSES="$DEST_ROOT/responses"
DEST_HAMMERSPOON_DIR="$HOME/.hammerspoon"
DEST_HAMMERSPOON_INIT="$DEST_HAMMERSPOON_DIR/init.lua"
DEST_SERVICES_DIR="$HOME/Library/Services"
SETTINGS_FILE="$DEST_CONFIG/voice_extension_settings.json"
SALUTE_ENV_FILE="$DEST_CONFIG/salute_speech.env"
GIGACHAT_ENV_FILE="$DEST_CONFIG/gigachat.env"
ELEVENLABS_ENV_FILE="$DEST_CONFIG/elevenlabs.env"
BRAVE_ENV_FILE="$DEST_CONFIG/brave_search.env"
SBER_CA_BUNDLE="$DEST_CONFIG/sber-trusted-chain.pem"

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_ROOT="$HOME/.muhomor-govorun/backups-muhomor-govorun/$STAMP"
BRAND_NAME="Мухомор - Говорун"

say_step() {
  echo
  echo "==> $1"
}

fail() {
  echo
  echo "Ошибка: $1" >&2
  exit 1
}

ensure_xcode_tools() {
  if xcode-select -p >/dev/null 2>&1; then
    return
  fi
  echo "Командные инструменты Xcode не найдены. Пытаюсь запустить установку..."
  xcode-select --install >/dev/null 2>&1 || true
  fail "Установите Command Line Tools, затем запустите install.command ещё раз."
}

ensure_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    return
  fi
  say_step "Устанавливаю Homebrew"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

ensure_brew_env() {
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

backup_existing_files() {
  mkdir -p "$BACKUP_ROOT/bin" "$BACKUP_ROOT/hammerspoon" "$BACKUP_ROOT/config"
  if [ -d "$DEST_BIN" ]; then
    for file in "$SRC_SCRIPTS"/*; do
      local name
      name="$(basename "$file")"
      if [ -f "$DEST_BIN/$name" ]; then
        cp "$DEST_BIN/$name" "$BACKUP_ROOT/bin/$name"
      fi
    done
  fi
  if [ -f "$DEST_HAMMERSPOON_INIT" ]; then
    cp "$DEST_HAMMERSPOON_INIT" "$BACKUP_ROOT/hammerspoon/init.lua"
  fi
  if [ -f "$SETTINGS_FILE" ]; then
    cp "$SETTINGS_FILE" "$BACKUP_ROOT/config/voice_extension_settings.json"
  fi
}

write_default_settings() {
  local default_tts
  default_tts="${ENTERPRISE_DEFAULT_TTS:-local_fast}"
  cat > "$SETTINGS_FILE" <<EOF
{
  "summary_backend" : "gigachat_api",
  "search_explain_backend" : "gigachat_api",
  "summary_style" : "balanced",
  "tts_backend" : "$default_tts",
  "local_tts_voice" : "Milena",
  "voice_label" : "Локальный быстрый голос",
  "voice_style" : "local_fast"
}
EOF
}

write_elevenlabs_env() {
  local elevenlabs_key elevenlabs_voice elevenlabs_model
  elevenlabs_key="${ENTERPRISE_ELEVENLABS_API_KEY:-}"
  elevenlabs_voice="${ENTERPRISE_ELEVENLABS_VOICE_ID:-JBFqnCBsd6RMkjVDRZzb}"
  elevenlabs_model="${ENTERPRISE_ELEVENLABS_MODEL_ID:-eleven_multilingual_v2}"
  cat > "$ELEVENLABS_ENV_FILE" <<EOF
ELEVENLABS_API_KEY=$elevenlabs_key
ELEVENLABS_VOICE_ID=$elevenlabs_voice
ELEVENLABS_MODEL_ID=$elevenlabs_model
ELEVENLABS_OUTPUT_FORMAT=mp3_44100_128
ELEVENLABS_STABILITY=0.48
ELEVENLABS_SIMILARITY_BOOST=0.78
ELEVENLABS_STYLE=0.18
EOF
  chmod 600 "$ELEVENLABS_ENV_FILE"
}

write_salute_env() {
  local salute_key salute_insecure
  salute_key="${ENTERPRISE_SALUTE_AUTH_KEY:-}"
  salute_insecure="${ENTERPRISE_SALUTE_CURL_INSECURE:-0}"
  cat > "$SALUTE_ENV_FILE" <<EOF
SALUTE_AUTH_KEY=$salute_key
SALUTE_SCOPE=SALUTE_SPEECH_PERS
SALUTE_VOICE=Ost_24000
SALUTE_FORMAT=wav16
SALUTE_CURL_INSECURE=$salute_insecure
SALUTE_CA_BUNDLE=$SBER_CA_BUNDLE
EOF
  chmod 600 "$SALUTE_ENV_FILE"
}

write_gigachat_env() {
  local gigachat_key gigachat_insecure
  gigachat_key="${ENTERPRISE_GIGACHAT_AUTH_KEY:-}"
  gigachat_insecure="${ENTERPRISE_GIGACHAT_CURL_INSECURE:-0}"
  cat > "$GIGACHAT_ENV_FILE" <<EOF
GIGACHAT_AUTH_KEY=$gigachat_key
GIGACHAT_MODEL=GigaChat
GIGACHAT_EXPLAIN_MODEL=GigaChat
GIGACHAT_SCOPE=GIGACHAT_API_PERS
GIGACHAT_CURL_INSECURE=$gigachat_insecure
GIGACHAT_CA_BUNDLE=$SBER_CA_BUNDLE
EOF
  chmod 600 "$GIGACHAT_ENV_FILE"
}

write_brave_env() {
  local brave_key brave_count
  brave_key="${ENTERPRISE_BRAVE_SEARCH_API_KEY:-}"
  brave_count="${ENTERPRISE_BRAVE_SEARCH_COUNT:-8}"
  cat > "$BRAVE_ENV_FILE" <<EOF
BRAVE_SEARCH_API_KEY=$brave_key
BRAVE_SEARCH_COUNT=$brave_count
EOF
  chmod 600 "$BRAVE_ENV_FILE"
}

write_sber_bundle() {
  openssl s_client -showcerts -connect ngw.devices.sberbank.ru:9443 -servername ngw.devices.sberbank.ru </dev/null 2>/dev/null > "$DEST_CONFIG/sber-full-chain.txt"
  python3 - <<'PY' "$DEST_CONFIG/sber-full-chain.txt" "$SBER_CA_BUNDLE"
from pathlib import Path
import sys

src = Path(sys.argv[1]).read_text()
dst = Path(sys.argv[2])
parts = []
cur = []
inside = False
for line in src.splitlines():
    if 'BEGIN CERTIFICATE' in line:
        inside = True
        cur = [line]
    elif 'END CERTIFICATE' in line and inside:
        cur.append(line)
        parts.append('\n'.join(cur) + '\n')
        inside = False
        cur = []
    elif inside:
        cur.append(line)

if len(parts) >= 3:
    dst.write_text(parts[1] + parts[2])
elif len(parts) >= 2:
    dst.write_text(parts[1])
else:
    raise SystemExit(1)
PY
  rm -f "$DEST_CONFIG/sber-full-chain.txt"
}

install_brew_dependencies() {
  say_step "Устанавливаю системные зависимости"
  brew bundle --file="$BREWFILE"
}

prepare_directories() {
  mkdir -p "$DEST_BIN" "$DEST_CONFIG" "$DEST_RESPONSES" "$DEST_HAMMERSPOON_DIR"
  mkdir -p "$DEST_SERVICES_DIR"
}

copy_project_files() {
  say_step "Копирую файлы проекта"
  cp "$SRC_SCRIPTS"/* "$DEST_BIN/"
  chmod 700 "$DEST_BIN"/*.sh "$DEST_BIN"/*.py
  cp "$SRC_HAMMERSPOON" "$DEST_HAMMERSPOON_INIT"
  if [ -d "$SCRIPT_DIR/services" ]; then
    cp -R "$SCRIPT_DIR/services/." "$DEST_SERVICES_DIR/"
  fi
  write_sber_bundle
  write_default_settings
  write_salute_env
  write_gigachat_env
  write_brave_env
  write_elevenlabs_env
}

restart_hammerspoon() {
  say_step "Перезапускаю Hammerspoon"
  pkill -f '/Applications/Hammerspoon.app/Contents/MacOS/Hammerspoon' >/dev/null 2>&1 || true
  sleep 1
  open -na /Applications/Hammerspoon.app >/dev/null 2>&1 || true
}

print_finish() {
  echo
  echo "$BRAND_NAME v1.0 установлен."
  echo "Резервные копии сохранены в: $BACKUP_ROOT"
  echo
  echo "Горячие клавиши:"
  echo "  Cmd+D        саммари и озвучка"
  echo "  Cmd+Alt+S    саммари и озвучка"
  echo "  Cmd+Alt+B    Brave поиск + GPT-5.5 голосом"
  echo
  echo "Команды в верхнем меню:"
  echo "  Саммари и озвучка"
  echo "  Brave поиск + GPT-5.5 голосом"
  echo
  echo "По умолчанию:"
  echo "  TTS: ${ENTERPRISE_DEFAULT_TTS:-local_fast}"
  echo "  Summary: GigaChat API"
  echo
  if [ -n "${ENTERPRISE_SALUTE_AUTH_KEY:-}" ]; then
    echo "SaluteSpeech токен сохранён."
  else
    echo "SaluteSpeech токен не введён. Его можно добавить позже."
  fi
  if [ -n "${ENTERPRISE_GIGACHAT_AUTH_KEY:-}" ]; then
    echo "GigaChat ключ сохранён."
  else
    echo "GigaChat ключ не введён. Без него summary и пояснения не заработают."
  fi
  if [ -n "${ENTERPRISE_ELEVENLABS_API_KEY:-}" ]; then
    echo "ElevenLabs ключ сохранён."
  else
    echo "ElevenLabs ключ не введён. Красивый голос можно подключить позже."
  fi
  echo
  echo "Дальше можно открыть меню \"$BRAND_NAME\" в верхней строке и управлять настройками."
}

main() {
  [ "$(uname -s)" = "Darwin" ] || fail "Этот установщик рассчитан на macOS."
  ensure_xcode_tools
  ensure_homebrew
  ensure_brew_env
  backup_existing_files
  install_brew_dependencies
  prepare_directories
  copy_project_files
  restart_hammerspoon
  print_finish
}

main "$@"
