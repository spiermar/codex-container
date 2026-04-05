# App Server Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `MODE=server` runtime to the container that starts `codex app-server --listen` in WebSocket mode using configurable host and port defaults.

**Architecture:** Extend the shared `codex-base` entrypoint so runtime mode selection stays centralized in `base/entrypoint.sh`. Add static regression coverage for the new mode, then add a bounded runtime smoke test in `Makefile`, and finally update the README so docs match the shipped behavior.

**Tech Stack:** Docker, Make, Bash, Git, Markdown

---

## File Structure

```
codex-container/
|-- Makefile                                               # Image builds and smoke tests
|-- README.md                                              # Runtime docs and docker run examples
|-- base/
|   |-- Dockerfile                                         # Shared runtime env defaults
|   `-- entrypoint.sh                                      # Runtime mode dispatch and auth checks
|-- docs/superpowers/plans/
|   `-- 2026-04-05-app-server-mode.md
`-- tests/
    `-- regression.sh                                      # Repo-level static regression checks
```

---

### Task 1: Add regression coverage for server mode contracts

**Files:**
- Modify: `tests/regression.sh`
- Test: `tests/regression.sh`

- [ ] **Step 1: Add a regression test for the entrypoint server branch**

Insert this function immediately after `test_base_requires_openai_api_key_without_auth_json()` in `tests/regression.sh`:

```bash
test_base_entrypoint_supports_server_mode() {
  local entrypoint
  entrypoint="$(<"$repo_root/base/entrypoint.sh")"

  assert_contains "$entrypoint" 'server)'
  assert_contains "$entrypoint" 'listen_url="ws://${APP_SERVER_HOST:-0.0.0.0}:${APP_SERVER_PORT:-4500}"'
  assert_contains "$entrypoint" 'Starting Codex app-server on ${listen_url}...'
  assert_contains "$entrypoint" 'exec codex app-server --listen "$listen_url"'
  assert_contains "$entrypoint" "Supported modes: interactive, server"
}
```

- [ ] **Step 2: Add a regression test for Dockerfile defaults**

Insert this function immediately after `test_base_dockerfile_precreates_codex_config_dir()` in `tests/regression.sh`:

```bash
test_base_dockerfile_sets_app_server_defaults() {
  local dockerfile
  dockerfile="$(<"$repo_root/base/Dockerfile")"

  assert_contains "$dockerfile" 'ENV MODE=interactive \
    APP_SERVER_HOST=0.0.0.0 \
    APP_SERVER_PORT=4500 \
    GIT_EMAIL=codex@local \
    GIT_NAME=Codex \
    NVM_DIR=/home/codex/.nvm'
}
```

- [ ] **Step 3: Add a regression test for README server-mode docs**

Insert this function immediately after `test_readme_documents_two_image_model()` in `tests/regression.sh`:

```bash
test_readme_documents_server_mode() {
  local readme
  readme="$(<"$repo_root/README.md")"

  assert_contains "$readme" '- starts `codex app-server --listen ws://...` when `MODE=server`'
  assert_contains "$readme" '| `MODE` | No | `interactive` | Supported values: `interactive`, `server` |'
  assert_contains "$readme" '| `APP_SERVER_HOST` | No | `0.0.0.0` | Host used when `MODE=server` builds the WebSocket listen URL |'
  assert_contains "$readme" '| `APP_SERVER_PORT` | No | `4500` | Port used when `MODE=server` builds the WebSocket listen URL |'
  assert_contains "$readme" '-e MODE=server \
  -p 4500:4500 \
  codex-base:latest'
  assert_contains "$readme" '`codex-superpowers` accepts the same environment variables and entrypoint behavior as `codex-base`, including `MODE=server`.'
}
```

- [ ] **Step 4: Wire the new regression tests into the invocation list**

Add these exact lines in `tests/regression.sh`:

Immediately after `test_base_requires_openai_api_key_without_auth_json`:

```bash
test_base_entrypoint_supports_server_mode
```

Immediately after `test_base_dockerfile_precreates_codex_config_dir`:

```bash
test_base_dockerfile_sets_app_server_defaults
```

Immediately after `test_readme_documents_two_image_model`:

```bash
test_readme_documents_server_mode
```

- [ ] **Step 5: Run the regression script to verify the new checks fail**

Run: `bash tests/regression.sh`

Expected: FAIL because `base/entrypoint.sh`, `base/Dockerfile`, and `README.md` do not yet contain the new server-mode strings.

- [ ] **Step 6: Commit the failing-test addition**

```bash
git add tests/regression.sh
git commit -m "test: add app server mode regression coverage"
```

---

### Task 2: Implement server mode in the shared runtime

**Files:**
- Modify: `base/entrypoint.sh`
- Modify: `base/Dockerfile`
- Test: `tests/regression.sh`

- [ ] **Step 1: Update the entrypoint to support `MODE=server`**

Replace `base/entrypoint.sh` with:

```bash
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
  server)
    listen_url="ws://${APP_SERVER_HOST:-0.0.0.0}:${APP_SERVER_PORT:-4500}"
    echo "Starting Codex app-server on ${listen_url}..."
    exec codex app-server --listen "$listen_url"
    ;;
  *)
    echo "Error: unsupported MODE '${MODE}'. Supported modes: interactive, server" >&2
    exit 1
    ;;
