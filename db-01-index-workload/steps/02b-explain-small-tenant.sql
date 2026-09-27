-- Optional: the same SQL for a small tenant (org-045, customer 80641). Same query, different plan.
\set ECHO queries
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, created_at, total FROM orders
WHERE org_id = 'org-045' AND customer_id = 80641
ORDER BY created_at DESC LIMIT 10;
