# docker-02-compose-startup: recorded run

Recorded 2026-09-30 03:21 UTC with Docker Engine 29.1.2 (Docker Desktop 4.54.0 (212467)), client 29.8.1, Docker Compose version v5.5.1 by `scripts/verify.sh`.

The run sheet part runs each `docker compose up` attached, like the live demo, and stops it with `docker compose stop` where the instructor presses Ctrl+C. The repeated runs use `up -d` and read the api's state and logs. Times in parentheses are wall-clock seconds.

## Before the session

### Reset

`03:21:40 UTC`  `sh /lab/docker-02-compose-startup/scripts/reset.sh`  (3.8 s)

```
 Image onramp-docker02-api Building 
 Image onramp-docker02-api Built 
docker-02 ready: fresh volume, api image built.
```

## Run sheet

### 1. Race on a fresh volume

`03:21:44 UTC`  `docker compose -f race.compose.yaml up`, then Ctrl+C (api refused after 1.3 s)

```
 Network onramp-docker02_default Creating 
 Network onramp-docker02_default Creating 
 Volume onramp-docker02_pgdata Creating 
 Volume onramp-docker02_pgdata Creating 
 Volume onramp-docker02_pgdata Created 
 Volume onramp-docker02_pgdata Created 
 Network onramp-docker02_default Created 
 Network onramp-docker02_default Created 
 Container onramp-docker02-db-1 Creating 
 Container onramp-docker02-db-1 Created 
 Container onramp-docker02-api-1 Creating 
 Container onramp-docker02-api-1 Created 
Attaching to api-1, db-1
 Container onramp-docker02-db-1 Starting 
 Container onramp-docker02-db-1 Started 
 Container onramp-docker02-api-1 Starting 
db-1  | The files belonging to this database system will be owned by user "postgres".
db-1  | This user must also own the server process.
db-1  | 
db-1  | The database cluster will be initialized with locale "en_US.utf8".
db-1  | The default database encoding has accordingly been set to "UTF8".
db-1  | The default text search configuration will be set to "english".
db-1  | 
db-1  | Data page checksums are enabled.
db-1  | 
db-1  | fixing permissions on existing directory /var/lib/postgresql/18/docker ... ok
db-1  | creating subdirectories ... ok
db-1  | selecting dynamic shared memory implementation ... posix
db-1  | selecting default "max_connections" ... 100
db-1  | selecting default "shared_buffers" ... 128MB
db-1  | selecting default time zone ... Etc/UTC
db-1  | creating configuration files ... ok
 Container onramp-docker02-api-1 Started 
db-1  | running bootstrap script ... ok
api-1  | ECONNREFUSED 172.18.0.2:5432
api-1 exited with code 1
db-1   | performing post-bootstrap initialization ... ok
db-1   | syncing data to disk ... ok
db-1   | 
db-1   | 
db-1   | Success. You can now start the database server using:
db-1   | 
db-1   |     pg_ctl -D /var/lib/postgresql/18/docker -l logfile start
db-1   | 
db-1   | initdb: warning: enabling "trust" authentication for local connections
db-1   | initdb: hint: You can change this by editing pg_hba.conf or using the option -A, or --auth-local and --auth-host, the next time you run initdb.
db-1   | waiting for server to start....2026-09-30 03:21:45.773 UTC [59] LOG:  starting PostgreSQL 18.6 (Debian 18.6-1.pgdg13+2) on x86_64-pc-linux-gnu, compiled by gcc (Debian 14.2.0-19) 14.2.0, 64-bit
db-1   | 2026-09-30 03:21:45.774 UTC [59] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
db-1   | 2026-09-30 03:21:45.780 UTC [65] LOG:  database system was shut down at 2026-09-30 03:21:45 UTC
db-1   | 2026-09-30 03:21:45.784 UTC [59] LOG:  database system is ready to accept connections
db-1   |  done
db-1   | server started
db-1   | 
db-1   | /usr/local/bin/docker-entrypoint.sh: ignoring /docker-entrypoint-initdb.d/*
db-1   | 
db-1   | waiting for server to shut down....2026-09-30 03:21:45.881 UTC [59] LOG:  received fast shutdown request
db-1   | 2026-09-30 03:21:45.884 UTC [59] LOG:  aborting any active transactions
db-1   | 2026-09-30 03:21:45.885 UTC [59] LOG:  background worker "logical replication launcher" (PID 68) exited with exit code 1
db-1   | 2026-09-30 03:21:45.886 UTC [63] LOG:  shutting down
db-1   | 2026-09-30 03:21:45.887 UTC [63] LOG:  checkpoint starting: shutdown immediate
db-1   | 2026-09-30 03:21:45.897 UTC [63] LOG:  checkpoint complete: wrote 0 buffers (0.0%), wrote 3 SLRU buffers; 0 WAL file(s) added, 0 removed, 0 recycled; write=0.003 s, sync=0.001 s, total=0.012 s; sync files=2, longest=0.001 s, average=0.001 s; distance=0 kB, estimate=0 kB; lsn=0/1761918, redo lsn=0/1761918
db-1   | 2026-09-30 03:21:45.904 UTC [59] LOG:  database system is shut down
db-1   |  done
db-1   | server stopped
db-1   | 
db-1   | PostgreSQL init process complete; ready for start up.
db-1   | 
db-1   | 2026-09-30 03:21:45.999 UTC [1] LOG:  starting PostgreSQL 18.6 (Debian 18.6-1.pgdg13+2) on x86_64-pc-linux-gnu, compiled by gcc (Debian 14.2.0-19) 14.2.0, 64-bit
db-1   | 2026-09-30 03:21:45.999 UTC [1] LOG:  listening on IPv4 address "0.0.0.0", port 5432
db-1   | 2026-09-30 03:21:45.999 UTC [1] LOG:  listening on IPv6 address "::", port 5432
db-1   | 2026-09-30 03:21:46.001 UTC [1] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
db-1   | 2026-09-30 03:21:46.005 UTC [79] LOG:  database system was shut down at 2026-09-30 03:21:45 UTC
db-1   | 2026-09-30 03:21:46.008 UTC [1] LOG:  database system is ready to accept connections
db-1   | 2026-09-30 03:21:47.494 UTC [1] LOG:  received fast shutdown request
db-1   | 2026-09-30 03:21:47.496 UTC [1] LOG:  aborting any active transactions
db-1   | 2026-09-30 03:21:47.497 UTC [1] LOG:  background worker "logical replication launcher" (PID 82) exited with exit code 1
db-1   | 2026-09-30 03:21:47.497 UTC [77] LOG:  shutting down
db-1   | 2026-09-30 03:21:47.498 UTC [77] LOG:  checkpoint starting: shutdown immediate
db-1   | 2026-09-30 03:21:47.504 UTC [77] LOG:  checkpoint complete: wrote 0 buffers (0.0%), wrote 3 SLRU buffers; 0 WAL file(s) added, 0 removed, 0 recycled; write=0.002 s, sync=0.001 s, total=0.007 s; sync files=2, longest=0.001 s, average=0.001 s; distance=0 kB, estimate=0 kB; lsn=0/1761990, redo lsn=0/1761990
db-1   | 2026-09-30 03:21:47.510 UTC [1] LOG:  database system is shut down
db-1 exited with code 0
```

