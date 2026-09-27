# db-02-pitr-restore: recorded run

Recorded 2026-09-27 15:26 UTC on PostgreSQL 18.6.

## Reset (before the session)

`15:26:01 UTC`  `/labs/db-02-pitr-restore/scripts/reset.sh`

```
Seeding 2M orders (about 20-40 s)...
Taking the base backup (the 'Sunday 02:00 full copy')...
Simulating traffic since the backup...
db-02 ready: 2050000 orders, base backup at 2026-09-27 15:26:21 UTC.
```

## 1. Status

`15:26:24 UTC`  `/labs/db-02-pitr-restore/steps/01-status.sql`

```
SELECT split_part(split_part(pg_read_file('/var/lib/postgresql/base_backup/backup_label'),
       'START TIME: ', 2), E'\n', 1) AS base_backup_taken;
    base_backup_taken    
-------------------------
 2026-09-27 15:26:21 UTC
(1 row)

SELECT archived_count, last_archived_wal, last_archived_time, failed_count FROM pg_stat_archiver;
 archived_count |    last_archived_wal     |      last_archived_time       | failed_count 
----------------+--------------------------+-------------------------------+--------------
            313 | 000000010000000100000034 | 2026-09-27 15:26:24.292131+00 |            0
(1 row)

SELECT count(*) AS orders, pg_size_pretty(pg_database_size('onramp')) AS database_size FROM orders;
 orders  | database_size 
---------+---------------
 2050000 | 317 MB
(1 row)
```

## 2. Marker order

`15:26:24 UTC`  `/labs/db-02-pitr-restore/steps/02-marker.sql`

```
INSERT INTO orders (org_id, customer_id, status, created_at, total)
VALUES ('acme', 4242, 'open', now(), 1234.56)
RETURNING order_id, customer_id, total, created_at;
 order_id | customer_id |  total  |          created_at           
----------+-------------+---------+-------------------------------
  2050001 |        4242 | 1234.56 | 2026-09-27 15:26:24.929868+00
(1 row)

INSERT 0 1
```

## 3. The incident

`15:26:24 UTC`  `/labs/db-02-pitr-restore/steps/03-drop.sql`

```
COPY (SELECT count(*) FROM orders) TO '/var/lib/postgresql/orders_before_drop';
COPY 1
COPY (SELECT now()) TO '/var/lib/postgresql/last_good_time';
COPY 1
SELECT rtrim(pg_read_file('/var/lib/postgresql/last_good_time'), E'\n') AS last_good_moment;
       last_good_moment        
-------------------------------
 2026-09-27 15:26:25.109507+00
(1 row)

DROP TABLE orders;
DROP TABLE
INSERT INTO users (id, org_id, email) VALUES (200001, 'acme', 'user200001@acme.example');
INSERT 0 1
SELECT pg_switch_wal();
 pg_switch_wal 
---------------
 1/35860BD8
(1 row)

SELECT pg_sleep(2);
 pg_sleep 
----------
 
(1 row)

SELECT last_archived_wal, last_archived_time FROM pg_stat_archiver;
    last_archived_wal     |      last_archived_time       
--------------------------+-------------------------------
 000000010000000100000035 | 2026-09-27 15:26:25.159634+00
(1 row)
```

## Pause: the group guesses the RTO in the chat

## 4. Restore

`15:26:27 UTC`  `/labs/db-02-pitr-restore/scripts/restore.sh`

```
Recovery target: 2026-09-27 15:26:25.109507+00
1. Copied the base backup:            0.5 s
2. Replayed WAL up to the target:      1.6 s
   Postgres: recovery stopping before commit of transaction 1067, time 2026-09-27 15:26:25.111333+00
3. Copied orders back into production: 6.9 s
Measured RTO: 9.1 s
```

## 5. Verify

`15:26:36 UTC`  `/labs/db-02-pitr-restore/steps/05-verify.sql`

```
SELECT order_id, customer_id, total, created_at FROM orders WHERE customer_id = 4242 AND total = 1234.56;
 order_id | customer_id |  total  |          created_at           
----------+-------------+---------+-------------------------------
  2050001 |        4242 | 1234.56 | 2026-09-27 15:26:24.929868+00
(1 row)

SELECT count(*) AS orders_now,
       pg_read_file('/var/lib/postgresql/orders_before_drop')::bigint AS orders_before_drop
FROM orders;
 orders_now | orders_before_drop 
------------+--------------------
    2050001 |            2050001
(1 row)

SELECT id, email FROM users WHERE id = 200001;
   id   |          email          
--------+-------------------------
 200001 | user200001@acme.example
(1 row)
```

