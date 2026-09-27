-- "Monday morning": traffic after the base backup, so the restore has changes to replay.
SELECT setseed(0.7);
INSERT INTO orders (org_id, customer_id, status, created_at, total)
SELECT u.org_id, u.id, 'open', now(), round((5 + random() * 495)::numeric, 2)
FROM (SELECT floor(random() * 200000)::bigint + 1 AS cust FROM generate_series(1, 50000)) s
JOIN users u ON u.id = s.cust;
UPDATE orders SET status = 'paid' WHERE status = 'open' AND order_id % 10 = 0;
