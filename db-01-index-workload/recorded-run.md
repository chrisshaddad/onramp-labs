# db-01-index-workload: recorded run

Recorded 2026-09-27 15:24 UTC on PostgreSQL 18.6.

## Reset (before the session)

`15:24:50 UTC`  `/labs/db-01-index-workload/scripts/reset.sh`

```
Running 20 s of app traffic...
number of transactions actually processed: 1097
tps = 53.387238 (without initial connection time)
db-01 ready: indexes on orders are orders_pkey and idx_orders_org_created.
```

## 1. Top statements

`15:25:11 UTC`  `/labs/db-01-index-workload/steps/01-top-statements.sql`

```
SELECT calls, round(total_exec_time) AS total_ms,
       round(mean_exec_time::numeric, 1) AS avg_ms, left(query, 70) AS query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;
 calls | total_ms | avg_ms |                                 query                                  
-------+----------+--------+------------------------------------------------------------------------
   345 |    54920 |  159.2 | SELECT order_id, created_at, total FROM orders WHERE org_id = $1 AND c
    84 |    14454 |  172.1 | SELECT count(*) FROM orders WHERE org_id = $1 AND status = $2
     3 |    10154 | 3384.6 | SELECT org_id, date_trunc($1, created_at) AS month, sum(total) AS reve
  1094 |       52 |    0.0 | SELECT org_id AS org FROM users WHERE id = $1
   446 |       28 |    0.1 | SELECT order_id, total FROM orders WHERE org_id = $1 ORDER BY created_
   219 |       11 |    0.1 | SELECT id, org_id FROM users WHERE lower(email) = lower($1)
     1 |        0 |    0.1 | SELECT pg_stat_statements_reset()
(7 rows)
```

## 2. EXPLAIN the top statement

`15:25:11 UTC`  `/labs/db-01-index-workload/steps/02-explain-top.sql`

```
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, created_at, total FROM orders
WHERE org_id = 'acme' AND customer_id = 4242
ORDER BY created_at DESC LIMIT 10;
                                                      QUERY PLAN                                                       
-----------------------------------------------------------------------------------------------------------------------
 Limit  (cost=48802.04..48802.05 rows=4 width=22) (actual time=221.387..221.390 rows=8.00 loops=1)
   Buffers: shared hit=16015 read=2790
   ->  Sort  (cost=48802.04..48802.05 rows=4 width=22) (actual time=221.384..221.385 rows=8.00 loops=1)
         Sort Key: created_at DESC
         Sort Method: quicksort  Memory: 25kB
         Buffers: shared hit=16015 read=2790
         ->  Seq Scan on orders  (cost=0.00..48802.00 rows=4 width=22) (actual time=58.700..221.332 rows=8.00 loops=1)
               Filter: ((org_id = 'acme'::text) AND (customer_id = 4242))
               Rows Removed by Filter: 1999992
               Buffers: shared hit=16012 read=2790
 Planning:
   Buffers: shared hit=119 read=16
 Planning Time: 0.676 ms
 Execution Time: 221.463 ms
(14 rows)
```

## 2b. Same SQL, small tenant (optional)

`15:25:12 UTC`  `/labs/db-01-index-workload/steps/02b-explain-small-tenant.sql`

```
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, created_at, total FROM orders
WHERE org_id = 'org-045' AND customer_id = 80641
ORDER BY created_at DESC LIMIT 10;
                                                                      QUERY PLAN                                                                      
------------------------------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=12797.25..12797.25 rows=1 width=22) (actual time=29.440..29.444 rows=6.00 loops=1)
   Buffers: shared hit=4270 read=854
   ->  Sort  (cost=12797.25..12797.25 rows=1 width=22) (actual time=29.437..29.440 rows=6.00 loops=1)
         Sort Key: created_at DESC
         Sort Method: quicksort  Memory: 25kB
         Buffers: shared hit=4270 read=854
         ->  Bitmap Heap Scan on orders  (cost=145.47..12797.24 rows=1 width=22) (actual time=10.684..29.394 rows=6.00 loops=1)
               Recheck Cond: (org_id = 'org-045'::text)
               Filter: (customer_id = 80641)
               Rows Removed by Filter: 5938
               Heap Blocks: exact=5093
               Buffers: shared hit=4267 read=854
               ->  Bitmap Index Scan on idx_orders_org_created  (cost=0.00..145.47 rows=6006 width=0) (actual time=1.446..1.446 rows=5944.00 loops=1)
                     Index Cond: (org_id = 'org-045'::text)
                     Index Searches: 1
                     Buffers: shared hit=1 read=27
 Planning:
   Buffers: shared hit=135
 Planning Time: 0.604 ms
 Execution Time: 29.539 ms
(20 rows)
```

## 3. Insert batch, baseline

`15:25:12 UTC`  `/labs/db-01-index-workload/steps/03-insert-batch.sql`

