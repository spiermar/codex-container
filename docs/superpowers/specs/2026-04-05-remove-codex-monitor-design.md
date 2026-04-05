# Remove codex-monitor Design

Remove the `codex-monitor` image from the repository and make `codex-superpowers` build directly on top of `codex-base`.

## Goals

- remove the `codex-monitor` image and its supporting files from the repository
- make `codex-superpowers` build from `codex-base:latest`
- keep `codex-superpowers` focused on baked-in Superpowers setup only
- update build, test, and documentation flows so they describe only supported images

## Non-Goals

- changing `codex-base` runtime behavior
- adding new runtime features to `codex-superpowers`
- preserving daemon-mode behavior or monitor binaries in any image

## Architecture

The repository will support two images after the change:

1. `codex-base`: the shared interactive Codex CLI environment
2. `codex-superpowers`: a `codex-base`-derived image that adds the Superpowers repository, skill symlink, and Codex multi-agent config

`codex-monitor` will be removed completely. `codex-superpowers` will no longer inherit the monitor entrypoint, daemon defaults, or monitor binaries. It will inherit the normal `codex-base` entrypoint and interactive runtime behavior.

## File Changes

### Delete

- `codex-monitor/Dockerfile`
- `codex-monitor/entrypoint.sh`

### Update

- `codex-superpowers/Dockerfile`
- `Makefile`
- `README.md`
- `tests/regression.sh`

## Detailed Design

### codex-superpowers Dockerfile

Change the base image from `codex-monitor:latest` to `codex-base:latest`.

Keep the existing Superpowers setup intact:

- create `/home/codex/.codex` and `/home/codex/.agents/skills`
- clone `https://github.com/obra/superpowers.git` into `/home/codex/.codex/superpowers`
- create the `/home/codex/.agents/skills/superpowers` symlink
- write `/home/codex/.codex/config.toml` with `multi_agent = true`

No monitor-specific binaries, environment variables, entrypoint overrides, or daemon-mode defaults should remain in the superpowers image.

### Makefile

Simplify the build graph to match the new image model.

- remove `MONITOR_IMAGE`
- remove `codex-monitor` from `.PHONY`
- remove the `codex-monitor` build target
- make `codex-superpowers` depend on `base`
- remove `test-monitor`
- update `all`, `test`, and `clean` so they reference only `base` and `codex-superpowers`

### Regression Tests

Remove tests that directly validate `codex-monitor` artifacts or make targets.

Keep and adjust the remaining checks so they validate the new supported behavior:

- `test-superpowers` should verify `codex --version`
- it should verify the Superpowers clone exists
- it should verify the skills symlink points at `/home/codex/.codex/superpowers/skills`
- it should verify `/home/codex/.codex/config.toml` still enables `multi_agent = true`
- it should no longer require `codex_monitor_daemonctl`

Any regression test that reads `codex-monitor/Dockerfile`, expects a `codex-monitor` make target, or asserts monitor-specific smoke-test content should be removed or rewritten.

### README

Rewrite the repository documentation to describe only supported images.

- remove `codex-monitor` from the image overview table
- remove the dedicated `codex-monitor` sections, commands, and environment-variable table
- describe `codex-superpowers` as extending `codex-base`
- update build command summaries so `make codex-superpowers` builds from `base`
- update running examples so `codex-superpowers` is documented as an interactive image inheriting `codex-base` behavior

## Error Handling

No new runtime error-handling logic is required.

Expected failure modes remain the same as today for supported images:

- Docker build failures from missing network access or package downloads
- Superpowers clone failures during image build
- existing `codex-base` authentication and startup failures at container runtime

Removing `codex-monitor` also removes its daemon-specific validation paths and related runtime errors.

## Testing

Verification should cover:

1. updated regression checks for the Makefile and documentation
2. `make test-base`
3. `make test-superpowers`
4. the repository regression script

Success means:

- the repository no longer contains supported build/test flows for `codex-monitor`
- `codex-superpowers` builds successfully from `codex-base`
- smoke tests pass without monitor-specific assumptions
- documentation consistently describes the two-image model
