# db-02-pitr-restore

**Deck:** Disaster Recovery Planning - Demo: restore drill
**Teaches:** point-in-time recovery is a full copy plus replaying every change since, stopped at a chosen moment. The measured RTO is the real one, not the guess. Restore beside production, not over it.
**Container:** `onramp-pitr` · **Demo time:** about 10 minutes

## How it works here

```
base_backup/  (full copy, taken by the reset)
     +  wal_archive/  (every change since, shipped as it's written)
     |
     v
restore/  second Postgres on port 5433, replays up to the last good moment, then promotes
     |
     |  pg_dump -t orders
     v
live database on port 5432: orders is back, nothing else is rolled back
```

Everything lives on one Docker volume to keep the demo small. In production the WAL archive lives off the server, in object storage in a separate account, and tools like pgBackRest or Barman (or your managed provider's PITR) do the copying.

## Setup

1. Start the containers once (repo root): `docker compose -f db-shared/compose.yaml up -d`
2. Before the session: `docker exec -u postgres onramp-pitr bash /labs/db-02-pitr-restore/scripts/reset.sh`
   It reseeds the database, takes a fresh base backup, trims the archive and adds 50,000 orders of "traffic since the backup" so the restore has changes to replay.

Every command runs as `-u postgres`, because `pg_ctl` refuses to run as root.

## Run sheet

The slide's speaker notes use the same text.

- Before the session: `docker exec -u postgres onramp-pitr bash /labs/db-02-pitr-restore/scripts/reset.sh` (about 1 minute).
- Open: `docker exec -it -u postgres onramp-pitr psql`, then `\cd /labs/db-02-pitr-restore/steps`
- 1: `\i 01-status.sql`. The full copy (taken by the reset) and every change since, archived. failed_count must be 0.
- 2: `\i 02-marker.sql`. An order placed just before the incident: order 2050001, total 1234.56.
- 3: `\i 03-drop.sql`. DROP TABLE orders, then a new user signs up while the app keeps running.
- Pause: "How long until orders is back? Answer in the chat, with a unit." Wait for a few guesses.
- 4: `\! bash /labs/db-02-pitr-restore/scripts/restore.sh`. Prints the copy, replay and copy-back times, the "recovery stopping before commit" line, and the measured RTO (about 10 s; up to 30 s on a slower laptop).
- 5: `\i 05-verify.sql`. The marker order is back, the order count matches, and user 200001 is still there.
- Fallback: open `recorded-run.md` in this folder and walk through it.
- About 10 minutes. Run the reset command again afterwards.

## Expected output

Measured on Postgres 18.6 in Docker (2 vCPUs). `recorded-run.md` has a full run.

| Step | What you see |
|---|---|
| Reset | About 1 minute. Ends with `db-02 ready: 2050000 orders, base backup at <time> UTC.` |
| 1 | base_backup_taken = the reset time. archived_count > 0, failed_count 0. 2,050,000 orders, about 320 MB. |
| 2 | One row: order_id 2050001, customer 4242, total 1234.56. |
| 3 | last_good_moment printed, `DROP TABLE`, `INSERT 0 1`, then the WAL switch and a fresh last_archived_wal. |
| 4 | `1. Copied the base backup: 0.5 s` · `2. Replayed WAL up to the target: 1.6 s` · `Postgres: recovery stopping before commit of transaction N` (that's the DROP) · `3. Copied orders back into production: 6.6 to 6.9 s` · `Measured RTO: 8 to 9 s` |
| 5 | Marker row present. orders_now = orders_before_drop = 2050001. User 200001 present. |

For the extrapolation in the notes: copy time grows with database size, replay time with the WAL written since the last full copy. The demo copies about 320 MB from a backup a few minutes old.

## Verify

```
docker exec -u postgres onramp-pitr bash /labs/db-02-pitr-restore/scripts/verify.sh
docker cp onramp-pitr:/tmp/recorded-run.md db-02-pitr-restore/recorded-run.md
```

This runs the whole lab without pauses, prints PASS/FAIL per check, and ends with a reset so the lab is ready. Commit the new `recorded-run.md` when the numbers change.

## Files

| Path | What it is |
|---|---|
| `initdb/01-archive-dir.sh` | Creates the WAL archive folder on the container's first start |
| `sql/traffic.sql` | 50,000 orders and some updates after the base backup |
| `scripts/reset.sh` | The one reset command |
| `scripts/restore.sh` | The timed restore: copy, replay to the target, copy `orders` back. Optional argument: a different recovery target time. |
| `scripts/verify.sh` | End-to-end check and transcript |
| `steps/*.sql` | One file per demo step, run with `\i` |

## Troubleshooting

- **`FATAL: recovery ended before configured recovery target was reached`:** the WAL with the DROP wasn't archived. Check `failed_count` in step 1 and that step 3 ran `pg_switch_wal()`, then reset and repeat.
- **`orders still exists in the live database`:** step 4 was run before step 3. Run step 3, or reset.
- **Restore fails partway:** the reset stops any leftover second instance and cleans up.
