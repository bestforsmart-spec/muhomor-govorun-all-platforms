#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BOOTSTRAP="$SCRIPT_DIR/bootstrap.command"

ask_text() {
  local prompt="$1"
  local default_value="${2:-}"
  osascript <<EOF
tell application "System Events"
  activate
  text returned of (display dialog "$prompt" default answer "$default_value" buttons {"Продолжить"} default button "Продолжить")
end tell
EOF
}

ask_secret() {
  local prompt="$1"
  osascript <<EOF
tell application "System Events"
  activate
  text returned of (display dialog "$prompt" default answer "" with hidden answer buttons {"Продолжить"} default button "Продолжить")
end tell
EOF
}

ask_choice() {
  local prompt="$1"
  local yes_label="$2"
  local no_label="$3"
  osascript <<EOF
tell application "System Events"
  activate
  button returned of (display dialog "$prompt" buttons {"$no_label", "$yes_label"} default button "$yes_label")
end tell
EOF
}

ask_tts_choice() {
  local prompt="$1"
  osascript <<EOF
tell application "System Events"
  activate
  button returned of (display dialog "$prompt" buttons {"ElevenLabs", "SaluteSpeech", "Локальный"} default button "Локальный")
end tell
EOF
}

show_note() {
  local text="$1"
  osascript <<EOF
tell application "System Events"
  activate
  display dialog "$text" buttons {"Продолжить"} default button "Продолжить"
end tell
EOF
}

show_note "Мухомор - Говорун simple\n\nУстановщик оставит только 3 варианта озвучки: локальный быстрый, SaluteSpeech быстрый облачный и ElevenLabs красивый голос."

SALUTE_AUTH_KEY="$(ask_secret "Шаг 1 из 5\n\nВставьте токен SaluteSpeech API.\n\nМожно оставить поле пустым и настроить позже.")"
GIGACHAT_AUTH_KEY="$(ask_secret "Шаг 2 из 5\n\nВставьте ключ GigaChat API.\n\nОн нужен для команды саммари и озвучки.")"
BRAVE_SEARCH_API_KEY="$(ask_secret "Шаг 3 из 5\n\nВставьте Brave Search API key.\n\nОн нужен для команды Brave поиск + GPT-5.5 голосом.")"
ELEVENLABS_API_KEY="$(ask_secret "Шаг 4 из 5\n\nВставьте ElevenLabs API key для красивого голоса.\n\nМожно оставить поле пустым и настроить позже.")"
DEFAULT_TTS_CHOICE="$(ask_tts_choice "Шаг 5 из 5\n\nКакую озвучку сделать по умолчанию?")"

if [ "$DEFAULT_TTS_CHOICE" = "ElevenLabs" ]; then
  export ENTERPRISE_DEFAULT_TTS="elevenlabs_tts"
elif [ "$DEFAULT_TTS_CHOICE" = "SaluteSpeech" ]; then
  export ENTERPRISE_DEFAULT_TTS="salute_tts"
else
  export ENTERPRISE_DEFAULT_TTS="local_fast"
fi

export ENTERPRISE_SALUTE_AUTH_KEY="$SALUTE_AUTH_KEY"
export ENTERPRISE_GIGACHAT_AUTH_KEY="$GIGACHAT_AUTH_KEY"
export ENTERPRISE_BRAVE_SEARCH_API_KEY="$BRAVE_SEARCH_API_KEY"
export ENTERPRISE_ELEVENLABS_API_KEY="$ELEVENLABS_API_KEY"

"$BOOTSTRAP"
