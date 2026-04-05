FROM codex-base:latest

USER codex
WORKDIR /home/codex

SHELL ["/bin/bash", "-lc"]

RUN mkdir -p /home/codex/.codex /home/codex/.agents/skills && \
    git clone --branch main https://github.com/obra/superpowers.git /home/codex/.codex/superpowers && \
    ln -s /home/codex/.codex/superpowers/skills /home/codex/.agents/skills/superpowers && \
    printf '[features]\nmulti_agent = true\n' > /home/codex/.codex/config.toml

WORKDIR /home/codex/workspace
