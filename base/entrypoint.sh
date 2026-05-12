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

start_ssh_server() {
  local ssh_public_key_file="${SSH_PUBLIC_KEY_FILE:-}"

  if [[ -z "$ssh_public_key_file" ]]; then
    echo "Error: SSH_PUBLIC_KEY_FILE is required for MODE=server." >&2
    exit 1
  fi

  if [[ ! -f "$ssh_public_key_file" ]]; then
    echo "Error: SSH_PUBLIC_KEY_FILE '$ssh_public_key_file' does not exist." >&2
    exit 1
  fi

  if [[ ! -r "$ssh_public_key_file" ]]; then
    echo "Error: SSH_PUBLIC_KEY_FILE '$ssh_public_key_file' is not readable." >&2
    exit 1
  fi

  local ssh_dir="${HOME:-/home/codex}/.ssh"
  local authorized_keys_file="$ssh_dir/authorized_keys"

  mkdir -p "$ssh_dir"
  chmod 700 "$ssh_dir"
  cp "$ssh_public_key_file" "$authorized_keys_file"
  chmod 600 "$authorized_keys_file"

  sudo ssh-keygen -A
  sudo mkdir -p /run/sshd

  echo "Starting SSH server on 0.0.0.0:22..."
  exec sudo /usr/sbin/sshd -D -e
}

case "${MODE:-interactive}" in
  interactive)
    echo "Starting interactive shell..."
    exec /bin/bash
    ;;
  server)
    start_ssh_server
    ;;
  *)
    echo "Error: unsupported MODE '${MODE}'. Supported modes: interactive, server" >&2
    exit 1
    ;;
esac
