-- Finance export: revenue per tenant per month for the last year. Slow, but runs rarely.
SELECT org_id, date_trunc('month', created_at) AS month, sum(total) AS revenue
FROM orders
WHERE created_at >= now() - interval '1 year'
GROUP BY org_id, month
ORDER BY org_id, month;
