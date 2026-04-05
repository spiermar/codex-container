# Remove codex-monitor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the `codex-monitor` image from the repository and make `codex-superpowers` build directly from `codex-base`.

**Architecture:** Collapse the repo to a two-image model: `codex-base` remains the shared interactive image, and `codex-superpowers` becomes a thin layer on top of it that only installs Superpowers and enables multi-agent mode. Remove the monitor Docker context, Make targets, regression coverage, and README sections so no supported workflow still references `codex-monitor`.

**Tech Stack:** Docker, Make, Bash, Git, Markdown

---

## File Structure

```
codex-container/
|-- Makefile                                   # Build, test, and clean targets for supported images
|-- README.md                                  # User-facing image overview and run instructions
|-- codex-superpowers/
|   `-- Dockerfile                             # Superpowers image built directly from codex-base
|-- docs/superpowers/specs/
|   `-- 2026-04-05-remove-codex-monitor-design.md
`-- tests/
    `-- regression.sh                          # Repo-level regression checks for Makefile and docs behavior
```

---

### Task 1: Remove the monitor image and retarget the superpowers image

**Files:**
- Delete: `codex-monitor/Dockerfile`
- Delete: `codex-monitor/entrypoint.sh`
- Modify: `codex-superpowers/Dockerfile`

- [ ] **Step 1: Write the failing regression test for the new parent image**

Update `tests/regression.sh` by adding this test function immediately after `test_base_smoke_test_recipe_checks_codex_uid_gid()`:

```bash
test_superpowers_dockerfile_uses_base_image() {
  local dockerfile
  dockerfile="$(<"$repo_root/codex-superpowers/Dockerfile")"

  assert_contains "$dockerfile" 'FROM codex-base:latest'
  assert_not_contains "$dockerfile" 'FROM codex-monitor:latest'
  assert_not_contains "$dockerfile" 'codex_monitor_daemonctl'
}
```

Also add this function call near the bottom with the other invocations, just before `printf 'PASS: regression checks\n'`:

```bash
test_superpowers_dockerfile_uses_base_image
```

- [ ] **Step 2: Run the regression script to verify the new test fails**

Run:

```bash
bash tests/regression.sh
```

Expected: FAIL because `codex-superpowers/Dockerfile` still contains `FROM codex-monitor:latest`.

- [ ] **Step 3: Update the superpowers Dockerfile to inherit from base**

Replace `codex-superpowers/Dockerfile` with:

```dockerfile
FROM codex-base:latest

USER codex
WORKDIR /home/codex

SHELL ["/bin/bash", "-lc"]

RUN mkdir -p /home/codex/.codex /home/codex/.agents/skills && \
    git clone --branch main https://github.com/obra/superpowers.git /home/codex/.codex/superpowers && \
    ln -s /home/codex/.codex/superpowers/skills /home/codex/.agents/skills/superpowers && \
    printf '[features]\nmulti_agent = true\n' > /home/codex/.codex/config.toml

WORKDIR /home/codex/workspace
```

- [ ] **Step 4: Remove the obsolete monitor Docker context**

Delete these files from the repository:

```text
codex-monitor/Dockerfile
codex-monitor/entrypoint.sh
```

- [ ] **Step 5: Run the regression script again to verify the Dockerfile test passes**

Run:

```bash
bash tests/regression.sh
```

Expected: PASS for `test_superpowers_dockerfile_uses_base_image`, but the full script may still fail on remaining monitor-specific assertions until later tasks are complete.

- [ ] **Step 6: Commit the image cleanup**

```bash
git add tests/regression.sh codex-superpowers/Dockerfile codex-monitor
git commit -m "refactor: remove codex-monitor image"
```

---

### Task 2: Simplify Makefile targets and smoke tests to the two-image model

**Files:**
- Modify: `Makefile`
- Modify: `tests/regression.sh`

- [ ] **Step 1: Write the failing regression tests for Makefile cleanup**

In `tests/regression.sh`, remove `test_monitor_dockerfile_includes_native_build_deps` entirely and add these two new tests in its place:

```bash
test_makefile_removes_monitor_targets() {
  local makefile
  makefile="$(<"$repo_root/Makefile")"

  assert_not_contains "$makefile" 'MONITOR_IMAGE :='
  assert_not_contains "$makefile" 'codex-monitor:'
  assert_not_contains "$makefile" 'test-monitor:'
  assert_not_contains "$makefile" 'codex-monitor '
}

test_superpowers_smoke_test_recipe_drops_monitor_checks() {
  local output
  output="$(/usr/bin/make -n -C "$repo_root" test-superpowers 2>&1)"

  assert_contains "$output" 'test -d /home/codex/.codex/superpowers'
  assert_contains "$output" 'test "$(readlink -f /home/codex/.agents/skills/superpowers)" = "/home/codex/.codex/superpowers/skills"'
  assert_contains "$output" 'cmp -s /home/codex/.codex/config.toml <(printf "[features]\nmulti_agent = true\n")'
  assert_not_contains "$output" 'codex_monitor_daemonctl'
}
```

