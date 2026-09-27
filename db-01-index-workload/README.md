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
- 1: `\i 01-top-statements.sql`. Pause: "Which statement costs the most?" Expect customer history on top by total_ms (about 150 ms avg). The finance report is slowest per call (about 3 s) but runs rarely.
- 2: `\i 02-explain-top.sql`. Pause: "What is the plan telling you?" Expect Seq Scan on orders, Rows Removed by Filter about 2M, estimated rows=4 vs actual 8.
- 3: `\i 03-insert-batch.sql`. Note the INSERT time, about 0.5 to 0.8 s: the baseline.
- 4: `\i 04-choose-index.sql`. Pause: the group votes A, B, C or D in the chat. Create the majority pick.
- 5: `\i 05b-index-org-customer-created.sql`, or 05a, 05c or 05d for the other options. About 3 to 4 s.
- 6: `\i 02-explain-top.sql`. With B: Index Scan Backward, no Sort, under 1 ms.
- 7: `\i 03-insert-batch.sql`. With B roughly 1.5 to 2x the baseline, with A or C about 1.4x.
- 8, if time: `\! bash /labs/db-01-index-workload/scripts/workload.sh`, then `\i 01-top-statements.sql`. About 3x the transactions, and the open-orders count is now on top: the bottleneck moves.
- Fallback: open `recorded-run.md` in this folder and walk through it.
- About 12 minutes, including the poll. Run the reset command again afterwards.

## Expected output

Measured on Postgres 18.6 in Docker (2 vCPUs, 128 MB shared_buffers). Your laptop's numbers will differ, so compare the shape, not the exact values. `recorded-run.md` has a full run.

| Step | What you see |
|---|---|
| 1 | customer history: about 370 calls, about 56 s total, about 150 ms avg. Open-orders count: about 90 calls, about 175 ms avg. Finance report: 3 calls at about 2.6 s each. The users-by-id lookup has the most calls and costs almost nothing. |
| 2 | `Seq Scan on orders`, `Rows Removed by Filter: 1999992`, `rows=4` estimated vs `rows=8.00` actual, about 160 to 200 ms. |
| 2b (optional) | Small tenant: `Bitmap Heap Scan` on `idx_orders_org_created`, about 5,900 rows removed, about 20 ms. |
| 3 | `INSERT 0 100000`, about 0.5 to 0.8 s. |
| 5 | `CREATE INDEX` in about 3 to 4 s. Index B is about 77 MB. |
| 6 | B: `Index Scan Backward using idx_orders_org_customer_created`, no Sort, about 0.1 to 0.3 ms. A: Bitmap Heap Scan on `idx_orders_customer` plus a small Sort, about 0.15 ms. C and D: still `Seq Scan`. |
| 7 | Measured (warm cache): baseline 0.53 s; A 0.77 s; B 1.15 s; C 0.75 s; D 0.94 s. |
| 8 | About 3,300 transactions instead of about 1,150 in the same 20 s. Customer history drops to about 0.1 ms avg; the open-orders count (about 175 ms avg) is the new top statement. |

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
| `workload/*.sql` | pgbench scripts, one per "endpoint" (customer history, order list, login, open-orders count, finance report) |
| `scripts/workload.sh` | Resets statement statistics, then runs 20 s of traffic with 4 clients |
| `scripts/reset.sh` | The one reset command |
| `scripts/drop-lab-indexes.sql` | Drops every index on orders except the two baseline ones |
| `scripts/verify.sh` | End-to-end check and transcript |
| `steps/*.sql` | One file per demo step, run with `\i` |

## Troubleshooting

- **Output wraps badly:** widen the terminal to at least 160 columns, or lower the font size.
- **`CREATE INDEX CONCURRENTLY` failed halfway:** it leaves an INVALID index. The reset drops it.
- **Step 1 shows no workload statements:** run the reset, or `\! bash /labs/db-01-index-workload/scripts/workload.sh`.
