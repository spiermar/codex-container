# codex-container

Docker images for running the OpenAI Codex CLI in a consistent Ubuntu-based environment, with an optional `codex-superpowers` variant that adds baked-in Superpowers skills on top of the main `codex-base` image.

## Overview

This repository builds two local Docker images:

| Image | Purpose |
| --- | --- |
| `codex-base` | Interactive Codex CLI environment with common development tools preinstalled |
| `codex-superpowers` | Extends `codex-base` with baked-in Superpowers skills and Codex multi-agent config |

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
- `GITHUB_TOKEN` plus either a mounted `auth.json` or `OPENAI_API_KEY` when using authenticated Codex workflows

## Image Variants

### `codex-base`

`codex-base` is the main interactive development image. Its entrypoint:

- configures global Git identity if one is not already set
- requires either `/home/codex/.codex/auth.json` or `OPENAI_API_KEY`
- requires `GITHUB_TOKEN`
- logs `gh` in with the provided token
- starts an interactive shell when `MODE=interactive`
- starts `codex app-server --listen ws://...` when `MODE=server`

### `codex-superpowers`

`codex-superpowers` builds on top of `codex-base` and bakes in the Superpowers plugin for Codex. It adds:

- a clone of `https://github.com/obra/superpowers.git` at `/home/codex/.codex/superpowers`
- a skill-discovery symlink at `/home/codex/.agents/skills/superpowers`
- Codex config at `/home/codex/.codex/config.toml` with `multi_agent = true`

`codex-superpowers` accepts the same environment variables and entrypoint behavior as `codex-base`, including `MODE=server`.

Superpowers is cloned from upstream `main` during image build. Rebuilding can refresh it, but Docker may reuse the cached clone layer unless you invalidate that cache or rebuild without cache.

## Build Commands

Use the provided `Makefile`:

```bash
make base
make codex-superpowers
make all
make test
make clean
```

Target summary:

- `make base` builds `codex-base:latest`
- `make codex-superpowers` builds `codex-superpowers:latest` after building `codex-base`
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

To use a host-side Codex auth file instead of `OPENAI_API_KEY`, add:

```bash
-v "$HOME/.codex/auth.json:/home/codex/.codex/auth.json:ro"
```

When `/home/codex/.codex/auth.json` is mounted, `OPENAI_API_KEY` is optional.

Example using the mounted auth file:

```bash
docker run --rm -it \
  -e GITHUB_TOKEN="$GITHUB_TOKEN" \
  -v "$HOME/.codex/auth.json:/home/codex/.codex/auth.json:ro" \
  -v "$PWD":/home/codex/workspace \
  codex-base:latest
```

Server mode example:

```bash
docker run --rm \
  -e OPENAI_API_KEY="$OPENAI_API_KEY" \
  -e GITHUB_TOKEN="$GITHUB_TOKEN" \
  -e MODE=server \
  -p 4500:4500 \
  -v "$PWD":/home/codex/workspace \
  codex-base:latest
```

This starts `codex app-server --listen ws://0.0.0.0:4500` inside the container so remote clients can connect through the published Docker port.

Server-mode-specific flags:

```bash
-e MODE=server \
  -p 4500:4500 \
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

`OPENAI_API_KEY` can also be omitted if `-v "$HOME/.codex/auth.json:/home/codex/.codex/auth.json:ro"` is used.

## Running `codex-superpowers`

`codex-superpowers` starts with Superpowers already installed, while keeping the same interactive entrypoint behavior as `codex-base`.

Interactive shell example:

```bash
docker run --rm -it \
  -e OPENAI_API_KEY="$OPENAI_API_KEY" \
  -e GITHUB_TOKEN="$GITHUB_TOKEN" \
  -v "$PWD":/home/codex/workspace \
  codex-superpowers:latest
```

If you want to use a host-side Codex auth file instead of `OPENAI_API_KEY`, the mount usage mirrors `codex-base`; replace only the image name:

```bash
docker run --rm -it \
  -e GITHUB_TOKEN="$GITHUB_TOKEN" \
  -v "$HOME/.codex/auth.json:/home/codex/.codex/auth.json:ro" \
  -v "$PWD":/home/codex/workspace \
  codex-superpowers:latest
```

## Environment Variables

### `codex-base`

| Variable | Required | Default | Notes |
| --- | --- | --- | --- |
| `OPENAI_API_KEY` | If `/home/codex/.codex/auth.json` is not mounted | none | Required by the entrypoint unless the auth file is mounted |
| `GITHUB_TOKEN` | Yes | none | Used for `gh auth login --with-token` |
| `MODE` | No | `interactive` | Supported values: `interactive`, `server` |
| `APP_SERVER_HOST` | No | `0.0.0.0` | Host used when `MODE=server` builds the WebSocket listen URL |
| `APP_SERVER_PORT` | No | `4500` | Port used when `MODE=server` builds the WebSocket listen URL |
| `GIT_NAME` | No | `Codex` | Used only if global Git name is unset |
| `GIT_EMAIL` | No | `codex@local` | Used only if global Git email is unset |

## Security Notes

- `OPENAI_API_KEY`, `GITHUB_TOKEN`, and host-side `~/.codex/auth.json` contents are sensitive secrets; handle them with environment and file-permission management appropriate for your system.
- Review container mounts carefully before exposing host credentials or source trees inside the image.

## Differences from `opencode-container`

This repository is focused on the OpenAI Codex CLI stack rather than the OpenCode stack:

- it installs `@openai/codex` instead of OpenCode tooling
- the primary authenticated environment variables are `OPENAI_API_KEY` and `GITHUB_TOKEN`
- it provides one optional Superpowers-enabled variant, `codex-superpowers`

## License

No license file is currently included in this repository. Treat the contents as unlicensed unless and until a license is added.