Replace the old invocation list entries:

```bash
test_monitor_dockerfile_includes_native_build_deps
test_superpowers_smoke_test_recipe_preserves_shell_expressions
```

with:

```bash
test_makefile_removes_monitor_targets
test_superpowers_smoke_test_recipe_drops_monitor_checks
```

- [ ] **Step 2: Run the regression script to verify the Makefile tests fail**

Run:

```bash
bash tests/regression.sh
```

Expected: FAIL because `Makefile` still defines `MONITOR_IMAGE`, `codex-monitor`, `test-monitor`, and the `test-superpowers` recipe still checks `codex_monitor_daemonctl`.

- [ ] **Step 3: Update the Makefile to remove monitor targets and recipes**

Edit `Makefile` so it reads:

```make
.DEFAULT_GOAL := all

.PHONY: all base codex-superpowers clean test test-base test-superpowers

BASE_IMAGE := codex-base:latest
SUPERPOWERS_IMAGE := codex-superpowers:latest
TEST_OPENAI_API_KEY := test-openai-key
TEST_GITHUB_TOKEN := test-github-token

all: base codex-superpowers

test: test-base test-superpowers

base:
	@printf 'Building %s from ./base...\n' "$(BASE_IMAGE)"
	@docker build -t "$(BASE_IMAGE)" ./base
	@printf 'Successfully built %s\n' "$(BASE_IMAGE)"

codex-superpowers: base
	@printf 'Building %s from ./codex-superpowers...\n' "$(SUPERPOWERS_IMAGE)"
	@docker build -t "$(SUPERPOWERS_IMAGE)" ./codex-superpowers
	@printf 'Successfully built %s\n' "$(SUPERPOWERS_IMAGE)"

clean:
	@if ! command -v docker >/dev/null 2>&1; then \
		printf 'Skipping clean: docker is not installed or not on PATH.\n'; \
	else \
		printf 'Removing Docker images %s and %s...\n' "$(SUPERPOWERS_IMAGE)" "$(BASE_IMAGE)"; \
		docker image rm -f "$(SUPERPOWERS_IMAGE)" "$(BASE_IMAGE)" >/dev/null 2>&1 || true; \
		printf 'Docker image cleanup complete for %s and %s\n' "$(SUPERPOWERS_IMAGE)" "$(BASE_IMAGE)"; \
	fi

test-base: base
	@printf 'Testing %s toolchain...\n' "$(BASE_IMAGE)"
	@docker run --rm \
		-e OPENAI_API_KEY="$(TEST_OPENAI_API_KEY)" \
		-e GITHUB_TOKEN="$(TEST_GITHUB_TOKEN)" \
		-e MODE=interactive \
		--entrypoint /bin/bash \
		"$(BASE_IMAGE)" \
		-lc 'codex --version && gh --version && node --version && id -u codex | grep -Fx 1000 && id -g codex | grep -Fx 1000'
	@printf 'Successfully tested %s\n' "$(BASE_IMAGE)"

test-superpowers: codex-superpowers
	@printf 'Testing %s superpowers setup...\n' "$(SUPERPOWERS_IMAGE)"
	@docker run --rm -i \
		-e OPENAI_API_KEY="$(TEST_OPENAI_API_KEY)" \
		-e GITHUB_TOKEN="$(TEST_GITHUB_TOKEN)" \
		-e MODE=interactive \
		--entrypoint /bin/bash \
		"$(SUPERPOWERS_IMAGE)" \
		-lc 'codex --version && test -d /home/codex/.codex/superpowers && test -L /home/codex/.agents/skills/superpowers && test "$$(readlink -f /home/codex/.agents/skills/superpowers)" = "/home/codex/.codex/superpowers/skills" && cmp -s /home/codex/.codex/config.toml <(printf "[features]\nmulti_agent = true\n")'
	@printf 'Successfully tested %s\n' "$(SUPERPOWERS_IMAGE)"
```

- [ ] **Step 4: Run the regression script again to verify the Makefile tests pass**

Run:

```bash
bash tests/regression.sh
```

Expected: PASS for `test_makefile_removes_monitor_targets`, `test_superpowers_smoke_test_recipe_drops_monitor_checks`, and the clean-output assertions.

- [ ] **Step 5: Commit the build and regression changes**

```bash
git add Makefile tests/regression.sh
git commit -m "refactor: simplify image build targets"
```

---

