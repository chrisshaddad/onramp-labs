# eda-01-duplicates-ordering

**Deck:** S25 - Event-Driven Architecture. Two demos, each with its own slide: "Demo - A duplicate, live" (right after "Duplicates are normal - Handle them at the consumer") and "Demo - Out of order, live" (right after "Scenario - The fix").
**Teaches:** a consumer that crashes after the work but before committing its offset runs the work twice; saving the event id in the same transaction as the effect makes the redelivery harmless. Events can also arrive out of order; a per-order version in the consumer skips the stale one, whatever order the broker delivers.
**Runs in:** the `onramp-eda-app` container, with `docker exec` · **Demo time:** about 4 minutes per part.

## Setup

1. Once, from the repo root:
   `docker compose -f eda-01-duplicates-ordering/compose.yaml up -d --build`
   The first run pulls the Kafka image (about 240 MB) and runs `npm ci`: about 6 minutes on the laptop, almost all of it the download. After that, `up -d` takes about 7 s until all three containers are up.
   This starts `onramp-eda-kafka` (Kafka 4.3.1, one node, KRaft), `onramp-eda-db` (Postgres 18.6) and `onramp-eda-app` (Node 24 and the `demo` CLI). No ports are published, so it never clashes with `onramp-db` on 5432.
2. Before the session: `docker exec onramp-eda-app demo reset` (about 0.4 s; it ends with `eda-01 ready`).
3. Open a terminal (PowerShell or Windows Terminal) for the demo. Both parts run in one bash session in the app container.

## Run sheet

The two demo slides' speaker notes use the same text.

```
Open:  docker exec -it onramp-eda-app bash

Part 1 - Duplicates (after "Duplicates are normal")
1   demo setup dup
2   demo send o_42
3   demo consume naive --crash        invoice inserted, dies before the offset commit
4   demo invoices o_42                1 invoice
    (chat) how many after the restart?
5   demo consume naive                the same event is redelivered and inserted again
6   demo invoices o_42                2 invoices
7   demo send o_43
8   demo consume dedup --crash        invoice and event id committed together, dies before the offset commit
9   demo consume dedup                "duplicate, skipped"
10  demo invoices o_43                1 invoice

Part 2 - Out of order (after "Scenario - The fix")
1   demo setup order
2   demo send-out-of-order o_7        cancelled #2, then placed #1, same partition
3   demo consume notify-naive         two emails; the second says "confirmed"
    (chat) what does the version-check consumer send?
4   demo consume notify-versioned     one email; placed #1 skipped (have #2)
5   demo state o_7                    o_7 | 2 | cancelled

Quit:  exit
```

- Fallback: open `recorded-run.md` in this folder and walk through it.
- Run `demo reset` again afterwards.

## Steps and expected output

Measured on the Windows laptop (Docker Desktop 4.54.0, Engine 29.1.2, WSL 2, 16 CPUs) by running the run sheet in an interactive session. Event ids are random, so yours differ; the offsets don't. Every consumer waits 3 s for more messages before it prints `idle, exiting`, so a consumer run takes about 3.4 s and every other command under half a second. `recorded-run.md` has a full run.

### Part 1 - Duplicates

| Step | Command | What to point at | Expected output |
|---|---|---|---|
| 1 | `demo setup dup` | A fresh start: no invoices, an empty topic, no group. | `emptied invoices, processed_events; topic orders recreated (1 partition); deleted group invoicing`, then `part 1 ready`. About 0.3 s. |
| 2 | `demo send o_42` | One `order.placed` event, offset 0. | `sent o_42 order.placed #1 id=1f3c9a2e partition=0 offset=0` |
| 3 | `demo consume naive --crash` | The invoice is in the database, but the process died before telling Kafka it was done. | `[naive] o_42 order.placed id=1f3c9a2e offset=0 -> invoice inserted`, then `[naive] CRASH before offset commit`. Exit code 1. |
| 4 | `demo invoices o_42` | One invoice so far. | `o_42: 1 invoice`, then the row (`id=1  created_at=...`). |
| chat | | How many invoices after the restart? | Take answers, then run step 5. |
| 5 | `demo consume naive` | The same id and offset as step 3: the group's committed offset still pointed at 0, so Kafka delivered it again. The restart gets it at once (static membership, below). | `[naive] o_42 order.placed id=1f3c9a2e offset=0 -> invoice inserted` within half a second of Enter, then `[naive] idle, exiting`. |
| 6 | `demo invoices o_42` | One order, two invoices: a duplicate effect. | `o_42: 2 invoices` |
| 7 | `demo send o_43` | Offset 1. | `sent o_43 order.placed #1 id=7b21c0d4 partition=0 offset=1` |
| 8 | `demo consume dedup --crash` | Same group, new code: it starts at offset 1, where the naive restart committed. The event id and the invoice commit in one transaction, then it dies before the offset commit. | `[dedup] o_43 order.placed id=7b21c0d4 offset=1 -> invoice inserted, transaction committed`, then `[dedup] CRASH before offset commit`. |
| 9 | `demo consume dedup` | Redelivered again, same id, but this time the event id is already saved: 0 rows, so it rolls back, acks and skips. | `[dedup] o_43 order.placed id=7b21c0d4 offset=1 -> duplicate, skipped`, then `[dedup] idle, exiting`. |
| 10 | `demo invoices o_43` | Redelivered, but one invoice. | `o_43: 1 invoice` |

