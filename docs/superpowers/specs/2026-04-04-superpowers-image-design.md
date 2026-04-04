# Codex Superpowers image design

## Summary

Add a third Docker image, `codex-superpowers`, that builds on top of `codex-monitor` and bakes in the Superpowers plugin for Codex. The image should preserve `codex-monitor`'s existing entrypoint and default daemon behavior while making Superpowers skills available immediately and enabling Codex multi-agent support by default.

## Scope

This change affects:

- `codex-superpowers/Dockerfile`
- `Makefile`
- `README.md`

This change does not affect:

- `base/Dockerfile`
- `codex-monitor/Dockerfile`
- `codex-monitor/entrypoint.sh`
- existing `codex-base` or `codex-monitor` runtime semantics

## Goals

- Add a separate `codex-superpowers:latest` image variant
- Install Superpowers during image build instead of container startup
- Keep `codex-monitor` as the parent image and preserve its defaults
- Enable Superpowers subagent skills by setting Codex `multi_agent = true`
- Document the new image, its build path, and its runtime behavior clearly

## Non-goals

- Replacing or renaming `codex-monitor`
- Pinning Superpowers to a fixed commit or tag
- Updating Superpowers automatically at container startup
- Changing the existing daemon or interactive mode logic in `codex-monitor`
- Introducing extra environment variables for Superpowers installation or configuration

## Image layering

The image stack will become:

1. `codex-base`: shared Codex CLI environment and common tools
2. `codex-monitor`: monitor daemon binaries and monitor-specific defaults
3. `codex-superpowers`: Superpowers installation and Codex multi-agent configuration

`codex-superpowers` should use `FROM codex-monitor:latest` so it inherits the monitor binaries, entrypoint, environment defaults, and daemon-mode behavior without duplicating that logic.

## Build-time installation

The `codex-superpowers` Dockerfile should install Superpowers at build time as the `codex` user.

The build should:

1. Ensure `/home/codex/.codex` exists.
2. Clone `https://github.com/obra/superpowers.git` into `/home/codex/.codex/superpowers`.
3. Ensure `/home/codex/.agents/skills` exists.
4. Create the symlink `/home/codex/.agents/skills/superpowers -> /home/codex/.codex/superpowers/skills`.
5. Write Codex configuration enabling multi-agent support.

The clone should track upstream `main` at build time. Rebuilding the image is the mechanism for picking up new Superpowers changes.

## Codex configuration

`codex-superpowers` should write a minimal Codex config file at:

`/home/codex/.codex/config.toml`

The file should contain:

```toml
[features]
multi_agent = true
```

This is required so Superpowers skills that depend on Codex multi-agent support work out of the box.

The configuration should be baked into the image rather than generated at startup.

## Ownership and filesystem layout

All Superpowers-related files created by the image should be owned by `codex:codex`.

Expected paths inside the image:

- `/home/codex/.codex/superpowers`
- `/home/codex/.agents/skills/superpowers`
- `/home/codex/.codex/config.toml`

The symlink target should remain inside the same home directory tree so the installation is self-contained and does not depend on external mounts.

## Runtime behavior

`codex-superpowers` should preserve `codex-monitor` runtime behavior:

- `ENTRYPOINT` remains the monitor entrypoint inherited from `codex-monitor`
- default `MODE=daemon` remains unchanged
- `MODE=interactive` remains available exactly as it is today
- monitor daemon binaries and environment handling continue to behave exactly as they do in `codex-monitor`

Superpowers should be passive at runtime. The image only preinstalls the skill repository and Codex config; it should not run any installer, updater, or bootstrap step when the container starts.

## Makefile integration

The Makefile should gain a dedicated image target for `codex-superpowers`.

Required changes:

- add an image variable for `codex-superpowers:latest`
- add a `codex-superpowers` target that depends on `codex-monitor`
- add a `test-superpowers` target
- update `all` to build the new image
- update `test` to include the new image test
- update `clean` to remove the new image alongside the existing ones

This should preserve the repo's existing image-build workflow and naming pattern.

## Testing

Add image-level coverage through the Makefile test workflow.

`test-superpowers` should build and run `codex-superpowers:latest` in interactive mode with `/bin/bash -lc` checks for:

- `codex --version`
- `codex_monitor_daemonctl --help`
- presence of `/home/codex/.codex/superpowers`
- presence and correctness of the symlink at `/home/codex/.agents/skills/superpowers`
- Codex config containing `multi_agent = true`

The new test should be additive and should not weaken or replace the existing `test-base` and `test-monitor` coverage.

## Documentation changes

`README.md` should be updated to:

- add `codex-superpowers` to the image overview table
- describe it as a `codex-monitor`-based variant with baked-in Superpowers
- include `make codex-superpowers` in the build command summary
- add a run example for `codex-superpowers`
- explain that Superpowers is cloned from upstream `main` during image build
- explain that Codex multi-agent support is pre-enabled in this image

The documentation should make clear that `codex-superpowers` keeps `codex-monitor`'s default daemon behavior and exists as an additional opt-in image, not a replacement.

## Risks

- Because the build clones Superpowers from `main`, repeated builds may produce behavior changes without changes in this repository.
- If the Superpowers installation instructions or expected skill-discovery paths change upstream, the Dockerfile may need to be updated.
- If a user bind-mounts over `/home/codex/.codex` or `/home/codex/.agents`, they may hide the baked-in installation.

## Success criteria

- `make codex-superpowers` builds a new `codex-superpowers:latest` image on top of `codex-monitor`
- the built image contains a working Superpowers clone and skills symlink under the `codex` home directory
- Codex multi-agent support is enabled by default in the image configuration
- `codex-superpowers` preserves `codex-monitor`'s current default daemon behavior
- README and Makefile usage make the new image discoverable and testable
