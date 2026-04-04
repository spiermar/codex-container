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

test_daemon_allows_auth_json_without_openai_api_key() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN

  mkdir -p "$tmp_dir/bin" "$tmp_dir/home/.codex"
  printf '{}\n' >"$tmp_dir/home/.codex/auth.json"

  write_stub "$tmp_dir/bin/gh" '#!/bin/bash
exit 0'
  write_stub "$tmp_dir/bin/codex_monitor_daemon" '#!/bin/bash
exit 0'

  local stdout stderr output status
  stdout="$tmp_dir/stdout"
  stderr="$tmp_dir/stderr"

  set +e
  HOME="$tmp_dir/home" \
    OPENAI_API_KEY= \
    MODE=daemon \
    GITHUB_TOKEN=test-github-token \
    CODEX_MONITOR_HOST=127.0.0.1 \
    CODEX_MONITOR_PORT=4732 \
    PATH="$tmp_dir/bin:/usr/bin:/bin" \
    bash "$repo_root/codex-monitor/entrypoint.sh" >"$stdout" 2>"$stderr"
  status=$?
  set -e

  output="$(<"$stdout")\n$(<"$stderr")"

  [[ $status -eq 0 ]] || fail 'expected monitor daemon with auth.json to succeed without OPENAI_API_KEY'
  assert_contains "$output" 'Starting Codex Monitor daemon'
}

test_daemon_requires_openai_api_key_without_auth_json() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN

  mkdir -p "$tmp_dir/bin" "$tmp_dir/home"
  write_stub "$tmp_dir/bin/gh" '#!/bin/bash
exit 0'
  write_stub "$tmp_dir/bin/codex_monitor_daemon" '#!/bin/bash
exit 0'

  local stdout stderr output status
  stdout="$tmp_dir/stdout"
  stderr="$tmp_dir/stderr"

  set +e
  HOME="$tmp_dir/home" \
    OPENAI_API_KEY= \
    MODE=daemon \
    GITHUB_TOKEN=test-github-token \
    CODEX_MONITOR_HOST=127.0.0.1 \
    CODEX_MONITOR_PORT=4732 \
    PATH="$tmp_dir/bin:/usr/bin:/bin" \
    bash "$repo_root/codex-monitor/entrypoint.sh" >"$stdout" 2>"$stderr"
  status=$?
  set -e

  output="$(<"$stdout")\n$(<"$stderr")"

  [[ $status -ne 0 ]] || fail 'expected monitor daemon without auth.json or OPENAI_API_KEY to fail'
  assert_contains "$output" 'Error: OPENAI_API_KEY is required.'
}

test_daemon_requires_token_for_non_local_bind() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN

  mkdir -p "$tmp_dir/bin" "$tmp_dir/home"
  write_stub "$tmp_dir/bin/gh" '#!/bin/bash
exit 0'
  write_stub "$tmp_dir/bin/codex_monitor_daemon" '#!/bin/bash
exit 0'

  local stdout stderr output status
  stdout="$tmp_dir/stdout"
  stderr="$tmp_dir/stderr"

  set +e
  HOME="$tmp_dir/home" \
    MODE=daemon \
    OPENAI_API_KEY=test-openai-key \
    GITHUB_TOKEN=test-github-token \
    CODEX_MONITOR_HOST=0.0.0.0 \
    CODEX_MONITOR_PORT=4732 \
    PATH="$tmp_dir/bin:/usr/bin:/bin" \
    bash "$repo_root/codex-monitor/entrypoint.sh" >"$stdout" 2>"$stderr"
  status=$?
  set -e

  output="$(<"$stdout")\n$(<"$stderr")"

  [[ $status -ne 0 ]] || fail 'expected daemon startup without a token on a non-local bind to fail'
  assert_contains "$output" 'CODEX_MONITOR_TOKEN'
  assert_contains "$output" 'CODEX_MONITOR_HOST'
}

test_clean_skips_when_docker_is_unavailable() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN

  local output status
  set +e
  output="$(PATH="$tmp_dir/bin:/bin" /usr/bin/make -C "$repo_root" clean 2>&1)"
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

test_monitor_dockerfile_includes_native_build_deps() {
  local dockerfile
  dockerfile="$(<"$repo_root/codex-monitor/Dockerfile")"

  assert_contains "$dockerfile" 'libglib2.0-dev'
  assert_contains "$dockerfile" 'libasound2-dev'
  assert_contains "$dockerfile" 'libclang-dev'
  assert_contains "$dockerfile" 'libwebkit2gtk-4.1-dev'
  assert_contains "$dockerfile" 'libxdo-dev'
  assert_contains "$dockerfile" 'libayatana-appindicator3-dev'
  assert_contains "$dockerfile" 'librsvg2-dev'
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

test_base_allows_auth_json_without_openai_api_key
test_base_requires_openai_api_key_without_auth_json
test_daemon_allows_auth_json_without_openai_api_key
test_daemon_requires_openai_api_key_without_auth_json
test_daemon_requires_token_for_non_local_bind
test_clean_skips_when_docker_is_unavailable
test_clean_reports_completion_when_docker_is_available
test_monitor_dockerfile_includes_native_build_deps
test_readme_documents_auth_json_mount

printf 'PASS: regression checks\n'
