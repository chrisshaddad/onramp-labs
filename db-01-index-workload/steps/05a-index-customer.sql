-- Option A
\set ECHO queries
\timing on
CREATE INDEX CONCURRENTLY idx_orders_customer ON orders (customer_id);
\timing off
\di+ idx_orders_customer
