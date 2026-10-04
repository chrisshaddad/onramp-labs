# eda-01-duplicates-ordering: recorded run

Recorded 2026-10-04 10:01 UTC by `scripts/verify.sh`: apache/kafka:4.3.1, Postgres 18.6 (Debian 18.6-1.pgdg13+2), Node 24.21.0, @confluentinc/kafka-javascript 1.10.1 (librdkafka 2.15.1).

Each block is one run-sheet command, typed in `docker exec -it onramp-eda-app bash`, and its output. The line above it gives the start time and how long the command took.

## Before the session

### Reset

`10:01:32 UTC` · 1.6 s

```
$ demo reset
tables dropped and recreated: invoices, processed_events, order_state, sent_emails
topic orders recreated (1 partition)
consumer groups deleted: invoicing, notify-naive, notify-versioned
eda-01 ready
```

## Part 1 - Duplicates (after "Duplicates are normal")

### 1. Fresh start

`10:01:34 UTC` · 0.2 s

```
$ demo setup dup
emptied invoices, processed_events; topic orders recreated (1 partition); deleted group invoicing
part 1 ready
```

### 2. Publish order o_42

`10:01:34 UTC` · 0.2 s

```
$ demo send o_42
sent o_42 order.placed #1 id=7a03b517 partition=0 offset=0
```

### 3. Naive consumer, crash before the offset commit

`10:01:34 UTC` · 0.3 s · exit code 1

```
$ demo consume naive --crash
[naive] o_42 order.placed id=7a03b517 offset=0 -> invoice inserted
[naive] CRASH before offset commit
```

### 4. Invoices for o_42

`10:01:34 UTC` · 0.1 s

```
$ demo invoices o_42
o_42: 1 invoice
  id=1  created_at=2026-10-04 10:01:34.817
```

> (chat) how many after the restart?

### 5. Restart the naive consumer

`10:01:34 UTC` · 3.4 s

```
$ demo consume naive
[naive] o_42 order.placed id=7a03b517 offset=0 -> invoice inserted
[naive] idle, exiting
```

### 6. Invoices for o_42

`10:01:38 UTC` · 0.1 s

```
$ demo invoices o_42
o_42: 2 invoices
  id=1  created_at=2026-10-04 10:01:34.817
  id=2  created_at=2026-10-04 10:01:35.310
```

### 7. Publish order o_43

`10:01:38 UTC` · 0.2 s

```
$ demo send o_43
sent o_43 order.placed #1 id=6b574806 partition=0 offset=1
```

### 8. Dedup consumer, crash before the offset commit

`10:01:38 UTC` · 0.2 s · exit code 1

```
$ demo consume dedup --crash
[dedup] o_43 order.placed id=6b574806 offset=1 -> invoice inserted, transaction committed
[dedup] CRASH before offset commit
```

### 9. Restart the dedup consumer

`10:01:38 UTC` · 3.3 s

```
$ demo consume dedup
[dedup] o_43 order.placed id=6b574806 offset=1 -> duplicate, skipped
[dedup] idle, exiting
```

### 10. Invoices for o_43

`10:01:42 UTC` · 0.1 s

```
$ demo invoices o_43
o_43: 1 invoice
  id=3  created_at=2026-10-04 10:01:38.971
```

## Part 2 - Out of order (after "Scenario - The fix")

### 1. Fresh start

`10:01:42 UTC` · 0.2 s

```
$ demo setup order
emptied order_state, sent_emails; topic orders recreated (1 partition); deleted group notify-naive, notify-versioned
part 2 ready
```

### 2. Publish cancelled #2, then placed #1

`10:01:42 UTC` · 0.2 s

```
$ demo send-out-of-order o_7
sent o_7 order.cancelled #2 id=e5069140 partition=0 offset=0
sent o_7 order.placed #1 id=72179171 partition=0 offset=1
```

### 3. Naive notifier

`10:01:42 UTC` · 3.4 s

```
$ demo consume notify-naive
[notify-naive] o_7 order.cancelled #2 -> email: "Your order is cancelled"
[notify-naive] o_7 order.placed #1 -> email: "Your order is confirmed"
[notify-naive] idle, exiting
```

> (chat) what does the version-check consumer send?

### 4. Version-check notifier

`10:01:46 UTC` · 3.4 s

```
$ demo consume notify-versioned
[notify-versioned] o_7 order.cancelled #2 -> email: "Your order is cancelled"
[notify-versioned] o_7 order.placed #1 -> skipped (have #2)
[notify-versioned] idle, exiting
```

### 5. The order_state row

`10:01:49 UTC` · 0.1 s

```
$ demo state o_7
o_7 | 2 | cancelled
```

### Check (not on the run sheet): emails sent for o_7

`10:01:49 UTC` · 0.2 s

```
$ demo emails o_7
o_7: 3 emails
  notify-naive      "Your order is cancelled"
  notify-naive      "Your order is confirmed"
  notify-versioned  "Your order is cancelled"
```

## After the session

### Reset for the next run

`10:01:50 UTC` · 4.8 s

```
$ demo reset
tables dropped and recreated: invoices, processed_events, order_state, sent_emails
topic orders recreated (1 partition)
waiting for notify-naive, notify-versioned: the last consumer's session is still open (up to 6 s)
consumer groups deleted: invoicing, notify-naive, notify-versioned
eda-01 ready
```

## Timings

| Part | Step | Command | Time |
|---|---|---|---|
| Before | Reset | `demo reset` | 1.6 s |
| Part 1 | 1. Fresh start | `demo setup dup` | 0.2 s |
| Part 1 | 2. Publish order o_42 | `demo send o_42` | 0.2 s |
| Part 1 | 3. Naive consumer, crash before the offset commit | `demo consume naive --crash` | 0.3 s |
| Part 1 | 4. Invoices for o_42 | `demo invoices o_42` | 0.1 s |
| Part 1 | 5. Restart the naive consumer | `demo consume naive` | 3.4 s |
| Part 1 | 6. Invoices for o_42 | `demo invoices o_42` | 0.1 s |
| Part 1 | 7. Publish order o_43 | `demo send o_43` | 0.2 s |
| Part 1 | 8. Dedup consumer, crash before the offset commit | `demo consume dedup --crash` | 0.2 s |
| Part 1 | 9. Restart the dedup consumer | `demo consume dedup` | 3.3 s |
| Part 1 | 10. Invoices for o_43 | `demo invoices o_43` | 0.1 s |
| Part 2 | 1. Fresh start | `demo setup order` | 0.2 s |
| Part 2 | 2. Publish cancelled #2, then placed #1 | `demo send-out-of-order o_7` | 0.2 s |
| Part 2 | 3. Naive notifier | `demo consume notify-naive` | 3.4 s |
| Part 2 | 4. Version-check notifier | `demo consume notify-versioned` | 3.4 s |
| Part 2 | 5. The order_state row | `demo state o_7` | 0.1 s |
| Part 2 | Check (not on the run sheet): emails sent for o_7 | `demo emails o_7` | 0.2 s |
| After | Reset for the next run | `demo reset` | 4.8 s |

- Part 1 machine time (steps 1 to 10): 8.3 s. Part 2 (steps 1 to 5): 7.3 s.
- Restart to redelivered message: naive 0.3 s, dedup 0.2 s (from Enter to the first output line).
- Each consumer run includes about 3 s of waiting for more messages before `idle, exiting`.
