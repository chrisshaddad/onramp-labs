# db-01-index-workload: recorded run

Recorded 2026-11-19 19:20 UTC on PostgreSQL 18.6.

## Reset (before the session)

`19:20:17 UTC`  `/labs/db-01-index-workload/scripts/reset.sh`

```
psql:/labs/db-01-index-workload/scripts/drop-lab-indexes.sql:12: NOTICE:  dropped 16482
Running 20 s of app traffic...
number of transactions actually processed: 2934
tps = 145.829210 (without initial connection time)
db-01 ready: indexes on orders are orders_pkey and idx_orders_org_created.
```

## 1. Top statements

`19:20:37 UTC`  `/labs/db-01-index-workload/steps/01-top-statements.sql`

```
SELECT coalesce(substring(query from '/\* page: ([^*]*) \*/'), '') AS page,
       calls, round(total_exec_time) AS total_ms,
       round(mean_exec_time::numeric, 1) AS avg_ms,
       left(regexp_replace(query, ' /\*[^*]*\*/', ''), 70) AS query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;
      page      | calls | total_ms | avg_ms |                                 query                                  
----------------+-------+----------+--------+------------------------------------------------------------------------
 customer       |   920 |    59305 |   64.5 | SELECT order_id, created_at, total FROM orders WHERE org_id = $1 AND c
 dashboard      |   255 |    15437 |   60.5 | SELECT count(*) FROM orders WHERE org_id = $1 AND status = $2
 finance export |     7 |     4086 |  583.6 | SELECT org_id, date_trunc($1, created_at) AS month, sum(total) AS reve
 every page     |  2927 |      361 |    0.1 | SELECT org_id AS org FROM users WHERE id = $1
 login          |   560 |      233 |    0.4 | SELECT id, org_id FROM users WHERE lower(email) = lower($1)
 orders         |  1192 |       30 |    0.0 | SELECT order_id, total FROM orders WHERE org_id = $1 ORDER BY created_
                |     1 |        0 |    0.3 | SELECT pg_stat_statements_reset()
(7 rows)
```

## 2. EXPLAIN the top statement

`19:20:37 UTC`  `/labs/db-01-index-workload/steps/02-explain-top.sql`

```
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, created_at, total FROM orders
WHERE org_id = 'acme' AND customer_id = 4242
ORDER BY created_at DESC LIMIT 10;
                                                     QUERY PLAN                                                      
---------------------------------------------------------------------------------------------------------------------
 Limit  (cost=48802.04..48802.05 rows=4 width=22) (actual time=99.551..99.553 rows=8.00 loops=1)
   Buffers: shared hit=16032 read=2773
   ->  Sort  (cost=48802.04..48802.05 rows=4 width=22) (actual time=99.550..99.551 rows=8.00 loops=1)
         Sort Key: created_at DESC
         Sort Method: quicksort  Memory: 25kB
         Buffers: shared hit=16032 read=2773
         ->  Seq Scan on orders  (cost=0.00..48802.00 rows=4 width=22) (actual time=8.619..99.529 rows=8.00 loops=1)
               Filter: ((org_id = 'acme'::text) AND (customer_id = 4242))
               Rows Removed by Filter: 1999992
               Buffers: shared hit=16029 read=2773
 Planning:
   Buffers: shared hit=121 read=14
 Planning Time: 1.598 ms
 Execution Time: 99.575 ms
(14 rows)
```

## 2b. Same SQL, small tenant (optional)

`19:20:37 UTC`  `/labs/db-01-index-workload/steps/02b-explain-small-tenant.sql`

```
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, created_at, total FROM orders
WHERE org_id = 'org-045' AND customer_id = 80641
ORDER BY created_at DESC LIMIT 10;
                                                                      QUERY PLAN                                                                      
------------------------------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=12835.54..12835.55 rows=1 width=22) (actual time=16.490..16.491 rows=6.00 loops=1)
   Buffers: shared hit=4254 read=870
   ->  Sort  (cost=12835.54..12835.55 rows=1 width=22) (actual time=16.489..16.489 rows=6.00 loops=1)
         Sort Key: created_at DESC
         Sort Method: quicksort  Memory: 25kB
         Buffers: shared hit=4254 read=870
         ->  Bitmap Heap Scan on orders  (cost=145.70..12835.53 rows=1 width=22) (actual time=6.615..16.466 rows=6.00 loops=1)
               Recheck Cond: (org_id = 'org-045'::text)
               Filter: (customer_id = 80641)
               Rows Removed by Filter: 5938
               Heap Blocks: exact=5093
               Buffers: shared hit=4251 read=870
               ->  Bitmap Index Scan on idx_orders_org_created  (cost=0.00..145.70 rows=6036 width=0) (actual time=0.756..0.757 rows=5944.00 loops=1)
                     Index Cond: (org_id = 'org-045'::text)
                     Index Searches: 1
                     Buffers: shared hit=1 read=27
 Planning:
   Buffers: shared hit=135
 Planning Time: 0.307 ms
 Execution Time: 16.535 ms
(20 rows)
```

## 3. Insert batch, baseline

