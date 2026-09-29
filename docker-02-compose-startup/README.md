# docker-02-compose-startup

**Deck:** S03 - Containers and Docker, slides "Quick Check - Works on the Second Try", then "Health Checks in Compose - Gate Startup on Health". Run the race live after posing the question, then the fix.
**Teaches:** short-form `depends_on` waits for the db container to start, not for Postgres to accept connections. A healthcheck plus `condition: service_healthy` fixes startup order; the app still needs retries at runtime.
**Runs on:** the host's Docker CLI, in PowerShell or bash · **Demo time:** about 4 minutes, in place of reading the logs off the slide.

## Why the first run fails

```
fresh volume   db:  container started -> initdb + temporary server (Unix socket only) -> restart -> listening on 5432
               api: started right after db -> connects over TCP -> ECONNREFUSED -> exit 1
warm volume    db:  container started -> listening on 5432 (no initdb)
               api: started right after db -> connects
```

The api connects once at startup and exits on failure, with no retry. That's the bug the slide is about.

The healthcheck uses `pg_isready -h 127.0.0.1` on purpose: during initdb the temporary server listens only on the Unix socket, so a plain `pg_isready` would report healthy too early.

## Setup

1. Before the session, from the repo root:
   `docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "${PWD}:/lab" -w /lab docker:29-cli sh docker-02-compose-startup/scripts/reset.sh`
   It runs `down -v` (removes the containers and the volume), pre-pulls `postgres:18` and `node:24-slim`, and builds the api image so `up` doesn't build live.
2. Open a terminal in `docker-02-compose-startup`.

## Run sheet

The Quick Check slide's speaker notes use the same text.

```
Open a terminal in onramp-labs/docker-02-compose-startup.
1  docker compose -f race.compose.yaml up          fresh volume: api prints ECONNREFUSED and exits 1
   Ctrl+C
   (chat) why does it fail the first time?
2  docker compose -f race.compose.yaml up          data exists now: api connects
   Ctrl+C
3  docker compose -f race.compose.yaml down -v     back to a fresh volume
4  docker compose -f fixed.compose.yaml up         api waits for db (healthy), then connects
   Ctrl+C
5  docker compose -f fixed.compose.yaml down -v
```

- Fallback: open `recorded-run.md` in this folder and walk through it.
- Step 5 leaves a fresh volume, so the next session only needs the reset if something went wrong.

## Expected output

Measured on the Windows laptop (Docker Desktop 4.54.0 on WSL 2). `recorded-run.md` has a full run.

| Step | What you see |
|---|---|
| 1 | db-1 prints the initdb output. About 1 s after `up`, while initdb is still running, `api-1  \| ECONNREFUSED 172.18.0.2:5432` and `api-1 exited with code 1`. db-1 then finishes initdb, restarts and prints `database system is ready to accept connections`. The address depends on the network Docker creates. |
| 2 | `PostgreSQL Database directory appears to contain a database; Skipping initialization`, and Postgres is ready almost at once. Then `api-1  \| connected to Postgres` and `listening on 3000`. |
| 3 | The containers, the network and the `onramp-docker02_pgdata` volume are removed. |
| 4 | `Container onramp-docker02-db-1  Waiting`, then `Healthy` about 6 s after `up` (the first healthcheck runs one 5 s interval after the start), then `api-1  \| connected to Postgres`. |
| Ctrl+C | `api-1 exited with code 0`: the SIGTERM handler closes the server and the connection. |

The failure in step 1, as printed (a terminal adds colors and shows the compose status lines as a progress block):

```
db-1  | running bootstrap script ... ok
api-1  | ECONNREFUSED 172.18.0.2:5432
api-1 exited with code 1
db-1   | performing post-bootstrap initialization ... ok
db-1   | syncing data to disk ... ok
```

### Repeated runs, measured

`verify.sh` runs each scenario 10 times:

| Scenario | Result | Time from `up -d` |
|---|---|---|
| `race.compose.yaml`, fresh volume | api exits 1 with ECONNREFUSED in 10 of 10 runs | about 1.0 s |
| `race.compose.yaml`, warm volume | api connects in 10 of 10 runs | about 0.9 s |
| `fixed.compose.yaml`, fresh volume | api connects in 10 of 10 runs | about 6.2 s |

On this laptop the warm race never lost: on an existing volume, Postgres was ready before the api container had started. It's still a race (a slower disk, or crash recovery after an unclean stop, can lose it), which is why the fix is the healthcheck and not "run it twice".

## Verify

From the repo root:

```
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "${PWD}:/lab" -w /lab docker:29-cli sh docker-02-compose-startup/scripts/verify.sh
```

This runs the run sheet once (attached `up`, with `docker compose stop` for Ctrl+C), then each scenario 10 times with `up -d`, prints PASS/WARN/FAIL per check, writes `recorded-run.md` in this folder and ends with `down -v`. About 2 minutes. The warm-volume race only WARNs: it's a race, and the lab has no sleeps to make it pass. Commit the new `recorded-run.md` when the numbers change.

## Versions

Recorded on 2026-09-30.

| What | Version |
|---|---|
| Docker Desktop | 4.54.0 (212467), Engine 29.1.2 |
| Script image | `docker:29-cli`: Docker CLI 29.8.1, Compose 5.5.1 |
| `postgres:18` | PostgreSQL 18.6 (`sha256:5a5a84b19854a9ffaa54082c166ff4ec27473a361e496e5ea167f298f2da9722`), the same image as `postgres:18.6-trixie` in the database labs, so nothing extra to pull |
| `node:24-slim` | Node 24.21.0 (`sha256:0e0ff40c39bc087845bfb27465a0df4ea419520094bc35842ff83dd8cbe6f9b6`) |
| npm packages | pg 8.23.0 |

## Files

| Path | What it is |
|---|---|
| `race.compose.yaml` | The Quick Check slide's file, plus `env_file`: short-form `depends_on` |
| `fixed.compose.yaml` | The "Health Checks in Compose" slide's file, plus `env_file`: healthcheck and `condition: service_healthy` |
| `db.env` | The lab's Postgres password. Real projects keep env files out of git |
| `api/server.js` | Connects to Postgres once at startup, exits 1 on failure, then serves `SELECT now()` on port 3000 inside the network |
| `api/Dockerfile` | Same pattern as docker-01's optimized image: `node:24-slim`, `npm ci --omit=dev`, `USER node` |
| `scripts/reset.sh` | The one reset command |
| `scripts/verify.sh` | End-to-end check, repeated runs and transcript |

Both compose files set `name: onramp-docker02`, so they share one project and one volume, and one `down -v` resets both.

## Troubleshooting

- **Step 1 connects instead of failing:** the volume wasn't fresh. Run step 3 (`down -v`) or the reset, then step 1 again.
- **Step 2 fails too:** Postgres was still starting. That's the same race, which the healthcheck removes. Run step 2 again.
- **`docker: error during connect` or `Cannot connect to the Docker daemon`:** start Docker Desktop.
