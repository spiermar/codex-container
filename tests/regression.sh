#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"

  [[ "$haystack" == *"$needle"* ]] || fail "expected output to contain '$needle'"
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"

  [[ "$haystack" != *"$needle"* ]] || fail "expected output to not contain '$needle'"
}

write_stub() {
  local path="$1"
  local content="$2"

  printf '%s\n' "$content" >"$path"
  chmod +x "$path"
}

test_base_allows_auth_json_without_openai_api_key() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN

  mkdir -p "$tmp_dir/bin" "$tmp_dir/home/.codex"
  printf '{}\n' >"$tmp_dir/home/.codex/auth.json"

  write_stub "$tmp_dir/bin/gh" '#!/bin/bash
exit 0'

  local stdout stderr output status
  stdout="$tmp_dir/stdout"
  stderr="$tmp_dir/stderr"

  set +e
  HOME="$tmp_dir/home" \
    OPENAI_API_KEY= \
    GITHUB_TOKEN=test-github-token \
    MODE=interactive \
    PATH="$tmp_dir/bin:/usr/bin:/bin" \
    bash "$repo_root/base/entrypoint.sh" >"$stdout" 2>"$stderr"
  status=$?
  set -e

  output="$(<"$stdout")\n$(<"$stderr")"

  [[ $status -eq 0 ]] || fail 'expected base entrypoint with auth.json to succeed without OPENAI_API_KEY'
  assert_contains "$output" 'Starting interactive shell'
}

test_base_requires_openai_api_key_without_auth_json() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN

  mkdir -p "$tmp_dir/bin" "$tmp_dir/home"
  write_stub "$tmp_dir/bin/gh" '#!/bin/bash
exit 0'

  local stdout stderr output status
  stdout="$tmp_dir/stdout"
  stderr="$tmp_dir/stderr"

  set +e
  HOME="$tmp_dir/home" \
    OPENAI_API_KEY= \
    GITHUB_TOKEN=test-github-token \
    MODE=interactive \
    PATH="$tmp_dir/bin:/usr/bin:/bin" \
    bash "$repo_root/base/entrypoint.sh" >"$stdout" 2>"$stderr"
  status=$?
  set -e

  output="$(<"$stdout")\n$(<"$stderr")"

  [[ $status -ne 0 ]] || fail 'expected base entrypoint without auth.json or OPENAI_API_KEY to fail'
  assert_contains "$output" 'Error: OPENAI_API_KEY is required.'
}

test_base_server_mode_requires_ssh_public_key_file() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN

  mkdir -p "$tmp_dir/bin" "$tmp_dir/home/.codex"
  printf '{}\n' >"$tmp_dir/home/.codex/auth.json"

  write_stub "$tmp_dir/bin/gh" '#!/bin/bash
exit 0'

  local stdout stderr output status
  stdout="$tmp_dir/stdout"
  stderr="$tmp_dir/stderr"

  set +e
  HOME="$tmp_dir/home" \
    OPENAI_API_KEY= \
    GITHUB_TOKEN=test-github-token \
    MODE=server \
    SSH_PUBLIC_KEY_FILE= \
    PATH="$tmp_dir/bin:/usr/bin:/bin" \
    bash "$repo_root/base/entrypoint.sh" >"$stdout" 2>"$stderr"
  status=$?
  set -e

  output="$(<"$stdout")\n$(<"$stderr")"

  [[ $status -ne 0 ]] || fail 'expected base server mode without SSH_PUBLIC_KEY_FILE to fail'
  assert_contains "$output" 'Error: SSH_PUBLIC_KEY_FILE is required for MODE=server.'
}

test_base_server_mode_installs_authorized_key_and_starts_sshd() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN

  mkdir -p "$tmp_dir/bin" "$tmp_dir/home/.codex"
  printf '{}\n' >"$tmp_dir/home/.codex/auth.json"
  printf 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleCodexPublicKeyForTests codex@test\n' >"$tmp_dir/key.pub"

  write_stub "$tmp_dir/bin/gh" '#!/bin/bash
exit 0'

  write_stub "$tmp_dir/bin/sudo" '#!/bin/bash
if [[ "$1" == "ssh-keygen" && "$2" == "-A" ]]; then
  exit 0
fi

if [[ "$1" == "mkdir" && "$2" == "-p" && "$3" == "/run/sshd" ]]; then
  exit 0
fi

