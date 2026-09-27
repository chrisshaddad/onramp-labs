#!/usr/bin/env bash
# Reset db-02: fresh database, fresh base backup, some traffic after it.
# Run: docker exec -u postgres onramp-pitr bash /labs/db-02-pitr-restore/scripts/reset.sh
set -euo pipefail
BASE=/var/lib/postgresql
SQL=/labs/db-shared/sql
q() { psql -X -q -v ON_ERROR_STOP=1 "$@"; }

pg_ctl -D $BASE/restore status >/dev/null 2>&1 && pg_ctl -D $BASE/restore stop -m fast >/dev/null
rm -rf $BASE/restore $BASE/base_backup $BASE/last_good_time $BASE/orders_before_drop $BASE/restore.log
mkdir -p $BASE/wal_archive

echo "Seeding 2M orders (about 20-40 s)..."
dropdb --if-exists --force onramp
createdb onramp
q -f $SQL/schema.sql
q -f $SQL/seed.sql >/dev/null

echo "Taking the base backup (the 'Sunday 02:00 full copy')..."
pg_basebackup -D $BASE/base_backup -Fp -Xs -c fast
# WAL older than the backup is no longer needed: keep the archive small.
first=$(sed -n 's/^START WAL LOCATION: .*(file \(.*\))$/\1/p' $BASE/base_backup/backup_label)
pg_archivecleanup $BASE/wal_archive "$first"

echo "Simulating traffic since the backup..."
q -f /labs/db-02-pitr-restore/sql/traffic.sql >/dev/null
echo "db-02 ready: $(psql -X -Atc 'SELECT count(*) FROM orders') orders, base backup at $(sed -n 's/^START TIME: //p' $BASE/base_backup/backup_label)."
