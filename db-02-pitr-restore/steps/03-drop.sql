\set ECHO queries
COPY (SELECT count(*) FROM orders) TO '/var/lib/postgresql/orders_before_drop';
-- The last good moment. In a real incident you find it in the logs (log_statement = 'ddl') or an audit trail.
COPY (SELECT now()) TO '/var/lib/postgresql/last_good_time';
SELECT rtrim(pg_read_file('/var/lib/postgresql/last_good_time'), E'\n') AS last_good_moment;
DROP TABLE orders;
-- The app keeps running: someone signs up after the drop.
INSERT INTO users (id, org_id, email) VALUES (200001, 'acme', 'user200001@acme.example');
-- Ship the current WAL file now instead of waiting up to archive_timeout (60 s).
SELECT pg_switch_wal();
SELECT pg_sleep(2);
SELECT last_archived_wal, last_archived_time FROM pg_stat_archiver;
