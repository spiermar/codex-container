# UID 1000 Container Runtime Design

## Goal

Adopt the same runtime-user approach used in the reference image by making the built-in `codex` user own uid/gid `1000`. This should allow bind-mounted workspaces owned by the host's default user to be readable and writable inside the container without requiring `docker run --user 1000:1000`.

## Scope

In scope:

- `base/Dockerfile`
- derived Dockerfiles whose behavior depends on the base runtime user:
  - `codex-monitor/Dockerfile`
  - `codex-superpowers/Dockerfile`

Out of scope:

- renaming `/home/codex`
- renaming the `codex` user
- rewriting README examples or broad documentation unrelated to the runtime-user fix

## Recommended Approach

Keep the existing `codex` username and `/home/codex` home directory, but recreate `codex` explicitly as uid/gid `1000` during the base image build.

This preserves the current runtime paths and user-facing mount locations while aligning the container's primary non-root user with the common host user id used for bind-mounted workspaces.

## Design

### Base Image

`base/Dockerfile` will change from creating an unconstrained `codex` user to the following flow:

1. Remove any existing user with uid `1000` if one exists.
2. Remove any existing group with gid `1000` if one exists.
3. Create group `codex` with gid `1000`.
4. Create user `codex` with uid `1000`, gid `1000`, home `/home/codex`, and shell `/bin/bash`.
5. Create `/home/codex/workspace` and ensure it is owned by `codex:codex`.

The entrypoint will remain at `/home/codex/entrypoint.sh` and will continue to be copied with `--chown=codex:codex` and marked executable.

### Derived Images

`codex-monitor/Dockerfile` and `codex-superpowers/Dockerfile` will continue to use:

- `USER codex`
- `WORKDIR /home/codex`
- paths rooted at `/home/codex`

No rename is required. The only expectation is that the inherited `codex` user now resolves to uid/gid `1000`, so existing `chown codex:codex` and copied entrypoints continue to work unchanged.

## Runtime Behavior

After this change:

1. The container should run as the built-in `codex` user by default.
2. That user should resolve to uid/gid `1000:1000`.
3. A bind mount such as `-v "$PWD":/home/codex/workspace` should be accessible without passing `--user 1000:1000`.
4. Existing auth and daemon paths under `/home/codex` should continue to work unchanged.

## Failure Modes and Handling

- If the base image already contains a user or group with uid/gid `1000`, the Dockerfile will remove them before creating `codex`.
- If a downstream Dockerfile assumes a different numeric uid for `codex`, that assumption will no longer be valid; this repo's downstream Dockerfiles do not currently appear to depend on a different uid.
- If a host environment uses a different uid for the mounted workspace owner, users may still need a different strategy, but this change solves the reported `1000:1000` case.

## Verification

Verification should confirm:

1. The base image still builds successfully.
2. `id -u codex` returns `1000` in the built image.
3. `id -g codex` returns `1000` in the built image.
4. The existing entrypoint files remain executable and runnable as `codex`.
5. Existing regression or smoke tests for `codex-monitor` and `codex-superpowers` still pass.

## Notes

This design intentionally does not move the entrypoint to `/usr/local/bin` because that would treat the symptom while leaving the primary runtime user mismatch in place. The change instead aligns the image's default non-root user with the host uid/gid expected for workspace mounts.

Per repository policy, this spec is written but not committed automatically.