Pause: (chat) why does it fail the first time?

### 2. Race again, data exists now

`03:21:47 UTC`  `docker compose -f race.compose.yaml up`, then Ctrl+C (api connected after 0.8 s)

```
Attaching to api-1, db-1
 Container onramp-docker02-db-1 Starting 
 Container onramp-docker02-db-1 Started 
 Container onramp-docker02-api-1 Starting 
db-1  | 
db-1  | PostgreSQL Database directory appears to contain a database; Skipping initialization
db-1  | 
db-1  | 2026-09-30 03:21:48.111 UTC [1] LOG:  starting PostgreSQL 18.6 (Debian 18.6-1.pgdg13+2) on x86_64-pc-linux-gnu, compiled by gcc (Debian 14.2.0-19) 14.2.0, 64-bit
db-1  | 2026-09-30 03:21:48.111 UTC [1] LOG:  listening on IPv4 address "0.0.0.0", port 5432
db-1  | 2026-09-30 03:21:48.112 UTC [1] LOG:  listening on IPv6 address "::", port 5432
db-1  | 2026-09-30 03:21:48.114 UTC [1] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
db-1  | 2026-09-30 03:21:48.119 UTC [32] LOG:  database system was shut down at 2026-09-30 03:21:47 UTC
db-1  | 2026-09-30 03:21:48.122 UTC [1] LOG:  database system is ready to accept connections
 Container onramp-docker02-api-1 Started 
api-1  | connected to Postgres
api-1  | listening on 3000
api-1 exited with code 0
db-1   | 2026-09-30 03:21:49.827 UTC [1] LOG:  received fast shutdown request
db-1   | 2026-09-30 03:21:49.829 UTC [1] LOG:  aborting any active transactions
db-1   | 2026-09-30 03:21:49.830 UTC [1] LOG:  background worker "logical replication launcher" (PID 35) exited with exit code 1
db-1   | 2026-09-30 03:21:49.830 UTC [30] LOG:  shutting down
db-1   | 2026-09-30 03:21:49.831 UTC [30] LOG:  checkpoint starting: shutdown immediate
db-1   | 2026-09-30 03:21:49.838 UTC [30] LOG:  checkpoint complete: wrote 0 buffers (0.0%), wrote 3 SLRU buffers; 0 WAL file(s) added, 0 removed, 0 recycled; write=0.002 s, sync=0.001 s, total=0.008 s; sync files=2, longest=0.001 s, average=0.001 s; distance=0 kB, estimate=0 kB; lsn=0/1761A08, redo lsn=0/1761A08
db-1   | 2026-09-30 03:21:49.843 UTC [1] LOG:  database system is shut down
db-1 exited with code 0
```

