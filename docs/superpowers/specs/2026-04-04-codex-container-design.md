# Codex Container Design

Docker containers for running Codex CLI with optional CodexMonitor daemon support.

## Project Structure

```
codex-container/
├── Makefile
├── README.md
├── base/
│   └── Dockerfile
├── codex-monitor/
│   └── Dockerfile
└── .gitignore
```

## Architecture

### Image Variants

| Image | Description |
|-------|-------------|
| `codex-base` | Base image with Codex CLI and common development tools |
| `codex-monitor` | CodexMonitor daemon for headless remote backend support |

### codex-base Image

Base image providing all common dependencies and Codex CLI.

**Includes:**
- **OS:** Ubuntu (latest)
- **Tools:** git, curl, jq, make, vim, ripgrep, wget, zip, openssh-client, postgresql-client, GitHub CLI
- **Runtime:** Node.js LTS (via nvm)
- **Codex CLI:** `@openai/codex@latest`
- **Provider:** OpenAI (pre-configured)

**User:** `codex` (non-root user with sudo access)

### codex-monitor Image

Adds CodexMonitor daemon binaries on top of codex-base for headless remote backend support.

**Includes:**
- Everything from codex-base
- **Rust toolchain:** stable (for building daemon binaries)
- **CodexMonitor:** Cloned from GitHub and built during image build
- **Pre-built binaries:**
  - `codex_monitor_daemon` - Remote daemon process
  - `codex_monitor_daemonctl` - Daemon control CLI

**Additional capabilities:**
- Headless daemon mode (no desktop UI required)
- Interactive mode for debugging/development

## Environment Variables

### codex-base

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `OPENAI_API_KEY` | Yes | - | API key for OpenAI provider |
| `GITHUB_TOKEN` | Yes | - | GitHub token for `gh` CLI authentication |
| `GIT_EMAIL` | No | `codex@local` | Git commit email |
| `GIT_NAME` | No | `Codex` | Git commit author name |
| `MODE` | No | `interactive` | Run mode: `interactive` |

### codex-monitor

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `OPENAI_API_KEY` | Yes | - | API key for OpenAI provider |
| `GITHUB_TOKEN` | Yes | - | GitHub token for `gh` CLI authentication |
| `GIT_EMAIL` | No | `codex@local` | Git commit email |
| `GIT_NAME` | No | `Codex` | Git commit author name |
| `MODE` | No | `daemon` | Run mode: `daemon` or `interactive` |
| `CODEX_MONITOR_TOKEN` | No | - | Token for daemon authentication |
| `CODEX_MONITOR_HOST` | No | `0.0.0.0` | Host to bind daemon |
| `CODEX_MONITOR_PORT` | No | `4732` | Port for daemon listener |

## Running Modes

### codex-base

**Interactive Mode (default):**
```bash
docker run -it \
  -e OPENAI_API_KEY="your-api-key" \
  -e GITHUB_TOKEN="your-github-token" \
  -v /path/to/workspace:/home/codex/workspace \
  codex-base
```

Starts a bash shell for direct interaction. Once inside the container, run `codex` to start the Codex CLI.

### codex-monitor

**Daemon Mode (default):**
```bash
docker run -d \
  -e OPENAI_API_KEY="your-api-key" \
  -e GITHUB_TOKEN="your-github-token" \
  -e CODEX_MONITOR_TOKEN="your-token" \
  -p 4732:4732 \
  -v /path/to/workspace:/home/codex/workspace \
  codex-monitor
```

Starts the CodexMonitor daemon in headless mode. Connect from iOS or another machine using the token and host:port.

**Interactive Mode:**
```bash
docker run -it \
  -e OPENAI_API_KEY="your-api-key" \
  -e GITHUB_TOKEN="your-github-token" \
  -e MODE=interactive \
  -v /path/to/workspace:/home/codex/workspace \
  codex-monitor
```

Starts a bash shell. Useful for debugging or running `codex_monitor_daemonctl` commands manually.

## Build Process

### Makefile Targets

```bash
# Build all images (base first, then codex-monitor)
make all

# Build individual images
make base
make codex-monitor

# Clean built images
make clean
```

### Build Dependencies

```
codex-base
  └── codex-monitor (depends on codex-base)
```

### Dockerfile Strategy

**base/Dockerfile:**
- Multi-stage build to minimize final image size
- Stage 1: Install build dependencies
- Stage 2: Final image with only runtime dependencies

**codex-monitor/Dockerfile:**
- Uses `codex-base` as base image
- Installs Rust toolchain
- Clones CodexMonitor repository
- Builds daemon binaries
- Copies binaries to final stage
- Removes build artifacts to keep image size down

## Entry Point Script

The container uses an entry point script (`entrypoint.sh`) to handle different modes:

1. **Interactive mode:** Starts bash shell
2. **Daemon mode:** Starts `codex_monitor_daemon` with configured options

The entry point also:
- Configures git with `GIT_EMAIL` and `GIT_NAME`
- Validates required environment variables
- Sets up proper file permissions

## Data Persistence

Recommended volumes:
- `/home/codex/workspace` - Your project/workspace directory
- `/home/codex/.codex` - Codex configuration and data (optional)

## Security Considerations

- Run as non-root user (`codex`)
- API keys passed via environment variables (not baked into image)
- Token-based authentication for daemon mode
- No sensitive data committed to the image

## Differences from opencode-container

| Aspect | opencode-container | codex-container |
|--------|-------------------|-----------------|
| CLI | OpenCode | Codex |
| Provider | Parasail (default) | OpenAI |
| Variants | 4 variants (superpowers, ralph, oh-my-opencode, gsd) | 1 variant (codex-monitor) |
| Skills | Pre-installed (anthropics, vercel-labs, spiermar) | None |
| Monitor | CodeNomad | CodexMonitor |
| Modes | server, codenomad, interactive | interactive, daemon |

## Success Criteria

1. `codex-base` image builds successfully and Codex CLI runs interactively
2. `codex-monitor` image builds successfully with daemon binaries
3. Daemon mode starts and listens on configured port
4. Interactive mode provides bash shell with access to `codex` and `codex_monitor_daemonctl`
5. Environment variables are properly handled
6. Git configuration is applied on container start
7. Documentation (README.md) covers all usage patterns
