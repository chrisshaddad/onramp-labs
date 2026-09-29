#!/bin/sh
# Reset docker-01: remove the lab images, put the greeting back to v1, pre-pull base images.
# Run from the repo root (see the root README for the full docker run command).
set -eu
cd "$(dirname "$0")/../app"
docker image rm -f onramp-api:naive onramp-api:optimized >/dev/null 2>&1 || true
sed -i 's/const GREETING = "hello v[0-9]*";/const GREETING = "hello v1";/' src/server.ts
# New build-context content on every reset (the file is gitignored). Without it, the v2 and v3 edits
# of an earlier rehearsal stay in the build cache and npm ci shows CACHED where the demo needs a rerun.
date -u +%Y-%m-%dT%H:%M:%SZ > .reset-id
# Pre-pull so nothing downloads live. If a pull fails (offline, Docker Hub rate limit), a local copy will do.
for img in node:24 node:24-slim alpine:3; do docker pull -q "$img" >/dev/null || docker image inspect "$img" >/dev/null; done
echo "docker-01 ready: lab images removed, greeting is v1, base images pulled."
