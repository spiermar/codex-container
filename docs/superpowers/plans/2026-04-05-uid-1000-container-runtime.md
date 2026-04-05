# UID 1000 Container Runtime Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the built-in `codex` runtime user use uid/gid `1000` so mounted workspaces work without `docker run --user 1000:1000`.

**Architecture:** Keep the existing `codex` username and `/home/codex` paths. Change the base image to recreate `codex` as uid/gid `1000`, then extend regression coverage and Docker smoke tests so the numeric identity is verified in the built images.

**Tech Stack:** Docker, Ubuntu base image, GNU Make, Bash regression tests

---

## File Structure

- Modify: `base/Dockerfile`
  Responsibility: define the non-root runtime user, home directory ownership, and base entrypoint installation.
- Modify: `Makefile`
  Responsibility: build/test smoke commands for the base, monitor, and superpowers images.
- Modify: `tests/regression.sh`
  Responsibility: repository-level shell regression checks for Dockerfile contents and generated command recipes.

### Task 1: Add a failing regression for uid/gid 1000 in the base image definition

**Files:**
- Modify: `tests/regression.sh`
- Test: `tests/regression.sh`

- [ ] **Step 1: Write the failing test**

Add this function near the other Dockerfile regression checks in `tests/regression.sh`:

```bash
test_base_dockerfile_creates_codex_user_with_uid_gid_1000() {
  local dockerfile
  dockerfile="$(<"$repo_root/base/Dockerfile")"

  assert_contains "$dockerfile" 'getent passwd 1000'
  assert_contains "$dockerfile" 'getent group 1000'
  assert_contains "$dockerfile" 'groupadd -g 1000 codex'
  assert_contains "$dockerfile" 'useradd -u 1000 -g 1000 -m -s /bin/bash codex'
}
```

Invoke it in the execution section near the bottom of the file:

```bash
test_base_dockerfile_creates_codex_user_with_uid_gid_1000
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/regression.sh`

Expected: `FAIL` mentioning one of the missing `uid/gid 1000` strings from `base/Dockerfile`.

- [ ] **Step 3: Write minimal implementation**

Update the user-creation block in `base/Dockerfile` from:

```dockerfile
RUN useradd -m -s /bin/bash codex && \
    mkdir -p /etc/sudoers.d && \
    echo "codex ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/codex && \
    chmod 0440 /etc/sudoers.d/codex
```

to:

```dockerfile
RUN (getent passwd 1000 | cut -d: -f1 | xargs -r userdel -r 2>/dev/null || true) && \
    (getent group 1000 | cut -d: -f1 | xargs -r groupdel 2>/dev/null || true) && \
    groupadd -g 1000 codex && \
    useradd -u 1000 -g 1000 -m -s /bin/bash codex && \
    mkdir -p /etc/sudoers.d && \
    echo "codex ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/codex && \
    chmod 0440 /etc/sudoers.d/codex
```

Keep the later ownership and entrypoint lines in place so `/home/codex`, `/home/codex/workspace`, and `/home/codex/entrypoint.sh` remain owned by `codex:codex`.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/regression.sh`

Expected: `PASS: regression checks`

- [ ] **Step 5: Commit**

```bash
git add base/Dockerfile tests/regression.sh
git commit -m "fix: align container runtime user with uid 1000"
```

### Task 2: Add failing smoke coverage for the built image identity

**Files:**
- Modify: `Makefile`
- Test: `Makefile`, `tests/regression.sh`

- [ ] **Step 1: Write the failing test**

In `tests/regression.sh`, add a recipe-preservation check that asserts the base image smoke test verifies `codex` numeric identity:

```bash
test_base_smoke_test_recipe_checks_codex_uid_gid() {
  local output
  output="$(/usr/bin/make -n -C "$repo_root" test-base 2>&1)"

  assert_contains "$output" 'id -u codex | grep -Fx 1000'
  assert_contains "$output" 'id -g codex | grep -Fx 1000'
}
```

Invoke it near the end of the file:

```bash
test_base_smoke_test_recipe_checks_codex_uid_gid
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/regression.sh`

Expected: `FAIL` because `make -n test-base` does not yet include the `id -u codex` and `id -g codex` checks.

- [ ] **Step 3: Write minimal implementation**

Update the `test-base` recipe in `Makefile` from:

```make
	@docker run --rm \
		-e OPENAI_API_KEY="$(TEST_OPENAI_API_KEY)" \
		-e GITHUB_TOKEN="$(TEST_GITHUB_TOKEN)" \
		-e MODE=interactive \
		--entrypoint /bin/bash \
		"$(BASE_IMAGE)" \
		-lc 'codex --version && gh --version && node --version'
```

to:

```make
	@docker run --rm \
		-e OPENAI_API_KEY="$(TEST_OPENAI_API_KEY)" \
		-e GITHUB_TOKEN="$(TEST_GITHUB_TOKEN)" \
		-e MODE=interactive \
		--entrypoint /bin/bash \
		"$(BASE_IMAGE)" \
		-lc 'codex --version && gh --version && node --version && id -u codex | grep -Fx 1000 && id -g codex | grep -Fx 1000'
```

Keep the existing smoke assertions intact and only append the uid/gid checks.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/regression.sh`

Expected: `PASS: regression checks`

- [ ] **Step 5: Commit**

```bash
git add Makefile tests/regression.sh
git commit -m "test: verify codex runtime uid and gid"
```

### Task 3: Build and verify the affected images end-to-end

**Files:**
- Modify: none
- Test: `base/Dockerfile`, `codex-monitor/Dockerfile`, `codex-superpowers/Dockerfile`, `Makefile`

- [ ] **Step 1: Run the focused base image smoke test**

Run: `make test-base`

Expected: base image builds, then the container command prints valid tool versions and confirms uid/gid `1000`.

- [ ] **Step 2: Run the full regression script**

Run: `bash tests/regression.sh`

Expected: `PASS: regression checks`

- [ ] **Step 3: Run the derived image smoke tests**

Run: `make test-monitor test-superpowers`

Expected: both images build successfully, `codex_monitor_daemonctl --help` succeeds, and the superpowers image still has the expected `/home/codex` files and symlink.

- [ ] **Step 4: Confirm there are no required code changes in derived Dockerfiles**

Inspect the current derived files and confirm they still rely on the inherited `codex` user and `/home/codex` paths:

```dockerfile
USER codex
WORKDIR /home/codex
COPY --chown=codex:codex entrypoint.sh /home/codex/entrypoint-monitor.sh
```

and:

```dockerfile
USER codex
WORKDIR /home/codex
RUN mkdir -p /home/codex/.codex /home/codex/.agents/skills && \
    git clone --branch main https://github.com/obra/superpowers.git /home/codex/.codex/superpowers
```

Expected: no patch is needed because the user name and home path remain unchanged.

- [ ] **Step 5: Commit**

```bash
git add base/Dockerfile Makefile tests/regression.sh
git commit -m "fix: use uid 1000 for the codex runtime user"
```
