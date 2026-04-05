#!/bin/bash
set -euo pipefail

if [[ -z "$(git config --global user.email 2>/dev/null || true)" ]]; then
  git config --global user.email "${GIT_EMAIL:-codex@local}"
fi

if [[ -z "$(git config --global user.name 2>/dev/null || true)" ]]; then
  git config --global user.name "${GIT_NAME:-Codex}"
fi

codex_auth_file="${HOME:-/home/codex}/.codex/auth.json"

if [[ ! -f "$codex_auth_file" ]] && [[ -z "${OPENAI_API_KEY:-}" ]]; then
  echo "Error: OPENAI_API_KEY is required." >&2
  exit 1
fi

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "Error: GITHUB_TOKEN is required." >&2
  exit 1
fi

gh auth setup-git

case "${MODE:-interactive}" in
  interactive)
    echo "Starting interactive shell..."
    exec /bin/bash
    ;;
  *)
    echo "Error: unsupported MODE '${MODE}'. Supported modes: interactive" >&2
    exit 1
    ;;
esac
