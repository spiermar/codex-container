# Codex Superpowers Image Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `codex-superpowers` Docker image that extends `codex-monitor` with baked-in Superpowers and enabled Codex multi-agent configuration.

**Architecture:** Add a thin third Docker layer on top of `codex-monitor` that clones Superpowers into the `codex` home directory, exposes its skills through Codex's discovery path, and writes a minimal config file enabling multi-agent support. Keep runtime behavior inherited from `codex-monitor`, then extend the Makefile and README so the new image can be built, tested, cleaned, and used without changing existing image semantics.

**Tech Stack:** Docker, Make, Bash, Git, Markdown, Codex CLI, Codex Monitor, Superpowers

---

## File Structure

```
codex-container/
├── Makefile                                        # Build, test, and clean targets for all images
├── README.md                                       # User-facing image overview and run instructions
├── codex-monitor/
│   └── Dockerfile                                  # Existing parent image for monitor behavior
└── codex-superpowers/
    └── Dockerfile                                  # New image layer that installs Superpowers and Codex config
```

---

### Task 1: Add the `codex-superpowers` image and smoke test

**Files:**
- Create: `codex-superpowers/Dockerfile`
- Modify: `Makefile`

- [ ] **Step 1: Create the image directory**

```bash
mkdir -p codex-superpowers
```

- [ ] **Step 2: Add Makefile support for building, testing, and cleaning `codex-superpowers`**

Update `Makefile` so the relevant sections read:

```make
.DEFAULT_GOAL := all

.PHONY: all base codex-monitor codex-superpowers clean test test-base test-monitor test-superpowers

BASE_IMAGE := codex-base:latest
MONITOR_IMAGE := codex-monitor:latest
SUPERPOWERS_IMAGE := codex-superpowers:latest
TEST_OPENAI_API_KEY := test-openai-key
TEST_GITHUB_TOKEN := test-github-token

all: base codex-monitor codex-superpowers

test: test-base test-monitor test-superpowers

base:
	@printf 'Building %s from ./base...\n' "$(BASE_IMAGE)"
	@docker build -t "$(BASE_IMAGE)" ./base
	@printf 'Successfully built %s\n' "$(BASE_IMAGE)"

codex-monitor: base
	@printf 'Building %s from ./codex-monitor...\n' "$(MONITOR_IMAGE)"
	@docker build -t "$(MONITOR_IMAGE)" ./codex-monitor
	@printf 'Successfully built %s\n' "$(MONITOR_IMAGE)"

codex-superpowers: codex-monitor
	@printf 'Building %s from ./codex-superpowers...\n' "$(SUPERPOWERS_IMAGE)"
	@docker build -t "$(SUPERPOWERS_IMAGE)" ./codex-superpowers
	@printf 'Successfully built %s\n' "$(SUPERPOWERS_IMAGE)"

clean:
	@if ! command -v docker >/dev/null 2>&1; then \
		printf 'Skipping clean: docker is not installed or not on PATH.\n'; \
	else \
		printf 'Removing Docker images %s, %s, and %s...\n' "$(SUPERPOWERS_IMAGE)" "$(MONITOR_IMAGE)" "$(BASE_IMAGE)"; \
		docker image rm -f "$(SUPERPOWERS_IMAGE)" "$(MONITOR_IMAGE)" "$(BASE_IMAGE)" >/dev/null 2>&1 || true; \
		printf 'Docker image cleanup complete for %s, %s, and %s\n' "$(SUPERPOWERS_IMAGE)" "$(MONITOR_IMAGE)" "$(BASE_IMAGE)"; \
	fi

test-base: base
	@printf 'Testing %s toolchain...\n' "$(BASE_IMAGE)"
	@docker run --rm \
		-e OPENAI_API_KEY="$(TEST_OPENAI_API_KEY)" \
		-e GITHUB_TOKEN="$(TEST_GITHUB_TOKEN)" \
		-e MODE=interactive \
		--entrypoint /bin/bash \
		"$(BASE_IMAGE)" \
		-lc 'codex --version && gh --version && node --version'
	@printf 'Successfully tested %s\n' "$(BASE_IMAGE)"

test-monitor: codex-monitor
	@printf 'Testing %s monitor commands...\n' "$(MONITOR_IMAGE)"
	@docker run --rm -i \
		-e OPENAI_API_KEY="$(TEST_OPENAI_API_KEY)" \
		-e GITHUB_TOKEN="$(TEST_GITHUB_TOKEN)" \
		-e MODE=interactive \
		--entrypoint /bin/bash \
		"$(MONITOR_IMAGE)" \
		-lc 'codex --version && codex_monitor_daemonctl --help'
	@printf 'Successfully tested %s\n' "$(MONITOR_IMAGE)"

test-superpowers: codex-superpowers
	@printf 'Testing %s superpowers setup...\n' "$(SUPERPOWERS_IMAGE)"
	@docker run --rm -i \
		-e OPENAI_API_KEY="$(TEST_OPENAI_API_KEY)" \
		-e GITHUB_TOKEN="$(TEST_GITHUB_TOKEN)" \
		-e MODE=interactive \
		--entrypoint /bin/bash \
		"$(SUPERPOWERS_IMAGE)" \
		-lc 'codex --version && codex_monitor_daemonctl --help >/dev/null && test -d /home/codex/.codex/superpowers && test -L /home/codex/.agents/skills/superpowers && test "$(readlink /home/codex/.agents/skills/superpowers)" = "/home/codex/.codex/superpowers/skills" && grep -Fq "[features]" /home/codex/.codex/config.toml && grep -Fq "multi_agent = true" /home/codex/.codex/config.toml'
	@printf 'Successfully tested %s\n' "$(SUPERPOWERS_IMAGE)"
```

