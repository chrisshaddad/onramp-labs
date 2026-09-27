# onramp-labs

Live demos for the OnRamp bootcamp. The instructor runs them over screen share, and the group answers in the chat. Students don't clone this repo.

One folder per lab, named topic first and numbered per topic (`db-01-...`, later `docker-01-...`). Every lab has a README with a **Run sheet** (the same text as the slide's speaker notes), a reset command and a `verify.sh`.

## Prerequisites

- Docker Desktop (WSL 2 backend on Windows) or Docker Engine with Compose v2
- git
- About 5 GB of free disk
- A terminal at least 160 columns wide, because EXPLAIN output is wide. On Windows, use PowerShell or Windows Terminal, not Git Bash (Git Bash needs `winpty` for `docker exec -it`).

Nothing else is needed on the host: every command runs inside the containers, so it's the same in PowerShell and bash.

## Start

From the repo root, once:

```
docker compose -f db-shared/compose.yaml up -d
```

This starts two Postgres 18.6 containers: `onramp-db` (db-01 and later labs) and `onramp-pitr` (db-02 only, with WAL archiving on).

Before a session, run the reset command of each lab you'll show. It takes about a minute per lab.

| Folder | Topic | Deck slide | Reset (run from anywhere) |
|---|---|---|---|
| [db-01-index-workload](db-01-index-workload/) | Choosing an index from evidence, and its write cost | Indexing Strategies - Demo: index a real workload | `docker exec onramp-db bash /labs/db-01-index-workload/scripts/reset.sh` |
| [db-02-pitr-restore](db-02-pitr-restore/) | Point-in-time recovery after a DROP TABLE, with a measured RTO | Disaster Recovery Planning - Demo: restore drill | `docker exec -u postgres onramp-pitr bash /labs/db-02-pitr-restore/scripts/reset.sh` |

## Stop and clean up

```
docker compose -f db-shared/compose.yaml stop       # stop, keep the data
docker compose -f db-shared/compose.yaml down -v    # remove containers and data
```

## Troubleshooting

- **`$'\r': command not found`:** the scripts were checked out with Windows line endings. `.gitattributes` prevents this on a fresh clone. For an old clone, run `git rm --cached -r . && git reset --hard`.
- **Port 5432 already in use:** set `DB_PORT` (for example `$env:DB_PORT=55432` in PowerShell) before `up`. Only GUI clients use this port; the labs don't.
