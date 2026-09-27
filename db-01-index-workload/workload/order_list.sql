-- Orders page: the tenant's latest orders (served by idx_orders_org_created)
\set cust random(1, 200000)
SELECT org_id AS org FROM users WHERE id = :cust \gset
SELECT order_id, total FROM orders WHERE org_id = ':org' ORDER BY created_at DESC LIMIT 20;
