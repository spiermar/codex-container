#!/bin/bash
set -e

git config --global user.email "${GIT_EMAIL:-codex@local}"
git config --global user.name "${GIT_NAME:-Codex}"

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  echo "Error: OPENAI_API_KEY is required." >&2
  exit 1
fi

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "Error: GITHUB_TOKEN is required." >&2
  exit 1
fi

echo "$GITHUB_TOKEN" | gh auth login --with-token

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
