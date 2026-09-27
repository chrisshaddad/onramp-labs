-- The top statement, with real values substituted for $1 and $2 (acme customer 4242)
\set ECHO queries
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, created_at, total FROM orders
WHERE org_id = 'acme' AND customer_id = 4242
ORDER BY created_at DESC LIMIT 10;
