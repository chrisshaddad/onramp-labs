-- OnRamp labs: deterministic seed. About 2M orders; one oversized tenant (acme, ~40% of rows).
\set ON_ERROR_STOP on
SELECT setseed(0.42);

-- 200 tenants: acme, globex, initech, org-004 .. org-200
-- 200,000 users: 1..80,000 belong to acme; the rest are spread over the other 199 tenants.
INSERT INTO users (id, org_id, email)
SELECT id, org, 'user' || id || '@' || org || '.example'
FROM (
  SELECT id,
         CASE WHEN id <= 80000 THEN 'acme'
              ELSE (ARRAY['globex','initech'] || ARRAY(SELECT 'org-' || lpad(n::text, 3, '0') FROM generate_series(4, 200) n))
                   [((id - 80001) % 199) + 1]
         END AS org
  FROM generate_series(1, 200000) id
) u;

-- 2,000,000 orders over the last two years, inserted in time order like real traffic.
INSERT INTO orders (org_id, customer_id, status, created_at, total)
SELECT u.org_id, u.id,
       CASE WHEN r < 0.05 THEN 'open' WHEN r < 0.75 THEN 'paid' WHEN r < 0.95 THEN 'shipped' ELSE 'cancelled' END,
       s.ts,
       round((5 + random() * 495)::numeric, 2)
FROM (
  SELECT g,
         floor(random() * 200000)::bigint + 1 AS cust,
         random() AS r,
         now() - interval '730 days' + (interval '730 days' * g / 2000000) AS ts
  FROM generate_series(1, 2000000) g
) s
JOIN users u ON u.id = s.cust
ORDER BY s.ts;

-- 100,000 live sessions
INSERT INTO sessions (token, user_id, expires_at)
SELECT md5(g::text || 'onramp'), floor(random() * 200000)::bigint + 1, now() + interval '1 day'
FROM generate_series(1, 100000) g;

VACUUM ANALYZE;