### 3. Back to a fresh volume

`03:21:50 UTC`  `docker compose -f race.compose.yaml down -v`  (0.3 s)

```
 Container onramp-docker02-api-1 Stopping 
 Container onramp-docker02-api-1 Stopped 
 Container onramp-docker02-api-1 Removing 
 Container onramp-docker02-api-1 Removed 
 Container onramp-docker02-db-1 Stopping 
 Container onramp-docker02-db-1 Stopped 
 Container onramp-docker02-db-1 Removing 
 Container onramp-docker02-db-1 Removed 
 Volume onramp-docker02_pgdata Removing 
 Network onramp-docker02_default Removing 
 Volume onramp-docker02_pgdata Removed 
 Network onramp-docker02_default Removed 
```

### 4. Healthcheck on a fresh volume

`03:21:50 UTC`  `docker compose -f fixed.compose.yaml up`, then Ctrl+C (api connected after 6.5 s)

```
 Network onramp-docker02_default Creating 
 Volume onramp-docker02_pgdata Creating 
 Network onramp-docker02_default Creating 
 Volume onramp-docker02_pgdata Creating 
 Volume onramp-docker02_pgdata Created 
 Volume onramp-docker02_pgdata Created 
 Network onramp-docker02_default Created 
 Network onramp-docker02_default Created 
 Container onramp-docker02-db-1 Creating 
 Container onramp-docker02-db-1 Created 
 Container onramp-docker02-api-1 Creating 
 Container onramp-docker02-api-1 Created 
Attaching to api-1, db-1
 Container onramp-docker02-db-1 Starting 
 Container onramp-docker02-db-1 Started 
 Container onramp-docker02-db-1 Waiting 
db-1  | The files belonging to this database system will be owned by user "postgres".
db-1  | This user must also own the server process.
db-1  | 
db-1  | The database cluster will be initialized with locale "en_US.utf8".
db-1  | The default database encoding has accordingly been set to "UTF8".
db-1  | The default text search configuration will be set to "english".
db-1  | 
db-1  | Data page checksums are enabled.
db-1  | 
db-1  | fixing permissions on existing directory /var/lib/postgresql/18/docker ... ok
db-1  | creating subdirectories ... ok
db-1  | selecting dynamic shared memory implementation ... posix
db-1  | selecting default "max_connections" ... 100
db-1  | selecting default "shared_buffers" ... 128MB
db-1  | selecting default time zone ... Etc/UTC
db-1  | creating configuration files ... ok
db-1  | running bootstrap script ... ok
db-1  | performing post-bootstrap initialization ... ok
db-1  | initdb: warning: enabling "trust" authentication for local connections
db-1  | initdb: hint: You can change this by editing pg_hba.conf or using the option -A, or --auth-local and --auth-host, the next time you run initdb.
db-1  | syncing data to disk ... ok
db-1  | 
db-1  | 
db-1  | Success. You can now start the database server using:
db-1  | 
db-1  |     pg_ctl -D /var/lib/postgresql/18/docker -l logfile start
db-1  | 
db-1  | waiting for server to start....2026-09-30 03:21:51.546 UTC [53] LOG:  starting PostgreSQL 18.6 (Debian 18.6-1.pgdg13+2) on x86_64-pc-linux-gnu, compiled by gcc (Debian 14.2.0-19) 14.2.0, 64-bit
db-1  | 2026-09-30 03:21:51.547 UTC [53] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
db-1  | 2026-09-30 03:21:51.552 UTC [59] LOG:  database system was shut down at 2026-09-30 03:21:51 UTC
db-1  | 2026-09-30 03:21:51.555 UTC [53] LOG:  database system is ready to accept connections
db-1  |  done
db-1  | server started
db-1  | 
db-1  | /usr/local/bin/docker-entrypoint.sh: ignoring /docker-entrypoint-initdb.d/*
db-1  | 
db-1  | waiting for server to shut down...2026-09-30 03:21:51.658 UTC [53] LOG:  received fast shutdown request
db-1  | .2026-09-30 03:21:51.663 UTC [53] LOG:  aborting any active transactions
db-1  | 2026-09-30 03:21:51.664 UTC [53] LOG:  background worker "logical replication launcher" (PID 62) exited with exit code 1
db-1  | 2026-09-30 03:21:51.664 UTC [57] LOG:  shutting down
db-1  | 2026-09-30 03:21:51.666 UTC [57] LOG:  checkpoint starting: shutdown immediate
db-1  | 2026-09-30 03:21:51.682 UTC [57] LOG:  checkpoint complete: wrote 0 buffers (0.0%), wrote 3 SLRU buffers; 0 WAL file(s) added, 0 removed, 0 recycled; write=0.003 s, sync=0.001 s, total=0.018 s; sync files=2, longest=0.001 s, average=0.001 s; distance=0 kB, estimate=0 kB; lsn=0/1761918, redo lsn=0/1761918
db-1  | 2026-09-30 03:21:51.690 UTC [53] LOG:  database system is shut down
db-1  |  done
db-1  | server stopped
db-1  | 
db-1  | PostgreSQL init process complete; ready for start up.
db-1  | 
db-1  | 2026-09-30 03:21:51.775 UTC [1] LOG:  starting PostgreSQL 18.6 (Debian 18.6-1.pgdg13+2) on x86_64-pc-linux-gnu, compiled by gcc (Debian 14.2.0-19) 14.2.0, 64-bit
db-1  | 2026-09-30 03:21:51.775 UTC [1] LOG:  listening on IPv4 address "0.0.0.0", port 5432
db-1  | 2026-09-30 03:21:51.775 UTC [1] LOG:  listening on IPv6 address "::", port 5432
db-1  | 2026-09-30 03:21:51.777 UTC [1] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
db-1  | 2026-09-30 03:21:51.781 UTC [73] LOG:  database system was shut down at 2026-09-30 03:21:51 UTC
db-1  | 2026-09-30 03:21:51.783 UTC [1] LOG:  database system is ready to accept connections
 Container onramp-docker02-db-1 Healthy 
 Container onramp-docker02-api-1 Starting 
 Container onramp-docker02-api-1 Started 
api-1  | connected to Postgres
api-1  | listening on 3000
api-1 exited with code 0
db-1   | 2026-09-30 03:21:58.233 UTC [1] LOG:  received fast shutdown request
db-1   | 2026-09-30 03:21:58.235 UTC [1] LOG:  aborting any active transactions
db-1   | 2026-09-30 03:21:58.236 UTC [1] LOG:  background worker "logical replication launcher" (PID 76) exited with exit code 1
db-1   | 2026-09-30 03:21:58.236 UTC [71] LOG:  shutting down
db-1   | 2026-09-30 03:21:58.237 UTC [71] LOG:  checkpoint starting: shutdown immediate
db-1   | 2026-09-30 03:21:58.243 UTC [71] LOG:  checkpoint complete: wrote 0 buffers (0.0%), wrote 3 SLRU buffers; 0 WAL file(s) added, 0 removed, 0 recycled; write=0.002 s, sync=0.001 s, total=0.008 s; sync files=2, longest=0.001 s, average=0.001 s; distance=0 kB, estimate=0 kB; lsn=0/1761990, redo lsn=0/1761990
db-1   | 2026-09-30 03:21:58.248 UTC [1] LOG:  database system is shut down
db-1 exited with code 0
```