esac
```

- [ ] **Step 2: Add default app-server host and port env vars to the base image**

Replace the current `ENV` block in `base/Dockerfile`:

```dockerfile
ENV MODE=interactive \
    APP_SERVER_HOST=0.0.0.0 \
    APP_SERVER_PORT=4500 \
    GIT_EMAIL=codex@local \
    GIT_NAME=Codex \
    NVM_DIR=/home/codex/.nvm
```

- [ ] **Step 3: Run the regression script to verify the new server-mode checks pass**

Run: `bash tests/regression.sh`

Expected: the new entrypoint and Dockerfile checks pass, while README-related checks may still fail until the docs task is complete.

- [ ] **Step 4: Commit the runtime implementation**

```bash
git add base/entrypoint.sh base/Dockerfile tests/regression.sh
git commit -m "feat: add codex app server mode"
```

---

### Task 3: Add a bounded server-mode smoke test to the Makefile

**Files:**
- Modify: `Makefile`
- Modify: `tests/regression.sh`
- Test: `Makefile`, `tests/regression.sh`

- [ ] **Step 1: Add a regression test that describes the new smoke-test recipe**

Insert this function immediately after `test_superpowers_smoke_test_recipe_matches_two_image_model()` in `tests/regression.sh`:

```bash
test_base_server_smoke_test_recipe_uses_timeout_and_websocket_mode() {
  local output
  output="$(/usr/bin/make -n -C "$repo_root" test-base 2>&1)"

  assert_contains "$output" 'timeout 10s docker run --rm'
  assert_contains "$output" '-e MODE=server'
  assert_contains "$output" '-e APP_SERVER_HOST=0.0.0.0'
  assert_contains "$output" '-e APP_SERVER_PORT=4500'
  assert_contains "$output" 'grep -F "Starting Codex app-server on ws://0.0.0.0:4500..."'
}
```

- [ ] **Step 2: Add the regression invocation**

Add this exact line in `tests/regression.sh` immediately after `test_superpowers_smoke_test_recipe_matches_two_image_model`:

```bash
test_base_server_smoke_test_recipe_uses_timeout_and_websocket_mode
```

- [ ] **Step 3: Run the regression script to verify the smoke-test check fails**

Run: `bash tests/regression.sh`

Expected: FAIL because `Makefile` still has only the interactive `test-base` recipe.

- [ ] **Step 4: Update `test-base` to cover both interactive tools and server startup**

Replace the `test-base` target in `Makefile` with:

```make
test-base: base
	@printf 'Testing %s toolchain...\n' "$(BASE_IMAGE)"
	@docker run --rm \
		-e OPENAI_API_KEY="$(TEST_OPENAI_API_KEY)" \
		-e GITHUB_TOKEN="$(TEST_GITHUB_TOKEN)" \
		-e MODE=interactive \
		--entrypoint /bin/bash \
		"$(BASE_IMAGE)" \
		-lc 'codex --version && gh --version && node --version && id -u codex | grep -Fx 1000 && id -g codex | grep -Fx 1000'
	@printf 'Testing %s app-server startup...\n' "$(BASE_IMAGE)"
	@timeout 10s docker run --rm \
		-e OPENAI_API_KEY="$(TEST_OPENAI_API_KEY)" \
		-e GITHUB_TOKEN="$(TEST_GITHUB_TOKEN)" \
		-e MODE=server \
		-e APP_SERVER_HOST=0.0.0.0 \
		-e APP_SERVER_PORT=4500 \
		"$(BASE_IMAGE)" 2>&1 | tee /tmp/codex-base-server-smoke.log
	@grep -F "Starting Codex app-server on ws://0.0.0.0:4500..." /tmp/codex-base-server-smoke.log
	@rm -f /tmp/codex-base-server-smoke.log
	@printf 'Successfully tested %s\n' "$(BASE_IMAGE)"