- [ ] **Step 3: Run the new smoke test to verify it fails before the Dockerfile exists**

Run:

```bash
make test-superpowers
```

Expected: FAIL during `docker build -t "codex-superpowers:latest" ./codex-superpowers` because `codex-superpowers/Dockerfile` does not exist yet.

- [ ] **Step 4: Write the minimal `codex-superpowers` Dockerfile**

Create `codex-superpowers/Dockerfile` with:

```dockerfile
FROM codex-monitor:latest

USER codex
WORKDIR /home/codex

SHELL ["/bin/bash", "-lc"]

RUN mkdir -p /home/codex/.codex /home/codex/.agents/skills && \
    git clone --depth 1 https://github.com/obra/superpowers.git /home/codex/.codex/superpowers && \
    ln -s /home/codex/.codex/superpowers/skills /home/codex/.agents/skills/superpowers && \
    cat <<'EOF' >/home/codex/.codex/config.toml
[features]
multi_agent = true
EOF

WORKDIR /home/codex/workspace
```

- [ ] **Step 5: Run the smoke test again and verify it passes**

Run:

```bash
make test-superpowers
```

Expected: PASS. Output should include `Successfully built codex-superpowers:latest` and `Successfully tested codex-superpowers:latest`.

- [ ] **Step 6: Commit the image and Makefile changes**

```bash
git add Makefile codex-superpowers/Dockerfile
git commit -m "feat: add codex-superpowers image"
```

---

### Task 2: Document the new image in the README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Verify the README does not already mention `codex-superpowers`**

Run:

```bash
rg -n "codex-superpowers" README.md
```

Expected: no matches.

- [ ] **Step 2: Update the overview, build, and run sections for `codex-superpowers`**

Edit `README.md` so these sections read as follows.

Update the image overview table:

```markdown
| Image | Purpose |
| --- | --- |
| `codex-base` | Interactive Codex CLI environment with common development tools preinstalled |
| `codex-monitor` | Extends `codex-base` with `codex_monitor_daemon` and `codex_monitor_daemonctl` binaries |
| `codex-superpowers` | Extends `codex-monitor` with baked-in Superpowers skills and Codex multi-agent config |
```

Add a new image-variant subsection immediately after the existing `### codex-monitor` section:

```markdown
### `codex-superpowers`

`codex-superpowers` builds on top of `codex-monitor` and bakes in the Superpowers plugin for Codex. It adds:

- a clone of `https://github.com/obra/superpowers.git` at `/home/codex/.codex/superpowers`
- a skill-discovery symlink at `/home/codex/.agents/skills/superpowers`
- Codex config at `/home/codex/.codex/config.toml` with `multi_agent = true`

It keeps the same entrypoint and mode behavior as `codex-monitor`:

- `MODE=daemon` remains the default
- `MODE=interactive` remains available for shell use

Superpowers is cloned from upstream `main` during image build, so rebuilding the image refreshes it.
```

Update the build commands block:

````markdown
```bash
make base
make codex-monitor
make codex-superpowers
make all
make test
make clean
```
````

Update the target summary bullets:

```markdown
- `make base` builds `codex-base:latest`
- `make codex-monitor` builds `codex-monitor:latest` after building `codex-base`
- `make codex-superpowers` builds `codex-superpowers:latest` after building `codex-monitor`
- `make all` builds all three images
- `make test` runs the image smoke tests defined in the `Makefile`
- `make clean` removes all three local images
```

Add a new run section after `## Running codex-monitor` and before `## Environment Variables`:

````markdown
## Running `codex-superpowers`

`codex-superpowers` accepts the same environment variables and modes as `codex-monitor`, but starts with Superpowers already installed.

Interactive shell example:

```bash
docker run --rm -it \
  -e MODE=interactive \
  -v "$PWD":/home/codex/workspace \
  codex-superpowers:latest
```

If you want daemon mode, use the same flags you would use for `codex-monitor` and replace only the image name.
````

Update the differences section bullets:

```markdown
- it installs `@openai/codex` instead of OpenCode tooling
- the primary authenticated environment variables are `OPENAI_API_KEY` and `GITHUB_TOKEN`
- it provides one optional monitor-enabled variant, `codex-monitor`
- it provides one optional Superpowers-enabled variant, `codex-superpowers`
- its monitor image compiles and ships Codex Monitor daemon binaries for remote backend usage
```

- [ ] **Step 3: Verify the README changes are present**

Run:

```bash
rg -n "codex-superpowers|multi_agent = true|Superpowers plugin" README.md
```

Expected: matches in the overview table, the new image-variant section, the build summary, and the new run section.

- [ ] **Step 4: Commit the README update**

```bash
git add README.md
git commit -m "docs: add codex-superpowers usage"
```
