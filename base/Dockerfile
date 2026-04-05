FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    bubblewrap \
    ca-certificates \
    curl \
    git \
    gnupg \
    jq \
    lsb-release \
    make \
    openssh-client \
    postgresql-client \
    ripgrep \
    sudo \
    unzip \
    vim \
    wget \
    zip && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends gh && \
    rm -rf /var/lib/apt/lists/*

RUN (getent passwd 1000 | cut -d: -f1 | xargs -r userdel -r 2>/dev/null || true) && \
    (getent passwd codex >/dev/null && userdel -r codex 2>/dev/null || true) && \
    (getent passwd | awk -F: '$4 == 1000 {print $1}' | xargs -r -n1 usermod -g nogroup 2>/dev/null || true) && \
    existing_group="$(getent group 1000 | cut -d: -f1)" && \
    if [ -n "$existing_group" ]; then \
        if [ "$existing_group" != "codex" ]; then \
            if getent group codex >/dev/null; then \
                groupmod -n "codex-old-$$" codex; \
            fi; \
            groupmod -n codex "$existing_group"; \
        fi; \
    elif getent group codex >/dev/null; then \
        groupmod -g 1000 codex; \
    else \
        groupadd -g 1000 codex; \
    fi && \
    useradd -u 1000 -g 1000 -m -s /bin/bash codex && \
    mkdir -p /etc/sudoers.d && \
    echo "codex ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/codex && \
    chmod 0440 /etc/sudoers.d/codex

COPY --chown=codex:codex entrypoint.sh /home/codex/entrypoint.sh
RUN chmod +x /home/codex/entrypoint.sh && \
    mkdir -p /home/codex/.codex /home/codex/workspace && \
    chown -R codex:codex /home/codex

USER codex
WORKDIR /home/codex

ENV MODE=interactive \
    APP_SERVER_HOST=0.0.0.0 \
    APP_SERVER_PORT=4500 \
    GIT_EMAIL=codex@local \
    GIT_NAME=Codex \
    NVM_DIR=/home/codex/.nvm

SHELL ["/bin/bash", "-lc"]

RUN curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash && \
    source "$NVM_DIR/nvm.sh" && \
    nvm install --lts && \
    nvm alias default 'lts/*' && \
    npm install -g @openai/codex@latest && \
    mkdir -p /home/codex/.local/bin && \
    NODE_BIN="$(dirname "$(command -v node)")" && \
    ln -sf "$NODE_BIN/node" /home/codex/.local/bin/node && \
    ln -sf "$NODE_BIN/npm" /home/codex/.local/bin/npm && \
    ln -sf "$NODE_BIN/npx" /home/codex/.local/bin/npx && \
    ln -sf "$NODE_BIN/codex" /home/codex/.local/bin/codex

ENV PATH=/home/codex/.local/bin:$PATH

WORKDIR /home/codex/workspace

ENTRYPOINT ["/home/codex/entrypoint.sh"]
