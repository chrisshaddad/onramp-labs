# docker-01-naive-vs-optimized

**Deck:** S03 - Containers and Docker, slide "Demo - Naive vs Optimized Image" (right after "Build Secrets"). The slide's table is filled in live: base image, image size, rebuild after a code edit, whoami.
**Teaches:** instruction order decides what the build cache can reuse, and Docker decides by content, not timestamps. A slim base and a second stage shrink the image; `USER node` removes root.
**Runs on:** the host's Docker CLI, in PowerShell or bash · **Demo time:** 12 minutes at most, including the timestamp step. The optional step 0 adds about 1 minute.

## Setup

1. Before the session, from the repo root:
   `docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "${PWD}:/lab" -w /lab docker:29-cli sh docker-01-naive-vs-optimized/scripts/reset.sh`
   It removes the two lab images, puts the greeting back to v1, writes a new `app/.reset-id` and pre-pulls `node:24`, `node:24-slim` and `alpine:3`. It keeps the build cache: `docker builder prune` would wipe your whole cache, not just the lab's.
2. Open a terminal in `docker-01-naive-vs-optimized/app`, and `src/server.ts` in the editor.

Why `.reset-id`: BuildKit caches by content, so after one rehearsal (or one `verify.sh`) the v2 and v3 versions of `server.ts` are already in the cache, and the live edit would show `RUN npm ci` as `CACHED`. The reset writes a new timestamp into this gitignored file, so every session's edits are new content. As a side effect, the first naive build of a session also runs `npm ci`.

## Run sheet

The demo slide's speaker notes use the same text.

```
Open a terminal in onramp-labs/docker-01-naive-vs-optimized/app, and src/server.ts in the editor.
0  (optional) docker run --rm node:24-slim sh -c "uname -r; grep PRETTY_NAME /etc/os-release"
              docker run --rm alpine:3 sh -c "uname -r; grep PRETTY_NAME /etc/os-release"
                                                       different OS files, same kernel
1  docker build -f naive.Dockerfile -t onramp-api:naive .
   docker image ls onramp-api
   docker history onramp-api:naive                     one layer per step; CMD is 0 B
2  (chat) which steps rerun after a one-line edit?
   docker run --rm -v "${PWD}:/app" alpine:3 touch /app/src/server.ts
   docker build -f naive.Dockerfile -t onramp-api:naive .
                                                       all CACHED: Docker hashes contents, not timestamps
   edit src/server.ts: "hello v1" -> "hello v2", save
   docker build -f naive.Dockerfile -t onramp-api:naive .
                                                       COPY, npm ci and the build rerun
3  docker build -t onramp-api:optimized .
   edit src/server.ts: "hello v2" -> "hello v3", save
   docker build -t onramp-api:optimized .              npm ci CACHED; only COPY . . and the build rerun
4  docker image ls onramp-api                          sizes for the table
   docker run --rm onramp-api:naive whoami             root
   docker run --rm onramp-api:optimized whoami         node
5  Fill in the table on the slide.
```

- Fallback: open `recorded-run.md` in this folder and walk through it.
- Run the reset command again afterwards.

## Expected output

Measured on the Windows laptop (Docker Desktop 4.54.0 on WSL 2, 16 CPUs) by running the run sheet in PowerShell. `npm ci` downloads every package on a cache miss, so its time follows the network: compare the shape, not the exact values. `recorded-run.md` has a full run.

