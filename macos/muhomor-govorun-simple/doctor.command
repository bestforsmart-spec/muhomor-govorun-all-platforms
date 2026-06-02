#!/bin/zsh
set -euo pipefail

ROOT="$HOME/.muhomor-govorun/local-ai-tools"
SETTINGS_FILE="$ROOT/config/voice_extension_settings.json"
SALUTE_ENV_FILE="$ROOT/config/salute_speech.env"
GIGACHAT_ENV_FILE="$ROOT/config/gigachat.env"
BRAVE_ENV_FILE="$ROOT/config/brave_search.env"
ELEVENLABS_ENV_FILE="$ROOT/config/elevenlabs.env"

ok() {
  echo "[OK] $1"
}

warn() {
  echo "[WARN] $1"
}

check_cmd() {
  if command -v "$1" >/dev/null 2>&1; then
    ok "Найдена команда: $1"
  else
    warn "Не найдена команда: $1"
  fi
}

echo "Проверка Мухомор - Говорун simple"
echo

[ -d /Applications/Hammerspoon.app ] && ok "Hammerspoon установлен" || warn "Hammerspoon не установлен"
[ -f "$HOME/.hammerspoon/init.lua" ] && ok "Hammerspoon config установлен" || warn "Hammerspoon config отсутствует"
[ -f "$SETTINGS_FILE" ] && ok "Файл настроек найден" || warn "Файл настроек не найден"
[ -f "$SALUTE_ENV_FILE" ] && ok "SaluteSpeech env найден" || warn "SaluteSpeech env не найден"
[ -f "$GIGACHAT_ENV_FILE" ] && ok "GigaChat env найден" || warn "GigaChat env не найден"
[ -f "$BRAVE_ENV_FILE" ] && ok "Brave Search env найден" || warn "Brave Search env не найден"
[ -f "$ELEVENLABS_ENV_FILE" ] && ok "ElevenLabs env найден" || warn "ElevenLabs env не найден"
[ -f "$ROOT/config/sber-trusted-chain.pem" ] && ok "Sber CA bundle найден" || warn "Sber CA bundle не найден"

check_cmd brew
check_cmd ffmpeg
check_cmd ffprobe
check_cmd say

echo
echo "Если есть предупреждения, запустите repair.command"
