-- What costs the most in total? (the query from "Choose indexes from evidence")
\set ECHO queries
SELECT calls, round(total_exec_time) AS total_ms,
       round(mean_exec_time::numeric, 1) AS avg_ms, left(query, 70) AS query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;
