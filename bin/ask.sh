#!/bin/bash
# debate/bin/ask.sh — Critic model caller (no council dependency)
#
# Backend priority (auto-detect unless SPARRING_CRITIC_BACKEND is set):
#   1. codex  — OpenAI Codex CLI with ChatGPT Plus OAuth (zero API cost)
#   2. openai — OpenAI API via OPENAI_API_KEY
#   3. agy    — Google AI CLI
#   4. gemini — Gemini API via GOOGLE_API_KEY
#
# Env vars:
#   SPARRING_CRITIC_BACKEND  = codex | openai | agy | gemini  (auto if unset)
#   SPARRING_CRITIC_MODEL    = model name override
#                            codex/openai default: gpt-4o
#                            agy/gemini default:   gemini-2.0-flash

set -euo pipefail

PROMPT="${1:-}"
if [ -z "$PROMPT" ]; then
  echo "Usage: ask.sh <prompt>" >&2
  exit 1
fi

BACKEND="${SPARRING_CRITIC_BACKEND:-auto}"

# Auto-detect
if [ "$BACKEND" = "auto" ]; then
  if command -v codex &>/dev/null; then
    BACKEND="codex"
  elif [ -n "${OPENAI_API_KEY:-}" ]; then
    BACKEND="openai"
  elif command -v agy &>/dev/null; then
    BACKEND="agy"
  elif [ -n "${GOOGLE_API_KEY:-}" ]; then
    BACKEND="gemini"
  else
    echo "ERROR: No critic backend found." >&2
    echo "Install one of: codex CLI, set OPENAI_API_KEY, install agy, or set GOOGLE_API_KEY" >&2
    echo "See README.md for setup instructions." >&2
    exit 1
  fi
fi

case "$BACKEND" in
  codex)
    MODEL="${SPARRING_CRITIC_MODEL:-}"
    _tmpf=$(mktemp /tmp/sparring_critic.XXXX)
    if [ -n "$MODEL" ]; then
      codex exec --skip-git-repo-check -s read-only --model "$MODEL" -o "$_tmpf" "$PROMPT" >/dev/null 2>&1
    else
      codex exec --skip-git-repo-check -s read-only -o "$_tmpf" "$PROMPT" >/dev/null 2>&1
    fi
    cat "$_tmpf"
    rm -f "$_tmpf"
    ;;

  openai)
    MODEL="${SPARRING_CRITIC_MODEL:-gpt-4o}"
    if [ -z "${OPENAI_API_KEY:-}" ]; then
      echo "ERROR: OPENAI_API_KEY not set." >&2; exit 1
    fi
    curl -sf https://api.openai.com/v1/chat/completions \
      -H "Authorization: Bearer $OPENAI_API_KEY" \
      -H "Content-Type: application/json" \
      -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":$(printf '%s' "$PROMPT" | jq -Rs .)}]}" \
      | jq -r '.choices[0].message.content'
    ;;

  agy)
    agy -p "$PROMPT" 2>/dev/null
    ;;

  gemini)
    MODEL="${SPARRING_CRITIC_MODEL:-gemini-2.0-flash}"
    if [ -z "${GOOGLE_API_KEY:-}" ]; then
      echo "ERROR: GOOGLE_API_KEY not set." >&2; exit 1
    fi
    curl -sf "https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=$GOOGLE_API_KEY" \
      -H "Content-Type: application/json" \
      -d "{\"contents\":[{\"parts\":[{\"text\":$(printf '%s' "$PROMPT" | jq -Rs .)}]}]}" \
      | jq -r '.candidates[0].content.parts[0].text'
    ;;

  *)
    echo "ERROR: Unknown backend '$BACKEND'. Valid: codex | openai | agy | gemini" >&2
    exit 1
    ;;
esac
