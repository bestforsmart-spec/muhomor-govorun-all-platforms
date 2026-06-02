#!/bin/zsh

if [ -n "${MUHOMOR_RUNTIME_ENV_LOADED:-}" ]; then
  return 0
fi
export MUHOMOR_RUNTIME_ENV_LOADED=1

if [ -n "${MUHOMOR_HOME:-}" ]; then
  APP_ROOT="$MUHOMOR_HOME"
else
  APP_ROOT="$HOME/.muhomor-govorun"
fi

RUNTIME_ROOT="${MUHOMOR_RUNTIME_ROOT:-$APP_ROOT/local-ai-tools}"
CONFIG_DIR="$RUNTIME_ROOT/config"
RESPONSES_DIR="$RUNTIME_ROOT/responses"

path_parts=(
  "/opt/homebrew/bin"
  "/usr/local/bin"
  "/usr/bin"
  "/bin"
  "/usr/sbin"
  "/sbin"
  "/Library/Frameworks/Python.framework/Versions/3.11/bin"
  "/Applications/Codex.app/Contents/Resources"
)

for node_bin in "$HOME"/.nvm/versions/node/*/bin(N); do
  path_parts=("$node_bin" "${path_parts[@]}")
done

if [ -n "${PATH:-}" ]; then
  path_parts+=("${(s/:/)PATH}")
fi

typeset -Ua path_parts
export PATH="${(j/:/)path_parts}"

export APP_ROOT
export RUNTIME_ROOT
export CONFIG_DIR
export RESPONSES_DIR
export SETTINGS_FILE="$CONFIG_DIR/voice_extension_settings.json"
export SALUTE_ENV_FILE="$CONFIG_DIR/salute_speech.env"
export GIGACHAT_ENV_FILE="$CONFIG_DIR/gigachat.env"
export BRAVE_ENV_FILE="$CONFIG_DIR/brave_search.env"
export ELEVENLABS_ENV_FILE="$CONFIG_DIR/elevenlabs.env"
export SBER_CA_BUNDLE="$CONFIG_DIR/sber-trusted-chain.pem"
