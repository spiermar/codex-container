.DEFAULT_GOAL := all

.PHONY: all base codex-monitor clean test test-base test-monitor

BASE_IMAGE := codex-base:latest
MONITOR_IMAGE := codex-monitor:latest
TEST_OPENAI_API_KEY := test-openai-key
TEST_GITHUB_TOKEN := test-github-token

all: base codex-monitor

test: test-base test-monitor

base:
	@printf 'Building %s from ./base...\n' "$(BASE_IMAGE)"
	@docker build -t "$(BASE_IMAGE)" ./base
	@printf 'Successfully built %s\n' "$(BASE_IMAGE)"

codex-monitor: base
	@printf 'Building %s from ./codex-monitor...\n' "$(MONITOR_IMAGE)"
	@docker build -t "$(MONITOR_IMAGE)" ./codex-monitor
	@printf 'Successfully built %s\n' "$(MONITOR_IMAGE)"

clean:
	@printf 'Removing Docker images %s and %s...\n' "$(MONITOR_IMAGE)" "$(BASE_IMAGE)"
	@docker image rm -f "$(MONITOR_IMAGE)" "$(BASE_IMAGE)" >/dev/null 2>&1 || true
	@printf 'Successfully removed %s and %s\n' "$(MONITOR_IMAGE)" "$(BASE_IMAGE)"

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
