-- Dashboard tile: open orders for the tenant (the query on "Read the plan, not just EXPLAIN")
\set cust random(1, 200000)
SELECT org_id AS org FROM users WHERE id = :cust \gset
SELECT count(*) FROM orders WHERE org_id = ':org' AND status = 'open';
