#!/usr/bin/env bash
set -euo pipefail

git config --global user.email "${GIT_EMAIL:-codex@local}"
git config --global user.name "${GIT_NAME:-Codex}"

if [ "$#" -gt 0 ]; then
  exec "$@"
fi

if [ "${MODE:-interactive}" = "interactive" ]; then
  exec /bin/bash
fi

exec /bin/bash -lc "${MODE}"
