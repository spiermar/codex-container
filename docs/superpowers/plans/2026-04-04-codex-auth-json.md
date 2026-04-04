# Codex auth.json Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow both container entrypoints to accept a mounted Codex `auth.json` file at `/home/codex/.codex/auth.json` instead of requiring `OPENAI_API_KEY`, while keeping the API key as a fallback and documenting the mount workflow in `README.md`.

**Architecture:** Keep the change local to the existing shell entrypoints and shell regression suite. Each entrypoint will perform one regular-file existence check for `/home/codex/.codex/auth.json` before enforcing `OPENAI_API_KEY`. README examples will show the exact bind mount path and keep the API-key flow documented as a fallback.

**Tech Stack:** Bash, Docker, GNU make, Markdown documentation

---

## File Structure

```text
codex-container/
├── README.md                    # User-facing run instructions and environment variable docs
├── base/
│   └── entrypoint.sh            # Interactive base image startup validation
├── codex-monitor/
│   └── entrypoint.sh            # Daemon and interactive monitor startup validation
└── tests/
    └── regression.sh            # Shell regressions for entrypoint and README behavior
```

Files to modify:

- `base/entrypoint.sh`
- `codex-monitor/entrypoint.sh`
- `tests/regression.sh`
- `README.md`

---

### Task 1: Add `codex-base` auth.json fallback with TDD

**Files:**
- Modify: `tests/regression.sh`
- Modify: `base/entrypoint.sh`
- Test: `tests/regression.sh`

- [ ] **Step 1: Write the failing regression for base auth.json startup**

Insert this function in `tests/regression.sh` after `write_stub()` and before the existing test functions:

```bash
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
```

Add this invocation near the bottom of `tests/regression.sh` before `test_daemon_requires_token_for_non_local_bind`:

```bash
test_base_allows_auth_json_without_openai_api_key
```

- [ ] **Step 2: Run the regression suite and verify the new test fails for the expected reason**

Run:

```bash
bash tests/regression.sh
```

Expected: FAIL with:

```text
FAIL: expected base entrypoint with auth.json to succeed without OPENAI_API_KEY
```

- [ ] **Step 3: Write the minimal base entrypoint change**

In `base/entrypoint.sh`, replace the current `OPENAI_API_KEY` check with this block:

```bash
codex_auth_file=/home/codex/.codex/auth.json

if [[ ! -f "$codex_auth_file" ]] && [[ -z "${OPENAI_API_KEY:-}" ]]; then
  echo "Error: OPENAI_API_KEY is required." >&2
  exit 1
fi
```

The top of `base/entrypoint.sh` should read:

```bash
#!/bin/bash
set -euo pipefail

if [[ -z "$(git config --global user.email 2>/dev/null || true)" ]]; then
  git config --global user.email "${GIT_EMAIL:-codex@local}"
fi

if [[ -z "$(git config --global user.name 2>/dev/null || true)" ]]; then
  git config --global user.name "${GIT_NAME:-Codex}"
fi

codex_auth_file=/home/codex/.codex/auth.json

if [[ ! -f "$codex_auth_file" ]] && [[ -z "${OPENAI_API_KEY:-}" ]]; then
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
```

- [ ] **Step 4: Run the regression suite and verify it passes**

Run:

```bash
bash tests/regression.sh
```

Expected:

```text
PASS: regression checks
```

- [ ] **Step 5: Commit the base auth.json change**

```bash
git add tests/regression.sh base/entrypoint.sh
git commit -m "fix: allow mounted auth.json in base image"
```

---

### Task 2: Add `codex-monitor` auth.json fallback with TDD

**Files:**
- Modify: `tests/regression.sh`
- Modify: `codex-monitor/entrypoint.sh`
- Test: `tests/regression.sh`

- [ ] **Step 1: Write the failing regression for monitor daemon auth.json startup**

Insert this function in `tests/regression.sh` after `test_base_allows_auth_json_without_openai_api_key()`:

```bash
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
```

Add this invocation near the bottom of `tests/regression.sh` before `test_daemon_requires_token_for_non_local_bind`:

```bash
test_daemon_allows_auth_json_without_openai_api_key
```

- [ ] **Step 2: Run the regression suite and verify the new monitor test fails**

Run:

```bash
bash tests/regression.sh
```

Expected: FAIL with:

```text
FAIL: expected monitor daemon with auth.json to succeed without OPENAI_API_KEY
```

- [ ] **Step 3: Write the minimal monitor entrypoint change**

In `codex-monitor/entrypoint.sh`, add the auth-file variable before the `case` statement and replace the daemon-mode key check.

Add this line before `case "${MODE:-daemon}" in`:

```bash
codex_auth_file=/home/codex/.codex/auth.json
```

Replace this block:

```bash
    if [[ -z "${OPENAI_API_KEY:-}" ]]; then
      echo "Error: OPENAI_API_KEY is required." >&2
      exit 1
    fi
```

With this block:

```bash
    if [[ ! -f "$codex_auth_file" ]] && [[ -z "${OPENAI_API_KEY:-}" ]]; then
      echo "Error: OPENAI_API_KEY is required." >&2
      exit 1
    fi
```

The top of `codex-monitor/entrypoint.sh` should read:

```bash
#!/bin/bash
set -euo pipefail

if [[ -z "$(git config --global user.email 2>/dev/null || true)" ]]; then
  git config --global user.email "${GIT_EMAIL:-codex@local}"
fi

if [[ -z "$(git config --global user.name 2>/dev/null || true)" ]]; then
  git config --global user.name "${GIT_NAME:-Codex}"
fi

codex_auth_file=/home/codex/.codex/auth.json

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

    echo "$GITHUB_TOKEN" | gh auth login --with-token

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
```

