# onramp-labs

Live demos for the OnRamp bootcamp. The instructor runs them over screen share, and the group answers in the chat. Students don't clone this repo.

One folder per lab, named topic first and numbered per topic (`db-01-...`, `docker-01-...`). Every lab has a README with a **Run sheet** (the same text as the slide's speaker notes), a reset command and a `verify.sh` that writes `recorded-run.md`.

The database labs run inside containers with `docker exec`. The Docker labs run the Docker CLI on the host, and their reset and verify scripts run in a `docker:29-cli` container. Both need only Docker Desktop and git.

## Prerequisites

- Docker Desktop (WSL 2 backend on Windows) or Docker Engine with Compose v2
- git
- About 8 GB of free disk: 5 GB for the database labs, about 3 GB more for the Docker labs (mostly `node:24` and the build cache)
- A terminal at least 160 columns wide, because EXPLAIN output is wide. On Windows, use PowerShell or Windows Terminal, not Git Bash: Git Bash needs `winpty` for `docker exec -it`, and it rewrites the `/var/run/docker.sock` and `/lab` paths in the Docker labs' commands.

Nothing else is needed on the host, and every command is the same in PowerShell and bash.

## Start

From the repo root, once:

```
docker compose -f db-shared/compose.yaml up -d
```

This starts two Postgres 18.6 containers: `onramp-db` (db-01 and later labs) and `onramp-pitr` (db-02 only, with WAL archiving on). The Docker labs need no start step.

Before a session, run the reset command of each lab you'll show. It takes about a minute per database lab, and a few seconds per Docker lab once the images are pulled. The first Docker resets download about 800 MB of images: allow 10 to 15 minutes on a slow connection.

| Folder | Topic | Deck slide | Reset |
|---|---|---|---|
| [db-01-index-workload](db-01-index-workload/) | Choosing an index from evidence, and its write cost | Indexing Strategies - Demo: index a real workload | `docker exec onramp-db bash /labs/db-01-index-workload/scripts/reset.sh` |
| [db-02-pitr-restore](db-02-pitr-restore/) | Point-in-time recovery after a DROP TABLE, with a measured RTO | Disaster Recovery Planning - Demo: restore drill | `docker exec -u postgres onramp-pitr bash /labs/db-02-pitr-restore/scripts/reset.sh` |
| [docker-01-naive-vs-optimized](docker-01-naive-vs-optimized/) | Instruction order, multi-stage builds, slim base and non-root, measured | Containers and Docker - Demo - Naive vs Optimized Image | `docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "${PWD}:/lab" -w /lab docker:29-cli sh docker-01-naive-vs-optimized/scripts/reset.sh` |
| [docker-02-compose-startup](docker-02-compose-startup/) | Short-form depends_on races Postgres on a fresh volume; a healthcheck fixes it | Containers and Docker - Quick Check - Works on the Second Try | `docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "${PWD}:/lab" -w /lab docker:29-cli sh docker-02-compose-startup/scripts/reset.sh` |

The database resets run from anywhere. The Docker resets mount the repo, so run them from the repo root.

## Stop and clean up

```
docker compose -f db-shared/compose.yaml stop       # stop, keep the data
docker compose -f db-shared/compose.yaml down -v    # remove containers and data
```

The Docker labs' resets remove what their demos create, except docker-02's api image: `docker image rm onramp-docker02-api`. The base images and the build cache stay.

## Troubleshooting

- **`$'\r': command not found` or `set: illegal option -`:** the scripts were checked out with Windows line endings. `.gitattributes` prevents this on a fresh clone. For an old clone, run `git rm --cached -r . && git reset --hard`.
- **Port 5432 already in use:** set `DB_PORT` (for example `$env:DB_PORT=55432` in PowerShell) before `up`. Only GUI clients use this port; the labs don't.