`19:20:37 UTC`  `/labs/db-01-index-workload/steps/03-insert-batch.sql`

```
Timing is on.
BEGIN;
BEGIN
Time: 0.112 ms
INSERT INTO orders (org_id, customer_id, status, created_at, total)
SELECT u.org_id, u.id, 'open', now(), 42.00
FROM generate_series(1, 100000) g
JOIN users u ON u.id = (g * 7919) % 200000 + 1;
INSERT 0 100000
Time: 347.297 ms
ROLLBACK;
ROLLBACK
Time: 0.106 ms
Timing is off.
VACUUM orders;
VACUUM
```

## 4. The poll: the group votes A, B, C or D in the chat

`19:20:38 UTC`  `/labs/db-01-index-workload/steps/04-choose-index.sql`

```

Which ONE index would you add for the top statement? Answer A, B, C or D in the chat.

  A  CREATE INDEX ... ON orders (customer_id);
  B  CREATE INDEX ... ON orders (org_id, customer_id, created_at);
  C  CREATE INDEX ... ON orders (status);
  D  CREATE INDEX ... ON orders (org_id, status);
```

## 5. Create option B

`19:20:38 UTC`  `/labs/db-01-index-workload/steps/05b-index-org-customer-created.sql`

```
Timing is on.
CREATE INDEX CONCURRENTLY idx_orders_org_customer_created ON orders (org_id, customer_id, created_at);
CREATE INDEX
Time: 1919.397 ms (00:01.919)
Timing is off.
                                                     List of indexes
 Schema |              Name               | Type  |  Owner   | Table  | Persistence | Access method | Size  | Description 
--------+---------------------------------+-------+----------+--------+-------------+---------------+-------+-------------
 public | idx_orders_org_customer_created | index | postgres | orders | permanent   | btree         | 77 MB | 
(1 row)
```

## 6. EXPLAIN again

`19:20:40 UTC`  `/labs/db-01-index-workload/steps/02-explain-top.sql`

```
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, created_at, total FROM orders
WHERE org_id = 'acme' AND customer_id = 4242
ORDER BY created_at DESC LIMIT 10;
                                                                         QUERY PLAN                                                                         
------------------------------------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=0.43..20.35 rows=4 width=22) (actual time=0.033..0.063 rows=8.00 loops=1)
   Buffers: shared hit=7 read=7
   ->  Index Scan Backward using idx_orders_org_customer_created on orders  (cost=0.43..20.35 rows=4 width=22) (actual time=0.033..0.061 rows=8.00 loops=1)
         Index Cond: ((org_id = 'acme'::text) AND (customer_id = 4242))
         Index Searches: 1
         Buffers: shared hit=7 read=7
 Planning:
   Buffers: shared hit=151 read=2
 Planning Time: 0.302 ms
 Execution Time: 0.081 ms
(10 rows)
```

## 7. Insert batch, with index B

`19:20:40 UTC`  `/labs/db-01-index-workload/steps/03-insert-batch.sql`

```
Timing is on.
BEGIN;
BEGIN
Time: 0.095 ms
INSERT INTO orders (org_id, customer_id, status, created_at, total)
SELECT u.org_id, u.id, 'open', now(), 42.00
FROM generate_series(1, 100000) g
JOIN users u ON u.id = (g * 7919) % 200000 + 1;
INSERT 0 100000
Time: 549.573 ms
ROLLBACK;
ROLLBACK
Time: 0.299 ms
Timing is off.
VACUUM orders;
VACUUM
```

## 8. Re-run the workload (optional)

`19:20:41 UTC`  `/labs/db-01-index-workload/scripts/workload.sh`

```
number of transactions actually processed: 11345
tps = 565.444789 (without initial connection time)
```

## 8. Top statements again

`19:21:01 UTC`  `/labs/db-01-index-workload/steps/01-top-statements.sql`

```
SELECT coalesce(substring(query from '/\* page: ([^*]*) \*/'), '') AS page,
       calls, round(total_exec_time) AS total_ms,
       round(mean_exec_time::numeric, 1) AS avg_ms,
       left(regexp_replace(query, ' /\*[^*]*\*/', ''), 70) AS query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;
      page      | calls | total_ms | avg_ms |                                 query                                  
----------------+-------+----------+--------+------------------------------------------------------------------------
 dashboard      |   945 |    61646 |   65.2 | SELECT count(*) FROM orders WHERE org_id = $1 AND status = $2
 finance export |    27 |    15691 |  581.1 | SELECT org_id, date_trunc($1, created_at) AS month, sum(total) AS reve
 login          |  2291 |      433 |    0.2 | SELECT id, org_id FROM users WHERE lower(email) = lower($1)
 every page     | 11318 |      139 |    0.0 | SELECT org_id AS org FROM users WHERE id = $1
 customer       |  3384 |      102 |    0.0 | SELECT order_id, created_at, total FROM orders WHERE org_id = $1 AND c
 orders         |  4698 |       98 |    0.0 | SELECT order_id, total FROM orders WHERE org_id = $1 ORDER BY created_
                |     1 |        0 |    0.1 | SELECT pg_stat_statements_reset()
(7 rows)
```