### Part 2 - Out of order

| Step | Command | What to point at | Expected output |
|---|---|---|---|
| 1 | `demo setup order` | A fresh start for part 2. | `emptied order_state, sent_emails; topic orders recreated (1 partition); deleted group notify-naive, notify-versioned`, then `part 2 ready`. |
| 2 | `demo send-out-of-order o_7` | The cancel (#2) is at offset 0, before the order it cancels (#1) at offset 1. Same key, same partition: Kafka delivers them in exactly this order. | `sent o_7 order.cancelled #2 id=... partition=0 offset=0`, then `sent o_7 order.placed #1 id=... partition=0 offset=1` |
| 3 | `demo consume notify-naive` | One email per event, in arrival order. The customer's last email says "confirmed" for a cancelled order. | `[notify-naive] o_7 order.cancelled #2 -> email: "Your order is cancelled"`, `[notify-naive] o_7 order.placed #1 -> email: "Your order is confirmed"`, `[notify-naive] idle, exiting` |
| chat | | What does the version-check consumer send? | Take answers, then run step 4. |
| 4 | `demo consume notify-versioned` | Same events, same order, its own group. #2 writes the row and sends; #1 finds version 2 already there: 0 rows, no email. | `[notify-versioned] o_7 order.cancelled #2 -> email: "Your order is cancelled"`, `[notify-versioned] o_7 order.placed #1 -> skipped (have #2)`, `[notify-versioned] idle, exiting` |
| 5 | `demo state o_7` | One row per order, at the highest version seen. | `o_7 \| 2 \| cancelled` |

`demo emails o_7` lists every email sent for the order (consumer and subject): two from `notify-naive`, one from `notify-versioned`.

### Timings

Measured on the laptop, in the hand run and in `verify.sh`:

| Command | Time |
|---|---|
| `demo reset` | 0.35 s (1.6 s on a just-started broker). Right after a consumer run it waits for that consumer's session first: 4.8 s (see "Static membership" below). |
| `demo setup dup`, `demo setup order` | 0.2 to 0.3 s |
| `demo send`, `demo send-out-of-order`, `demo invoices`, `demo state` | 0.1 to 0.2 s |
| A consumer run | 3.3 to 3.4 s, of which 3 s is the idle wait |
| `--crash` run | 0.2 to 0.3 s |
| Restart after a crash, Enter to the redelivered message | 0.2 to 0.3 s (`verify.sh`, restart right after the crash). In the hand run, restarted 30 s after the crash, the whole run took 3.4 s, the same as any consumer run. |
| Machine time per part | 8.3 s (part 1), 7.4 s (part 2): the rest of the 4 minutes is talk and the chat question |

## Chat questions

- **Part 1, after step 4:** how many invoices after the restart? (Two: the offset was never committed, so the same event comes back, and the naive consumer can't tell.)
- **Part 2, after step 3:** what does the version-check consumer send? (One email, "cancelled". The placed event is older than the row, so it writes nothing and sends nothing.)

## How it works

```
 demo send ...               Kafka                           demo consume <name>                  Postgres
 producer, key = orderId --> topic orders, 1 partition  -->  group invoicing / notify-*      -->  invoices, processed_events
                             offset 0, 1, 2 ...              1. read the message at offset N       order_state, sent_emails
                             committed offset per group <--  2. do the work, COMMIT in Postgres
                                                             3. ack: commit offset N+1 to Kafka
```

`--crash` kills the process between 2 and 3. The group's committed offset still points at N, so the next consumer in the group reads message N again. That's at-least-once delivery.

The offset commit is `ack()` in each consumer file (`app/src/consumers/`), which calls `commitOffsets` in `app/src/kafka.ts`. Auto-commit is off, so nothing else commits. With `--crash`, `ack()` prints the crash line and exits with code 1 instead: no commit, and the process doesn't leave the group, like a killed process.

**The dedup consumer** (`invoice-dedup.ts`) runs the SQL from "Duplicates are normal", word for word:

```sql
BEGIN;
INSERT INTO processed_events (event_id)
  VALUES ($1) ON CONFLICT DO NOTHING;
-- 0 rows: a duplicate. ROLLBACK, ack, skip.

-- 1 row: the first time. Apply the effect.
INSERT INTO invoices (order_id, total_cents)
  VALUES ($2, $3);
COMMIT;  -- then ack
```

As on the slide, `$1`, `$2`, `$3` (event id, order id, total) are one parameter list for the whole transaction. The second statement doesn't use `$1`, and Postgres must know the type of every parameter, so `sharedParams` in `app/src/db.ts` sends each statement with the three types declared in an unused `WITH params AS (SELECT $1::uuid, $2::text, $3::int)` in front of it. The statements themselves run as written.

**The version-check consumer** (`notify-versioned.ts`) runs the SQL from "Scenario - The fix", word for word:

```sql
-- one row per order
INSERT INTO order_state AS s
VALUES ($1, $2, $3)
ON CONFLICT (order_id) DO UPDATE
  SET version = $2, status = $3
  WHERE s.version < $2;
-- 0 rows: older event, skip it
```

If it writes 1 row, it sends the email (a row in `sent_emails`) in the same transaction, commits, then commits the offset.

**Static membership.** Each consumer joins its group with a fixed `group.instance.id` (`invoicing-1`, ...). A killed process doesn't leave the group, so without this the restarted consumer waits until the broker gives up on the dead one: the session timeout, 6 s in this lab (6.0 s in a test without static membership) and 45 s by default. With it, the restart takes the dead member's place at once (0.2 to 0.3 s). The broker setting `group.initial.rebalance.delay.ms=0` removes the 3 s wait when a consumer joins an empty group. Static members don't leave on a clean exit either, so `demo reset` or `demo setup` right after a consumer run waits for that session to time out (up to 6 s) before it can delete the group, and says so.

**The events** follow the deck's envelope ("The event envelope") and Zod 4 schema ("A contract you can enforce"), validated by the producer and by every consumer on receipt; an invalid event would be logged and skipped. `data.orderVersion` is new and optional, so the schema is still v1: the additive change from "Versioning - What breaks a consumer?". The message key is the order id; the tenant is `acme`.

Part 1 runs both consumers in one group, `invoicing`, like deploying new code to the same service: after the naive restart commits past o_42, the dedup consumer starts at o_43.

## Production differences

- Real crashes don't leave the group: without static membership the partition waits for the session timeout (45 s by default) before another consumer gets it. With static membership it waits the same time if the instance doesn't come back. The lab uses 6 s, the broker's minimum.
- The dedup table needs a cleanup job: keep event ids for longer than a duplicate can arrive (the topic's retention, or the producer's retry window), then delete them.
- Use more partitions, keyed by order id: Kafka orders events per partition, so one order's events stay in the order they were sent. They can still be sent out of order (two services, retries), which is why the version check stays.
- An email can't join a database transaction. The lab's `sent_emails` table stands in for the provider; in production, pass the event id as the provider's idempotency key ("Duplicates are normal").
- Invalid events go to a dead-letter topic rather than only a log line.

## Reset

`docker exec onramp-eda-app demo reset` (from anywhere). It drops and recreates the four tables from `sql/schema.sql`, recreates topic `orders` with 1 partition and deletes the three consumer groups. Run it twice in a row: it's idempotent. `demo setup dup` and `demo setup order` are the per-part fresh starts.

Stop: `docker compose -f eda-01-duplicates-ordering/compose.yaml stop`. Wipe (containers and data): `docker compose -f eda-01-duplicates-ordering/compose.yaml down -v`.

## Verify

```
docker exec onramp-eda-app bash /lab/scripts/verify.sh
docker cp onramp-eda-app:/tmp/recorded-run.md eda-01-duplicates-ordering/recorded-run.md
```

`verify.sh` runs both parts in run-sheet order without pauses, prints PASS/WARN/FAIL per check, writes `/tmp/recorded-run.md` (every command and its output, with start times and durations) and ends with `demo reset`. It checks: the reset; 1 invoice after the naive crash and 2 after the restart, with the same event id; the dedup redelivery skipped with 1 invoice for o_43; 2 naive emails (one "confirmed"); 1 version-check email, `skipped (have #2)` and `o_7 | 2 | cancelled`; the redelivery within 5 s (WARN only); the final reset. The `docker cp` line copies the transcript into this folder: commit it when the numbers change.

## Fallback

If Docker fails live, open `recorded-run.md` (on GitHub or in the editor) and walk through it: it shows every run-sheet command and its output, in order.

## Versions

Recorded on 2026-10-04, on Docker Desktop 4.54.0 (Engine 29.1.2).

| What | Version |
|---|---|
| Kafka | `apache/kafka:4.3.1` (`sha256:77e3df9054047a88b520d0cc46e16696d3b22022e1d580aeccd2632df6532837`), latest 4.x on Docker Hub on 2026-10-04 |
| Postgres | `postgres:18.6-trixie` (`sha256:5a5a84b19854a9ffaa54082c166ff4ec27473a361e496e5ea167f298f2da9722`) |
| App base | `node:24-slim` (`sha256:0e0ff40c39bc087845bfb27465a0df4ea419520094bc35842ff83dd8cbe6f9b6`): Node 24.21.0, npm 11.19.0 |
| Kafka client | `@confluentinc/kafka-javascript` 1.10.1 (librdkafka 2.15.1), KafkaJS-compatible API |
| Other npm packages | pg 8.23.1, zod 4.6.5; dev (editor types only): @types/node 24.19.1, @types/pg 8.23.1 |

The digests are the multi-platform index digests the tags resolved to. `npm ci` downloads the client's prebuilt binding (librdkafka) from the package's GitHub release at build time, so the build needs network and the demo doesn't. npm 11.19 only runs install scripts for packages listed under `allowScripts` in `package.json`, which is why the client is listed there.

## Files

| Path | What it is |
|---|---|
| `compose.yaml` | The three services, project `onramp-eda`, no published ports |
| `sql/schema.sql` | The four tables, dropped and recreated by `demo reset` |
| `app/Dockerfile`, `app/package.json`, `app/package-lock.json` | The app image: `node:24-slim`, `npm ci` at build time, `demo` on the PATH |
| `app/tsconfig.json` | Editor support only: Node 24 runs the `.ts` files directly (type stripping), no build step |
| `app/bin/demo` | The CLI wrapper: `exec node /app/src/demo.ts "$@"` |
| `app/src/demo.ts` | The `demo` commands |
| `app/src/events.ts` | The envelope and Zod 4 schemas |
| `app/src/kafka.ts` | The producer, the consumer loop (manual commit, `--crash`, idle exit, static membership) and the admin steps for reset and setup |
| `app/src/db.ts` | The pg pool, `sharedParams`, and the `sent_emails` stand-in for the email provider |
| `app/src/consumers/invoice-naive.ts` | Part 1, before the fix |
| `app/src/consumers/invoice-dedup.ts` | Part 1, the fix (the "Duplicates are normal" SQL) |
| `app/src/consumers/notify-naive.ts` | Part 2, before the fix |
| `app/src/consumers/notify-versioned.ts` | Part 2, the fix (the "Scenario - The fix" SQL) |
| `scripts/verify.sh` | End-to-end check and transcript |
| `recorded-run.md` | The transcript from `verify.sh` |

## Troubleshooting

- **`dependency failed to start` or `container onramp-eda-kafka is unhealthy` on `up`:** Kafka wasn't ready in time (it takes about 7 s on the laptop). Wait until `docker ps` shows it `(healthy)`, then run `up -d` again.
- **The restarted consumer prints nothing for about 6 s (45 s with the default session timeout), then the message:** static membership isn't in effect, so the restart waits for the dead member's session to time out. Check `group.instance.id` in `app/src/kafka.ts` and rebuild with `up -d --build`.
- **`demo reset` or `demo setup` prints `waiting for ...: the last consumer's session is still open`:** normal right after a consumer run. It waits up to 6 s, then deletes the group.
- **`$'\r': command not found` or `/usr/bin/env: 'bash\r'`:** the files were checked out with Windows line endings. `.gitattributes` prevents this on a fresh clone; for an old clone, run `git rm --cached -r . && git reset --hard`, then `up -d --build`.
- **A topic recreate fails because deletion is still pending:** setup retries for up to 15 s. If it still fails, run it again.
- **`npm ci` fails during the build with a download error:** the build fetches the Kafka client's binding from GitHub. Check the network and run `up -d --build` again.
