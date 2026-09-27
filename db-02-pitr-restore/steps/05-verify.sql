\set ECHO queries
-- The marker order is back
SELECT order_id, customer_id, total, created_at FROM orders WHERE customer_id = 4242 AND total = 1234.56;
-- Every order is back
SELECT count(*) AS orders_now,
       pg_read_file('/var/lib/postgresql/orders_before_drop')::bigint AS orders_before_drop
FROM orders;
-- The signup after the drop survived: we restored one table, not the whole database
SELECT id, email FROM users WHERE id = 200001;
