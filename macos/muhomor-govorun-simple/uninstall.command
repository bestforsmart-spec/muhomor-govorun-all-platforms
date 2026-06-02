#!/bin/zsh
set -euo pipefail

DEST_BIN="$HOME/.muhomor-govorun/local-ai-tools/bin"
DEST_HAMMERSPOON_INIT="$HOME/.hammerspoon/init.lua"
BACKUP_BASE="$HOME/.muhomor-govorun/backups-muhomor-govorun"
SERVICES_DIR="$HOME/Library/Services"

LATEST_BACKUP="$(ls -td "$BACKUP_BASE"/* 2>/dev/null | head -n 1 || true)"

for name in \
  bootstrap.command \
  enterprise-install.command \
  doctor.command \
  repair.command \
  enterprise_check_connections.sh \
  speak_file.sh \
  summarize_for_voice.sh \
  summarize_and_speak.sh \
  speak_chunks_file.sh \
  local_fast_tts_file.sh \
  salute_tts_file.sh \
  elevenlabs_tts_file.sh \
  elevenlabs_tts_file.py \
  transcribe_audio.py \
  voice_push_to_talk.sh \
  clean_for_voice.py \
  prepare_natural_tts_text.py \
  clean_text_stdin.py \
  normalize_summary.py
do
  rm -f "$DEST_BIN/$name"
done

rm -rf "$SERVICES_DIR/Мухомор - Говорун Озвучить.workflow"
rm -rf "$SERVICES_DIR/Мухомор - Говорун Пересказать.workflow"

if [ -n "${LATEST_BACKUP:-}" ] && [ -d "$LATEST_BACKUP/bin" ]; then
  cp "$LATEST_BACKUP/bin/"* "$DEST_BIN/" 2>/dev/null || true
fi

if [ -n "${LATEST_BACKUP:-}" ] && [ -f "$LATEST_BACKUP/hammerspoon/init.lua" ]; then
  cp "$LATEST_BACKUP/hammerspoon/init.lua" "$DEST_HAMMERSPOON_INIT"
fi

pkill -f '/Applications/Hammerspoon.app/Contents/MacOS/Hammerspoon' >/dev/null 2>&1 || true
sleep 1
open -na /Applications/Hammerspoon.app >/dev/null 2>&1 || true

echo
echo "Мухомор - Говорун simple удалён."
if [ -n "${LATEST_BACKUP:-}" ]; then
  echo "Restored from backup: $LATEST_BACKUP"
fi
