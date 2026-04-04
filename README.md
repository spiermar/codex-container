# codex-container

Docker images for running the OpenAI Codex CLI in a consistent Ubuntu-based environment, with an optional `codex-monitor` variant for remote Codex Monitor daemon access.

## Overview

This repository builds two local Docker images:

| Image | Purpose |
| --- | --- |
| `codex-base` | Interactive Codex CLI environment with common development tools preinstalled |
| `codex-monitor` | Extends `codex-base` with `codex_monitor_daemon` and `codex_monitor_daemonctl` binaries |

The images share the same base setup:

- Ubuntu 24.04
- Node.js LTS via `nvm`
- `@openai/codex` installed globally
- `git`, `gh`, `make`, `ripgrep`, `jq`, `vim`, and other common CLI tools
- non-root `codex` user with passwordless `sudo`

## Requirements

- Docker with permission to build and run images
- GNU `make`
- network access during image builds for package and dependency downloads
- valid `OPENAI_API_KEY` and `GITHUB_TOKEN` when using authenticated Codex workflows

## Image Variants

### `codex-base`

`codex-base` is the main interactive development image. Its entrypoint:

- configures global Git identity if one is not already set
- requires `OPENAI_API_KEY`
- requires `GITHUB_TOKEN`
- logs `gh` in with the provided token
- starts an interactive shell when `MODE=interactive`

### `codex-monitor`

`codex-monitor` builds on top of `codex-base` and compiles Codex Monitor from source at a pinned commit. It adds:

- `codex_monitor_daemon`
- `codex_monitor_daemonctl`

Its entrypoint supports two modes:

- `MODE=daemon` starts the monitor daemon
- `MODE=interactive` starts a shell instead of the daemon

In daemon mode it also:

- requires `OPENAI_API_KEY`
- requires `GITHUB_TOKEN`
- optionally accepts `CODEX_MONITOR_TOKEN`
- binds to `CODEX_MONITOR_HOST` and `CODEX_MONITOR_PORT`
- stores daemon state in `/home/codex/.codexmonitor`

## Build Commands

Use the provided `Makefile`:

```bash
make base
make codex-monitor
make all
make test
make clean
```

Target summary:

- `make base` builds `codex-base:latest`
- `make codex-monitor` builds `codex-monitor:latest` after building `codex-base`
- `make all` builds both images
- `make test` runs the image smoke tests defined in the `Makefile`
- `make clean` removes both local images

## Running `codex-base`

Minimal interactive example:

```bash
docker run --rm -it \
  -e OPENAI_API_KEY="$OPENAI_API_KEY" \
  -e GITHUB_TOKEN="$GITHUB_TOKEN" \
  -v "$PWD":/home/codex/workspace \
  codex-base:latest
```

Optional Git identity overrides:

```bash
docker run --rm -it \
  -e OPENAI_API_KEY="$OPENAI_API_KEY" \
  -e GITHUB_TOKEN="$GITHUB_TOKEN" \
  -e GIT_NAME="Your Name" \
  -e GIT_EMAIL="you@example.com" \
  -v "$PWD":/home/codex/workspace \
  codex-base:latest
```

## Running `codex-monitor`

### Daemon mode

Default daemon example:

```bash
docker run --rm -d \
  --name codex-monitor \
  -e OPENAI_API_KEY="$OPENAI_API_KEY" \
  -e GITHUB_TOKEN="$GITHUB_TOKEN" \
  -e CODEX_MONITOR_TOKEN="change-me" \
  -p 4732:4732 \
  -v "$PWD":/home/codex/workspace \
  -v codex-monitor-data:/home/codex/.codexmonitor \
  codex-monitor:latest
```

### Interactive mode

If you want the monitor image as a shell environment instead of a daemon:

```bash
docker run --rm -it \
  -e MODE=interactive \
  -v "$PWD":/home/codex/workspace \
  codex-monitor:latest
```

Interactive mode does not enforce `OPENAI_API_KEY` or `GITHUB_TOKEN`, and it does not run `gh auth login` during startup. If you want authenticated Codex or GitHub commands in that shell session, provide the credentials yourself and authenticate manually as needed.

## Environment Variables

### `codex-base`

| Variable | Required | Default | Notes |
| --- | --- | --- | --- |
| `OPENAI_API_KEY` | Yes | none | Required by the entrypoint |
| `GITHUB_TOKEN` | Yes | none | Used for `gh auth login --with-token` |
| `MODE` | No | `interactive` | Only `interactive` is supported |
| `GIT_NAME` | No | `Codex` | Used only if global Git name is unset |
| `GIT_EMAIL` | No | `codex@local` | Used only if global Git email is unset |

