#!/bin/sh
# Reset docker-02: remove the containers and the volume, pre-pull images, build the api image.
# Run from the repo root (see the root README for the full docker run command).
set -eu
cd "$(dirname "$0")/.."
docker compose -f race.compose.yaml down -v >/dev/null 2>&1
# Pre-pull so nothing downloads live. If a pull fails (offline, Docker Hub rate limit), a local copy will do.
for img in postgres:18 node:24-slim; do docker pull -q "$img" >/dev/null || docker image inspect "$img" >/dev/null; done
docker compose -f race.compose.yaml build -q api
echo "docker-02 ready: fresh volume, api image built."