### Task 3: Rewrite the README for the supported images only

**Files:**
- Modify: `README.md`
- Test: `tests/regression.sh`

- [ ] **Step 1: Write the failing README regression test**

In `tests/regression.sh`, keep `test_readme_documents_auth_json_mount()` unchanged and add this new test function immediately after it:

```bash
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
```

Add this new invocation immediately after `test_readme_documents_auth_json_mount`:

```bash
test_readme_documents_two_image_model
```

- [ ] **Step 2: Run the regression script to verify the README test fails**

Run:

```bash
bash tests/regression.sh
```

Expected: FAIL because `README.md` still contains the monitor overview, monitor run sections, and monitor environment variables.

- [ ] **Step 3: Update the README to remove monitor documentation**

Edit `README.md` so these sections read as follows.

Update the top summary and image overview table:

```markdown
# codex-container

Docker images for running the OpenAI Codex CLI in a consistent Ubuntu-based environment, with an optional `codex-superpowers` variant for baked-in Superpowers skills.

## Overview

This repository builds two local Docker images:

| Image | Purpose |
| --- | --- |
| `codex-base` | Interactive Codex CLI environment with common development tools preinstalled |
| `codex-superpowers` | Extends `codex-base` with baked-in Superpowers skills and Codex multi-agent config |
```

Update the `codex-superpowers` image section to:

```markdown
### `codex-superpowers`

`codex-superpowers` builds on top of `codex-base` and bakes in the Superpowers plugin for Codex. It adds:

- a clone of `https://github.com/obra/superpowers.git` at `/home/codex/.codex/superpowers`
- a skill-discovery symlink at `/home/codex/.agents/skills/superpowers`
- Codex config at `/home/codex/.codex/config.toml` with `multi_agent = true`

`codex-superpowers` accepts the same environment variables and entrypoint behavior as `codex-base`.

Superpowers is cloned from upstream `main` during image build. Rebuilding can refresh it, but Docker may reuse the cached clone layer unless you invalidate that cache or rebuild without cache.
```

Update the build summary bullets to:

```markdown
- `make base` builds `codex-base:latest`
- `make codex-superpowers` builds `codex-superpowers:latest` after building `codex-base`
- `make all` builds both images
- `make test` runs the image smoke tests defined in the `Makefile`
- `make clean` removes both local images
```

Replace the entire `## Running \`codex-monitor\`` and monitor environment-variable sections with this `codex-superpowers` run section:

```markdown
## Running `codex-superpowers`

`codex-superpowers` starts with Superpowers already installed while keeping the same interactive startup behavior as `codex-base`.

```bash
docker run --rm -it \
  -e OPENAI_API_KEY="$OPENAI_API_KEY" \
  -e GITHUB_TOKEN="$GITHUB_TOKEN" \
  -v "$PWD":/home/codex/workspace \
  codex-superpowers:latest
```

If you prefer the mounted auth file flow, use the same `auth.json` mount shown for `codex-base` and replace only the image name.
```

Keep the existing `codex-base` auth.json documentation intact.

- [ ] **Step 4: Run the regression script again to verify the README test passes**

Run:

```bash
bash tests/regression.sh
```

Expected: PASS for `test_readme_documents_two_image_model` and the existing auth.json assertions that still apply to `codex-base` content.

- [ ] **Step 5: Commit the documentation update**

```bash
git add README.md tests/regression.sh
git commit -m "docs: remove codex-monitor references"
```

---

### Task 4: Run final verification and capture the completed repo state

**Files:**
- Modify: none
- Test: `Makefile`, `tests/regression.sh`

- [ ] **Step 1: Run the repository regression script**

Run:

```bash
bash tests/regression.sh
```

Expected: PASS with final line `PASS: regression checks`.

- [ ] **Step 2: Run the base smoke test**

Run:

```bash
make test-base
```

Expected: PASS. Output includes `Successfully tested codex-base:latest`.

- [ ] **Step 3: Run the superpowers smoke test**

Run:

```bash
make test-superpowers
```

Expected: PASS. Output includes `Successfully built codex-superpowers:latest` and `Successfully tested codex-superpowers:latest`.

- [ ] **Step 4: Verify no tracked source files still reference codex-monitor**

Run:

```bash
rg -n "codex-monitor|CODEX_MONITOR|codex_monitor_daemon" Makefile README.md tests codex-superpowers docs/superpowers/specs/2026-04-05-remove-codex-monitor-design.md
```

Expected: matches only in the approved removal spec, not in active build, test, or runtime files.

- [ ] **Step 5: Commit the final verified state**

```bash
git add Makefile README.md tests/regression.sh codex-superpowers/Dockerfile codex-monitor
git commit -m "refactor: remove codex-monitor variant"
```