### `codex-monitor`

| Variable | Required | Default | Notes |
| --- | --- | --- | --- |
| `MODE` | No | `daemon` | Supported values: `daemon`, `interactive` |
| `OPENAI_API_KEY` | Daemon mode | none | Required only when `MODE=daemon`; not checked in interactive mode |
| `GITHUB_TOKEN` | Daemon mode | none | Required only when `MODE=daemon`; used for `gh auth login --with-token` only in daemon mode |
| `CODEX_MONITOR_HOST` | No | `0.0.0.0` | Daemon bind host |
| `CODEX_MONITOR_PORT` | No | `4732` | Daemon listen port |
| `CODEX_MONITOR_TOKEN` | No | unset | Passed to the daemon as `--token` when set |
| `GIT_NAME` | No | `Codex` | Used only if global Git name is unset |
| `GIT_EMAIL` | No | `codex@local` | Used only if global Git email is unset |

## Data Persistence and Recommended Volumes

Recommended mounts:

- mount your project into `/home/codex/workspace`
- persist `/home/codex/.codexmonitor` when using daemon mode

Example with both:

```bash
docker run --rm -d \
  --name codex-monitor \
  -e OPENAI_API_KEY="$OPENAI_API_KEY" \
  -e GITHUB_TOKEN="$GITHUB_TOKEN" \
  -e CODEX_MONITOR_TOKEN="change-me" \
  -p 4732:4732 \
  -v "$PWD":/home/codex/workspace \
  -v codex-monitor-data:/home/codex/.codexmonitor \
  codex-monitor:latest
```

Without a persistent volume, daemon state stored under `/home/codex/.codexmonitor` is lost when the container is removed.

## Custom Port Example

To run the daemon on a different container port:

```bash
docker run --rm -d \
  --name codex-monitor \
  -e OPENAI_API_KEY="$OPENAI_API_KEY" \
  -e GITHUB_TOKEN="$GITHUB_TOKEN" \
  -e CODEX_MONITOR_PORT=9000 \
  -e CODEX_MONITOR_TOKEN="change-me" \
  -p 9000:9000 \
  -v "$PWD":/home/codex/workspace \
  -v codex-monitor-data:/home/codex/.codexmonitor \
  codex-monitor:latest
```

## Connecting from iOS or a Remote Machine

The daemon binds to `0.0.0.0` by default, so other devices can reach it if:

- the Docker host is reachable on your network
- the published port is open
- you connect to the host machine's IP address or DNS name
- any required token is provided by your client

Typical flow:

1. Start `codex-monitor` with `-p 4732:4732` or your chosen port.
2. Set `CODEX_MONITOR_TOKEN` if the daemon will be reachable beyond your local machine.
3. From iOS or another remote client, connect to `http://<host-ip>:4732` or the host and port you published.
4. If you changed `CODEX_MONITOR_PORT`, use that same port in both the container config and the client.

For access outside a trusted LAN, prefer a VPN, SSH tunnel, or reverse proxy with TLS instead of exposing the daemon directly to the public internet.

## Security Notes

- `OPENAI_API_KEY` and `GITHUB_TOKEN` are sensitive secrets; pass them with environment management appropriate for your system.
- In `codex-monitor`, `gh auth login --with-token` is executed by the entrypoint only in `MODE=daemon`.
- `codex-monitor` listens on all interfaces by default because `CODEX_MONITOR_HOST=0.0.0.0`.
- Set `CODEX_MONITOR_TOKEN` before allowing remote clients to connect.
- Prefer binding to localhost, a private subnet, or a VPN-protected interface when possible.
- Do not publish the daemon port broadly unless you understand the trust boundary.

Example localhost-only publish:

```bash
docker run --rm -d \
  --name codex-monitor \
  -e OPENAI_API_KEY="$OPENAI_API_KEY" \
  -e GITHUB_TOKEN="$GITHUB_TOKEN" \
  -e CODEX_MONITOR_TOKEN="change-me" \
  -p 127.0.0.1:4732:4732 \
  -v "$PWD":/home/codex/workspace \
  -v codex-monitor-data:/home/codex/.codexmonitor \
  codex-monitor:latest
```

## Differences from `opencode-container`

This repository is focused on the OpenAI Codex CLI stack rather than the OpenCode stack:

- it installs `@openai/codex` instead of OpenCode tooling
- the primary authenticated environment variables are `OPENAI_API_KEY` and `GITHUB_TOKEN`
- it provides one optional monitor-enabled variant, `codex-monitor`
- its monitor image compiles and ships Codex Monitor daemon binaries for remote backend usage

## License

No license file is currently included in this repository. Treat the contents as unlicensed unless and until a license is added.
