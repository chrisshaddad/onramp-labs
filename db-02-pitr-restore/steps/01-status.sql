\set ECHO queries
-- The full copy
SELECT split_part(split_part(pg_read_file('/var/lib/postgresql/base_backup/backup_label'),
       'START TIME: ', 2), E'\n', 1) AS base_backup_taken;
-- Every change since is logged and shipped
SELECT archived_count, last_archived_wal, last_archived_time, failed_count FROM pg_stat_archiver;
SELECT count(*) AS orders, pg_size_pretty(pg_database_size('onramp')) AS database_size FROM orders;
