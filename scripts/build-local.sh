#!/usr/bin/env bash
set -euo pipefail
mvn -B clean verify
mkdir -p .local/efs
chmod 777 .local/efs # solo laboratorio local
docker compose -f docker-compose.local.yml up -d --build
curl --fail --retry 20 --retry-delay 2 --retry-connrefused http://localhost:8080/api/health
