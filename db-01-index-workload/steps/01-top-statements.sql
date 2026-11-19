-- What costs the most in total? (the query from "Choose indexes from evidence")
-- Every workload query ends with a tag like /* page: customer */, the way ORMs and tracing
-- tools tag queries with their route. The page column reads that tag back.
\set ECHO queries
SELECT coalesce(substring(query from '/\* page: ([^*]*) \*/'), '') AS page,
       calls, round(total_exec_time) AS total_ms,
       round(mean_exec_time::numeric, 1) AS avg_ms,
       left(regexp_replace(query, ' /\*[^*]*\*/', ''), 70) AS query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;
