# Codex Container Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Docker containers for running Codex CLI with optional CodexMonitor daemon support.

**Architecture:** Two-image design with codex-base providing common tools and Codex CLI, and codex-monitor adding headless daemon binaries for remote backend support.

**Tech Stack:** Docker, Ubuntu, Node.js, Rust, Codex CLI, CodexMonitor

---

## File Structure

```
codex-container/
├── Makefile                          # Build automation
├── README.md                         # Documentation
├── .gitignore                        # Git ignore patterns
├── base/
│   ├── Dockerfile                    # Base image definition
│   └── entrypoint.sh                 # Entry point script for base
└── codex-monitor/
    ├── Dockerfile                    # Monitor image definition
    └── entrypoint.sh                 # Entry point script for monitor
```

---

### Task 1: Project Setup

**Files:**
- Create: `.gitignore`
- Create: `README.md` (placeholder, will be updated in Task 7)

- [ ] **Step 1: Create .gitignore file**

```gitignore
# Docker
*.log

# OS
.DS_Store
Thumbs.db

# Editor
.vscode/
.idea/
*.swp
*.swo
*~

# Temporary files
tmp/
temp/
```

- [ ] **Step 2: Create placeholder README.md**

```markdown
# codex-container

Docker containers for running Codex CLI with optional CodexMonitor daemon support.

**Work in progress...**
```

- [ ] **Step 3: Commit project setup**

```bash
git add .gitignore README.md
git commit -m "chore: add project setup files"
```

---

### Task 2: Base Image Dockerfile

**Files:**
- Create: `base/Dockerfile`

- [ ] **Step 1: Create base directory**

```bash
mkdir -p base
```

- [ ] **Step 2: Write base/Dockerfile**

```dockerfile
# Stage 1: Build stage for any compile-time dependencies
FROM ubuntu:latest AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Stage 2: Final image
FROM ubuntu:latest

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install essential tools
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    jq \
    make \
    vim \
    ripgrep \
    zip \
    unzip \
    openssh-client \
    postgresql-client \
    sudo \
    ca-certificates \
    gnupg \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
    https://cli.github.com/packages stable main" | \
    sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && \
    apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*

# Create codex user with sudo access
RUN useradd -m -s /bin/bash codex && \
    echo "codex ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Install Node.js LTS via nvm
USER codex
WORKDIR /home/codex

ENV NVM_DIR=/home/codex/.nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash && \
    . "$NVM_DIR/nvm.sh" && \
    nvm install --lts && \
    nvm use --lts && \
    nvm alias default lts/*

# Add Node.js to PATH
ENV PATH="/home/codex/.nvm/versions/node/$(ls /home/codex/.nvm/versions/node)/bin:$PATH"

# Install Codex CLI
RUN npm install -g @openai/codex@latest

# Create workspace directory
RUN mkdir -p /home/codex/workspace

# Copy entrypoint script
COPY --chown=codex:codex entrypoint.sh /home/codex/entrypoint.sh
RUN chmod +x /home/codex/entrypoint.sh

# Set environment variables
ENV MODE=interactive
ENV GIT_EMAIL=codex@local
ENV GIT_NAME=Codex

# Set working directory
WORKDIR /home/codex/workspace

# Entry point
ENTRYPOINT ["/home/codex/entrypoint.sh"]
```

- [ ] **Step 3: Commit base Dockerfile**

```bash
git add base/
git commit -m "feat: add base Dockerfile"
```

---

### Task 3: Base Image Entrypoint Script

**Files:**
- Create: `base/entrypoint.sh`

- [ ] **Step 1: Write base/entrypoint.sh**

```bash
#!/bin/bash
set -e

# Configure git
git config --global user.email "${GIT_EMAIL:-codex@local}"
git config --global user.name "${GIT_NAME:-Codex}"

# Validate required environment variables
if [ -z "$OPENAI_API_KEY" ]; then
    echo "Error: OPENAI_API_KEY is not set"
    exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GITHUB_TOKEN is not set"
    exit 1
fi

# Configure GitHub CLI
echo "$GITHUB_TOKEN" | gh auth login --with-token

# Handle different modes
case "${MODE:-interactive}" in
    interactive)
        echo "Starting interactive mode..."
        exec /bin/bash
        ;;
    *)
        echo "Error: Unknown MODE '${MODE}'. Supported modes: interactive"
        exit 1
        ;;
esac
```

- [ ] **Step 2: Make entrypoint executable (handled in Dockerfile, but ensure locally too)**

```bash
chmod +x base/entrypoint.sh
```

