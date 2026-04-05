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
	@printf 'Testing %s app-server startup...\n' "$(BASE_IMAGE)"
	@bash -lc 'set -o pipefail; \
		timeout 10s docker run --rm \
			-e OPENAI_API_KEY="$(TEST_OPENAI_API_KEY)" \
			-e GITHUB_TOKEN="$(TEST_GITHUB_TOKEN)" \
			-e MODE=server \
			-e APP_SERVER_HOST=0.0.0.0 \
			-e APP_SERVER_PORT=4500 \
			"$(BASE_IMAGE)" 2>&1 | tee /tmp/codex-base-server-smoke.log; \
		test "$${PIPESTATUS[0]}" -eq 124'
	@grep -F "Starting Codex app-server on ws://0.0.0.0:4500..." /tmp/codex-base-server-smoke.log
	@rm -f /tmp/codex-base-server-smoke.log
	@printf 'Successfully tested %s\n' "$(BASE_IMAGE)"

test-superpowers: codex-superpowers
	@printf 'Testing %s superpowers setup...\n' "$(SUPERPOWERS_IMAGE)"
	@docker run --rm -i \
		-e OPENAI_API_KEY="$(TEST_OPENAI_API_KEY)" \
		-e GITHUB_TOKEN="$(TEST_GITHUB_TOKEN)" \
		-e MODE=interactive \
		--entrypoint /bin/bash \
		"$(SUPERPOWERS_IMAGE)" \
		-lc 'codex --version && test -d /home/codex/.codex/superpowers && test "$$(readlink -f /home/codex/.agents/skills/superpowers)" = "/home/codex/.codex/superpowers/skills" && cmp -s /home/codex/.codex/config.toml <(printf "[features]\nmulti_agent = true\n")'
	@printf 'Successfully tested %s\n' "$(SUPERPOWERS_IMAGE)"
