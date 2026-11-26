# db-01-index-workload

**Deck:** Indexing Strategies - Demo: index a real workload
**Teaches:** rank statements by total time, read the plan, pick one index from evidence, then pay for it on every write. Once the top statement is fixed, the bottleneck moves.
**Container:** `onramp-db` · **Demo time:** about 12 minutes

## Setup

1. Start the containers once (repo root): `docker compose -f db-shared/compose.yaml up -d`
2. Before the session: `docker exec onramp-db bash /labs/db-01-index-workload/scripts/reset.sh`
   It seeds 2M orders on the first run (add `--full` to reseed), drops any index the lab added, and records 20 seconds of app traffic.

## Run sheet

The slide's speaker notes use the same text.

- Before the session: `docker exec onramp-db bash /labs/db-01-index-workload/scripts/reset.sh` (about 1 minute; it also warms the cache).
- Open: `docker exec -it onramp-db psql`, then `\cd /labs/db-01-index-workload/steps`
- 1: `\i 01-top-statements.sql`. Pause: "Which statement costs the most?" The page column names the page that sent each query (see [Query tags](#query-tags)). Expect the customer page on top by total_ms. The finance export is slowest per call but runs rarely.
- 2: `\i 02-explain-top.sql`. Pause: "What is the plan telling you?" Expect Seq Scan on orders, Rows Removed by Filter about 2M, estimated rows=4 vs actual 8.
- 3: `\i 03-insert-batch.sql`. Note the INSERT time, about 0.35 to 0.7 s: the baseline.
- 4: `\i 04-choose-index.sql`. Pause: the group votes A, B, C or D in the chat. Create the majority pick.
- 5: `\i 05b-index-org-customer-created.sql`, or 05a, 05c or 05d for the other options. About 2 to 4 s.
- 6: `\i 02-explain-top.sql`. With B: Index Scan Backward, no Sort, under 1 ms.
- 7: `\i 03-insert-batch.sql`. With B about 1.5 to 2x the baseline, with A or C about 1.4x.
- 8, if time: `\! bash /labs/db-01-index-workload/scripts/workload.sh`, then `\i 01-top-statements.sql`. About 3 to 4x the transactions, and the dashboard's open-orders count is now on top: the bottleneck moves.
- Fallback: open `recorded-run.md` in this folder and walk through it.
- About 12 minutes, including the poll. Run the reset command again afterwards.

## Expected output

Measured on Postgres 18.6 in Docker (128 MB shared_buffers). Speed varies a lot between machines and runs, so compare the shape, not the exact values. `recorded-run.md` has a full run.

| Step | What you see |
|---|---|
| 1 | A `page` column first, and the `query` column shows each statement in full: long ones run over several lines, and a `+` at the end of a line means the statement continues. `customer` is on top with about 55 to 60 s total: fewer, slower calls on a slow run (about 350 at 160 ms), more, faster ones on a fast run (about 900 at 65 ms). `dashboard` (the open-orders count) is second. `finance export` is slowest per call (0.6 to 3.4 s) but runs only 3 to 7 times. `every page` (the user lookup) has the most calls and costs almost nothing. |
| 2 | `Seq Scan on orders`, `Rows Removed by Filter: 1999992`, `rows=4` estimated vs `rows=8.00` actual, about 100 to 220 ms. Buffers hit plus read add up to about 18,800. |
| 2b (optional) | Small tenant: `Bitmap Heap Scan` on `idx_orders_org_created`, about 5,900 rows removed, about 15 to 30 ms. |
| 3 | `INSERT 0 100000`, about 0.35 to 0.7 s. |
| 5 | `CREATE INDEX` in about 2 to 4 s. Index B is about 77 MB. |
| 6 | B: `Index Scan Backward using idx_orders_org_customer_created`, no Sort, about 0.1 ms, Buffers about 14. A: Bitmap Heap Scan on `idx_orders_customer` plus a small Sort, about 0.15 ms. C and D: still `Seq Scan`. |
| 7 | B: about 1.5 to 2x the baseline (latest run 0.35 s to 0.55 s). All four options in one earlier run (warm cache): baseline 0.53 s; A 0.77 s; B 1.15 s; C 0.75 s; D 0.94 s. |
| 8 | About 3 to 4x the transactions of the reset run in the same 20 s (latest run 11,345 vs 2,934). `customer` drops to about 0.03 ms avg; `dashboard`, the open-orders count, is the new top statement. |

## Query tags

Every workload query ends with a comment like `/* page: customer */`, and step 1 reads it back as the page column. ORMs and tracing tools (Rails query log tags, sqlcommenter) tag queries the same way, so a slow statement leads straight to the route that sent it.

- Postgres ignores comments when it groups statements, so the same SQL sent from two pages is one row, and pg_stat_statements keeps the text (and tag) of the first one it saw. That's why the shared user lookup is tagged `every page`.
- Put the tag at the end. Since Postgres 18 the stored text starts at the statement's first keyword, so a comment before it is dropped.
- Step 1 takes the tag out of the query column with `regexp_replace`, because the page column already shows it. Nothing else is trimmed.

## If the group picks C (status)

Show step 6 (the planner ignores it) and step 7 (inserts are still slower), then optionally `\i 06-unused-indexes.sql` after re-running the workload: `idx_orders_status` shows `idx_scan = 0`. Then run `\i 05b-index-org-customer-created.sql` to finish.

## Verify

```
docker exec onramp-db bash /labs/db-01-index-workload/scripts/verify.sh
docker cp onramp-db:/tmp/recorded-run.md db-01-index-workload/recorded-run.md
```

This runs the whole lab without pauses, prints PASS/WARN/FAIL per check, and ends with a reset. Timing checks only WARN, because timings vary. Commit the new `recorded-run.md` when the numbers change.

## Files

| Path | What it is |
|---|---|
| `workload/*.sql` | pgbench scripts, one per page (customer, orders, login, dashboard, finance export), each query tagged with `/* page: ... */`. Long queries are written over several lines, and step 1 shows them exactly as written |
| `scripts/workload.sh` | Resets statement statistics, then runs 20 s of traffic with 4 clients |
| `scripts/reset.sh` | The one reset command |
| `scripts/drop-lab-indexes.sql` | Drops every index on orders except the two baseline ones |
| `scripts/verify.sh` | End-to-end check and transcript |
| `steps/*.sql` | One file per demo step, run with `\i` |

## Troubleshooting

- **Output wraps badly:** widen the terminal to at least 160 columns, or lower the font size.
- **`CREATE INDEX CONCURRENTLY` failed halfway:** it leaves an INVALID index. The reset drops it.
- **Step 1 shows a long statement on one line:** the statistics are older than the workload files, and pg_stat_statements keeps the first text it saw. Run the reset.
- **Step 1 shows no workload statements:** run the reset, or `\! bash /labs/db-01-index-workload/scripts/workload.sh`.