- [ ] **Step 4: Run the regression suite and verify everything is green again**

Run:

```bash
bash tests/regression.sh
```

Expected:

```text
PASS: regression checks
```

- [ ] **Step 5: Commit the monitor auth.json change**

```bash
git add tests/regression.sh codex-monitor/entrypoint.sh
git commit -m "fix: allow mounted auth.json in monitor daemon"
```

---

### Task 3: Document the auth.json mount path with a README regression

**Files:**
- Modify: `tests/regression.sh`
- Modify: `README.md`
- Test: `tests/regression.sh`

- [ ] **Step 1: Write the failing README regression**

Insert this function in `tests/regression.sh` after `test_monitor_dockerfile_includes_native_build_deps()`:

```bash
test_readme_documents_auth_json_mount() {
  local readme
  readme="$(<"$repo_root/README.md")"

  assert_contains "$readme" '/home/codex/.codex/auth.json'
  assert_contains "$readme" '-v "$HOME/.codex/auth.json:/home/codex/.codex/auth.json:ro"'
  assert_contains "$readme" 'When `/home/codex/.codex/auth.json` is mounted, `OPENAI_API_KEY` is optional.'
}
```

Add this invocation near the bottom of `tests/regression.sh` before the final `printf`:

```bash
test_readme_documents_auth_json_mount
```

- [ ] **Step 2: Run the regression suite and verify the README test fails**

Run:

```bash
bash tests/regression.sh
```

Expected: FAIL with:

```text
expected output to contain '/home/codex/.codex/auth.json'
```

- [ ] **Step 3: Update `README.md` with exact auth.json mount guidance**

Make these content changes in `README.md`.

Replace the Requirements bullet:

```markdown
- valid `OPENAI_API_KEY` and `GITHUB_TOKEN` when using authenticated Codex workflows
```

With:

```markdown
- valid `GITHUB_TOKEN`, plus either a mounted Codex `auth.json` file or `OPENAI_API_KEY` when using authenticated Codex workflows
```

Replace the `codex-base` entrypoint bullets:

```markdown
- requires `OPENAI_API_KEY`
- requires `GITHUB_TOKEN`
```

With:

```markdown
- requires either `/home/codex/.codex/auth.json` or `OPENAI_API_KEY`
- requires `GITHUB_TOKEN`
```

Replace the `codex-monitor` daemon bullets:

```markdown
- requires `OPENAI_API_KEY`
- requires `GITHUB_TOKEN`
```

With:

```markdown
- requires either `/home/codex/.codex/auth.json` or `OPENAI_API_KEY`
- requires `GITHUB_TOKEN`
```

Insert this section after `## Running \`codex-base\`` and before `Minimal interactive example:`:

```markdown
### Using a mounted Codex auth file

If you already authenticated Codex on the host, mount the file into the container at the path Codex expects:

```bash
-v "$HOME/.codex/auth.json:/home/codex/.codex/auth.json:ro"
```

When `/home/codex/.codex/auth.json` is mounted, `OPENAI_API_KEY` is optional.
```

Add this `codex-base` example after the existing minimal example:

```markdown
Example using mounted Codex auth instead of `OPENAI_API_KEY`:

```bash
docker run --rm -it \
  -e GITHUB_TOKEN="$GITHUB_TOKEN" \
  -v "$HOME/.codex/auth.json:/home/codex/.codex/auth.json:ro" \
  -v "$PWD":/home/codex/workspace \
  codex-base:latest
```
```

Add this sentence below the `codex-monitor` daemon example block:

```markdown
You can also omit `OPENAI_API_KEY` there if you mount `-v "$HOME/.codex/auth.json:/home/codex/.codex/auth.json:ro"`.
```

Update the `codex-base` environment-variable row:

```markdown
| `OPENAI_API_KEY` | Yes | none | Required by the entrypoint |
```

To:

```markdown
| `OPENAI_API_KEY` | Conditional | none | Required only when `/home/codex/.codex/auth.json` is not mounted |
```

Update the `codex-monitor` environment-variable row:

```markdown
| `OPENAI_API_KEY` | Daemon mode | none | Required only when `MODE=daemon`; not checked in interactive mode |
```

To:

```markdown
| `OPENAI_API_KEY` | Conditional in daemon mode | none | Required only when `MODE=daemon` and `/home/codex/.codex/auth.json` is not mounted; not checked in interactive mode |
```

Update the Security Notes bullet:

```markdown
- `OPENAI_API_KEY` and `GITHUB_TOKEN` are sensitive secrets; pass them with environment management appropriate for your system.
```

To:

```markdown
- `OPENAI_API_KEY`, `GITHUB_TOKEN`, and your host-side `~/.codex/auth.json` contents are sensitive secrets; pass or mount them with environment and filesystem protections appropriate for your system.
```

- [ ] **Step 4: Run the regression suite and verify the README test passes**

Run:

```bash
bash tests/regression.sh
```

Expected:

```text
PASS: regression checks
```

- [ ] **Step 5: Commit the README update**

```bash
git add tests/regression.sh README.md
git commit -m "docs: explain mounted codex auth.json workflow"
```

---

## Final Verification

- [ ] Run the full regression suite one more time:

```bash
bash tests/regression.sh
```

Expected:

```text
PASS: regression checks
```

- [ ] Inspect the final diff before handoff:

```bash
git diff --stat HEAD~3..HEAD
```

Expected: changes limited to `README.md`, both entrypoints, `tests/regression.sh`, and no unrelated files.