- [ ] **Step 3: Commit base entrypoint script**

```bash
git add base/entrypoint.sh
git commit -m "feat: add base entrypoint script"
```

---

### Task 4: CodexMonitor Image Dockerfile

**Files:**
- Create: `codex-monitor/Dockerfile`

- [ ] **Step 1: Create codex-monitor directory**

```bash
mkdir -p codex-monitor
```

- [ ] **Step 2: Write codex-monitor/Dockerfile**

```dockerfile
# Use codex-base as the base image
# Note: This assumes codex-base has been built locally
FROM codex-base:latest

USER root

# Install Rust toolchain (needed for building CodexMonitor)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:$PATH"

# Install build dependencies for CodexMonitor
RUN apt-get update && apt-get install -y \
    build-essential \
    pkg-config \
    libssl-dev \
    cmake \
    && rm -rf /var/lib/apt/lists/*

# Switch to codex user for building
USER codex
WORKDIR /home/codex

# Clone and build CodexMonitor
RUN git clone https://github.com/Dimillian/CodexMonitor.git codexmonitor-src && \
    cd codexmonitor-src && \
    . "$NVM_DIR/nvm.sh" && \
    npm install && \
    cd src-tauri && \
    cargo build --release --bin codex_monitor_daemon --bin codex_monitor_daemonctl

# Create bin directory and copy binaries
RUN mkdir -p /home/codex/bin && \
    cp /home/codex/codexmonitor-src/src-tauri/target/release/codex_monitor_daemon /home/codex/bin/ && \
    cp /home/codex/codexmonitor-src/src-tauri/target/release/codex_monitor_daemonctl /home/codex/bin/ && \
    chmod +x /home/codex/bin/*

# Clean up build artifacts to reduce image size
RUN rm -rf /home/codex/codexmonitor-src

# Add binaries to PATH
ENV PATH="/home/codex/bin:$PATH"

USER root

# Clean up Rust installation to reduce image size (binaries are already built)
RUN rm -rf /root/.cargo /root/.rustup

# Install minimal runtime dependencies if needed
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

USER codex

# Copy entrypoint script
COPY --chown=codex:codex entrypoint.sh /home/codex/entrypoint-monitor.sh
RUN chmod +x /home/codex/entrypoint-monitor.sh

# Set environment variables
ENV MODE=daemon
ENV CODEX_MONITOR_HOST=0.0.0.0
ENV CODEX_MONITOR_PORT=4732

# Set working directory
WORKDIR /home/codex/workspace

# Entry point
ENTRYPOINT ["/home/codex/entrypoint-monitor.sh"]
```

- [ ] **Step 3: Commit codex-monitor Dockerfile**

```bash
git add codex-monitor/
git commit -m "feat: add codex-monitor Dockerfile"
```

---

### Task 5: CodexMonitor Entrypoint Script

**Files:**
- Create: `codex-monitor/entrypoint.sh`

- [ ] **Step 1: Write codex-monitor/entrypoint.sh**

```bash
#!/bin/bash
set -e

# Configure git
git config --global user.email "${GIT_EMAIL:-codex@local}"
git config --global user.name "${GIT_NAME:-Codex}"

# Validate required environment variables
if [ -z "$OPENAI_API_KEY" ]; then
    echo "Error: OPENAI_API_KEY is not set"
    exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GITHUB_TOKEN is not set"
    exit 1
fi

# Configure GitHub CLI
echo "$GITHUB_TOKEN" | gh auth login --with-token

# Handle different modes
case "${MODE:-daemon}" in
    daemon)
        echo "Starting CodexMonitor daemon in headless mode..."
        
        # Build daemon command
        DAEMON_CMD="codex_monitor_daemon --listen ${CODEX_MONITOR_HOST:-0.0.0.0}:${CODEX_MONITOR_PORT:-4732}"
        
        # Add token if provided
        if [ -n "$CODEX_MONITOR_TOKEN" ]; then
            DAEMON_CMD="$DAEMON_CMD --token $CODEX_MONITOR_TOKEN"
        fi
        
        # Add data directory (use workspace by default)
        DAEMON_CMD="$DAEMON_CMD --data-dir /home/codex/.codexmonitor"
        
        echo "Running: $DAEMON_CMD"
        exec $DAEMON_CMD
        ;;
    interactive)
        echo "Starting interactive mode..."
        echo "Available commands: codex, codex_monitor_daemon, codex_monitor_daemonctl"
        exec /bin/bash
        ;;
    *)
        echo "Error: Unknown MODE '${MODE}'. Supported modes: daemon, interactive"
        exit 1
        ;;
esac
```