if [[ "$1" == "/usr/sbin/sshd" && "$2" == "-D" && "$3" == "-e" ]]; then
  echo "stub sshd started"
  exit 0
fi

echo "unexpected sudo command: $*" >&2
exit 1'

  local stdout stderr output status
  stdout="$tmp_dir/stdout"
  stderr="$tmp_dir/stderr"

  set +e
  HOME="$tmp_dir/home" \
    OPENAI_API_KEY= \
    GITHUB_TOKEN=test-github-token \
    MODE=server \
    SSH_PUBLIC_KEY_FILE="$tmp_dir/key.pub" \
    PATH="$tmp_dir/bin:/usr/bin:/bin" \
    bash "$repo_root/base/entrypoint.sh" >"$stdout" 2>"$stderr"
  status=$?
  set -e

  output="$(<"$stdout")\n$(<"$stderr")"

  [[ $status -eq 0 ]] || fail 'expected base server mode with SSH_PUBLIC_KEY_FILE to start sshd'
  assert_contains "$output" 'Starting SSH server on 0.0.0.0:22...'
  assert_contains "$output" 'stub sshd started'
  assert_contains "$(<"$tmp_dir/home/.ssh/authorized_keys")" 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleCodexPublicKeyForTests codex@test'
}

test_base_entrypoint_supports_ssh_server_mode() {
  local entrypoint
  entrypoint="$(<"$repo_root/base/entrypoint.sh")"

  assert_contains "$entrypoint" 'server)'
  assert_contains "$entrypoint" 'ssh_public_key_file="${SSH_PUBLIC_KEY_FILE:-}"'
  assert_contains "$entrypoint" 'cp "$ssh_public_key_file" "$authorized_keys_file"'
  assert_contains "$entrypoint" 'sudo ssh-keygen -A'
  assert_contains "$entrypoint" 'exec sudo /usr/sbin/sshd -D -e'
  assert_contains "$entrypoint" "Supported modes: interactive, server"
  assert_not_contains "$entrypoint" 'codex app-server'
  assert_not_contains "$entrypoint" 'APP_SERVER_HOST'
  assert_not_contains "$entrypoint" 'APP_SERVER_PORT'
}

test_clean_skips_when_docker_is_unavailable() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN

  local output status
  set +e
  output="$(PATH="$tmp_dir/bin" /usr/bin/make -C "$repo_root" clean 2>&1)"
  status=$?
  set -e

  [[ $status -eq 0 ]] || fail 'expected make clean to succeed when Docker is unavailable'
  assert_contains "$output" 'Skipping clean'
  assert_not_contains "$output" 'Successfully removed'
}

test_clean_reports_completion_when_docker_is_available() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN

  mkdir -p "$tmp_dir/bin"
  write_stub "$tmp_dir/bin/docker" '#!/bin/bash
if [[ "$1" == "image" && "$2" == "rm" && "$3" == "-f" ]]; then
  exit 0
fi

exit 1'

  local output
  output="$(PATH="$tmp_dir/bin:/bin" /usr/bin/make -C "$repo_root" clean 2>&1)"

  assert_contains "$output" 'Removing Docker images'
  assert_contains "$output" 'Docker image cleanup complete'
}

test_superpowers_dockerfile_builds_from_base_without_monitor() {
  local dockerfile
  dockerfile="$(<"$repo_root/codex-superpowers/Dockerfile")"

  assert_not_contains "$dockerfile" 'FROM codex-monitor:latest'
  assert_contains "$dockerfile" 'FROM codex-base:latest'
  assert_not_contains "$dockerfile" 'codex_monitor_daemonctl'
}

test_makefile_uses_two_image_model() {
  local makefile
  makefile="$(<"$repo_root/Makefile")"

  assert_contains "$makefile" '.PHONY: all base codex-superpowers clean test test-base test-superpowers'
  assert_contains "$makefile" 'all: base codex-superpowers'
  assert_contains "$makefile" 'test: test-base test-superpowers'
  assert_contains "$makefile" 'codex-superpowers: base'
  assert_not_contains "$makefile" 'MONITOR_IMAGE :='
  assert_not_contains "$makefile" 'codex-monitor:'
  assert_not_contains "$makefile" 'test-monitor:'
  assert_not_contains "$makefile" 'codex-monitor '
}

