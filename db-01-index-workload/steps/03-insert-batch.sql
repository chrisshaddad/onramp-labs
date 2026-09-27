-- Write cost: insert 100,000 orders spread across customers, time it, then roll back.
-- VACUUM afterwards clears the rolled-back rows so every run starts from the same state.
\set ECHO queries
\timing on
BEGIN;
INSERT INTO orders (org_id, customer_id, status, created_at, total)
SELECT u.org_id, u.id, 'open', now(), 42.00
FROM generate_series(1, 100000) g
JOIN users u ON u.id = (g * 7919) % 200000 + 1;
ROLLBACK;
\timing off
VACUUM orders;