```
Timing is on.
BEGIN;
BEGIN
Time: 0.179 ms
INSERT INTO orders (org_id, customer_id, status, created_at, total)
SELECT u.org_id, u.id, 'open', now(), 42.00
FROM generate_series(1, 100000) g
JOIN users u ON u.id = (g * 7919) % 200000 + 1;
INSERT 0 100000
Time: 668.575 ms
ROLLBACK;
ROLLBACK
Time: 0.164 ms
Timing is off.
VACUUM orders;
VACUUM
```

## 4. The poll: the group votes A, B, C or D in the chat

`15:25:13 UTC`  `/labs/db-01-index-workload/steps/04-choose-index.sql`

```

Which ONE index would you add for the top statement? Answer A, B, C or D in the chat.

  A  CREATE INDEX ... ON orders (customer_id);
  B  CREATE INDEX ... ON orders (org_id, customer_id, created_at);
  C  CREATE INDEX ... ON orders (status);
  D  CREATE INDEX ... ON orders (org_id, status);
```

## 5. Create option B

`15:25:13 UTC`  `/labs/db-01-index-workload/steps/05b-index-org-customer-created.sql`

```
Timing is on.
CREATE INDEX CONCURRENTLY idx_orders_org_customer_created ON orders (org_id, customer_id, created_at);
CREATE INDEX
Time: 3236.849 ms (00:03.237)
Timing is off.
                                                     List of indexes
 Schema |              Name               | Type  |  Owner   | Table  | Persistence | Access method | Size  | Description 
--------+---------------------------------+-------+----------+--------+-------------+---------------+-------+-------------
 public | idx_orders_org_customer_created | index | postgres | orders | permanent   | btree         | 77 MB | 
(1 row)
```

## 6. EXPLAIN again

`15:25:16 UTC`  `/labs/db-01-index-workload/steps/02-explain-top.sql`

```
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, created_at, total FROM orders
WHERE org_id = 'acme' AND customer_id = 4242
ORDER BY created_at DESC LIMIT 10;
                                                                         QUERY PLAN                                                                         
------------------------------------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=0.43..20.33 rows=4 width=22) (actual time=0.050..0.096 rows=8.00 loops=1)
   Buffers: shared hit=7 read=7
   ->  Index Scan Backward using idx_orders_org_customer_created on orders  (cost=0.43..20.33 rows=4 width=22) (actual time=0.049..0.093 rows=8.00 loops=1)
         Index Cond: ((org_id = 'acme'::text) AND (customer_id = 4242))
         Index Searches: 1
         Buffers: shared hit=7 read=7
 Planning:
   Buffers: shared hit=151 read=2
 Planning Time: 0.550 ms
 Execution Time: 0.126 ms
(10 rows)
```

## 7. Insert batch, with index B

`15:25:16 UTC`  `/labs/db-01-index-workload/steps/03-insert-batch.sql`

```
Timing is on.
BEGIN;
BEGIN
Time: 0.154 ms
INSERT INTO orders (org_id, customer_id, status, created_at, total)
SELECT u.org_id, u.id, 'open', now(), 42.00
FROM generate_series(1, 100000) g
JOIN users u ON u.id = (g * 7919) % 200000 + 1;
INSERT 0 100000
Time: 1211.548 ms (00:01.212)
ROLLBACK;
ROLLBACK
Time: 0.181 ms
Timing is off.
VACUUM orders;
VACUUM
```

## 8. Re-run the workload (optional)

`15:25:17 UTC`  `/labs/db-01-index-workload/scripts/workload.sh`

```
number of transactions actually processed: 3118
tps = 146.075577 (without initial connection time)
```

## 8. Top statements again

`15:25:39 UTC`  `/labs/db-01-index-workload/steps/01-top-statements.sql`

```
SELECT calls, round(total_exec_time) AS total_ms,
       round(mean_exec_time::numeric, 1) AS avg_ms, left(query, 70) AS query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;
 calls | total_ms | avg_ms |                                 query                                  
-------+----------+--------+------------------------------------------------------------------------
   273 |    53239 |  195.0 | SELECT count(*) FROM orders WHERE org_id = $1 AND status = $2
     9 |    27238 | 3026.5 | SELECT org_id, date_trunc($1, created_at) AS month, sum(total) AS reve
   966 |       87 |    0.1 | SELECT order_id, created_at, total FROM orders WHERE org_id = $1 AND c
  3109 |       85 |    0.0 | SELECT org_id AS org FROM users WHERE id = $1
  1268 |       70 |    0.1 | SELECT order_id, total FROM orders WHERE org_id = $1 ORDER BY created_
   602 |       17 |    0.0 | SELECT id, org_id FROM users WHERE lower(email) = lower($1)
     1 |        0 |    0.1 | SELECT pg_stat_statements_reset()
(7 rows)
```

