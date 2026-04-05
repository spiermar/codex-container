# App Server Mode Design

Add a server runtime mode to the container so it can start Codex app-server with a WebSocket listener for remote connections.

## Goals

- add `MODE=server` to the shared container runtime
- start `codex app-server` in WebSocket mode for remote clients
- keep `MODE=interactive` as the default container behavior
- make the server listen host and port configurable with documented defaults
- keep `codex-superpowers` inheriting the shared runtime behavior from `codex-base`

## Non-Goals

- changing the image lineup or adding a new image variant
- changing the existing interactive shell behavior
- changing the existing authentication contract for container startup
- adding custom reverse proxy, TLS termination, or extra app-server management processes

## Architecture

The repository will continue to support two images:

1. `codex-base`: the shared Codex CLI image with runtime mode selection in `base/entrypoint.sh`
2. `codex-superpowers`: a thin layer on top of `codex-base` that inherits the same runtime modes

`MODE=interactive` remains the default and continues to start `/bin/bash`.

`MODE=server` will become a second supported runtime mode in `base/entrypoint.sh`. In that mode, the container will construct a WebSocket listen URL from `APP_SERVER_HOST` and `APP_SERVER_PORT`, then execute:

```bash
codex app-server --listen "ws://${APP_SERVER_HOST}:${APP_SERVER_PORT}"
```

The default server settings will be:

- `APP_SERVER_HOST=0.0.0.0`
- `APP_SERVER_PORT=4500`

Using `0.0.0.0` by default makes Docker port publishing work without extra overrides, while still allowing callers to set a narrower bind address when needed.

## Components

### `base/entrypoint.sh`

Extend the existing `case "${MODE:-interactive}"` dispatch to support `server`.

The startup flow will be:

1. configure global Git identity if unset
2. require either `/home/codex/.codex/auth.json` or `OPENAI_API_KEY`
3. require `GITHUB_TOKEN`
4. run `gh auth setup-git`
5. branch on `MODE`
6. for `server`, print the listen URL and `exec codex app-server --listen "ws://${APP_SERVER_HOST}:${APP_SERVER_PORT}"`

The unsupported-mode error will be updated to list both supported values: `interactive, server`.

### `base/Dockerfile`

Add `APP_SERVER_HOST` and `APP_SERVER_PORT` to the existing runtime defaults in the `ENV` block so both images inherit the same documented defaults.

### `README.md`

Update the runtime documentation to describe both supported modes.

Required updates:

- mention `MODE=server` in the `codex-base` behavior summary
- document `APP_SERVER_HOST` and `APP_SERVER_PORT` in the environment table
- add a server-mode `docker run` example with `-p 4500:4500`
- explain that server mode starts `codex app-server --listen ws://...` in WebSocket mode
- note that `codex-superpowers` inherits the same server-mode behavior as `codex-base`

### `Makefile`

Keep the existing interactive smoke tests. Add server-mode verification with a short-lived runtime check that proves the container can start app-server in WebSocket mode with the configured host and port.

### `tests/regression.sh`

Add repository-level checks that assert:

- `base/entrypoint.sh` contains a `server)` branch
- the entrypoint starts `codex app-server --listen`
- the entrypoint builds a `ws://` listen URL from `APP_SERVER_HOST` and `APP_SERVER_PORT`
- the unsupported-mode error mentions `interactive, server`
- `base/Dockerfile` defines `APP_SERVER_HOST` and `APP_SERVER_PORT`
- `README.md` documents server mode, WebSocket transport, and the server env vars

## Data Flow

In `MODE=server`, the container startup flow is:

1. Docker injects `MODE`, `APP_SERVER_HOST`, `APP_SERVER_PORT`, and auth-related environment variables
2. the entrypoint validates auth prerequisites using the same rules as interactive mode
3. the entrypoint derives the listen URL as `ws://${APP_SERVER_HOST}:${APP_SERVER_PORT}`
4. the entrypoint replaces itself with `codex app-server --listen <url>`
5. remote clients connect over the published WebSocket port

No additional wrapper process, supervisor, or background daemon is introduced.

## Error Handling

No new shell-side validation is required beyond mode selection and the existing auth checks.

Expected failure modes:

- missing `/home/codex/.codex/auth.json` and missing `OPENAI_API_KEY` still fail before startup
- missing `GITHUB_TOKEN` still fails before startup
- unsupported `MODE` values fail with an updated supported-modes message
- invalid host or port values are passed through to `codex app-server`, which remains the source of truth for listen argument validation

To make configuration issues easier to diagnose, the entrypoint should log the WebSocket listen URL before launching app-server.

## Testing

Verification should cover:

1. repository regression checks for the new mode, env vars, and docs
2. existing `make test-base` interactive toolchain coverage
3. existing `make test-superpowers` baked-in Superpowers coverage
4. a new server-mode smoke check that runs the container with `MODE=server` and confirms the app-server command starts with the expected WebSocket listen URL

The server smoke check should be short-lived rather than fully interactive. A bounded command such as wrapping the container run in `timeout` is sufficient if the observed output shows that app-server started in WebSocket mode and blocked waiting for client connections.

Success means:

- both images still build from the current Make targets
- interactive behavior remains unchanged by default
- `MODE=server` starts `codex app-server --listen` using `ws://${APP_SERVER_HOST}:${APP_SERVER_PORT}`
- documentation, regression checks, and smoke tests all describe the same two-mode runtime model
