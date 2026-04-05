#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

bash scripts/validate.sh

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required for CI validation"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for CI validation"
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "a running Docker daemon is required for CI validation"
  exit 1
fi

docker run --rm \
  -v "${ROOT_DIR}/ops/prometheus:/work:ro" \
  prom/prometheus:v3.2.1 \
  promtool check config /work/prometheus.yml

docker run --rm \
  -v "${ROOT_DIR}/ops/prometheus/rules:/work:ro" \
  prom/prometheus:v3.2.1 \
  promtool check rules /work/host-alerts.yml

jq empty "${ROOT_DIR}/ops/grafana/dashboards/server-overview.json"
echo "grafana dashboard json: ok"
