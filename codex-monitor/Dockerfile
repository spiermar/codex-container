FROM codex-base:latest

USER root

ENV CARGO_HOME="/usr/local/cargo" \
    RUSTUP_HOME="/usr/local/rustup" \
    CODEX_MONITOR_COMMIT="dd61b9abd37de5ded86e82b9fe8a83fd49d46fa5"

RUN mkdir -p "$CARGO_HOME" "$RUSTUP_HOME" && \
    curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable && \
    chown -R codex:codex "$CARGO_HOME" "$RUSTUP_HOME"

ENV PATH="/usr/local/cargo/bin:$PATH"

RUN apt-get update && apt-get install -y --no-install-recommends \
    libasound2-dev \
    build-essential \
    cmake \
    libayatana-appindicator3-dev \
    libclang-dev \
    libglib2.0-dev \
    libssl-dev \
    librsvg2-dev \
    libwebkit2gtk-4.1-dev \
    libxdo-dev \
    pkg-config && \
    rm -rf /var/lib/apt/lists/*

USER codex
WORKDIR /home/codex

SHELL ["/bin/bash", "-lc"]

RUN mkdir -p /home/codex/bin && \
    git clone https://github.com/Dimillian/CodexMonitor.git codexmonitor-src && \
    git -C codexmonitor-src checkout "$CODEX_MONITOR_COMMIT" && \
    source "$NVM_DIR/nvm.sh" && \
    cd codexmonitor-src && \
    if [ -f package-lock.json ]; then npm ci; else npm install; fi && \
    cd src-tauri && \
    cargo build --locked --release --bin codex_monitor_daemon --bin codex_monitor_daemonctl && \
    install -m 0755 target/release/codex_monitor_daemon /home/codex/bin/codex_monitor_daemon && \
    install -m 0755 target/release/codex_monitor_daemonctl /home/codex/bin/codex_monitor_daemonctl && \
    rm -rf /home/codex/codexmonitor-src

ENV PATH="/home/codex/bin:$PATH"

USER root

RUN rm -rf /root/.cargo /root/.rustup && \
    apt-get update && apt-get install -y --no-install-recommends ca-certificates && \
    rm -rf /var/lib/apt/lists/*

USER codex

COPY --chown=codex:codex entrypoint.sh /home/codex/entrypoint-monitor.sh
RUN chmod +x /home/codex/entrypoint-monitor.sh

ENV MODE=daemon \
    CODEX_MONITOR_HOST=0.0.0.0 \
    CODEX_MONITOR_PORT=4732

WORKDIR /home/codex/workspace

ENTRYPOINT ["/home/codex/entrypoint-monitor.sh"]