- [ ] **Step 2: Make entrypoint executable**

```bash
chmod +x codex-monitor/entrypoint.sh
```

- [ ] **Step 3: Commit codex-monitor entrypoint script**

```bash
git add codex-monitor/entrypoint.sh
git commit -m "feat: add codex-monitor entrypoint script"
```

---

### Task 6: Build Automation with Makefile

**Files:**
- Create: `Makefile`

- [ ] **Step 1: Write Makefile**

```makefile
.PHONY: all base codex-monitor clean

# Default target
all: base codex-monitor

# Build base image
base:
	@echo "Building codex-base image..."
	docker build -t codex-base:latest ./base
	@echo "✓ codex-base image built successfully"

# Build codex-monitor image (depends on base)
codex-monitor: base
	@echo "Building codex-monitor image..."
	docker build -t codex-monitor:latest ./codex-monitor
	@echo "✓ codex-monitor image built successfully"

# Clean built images
clean:
	@echo "Removing codex-container images..."
	docker rmi -f codex-monitor:latest 2>/dev/null || true
	docker rmi -f codex-base:latest 2>/dev/null || true
	@echo "✓ Images removed"

# Test base image
test-base: base
	@echo "Testing codex-base image..."
	docker run --rm -it \
		-e OPENAI_API_KEY="test-key" \
		-e GITHUB_TOKEN="test-token" \
		-e MODE=interactive \
		codex-base:latest \
		-c "codex --version && gh --version && node --version"
	@echo "✓ codex-base test passed"

# Test codex-monitor image
test-monitor: codex-monitor
	@echo "Testing codex-monitor image..."
	docker run --rm -it \
		-e OPENAI_API_KEY="test-key" \
		-e GITHUB_TOKEN="test-token" \
		-e MODE=interactive \
		codex-monitor:latest \
		-c "codex --version && codex_monitor_daemonctl --help"
	@echo "✓ codex-monitor test passed"
```

- [ ] **Step 2: Commit Makefile**

```bash
git add Makefile
git commit -m "feat: add Makefile for build automation"
```

---

### Task 7: Complete README Documentation

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Write complete README.md**

```markdown
# codex-container

Docker containers for running [Codex](https://github.com/openai/codex) CLI with optional [CodexMonitor](https://github.com/Dimillian/CodexMonitor) daemon support.

The project uses a **base + variant** architecture: a shared base image (`codex-base`) provides all common dependencies, and the variant (`codex-monitor`) adds CodexMonitor daemon binaries for headless remote backend support.

## Image Variants

| Image | Description | Added On Top of Base |
|-------|-------------|----------------------|
| `codex-base` | Codex CLI with development tools | Base image with Node.js, Codex CLI, git, GitHub CLI, and common tools |
| `codex-monitor` | CodexMonitor daemon support | Pre-built daemon binaries (`codex_monitor_daemon`, `codex_monitor_daemonctl`) |

## Building the Images

A `Makefile` is provided to build the base and variant images.

```bash
# Build all images (automatically builds base first)
make all

# Build a specific image
make base
make codex-monitor

# Clean built images
make clean

# Test images (optional)
make test-base
make test-monitor
```

The build dependency chain is:

```
codex-base
  └── codex-monitor (depends on codex-base)
```

## Using the Images

### codex-base

**Interactive Mode (default):**

```bash
docker run -it \
  -e OPENAI_API_KEY="your-api-key" \
  -e GITHUB_TOKEN="your-github-token" \
  -v /path/to/workspace:/home/codex/workspace \
  codex-base:latest
```

Once inside the container, you can run `codex` directly.

### codex-monitor

**Daemon Mode (default):**

Starts the CodexMonitor daemon in headless mode for remote backend access:

```bash
docker run -d \
  -e OPENAI_API_KEY="your-api-key" \
  -e GITHUB_TOKEN="your-github-token" \
  -e CODEX_MONITOR_TOKEN="your-token" \
  -p 4732:4732 \
  -v /path/to/workspace:/home/codex/workspace \
  codex-monitor:latest
```

**Interactive Mode:**

Starts a bash shell for debugging or manual daemon management:

```bash
docker run -it \
  -e OPENAI_API_KEY="your-api-key" \
  -e GITHUB_TOKEN="your-github-token" \
  -e MODE=interactive \
  -v /path/to/workspace:/home/codex/workspace \
  codex-monitor:latest