### 5. Clean up

`03:21:58 UTC`  `docker compose -f fixed.compose.yaml down -v`  (0.3 s)

```
 Container onramp-docker02-api-1 Stopping 
 Container onramp-docker02-api-1 Stopped 
 Container onramp-docker02-api-1 Removing 
 Container onramp-docker02-api-1 Removed 
 Container onramp-docker02-db-1 Stopping 
 Container onramp-docker02-db-1 Stopped 
 Container onramp-docker02-db-1 Removing 
 Container onramp-docker02-db-1 Removed 
 Volume onramp-docker02_pgdata Removing 
 Network onramp-docker02_default Removing 
 Volume onramp-docker02_pgdata Removed 
 Network onramp-docker02_default Removed 
```

## Repeated runs

Each run: `docker compose -f <file> up -d`, then read `docker compose ps -a` and the api's logs for up to 20 s. "Seconds" is the time from starting `up -d` until the api connected or exited.

### 1. race.compose.yaml, fresh volume (down -v between runs)

| Run | api | Seconds | api's first log line |
|---|---|---|---|
| 1 | refused | 1.0 | `ECONNREFUSED 172.18.0.2:5432` |
| 2 | refused | 1.0 | `ECONNREFUSED 172.18.0.2:5432` |
| 3 | refused | 1.0 | `ECONNREFUSED 172.18.0.2:5432` |
| 4 | refused | 1.0 | `ECONNREFUSED 172.18.0.2:5432` |
| 5 | refused | 1.0 | `ECONNREFUSED 172.18.0.2:5432` |
| 6 | refused | 1.0 | `ECONNREFUSED 172.18.0.2:5432` |
| 7 | refused | 1.1 | `ECONNREFUSED 172.18.0.2:5432` |
| 8 | refused | 1.0 | `ECONNREFUSED 172.18.0.2:5432` |
| 9 | refused | 0.9 | `ECONNREFUSED 172.18.0.2:5432` |
| 10 | refused | 1.0 | `ECONNREFUSED 172.18.0.2:5432` |

