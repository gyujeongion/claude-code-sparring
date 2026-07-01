#!/bin/bash
# debate/bin/advocate.sh — Advocate model caller
#
# Used when delegate_task (Claude Code Architect) is not available,
# or when the user wants a different advocate model.
#
# Backend priority (auto-detect unless SPARRING_ADVOCATE_BACKEND is set):
#   1. anthropic — Anthropic API via ANTHROPIC_API_KEY
#   2. openai    — OpenAI API via OPENAI_API_KEY
#   3. gemini    — Gemini API via GOOGLE_API_KEY
#   4. codex     — Codex CLI
#   5. agy       — Google agy CLI
#
# Env vars:
#   SPARRING_ADVOCATE_BACKEND  = anthropic | openai | gemini | codex | agy
#   SPARRING_ADVOCATE_MODEL    = model name override
#                              anthropic default: claude-opus-4-8
#                              openai default:    gpt-4o
#                              gemini default:    gemini-2.0-flash

set -euo pipefail

PROMPT="${1:-}"
if [ -z "$PROMPT" ]; then
  echo "Usage: advocate.sh <prompt>" >&2
  exit 1
fi

BACKEND="${SPARRING_ADVOCATE_BACKEND:-auto}"

if [ "$BACKEND" = "auto" ]; then
  if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    BACKEND="anthropic"
  elif [ -n "${OPENAI_API_KEY:-}" ]; then
    BACKEND="openai"
  elif [ -n "${GOOGLE_API_KEY:-}" ]; then
    BACKEND="gemini"
  elif command -v codex &>/dev/null; then
    BACKEND="codex"
  elif command -v agy &>/dev/null; then
    BACKEND="agy"
  else
    echo "ERROR: No advocate backend found." >&2
    echo "Set one of: ANTHROPIC_API_KEY, OPENAI_API_KEY, GOOGLE_API_KEY, or install codex/agy" >&2
    exit 1
  fi
fi

case "$BACKEND" in
  anthropic)
    MODEL="${SPARRING_ADVOCATE_MODEL:-claude-opus-4-8}"
    if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
      echo "ERROR: ANTHROPIC_API_KEY not set." >&2; exit 1
    fi
    curl -sf https://api.anthropic.com/v1/messages \
      -H "x-api-key: $ANTHROPIC_API_KEY" \
      -H "anthropic-version: 2023-06-01" \
      -H "Content-Type: application/json" \
      -d "{\"model\":\"$MODEL\",\"max_tokens\":4096,\"messages\":[{\"role\":\"user\",\"content\":$(printf '%s' "$PROMPT" | jq -Rs .)}]}" \
      | jq -r '.content[0].text'
    ;;

  openai)
    MODEL="${SPARRING_ADVOCATE_MODEL:-gpt-4o}"
    if [ -z "${OPENAI_API_KEY:-}" ]; then
      echo "ERROR: OPENAI_API_KEY not set." >&2; exit 1
    fi
    curl -sf https://api.openai.com/v1/chat/completions \
      -H "Authorization: Bearer $OPENAI_API_KEY" \
      -H "Content-Type: application/json" \
      -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":$(printf '%s' "$PROMPT" | jq -Rs .)}]}" \
      | jq -r '.choices[0].message.content'
    ;;

  gemini)
    MODEL="${SPARRING_ADVOCATE_MODEL:-gemini-2.0-flash}"
    if [ -z "${GOOGLE_API_KEY:-}" ]; then
      echo "ERROR: GOOGLE_API_KEY not set." >&2; exit 1
    fi
    curl -sf "https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=$GOOGLE_API_KEY" \
      -H "Content-Type: application/json" \
      -d "{\"contents\":[{\"parts\":[{\"text\":$(printf '%s' "$PROMPT" | jq -Rs .)}]}]}" \
      | jq -r '.candidates[0].content.parts[0].text'
    ;;

  codex)
    MODEL="${SPARRING_ADVOCATE_MODEL:-}"
    _tmpf=$(mktemp /tmp/sparring_advocate.XXXX)
    if [ -n "$MODEL" ]; then
      codex exec --skip-git-repo-check -s read-only --model "$MODEL" -o "$_tmpf" "$PROMPT" >/dev/null 2>&1
    else
      codex exec --skip-git-repo-check -s read-only -o "$_tmpf" "$PROMPT" >/dev/null 2>&1
    fi
    cat "$_tmpf"; rm -f "$_tmpf"
    ;;

  agy)
    agy -p "$PROMPT" 2>/dev/null
    ;;

  *)
    echo "ERROR: Unknown backend '$BACKEND'. Valid: anthropic | openai | gemini | codex | agy" >&2
    exit 1
    ;;
esac