```

Once inside, you can use:
- `codex` - Start the Codex CLI
- `codex_monitor_daemonctl status` - Check daemon status
- `codex_monitor_daemonctl start` - Start daemon manually
- `codex_monitor_daemonctl stop` - Stop daemon

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

## Data Persistence

Recommended volumes:
- `/home/codex/workspace` - Your project/workspace directory (required)
- `/home/codex/.codex` - Codex configuration and data (optional)
- `/home/codex/.codexmonitor` - CodexMonitor data directory (optional, for codex-monitor)

Example with persistent data:

```bash
docker run -d \
  -e OPENAI_API_KEY="your-api-key" \
  -e GITHUB_TOKEN="your-github-token" \
  -e CODEX_MONITOR_TOKEN="your-token" \
  -p 4732:4732 \
  -v /path/to/workspace:/home/codex/workspace \
  -v codex-data:/home/codex/.codex \
  -v codexmonitor-data:/home/codex/.codexmonitor \
  codex-monitor:latest
```

## Custom Port

To use a custom port for the daemon:

```bash
docker run -d \
  -e OPENAI_API_KEY="your-api-key" \
  -e GITHUB_TOKEN="your-github-token" \
  -e CODEX_MONITOR_TOKEN="your-token" \
  -e CODEX_MONITOR_PORT=8080 \
  -p 8080:8080 \
  -v /path/to/workspace:/home/codex/workspace \
  codex-monitor:latest
```

## Connecting from iOS or Remote Machine

Once the daemon is running, you can connect from the CodexMonitor iOS app or another machine:

1. Ensure both devices are on the same network or connected via Tailscale
2. In the CodexMonitor app, go to Settings > Server
3. Enter the host and port (e.g., `your-machine-ip:4732` or `your-machine.your-tailnet.ts.net:4732`)
4. Enter the token you set with `CODEX_MONITOR_TOKEN`
5. Tap "Connect & test"

## Security Notes

- Run as non-root user (`codex`) for better security
- API keys and tokens are passed via environment variables, not baked into the image
- Token-based authentication for daemon mode
- No sensitive data committed to the image

## Requirements

- Docker (latest version recommended)
- OpenAI API key
- GitHub personal access token (for `gh` CLI)

## Differences from opencode-container

| Aspect | opencode-container | codex-container |
|--------|-------------------|-----------------|
| CLI | OpenCode | Codex |
| Provider | Parasail (default) | OpenAI |
| Variants | 4 variants | 1 variant (codex-monitor) |
| Skills | Pre-installed | None |
| Monitor | CodeNomad | CodexMonitor |

## License

MIT
```

- [ ] **Step 2: Commit complete README**

```bash
git add README.md
git commit -m "docs: add complete README documentation"
```

---

### Task 8: Final Verification and Testing

**Files:**
- No new files

- [ ] **Step 1: Verify project structure**

```bash
ls -la
ls -la base/
ls -la codex-monitor/
```

Expected output: All files in place as defined in file structure.

- [ ] **Step 2: Build all images**

```bash
make clean
make all
```

Expected: Both images build successfully without errors.

- [ ] **Step 3: Test base image interactively**

```bash
docker run --rm -it \
  -e OPENAI_API_KEY="test-key" \
  -e GITHUB_TOKEN="test-token" \
  codex-base:latest \
  -c "codex --version && gh --version && node --version && git --version"
```

Expected: All version commands succeed.

- [ ] **Step 4: Test codex-monitor image binaries**

```bash
docker run --rm -it \
  -e OPENAI_API_KEY="test-key" \
  -e GITHUB_TOKEN="test-token" \
  -e MODE=interactive \
  codex-monitor:latest \
  -c "codex_monitor_daemonctl --help"
```

Expected: Help output displayed successfully.

- [ ] **Step 5: Final commit with all changes**

```bash
git status
```

Ensure all changes are committed. If any uncommitted files:

```bash
git add -A
git commit -m "chore: final cleanup and verification"
```

---

## Self-Review Checklist

- [x] **Spec coverage:** Each section in the spec maps to tasks
  - Project structure → Task 1
  - Base image → Tasks 2-3
  - CodexMonitor image → Tasks 4-5
  - Build process → Task 6
  - Documentation → Task 7
  - Verification → Task 8
- [x] **Placeholder scan:** No TBD, TODO, or vague instructions
- [x] **Type consistency:** Environment variable names consistent across all files
- [x] **File paths:** All file paths are exact and complete
- [x] **Code completeness:** All code blocks show complete implementation
- [x] **Test commands:** All test commands include expected output
