#!/bin/bash
set -euo pipefail

if [[ -z "$(git config --global user.email 2>/dev/null || true)" ]]; then
  git config --global user.email "${GIT_EMAIL:-codex@local}"
fi

if [[ -z "$(git config --global user.name 2>/dev/null || true)" ]]; then
  git config --global user.name "${GIT_NAME:-Codex}"
fi

codex_auth_file="${HOME:-/home/codex}/.codex/auth.json"

case "${MODE:-daemon}" in
  daemon)
    monitor_host="${CODEX_MONITOR_HOST:-0.0.0.0}"
    monitor_port="${CODEX_MONITOR_PORT:-4732}"

    if [[ ! -f "$codex_auth_file" ]] && [[ -z "${OPENAI_API_KEY:-}" ]]; then
      echo "Error: OPENAI_API_KEY is required." >&2
      exit 1
    fi

    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
      echo "Error: GITHUB_TOKEN is required." >&2
      exit 1
    fi

    if [[ -z "${CODEX_MONITOR_TOKEN:-}" ]] && [[ "$monitor_host" != "127.0.0.1" ]] && [[ "$monitor_host" != "localhost" ]]; then
      echo "Error: CODEX_MONITOR_TOKEN is required when MODE=daemon binds CODEX_MONITOR_HOST to '$monitor_host'. Use 127.0.0.1 or localhost for unauthenticated local-only access." >&2
      exit 1
    fi

    gh auth setup-git

    echo "Starting Codex Monitor daemon..."
    daemon_cmd=(
      codex_monitor_daemon
      --host "$monitor_host"
      --port "$monitor_port"
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
