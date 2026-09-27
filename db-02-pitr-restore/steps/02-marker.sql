\set ECHO queries
-- A customer places an order just before the incident. We must get it back.
INSERT INTO orders (org_id, customer_id, status, created_at, total)
VALUES ('acme', 4242, 'open', now(), 1234.56)
RETURNING order_id, customer_id, total, created_at;