### 2. race.compose.yaml, warm volume (down without -v between runs)

| Run | api | Seconds | api's first log line |
|---|---|---|---|
| 1 | connected | 0.9 | `connected to Postgres` |
| 2 | connected | 1.0 | `connected to Postgres` |
| 3 | connected | 0.9 | `connected to Postgres` |
| 4 | connected | 0.9 | `connected to Postgres` |
| 5 | connected | 0.9 | `connected to Postgres` |
| 6 | connected | 0.9 | `connected to Postgres` |
| 7 | connected | 0.9 | `connected to Postgres` |
| 8 | connected | 0.8 | `connected to Postgres` |
| 9 | connected | 0.9 | `connected to Postgres` |
| 10 | connected | 0.9 | `connected to Postgres` |

### 3. fixed.compose.yaml, fresh volume (down -v between runs)

| Run | api | Seconds | api's first log line |
|---|---|---|---|
| 1 | connected | 6.4 | `connected to Postgres` |
| 2 | connected | 6.3 | `connected to Postgres` |
| 3 | connected | 6.2 | `connected to Postgres` |
| 4 | connected | 6.2 | `connected to Postgres` |
| 5 | connected | 6.2 | `connected to Postgres` |
| 6 | connected | 6.2 | `connected to Postgres` |
| 7 | connected | 6.2 | `connected to Postgres` |
| 8 | connected | 6.2 | `connected to Postgres` |
| 9 | connected | 6.2 | `connected to Postgres` |
| 10 | connected | 6.2 | `connected to Postgres` |

## After the session

### Clean up

`03:23:50 UTC`  `docker compose -f fixed.compose.yaml down -v`  (0.6 s)

```
 Container onramp-docker02-api-1 Stopping 
 Container onramp-docker02-api-1 Stopped 
 Container onramp-docker02-api-1 Removing 
 Container onramp-docker02-api-1 Removed 
 Container onramp-docker02-db-1 Stopping 
 Container onramp-docker02-db-1 Stopped 
 Container onramp-docker02-db-1 Removing 
 Container onramp-docker02-db-1 Removed 
 Network onramp-docker02_default Removing 
 Volume onramp-docker02_pgdata Removing 
 Volume onramp-docker02_pgdata Removed 
 Network onramp-docker02_default Removed 
```

## Success rates

| Series | Result |
|---|---|
| Fresh volume, short-form depends_on | api exits 1 with ECONNREFUSED in 10 of 10 runs |
| Warm volume, short-form depends_on | api connects in 10 of 10 runs |
| Fresh volume, healthcheck + service_healthy | api connects in 10 of 10 runs |