test_base_dockerfile_creates_codex_user_with_uid_gid_1000() {
  local dockerfile
  dockerfile="$(<"$repo_root/base/Dockerfile")"

  assert_contains "$dockerfile" 'getent passwd 1000'
  assert_contains "$dockerfile" 'getent passwd codex >/dev/null'
  assert_contains "$dockerfile" 'userdel -r codex 2>/dev/null || true'
  assert_contains "$dockerfile" "'\$4 == 1000 {print \$1}'"
  assert_contains "$dockerfile" 'existing_group="$(getent group 1000 | cut -d: -f1)"'
  assert_contains "$dockerfile" 'groupmod -n "codex-old-$$" codex'
  assert_contains "$dockerfile" 'groupmod -n codex "$existing_group"'
  assert_contains "$dockerfile" 'elif getent group codex >/dev/null; then'
  assert_contains "$dockerfile" 'groupmod -g 1000 codex'
  assert_contains "$dockerfile" 'groupadd -g 1000 codex'
  assert_contains "$dockerfile" 'useradd -u 1000 -g 1000 -m -s /bin/bash codex'
}

test_base_dockerfile_precreates_codex_config_dir() {
  local dockerfile
  dockerfile="$(<"$repo_root/base/Dockerfile")"

  assert_contains "$dockerfile" 'mkdir -p /home/codex/.codex /home/codex/workspace'
}

test_base_dockerfile_sets_ssh_server_defaults() {
  local dockerfile
  dockerfile="$(<"$repo_root/base/Dockerfile")"

  assert_contains "$dockerfile" 'openssh-server'
  assert_contains "$dockerfile" '/etc/ssh/sshd_config.d/codex.conf'
  assert_contains "$dockerfile" 'rm -f /etc/ssh/ssh_host_*'
  assert_contains "$dockerfile" 'EXPOSE 22'
  assert_contains "$dockerfile" 'ENV MODE=interactive \
    SSH_PUBLIC_KEY_FILE=/run/codex/authorized_key.pub \
    GIT_EMAIL=codex@local \
    GIT_NAME=Codex \
    NVM_DIR=/home/codex/.nvm'
  assert_not_contains "$dockerfile" 'APP_SERVER_HOST'
  assert_not_contains "$dockerfile" 'APP_SERVER_PORT'
}

test_readme_documents_auth_json_mount() {
  local readme
  readme="$(<"$repo_root/README.md")"

  assert_contains "$readme" '/home/codex/.codex/auth.json'
  assert_contains "$readme" '-v "$HOME/.codex/auth.json:/home/codex/.codex/auth.json:ro"'
  assert_contains "$readme" 'requires either `/home/codex/.codex/auth.json` or `OPENAI_API_KEY`'
  assert_contains "$readme" '| `OPENAI_API_KEY` | If `/home/codex/.codex/auth.json` is not mounted | none | Required by the entrypoint unless the auth file is mounted |'
  assert_contains "$readme" '`OPENAI_API_KEY` can also be omitted if `-v "$HOME/.codex/auth.json:/home/codex/.codex/auth.json:ro"` is used.'
  assert_contains "$readme" 'When `/home/codex/.codex/auth.json` is mounted, `OPENAI_API_KEY` is optional.'
  assert_not_contains "$readme" 'valid `OPENAI_API_KEY` and `GITHUB_TOKEN` when using authenticated Codex workflows'
  assert_not_contains "$readme" $'- requires `OPENAI_API_KEY`\n- requires `GITHUB_TOKEN`'
  assert_not_contains "$readme" '| `OPENAI_API_KEY` | Yes | none | Required by the entrypoint |'
}

test_readme_documents_two_image_model() {
  local readme
  readme="$(<"$repo_root/README.md")"

  assert_contains "$readme" '| `codex-base` | Interactive Codex CLI environment with common development tools preinstalled |'
  assert_contains "$readme" '| `codex-superpowers` | Extends `codex-base` with baked-in Superpowers skills and Codex multi-agent config |'
  assert_contains "$readme" '- `make codex-superpowers` builds `codex-superpowers:latest` after building `codex-base`'
  assert_contains "$readme" '`codex-superpowers` accepts the same environment variables and entrypoint behavior as `codex-base`'
  assert_not_contains "$readme" '| `codex-monitor` |'
  assert_not_contains "$readme" '## Running `codex-monitor`'
  assert_not_contains "$readme" '### `codex-monitor`'
  assert_not_contains "$readme" 'CODEX_MONITOR_TOKEN'
}

