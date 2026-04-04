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

case "${MODE:-daemon}" in
  daemon)
    echo "Starting Codex Monitor daemon..."
    daemon_cmd=(
      codex_monitor_daemon
      --host "${CODEX_MONITOR_HOST}"
      --port "${CODEX_MONITOR_PORT}"
    )

    if [[ -n "${CODEX_MONITOR_TOKEN:-}" ]]; then
      daemon_cmd+=(--token "${CODEX_MONITOR_TOKEN}")
    fi

    daemon_cmd+=(--data-dir /home/codex/.codexmonitor)

    printf 'Executing:'
    printf ' %q' "${daemon_cmd[@]}"
    printf '\n'

    exec "${daemon_cmd[@]}"
    ;;
  interactive)
    echo "Starting interactive shell..."
    exec /bin/bash
    ;;
  *)
    echo "Error: unsupported MODE '${MODE}'. Supported modes: daemon, interactive" >&2
    exit 1
    ;;
esac
