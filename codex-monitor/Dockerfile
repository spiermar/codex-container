FROM codex-base:latest

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    libssl-dev \
    pkg-config && \
    rm -rf /var/lib/apt/lists/*

USER codex
WORKDIR /home/codex

SHELL ["/bin/bash", "-lc"]

ENV PATH=/home/codex/bin:/home/codex/.cargo/bin:$PATH

ARG CODEX_MONITOR_REF=main

RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable && \
    mkdir -p /home/codex/bin && \
    git clone --depth 1 --branch "$CODEX_MONITOR_REF" https://github.com/Dimillian/CodexMonitor.git /home/codex/CodexMonitor && \
    cargo build --locked --release \
      --manifest-path /home/codex/CodexMonitor/src-tauri/Cargo.toml \
      --bin codex_monitor_daemon \
      --bin codex_monitor_daemonctl && \
    install -m 0755 /home/codex/CodexMonitor/src-tauri/target/release/codex_monitor_daemon /home/codex/bin/codex_monitor_daemon && \
    install -m 0755 /home/codex/CodexMonitor/src-tauri/target/release/codex_monitor_daemonctl /home/codex/bin/codex_monitor_daemonctl && \
    rm -rf /home/codex/CodexMonitor

COPY --chown=codex:codex entrypoint.sh /home/codex/entrypoint-monitor.sh
RUN chmod +x /home/codex/entrypoint-monitor.sh

ENV MODE=daemon \
    CODEX_MONITOR_HOST=0.0.0.0 \
    CODEX_MONITOR_PORT=4732

WORKDIR /home/codex/workspace

ENTRYPOINT ["/home/codex/entrypoint-monitor.sh"]
