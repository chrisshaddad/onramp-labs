-- Option D
\set ECHO queries
\timing on
CREATE INDEX CONCURRENTLY idx_orders_org_status ON orders (org_id, status);
\timing off
\di+ idx_orders_org_status