test_readme_documents_ssh_server_mode() {
  local readme
  readme="$(<"$repo_root/README.md")"

  assert_contains "$readme" '- starts `sshd` on port 22 when `MODE=server`'
  assert_contains "$readme" '| `MODE` | No | `interactive` | Supported values: `interactive`, `server` |'
  assert_contains "$readme" '| `SSH_PUBLIC_KEY_FILE` | For `MODE=server` | `/run/codex/authorized_key.pub` | Public key file copied to `/home/codex/.ssh/authorized_keys` before `sshd` starts |'
  assert_contains "$readme" 'Server mode example:'
  assert_contains "$readme" 'docker run --rm \
  -e OPENAI_API_KEY="$OPENAI_API_KEY" \
  -e GITHUB_TOKEN="$GITHUB_TOKEN" \
  -e MODE=server \
  -p 2222:22 \
  -v "$HOME/.ssh/id_ed25519.pub:/run/codex/authorized_key.pub:ro" \
  -v "$PWD":/home/codex/workspace \
  codex-base:latest'
  assert_contains "$readme" 'ssh -p 2222 codex@localhost'
  assert_contains "$readme" '`codex-superpowers` accepts the same environment variables and entrypoint behavior as `codex-base`, including SSH server mode.'
  assert_not_contains "$readme" 'APP_SERVER_HOST'
  assert_not_contains "$readme" 'APP_SERVER_PORT'
  assert_not_contains "$readme" 'codex app-server'
}

test_base_allows_auth_json_without_openai_api_key
test_base_requires_openai_api_key_without_auth_json
test_base_server_mode_requires_ssh_public_key_file
test_base_server_mode_installs_authorized_key_and_starts_sshd
test_base_entrypoint_supports_ssh_server_mode
test_superpowers_dockerfile_builds_from_base_without_monitor
test_makefile_uses_two_image_model

test_superpowers_smoke_test_recipe_matches_two_image_model() {
  local output
  output="$(/usr/bin/make -n -C "$repo_root" test-superpowers 2>&1)"

  assert_contains "$output" 'codex --version'
  assert_contains "$output" 'test -d /home/codex/.codex/superpowers'
  assert_contains "$output" 'test "$(readlink -f /home/codex/.agents/skills/superpowers)" = "/home/codex/.codex/superpowers/skills"'
  assert_contains "$output" 'cmp -s /home/codex/.codex/config.toml <(printf "[features]\nmulti_agent = true\n")'
  assert_not_contains "$output" 'test -L /home/codex/.agents/skills/superpowers'
  assert_not_contains "$output" 'codex_monitor_daemonctl'
  assert_not_contains "$output" 'test "" = "/home/codex/.codex/superpowers/skills"'
}

test_base_server_smoke_test_recipe_uses_timeout_and_ssh_mode() {
  local output
  output="$(/usr/bin/make -n -C "$repo_root" test-base 2>&1)"

  assert_contains "$output" "bash -lc"
  assert_contains "$output" 'set -o pipefail'
  assert_contains "$output" 'timeout 10s docker run --rm'
  assert_contains "$output" '-e MODE=server'
  assert_contains "$output" '-v "$key_file:/run/codex/authorized_key.pub:ro"'
  assert_contains "$output" 'test "$status" -eq 124'
  assert_contains "$output" 'grep -F "Starting SSH server on 0.0.0.0:22..."'
  assert_not_contains "$output" 'APP_SERVER_HOST'
  assert_not_contains "$output" 'APP_SERVER_PORT'
  assert_not_contains "$output" 'codex app-server'
}

test_base_smoke_test_recipe_checks_codex_uid_gid() {
  local output
  output="$(/usr/bin/make -n -C "$repo_root" test-base 2>&1)"

  assert_contains "$output" 'id -u codex | grep -Fx 1000'
  assert_contains "$output" 'id -g codex | grep -Fx 1000'
}

test_clean_skips_when_docker_is_unavailable
test_clean_reports_completion_when_docker_is_available
test_base_dockerfile_creates_codex_user_with_uid_gid_1000
test_base_dockerfile_precreates_codex_config_dir
test_base_dockerfile_sets_ssh_server_defaults
test_readme_documents_auth_json_mount
test_readme_documents_two_image_model
test_readme_documents_ssh_server_mode
test_superpowers_smoke_test_recipe_matches_two_image_model
test_base_server_smoke_test_recipe_uses_timeout_and_ssh_mode
test_base_smoke_test_recipe_checks_codex_uid_gid

printf 'PASS: regression checks\n'
