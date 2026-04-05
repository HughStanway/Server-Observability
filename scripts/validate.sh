#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

ENV_FILE=""

if [[ -f .env ]]; then
  ENV_FILE=".env"
elif [[ -f .env.example ]]; then
  ENV_FILE=".env.example"
fi

if [[ -n "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

docker compose config >/dev/null
echo "docker compose config: ok"