```

- [ ] **Step 5: Run the regression script to verify the smoke-test contract passes**

Run: `bash tests/regression.sh`

Expected: PASS for `test_base_server_smoke_test_recipe_uses_timeout_and_websocket_mode`.

- [ ] **Step 6: Run the generated Make recipe**

Run: `make test-base`

Expected: PASS. The first container run prints tool versions. The second run is terminated by `timeout` after app-server startup, and the recipe still succeeds because the expected startup lines are present in `/tmp/codex-base-server-smoke.log`.

- [ ] **Step 7: Commit the smoke-test update**

```bash
git add Makefile tests/regression.sh
git commit -m "test: cover app server startup"
```

---

### Task 4: Document server mode in the README

**Files:**
- Modify: `README.md`
- Test: `tests/regression.sh`

- [ ] **Step 1: Update the `codex-base` behavior summary**

In `README.md`, replace the current bullet list under `Its entrypoint:` with:

```md
- configures global Git identity if one is not already set
- requires either `/home/codex/.codex/auth.json` or `OPENAI_API_KEY`
- requires `GITHUB_TOKEN`
- logs `gh` in with the provided token
- starts an interactive shell when `MODE=interactive`
- starts `codex app-server --listen ws://...` when `MODE=server`
```

- [ ] **Step 2: Add a server-mode run example for `codex-base`**

Insert this section immediately after the existing mounted-auth example under `## Running `codex-base``:

```md
Server mode example:

```bash
docker run --rm \
  -e OPENAI_API_KEY="$OPENAI_API_KEY" \
  -e GITHUB_TOKEN="$GITHUB_TOKEN" \
  -e MODE=server \
  -p 4500:4500 \
  -v "$PWD":/home/codex/workspace \
  codex-base:latest
```

This starts `codex app-server --listen ws://0.0.0.0:4500` inside the container so remote clients can connect through the published Docker port.
```

- [ ] **Step 3: Update the `codex-superpowers` runtime description**

Replace this sentence in `README.md`:

```md
`codex-superpowers` accepts the same environment variables and entrypoint behavior as `codex-base`.
```

with:

```md
`codex-superpowers` accepts the same environment variables and entrypoint behavior as `codex-base`, including `MODE=server`.
```

- [ ] **Step 4: Expand the environment variable table**

Replace the current `### `codex-base`` table in `README.md` with:

```md
| Variable | Required | Default | Notes |
| --- | --- | --- | --- |
| `OPENAI_API_KEY` | If `/home/codex/.codex/auth.json` is not mounted | none | Required by the entrypoint unless the auth file is mounted |
| `GITHUB_TOKEN` | Yes | none | Used for `gh auth login --with-token` |
| `MODE` | No | `interactive` | Supported values: `interactive`, `server` |
| `APP_SERVER_HOST` | No | `0.0.0.0` | Host used when `MODE=server` builds the WebSocket listen URL |
| `APP_SERVER_PORT` | No | `4500` | Port used when `MODE=server` builds the WebSocket listen URL |
| `GIT_NAME` | No | `Codex` | Used only if global Git name is unset |
| `GIT_EMAIL` | No | `codex@local` | Used only if global Git email is unset |
```

- [ ] **Step 5: Run the regression script to verify the README checks pass**

Run: `bash tests/regression.sh`

Expected: PASS, including `test_readme_documents_server_mode`.

- [ ] **Step 6: Run the full local verification suite**

Run: `make test && bash tests/regression.sh`

Expected: PASS. `make test` validates both image smoke-test targets, and the regression script confirms the repo-level static contracts.

- [ ] **Step 7: Commit the documentation update**

```bash
git add README.md tests/regression.sh Makefile base/entrypoint.sh base/Dockerfile
git commit -m "docs: document app server mode"
```

---

## Self-Review Checklist

- Spec coverage: the tasks cover runtime branching, host/port defaults, regression checks, a bounded smoke test, and README updates.
- Placeholder scan: no `TODO`, `TBD`, or implicit “write tests later” instructions remain.
- Type consistency: the same names are used throughout the plan: `MODE=server`, `APP_SERVER_HOST`, `APP_SERVER_PORT`, `ws://`, and `codex app-server --listen`.
