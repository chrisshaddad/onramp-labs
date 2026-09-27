-- Option C
\set ECHO queries
\timing on
CREATE INDEX CONCURRENTLY idx_orders_status ON orders (status);
\timing off
\di+ idx_orders_status
