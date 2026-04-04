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
		-lc 'codex --version && codex_monitor_daemonctl --help >/dev/null && test -d /home/codex/.codex/superpowers && test -L /home/codex/.agents/skills/superpowers && test "$$(readlink -f /home/codex/.agents/skills/superpowers)" = "/home/codex/.codex/superpowers/skills" && cmp -s /home/codex/.codex/config.toml <(printf "[features]\nmulti_agent = true\n")'
	@printf 'Successfully tested %s\n' "$(SUPERPOWERS_IMAGE)"