| Step | What to point at |
|---|---|
| 0 | Both print the same kernel, `6.18.33.2-microsoft-standard-WSL2` (Docker Desktop's VM), but different `PRETTY_NAME` lines: `Debian GNU/Linux 12 (bookworm)` and `Alpine Linux v3.24`. |
| 1 | The first build of a session runs `npm ci` (see Setup): about 14 s in all, up to 35 s on a slow network. `docker image ls` shows `onramp-api:naive` at 1.71GB DISK USAGE, 433MB CONTENT SIZE. `docker history` shows one row per instruction; the `CMD` row is `0B`. |
| 2, timestamp | Every step after `FROM` shows `CACHED`: `WORKDIR`, `COPY . .`, `RUN npm ci`, `RUN npm run build`. Under 1 s. |
| 2, edit | `COPY . .`, `RUN npm ci` and `RUN npm run build` rerun. `npm ci` took 11 s and the whole rebuild 16 s (27 s and 30 s in `recorded-run.md`, a few minutes earlier on the same laptop). |
| 3 | The first optimized build takes about 14 s if its `npm ci` isn't cached yet, a few seconds after a rehearsal. After the v3 edit, `COPY package*.json ./` and `RUN npm ci` show `CACHED`; only `COPY . .` and the build rerun: about 3 s in all. |
| 4 | The sizes in the table below. `whoami`: `root`, then `node`. |

### The slide table, measured

| | Naive | Optimized |
|---|---|---|
| Base image | `node:24` | `node:24-slim` |
| Image size (DISK USAGE) | 1.71GB | 335MB |
| Image size (CONTENT SIZE) | 433MB | 81.5MB |
| Rebuild after a code edit | 16 to 30 s (`npm ci` reruns) | about 3 s (`npm ci` cached) |
| whoami | root | node |

With the containerd image store (the default in current Docker Desktop), `docker image ls` shows two sizes. DISK USAGE is the unpacked size on disk, base image layers included; CONTENT SIZE is the compressed size a pull or push transfers. Use DISK USAGE on the slide: it's the first size column and what `docker images` called SIZE before the containerd store. Both give the same ratio, about 5x.

## Verify

From the repo root:

```
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "${PWD}:/lab" -w /lab docker:29-cli sh docker-01-naive-vs-optimized/scripts/verify.sh
```

This runs the whole demo without pauses (edits with `sed`), prints PASS/WARN/FAIL per check, writes `recorded-run.md` in this folder and ends with a reset. Beyond the run sheet, it checks that the per-Dockerfile ignore file works and that the optimized container answers and stops cleanly on SIGTERM. Only timing checks WARN. Commit the new `recorded-run.md` when the numbers change.

## Versions

Recorded on 2026-09-30.

| What | Version |
|---|---|
| Docker Desktop | 4.54.0 (212467), Engine 29.1.2, WSL 2 kernel 6.18.33.2 |
| Script image | `docker:29-cli`: Docker CLI 29.8.1, buildx 0.37.1, Compose 5.5.1 (`sha256:018edbc908e08fcc9dbf029c812c34251e9b4719e6f71ca0e5eae2a987d014ca`) |
| `node:24` | Node 24.21.0, npm 11.19.0 (`sha256:64af3819f9275802414d7cdc38c27e9d82bd564dec4d4da87d008255d36c63b4`) |
| `node:24-slim` | Node 24.21.0 on Debian 12 (`sha256:0e0ff40c39bc087845bfb27465a0df4ea419520094bc35842ff83dd8cbe6f9b6`) |
| `alpine:3` | 3.24 (`sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6`) |
| npm packages | express 5.2.1; dev: typescript 7.0.2, @types/express 5.0.6, @types/node 24.19.0 |

The digests are the multi-platform index digests the tags resolved to. The tags move: to reproduce these numbers exactly, pin them, for example `FROM node:24@sha256:64af...`. `@types/node` follows the runtime (Node 24) rather than the newest types (26.x). `tsconfig.json` sets `"types": ["node"]` so the Node globals don't depend on the compiler's defaults.

## Files

| Path | What it is |
|---|---|
| `app/src/server.ts` | The API: `GET /` returns the greeting, `GET /healthz`, and a SIGTERM handler that matches the "Graceful Shutdown" slide |
| `app/package.json`, `app/package-lock.json`, `app/tsconfig.json` | Express, plus TypeScript as a dev dependency; `npm run build` compiles `src/` to `dist/` |
| `app/naive.Dockerfile` | The Dockerfile from the recap and caching slides, on `node:24` |
| `app/naive.Dockerfile.dockerignore` | Empty on purpose. With BuildKit, `-f naive.Dockerfile` reads this file instead of `.dockerignore`, so the naive build sends the whole folder |
| `app/Dockerfile` | The "Multi-Stage Builds" slide, verbatim |
| `app/.dockerignore` | The optimized build's ignore list |
| `app/.reset-id` | Written by the reset, not in git (see Setup) |
| `scripts/reset.sh` | The one reset command |
| `scripts/verify.sh` | End-to-end check and transcript |

## Troubleshooting

- **Step 2's edit shows `RUN npm ci` as `CACHED`:** you ran the demo since the last reset. Run the reset command.
- **Step 2's touch rebuild is not all `CACHED`:** the file's contents changed, usually because an editor saved it with CRLF line endings. Keep it on LF (VS Code shows LF or CRLF in the status bar) and run the reset.
- **`docker: error during connect` or `Cannot connect to the Docker daemon`:** start Docker Desktop.
- **The reset command fails with a mount or socket error in Git Bash:** use PowerShell or Windows Terminal. Git Bash rewrites the `/var/run/docker.sock` and `/lab` paths.
