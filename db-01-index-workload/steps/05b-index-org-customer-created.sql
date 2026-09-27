-- Option B
\set ECHO queries
\timing on
CREATE INDEX CONCURRENTLY idx_orders_org_customer_created ON orders (org_id, customer_id, created_at);
\timing off
\di+ idx_orders_org_customer_created
