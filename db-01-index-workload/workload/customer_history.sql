-- Customer page: a customer's latest orders (tenant-scoped)
\set cust random(1, 200000)
SELECT org_id AS org FROM users WHERE id = :cust \gset
SELECT order_id, created_at, total FROM orders WHERE org_id = ':org' AND customer_id = :cust ORDER BY created_at DESC LIMIT 10;
