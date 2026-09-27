#!/usr/bin/env bash
# Point-in-time restore of the dropped orders table, timed.
# 1. Copy the base backup into a second instance (port 5433): never restore over your only copy.
# 2. Replay the WAL archive up to the last good moment, then promote.
# 3. Copy orders back into the live database (port 5432). Nothing else is rolled back.
# Optional argument: a recovery target time. Default: the moment saved by step 03.
set -euo pipefail
BASE=/var/lib/postgresql
SIDE=$BASE/restore
TARGET="${1:-$(cat $BASE/last_good_time)}"
ts() { date +%s.%N; }
secs() { awk -v a="$1" -v b="$2" 'BEGIN { printf "%.1f", b - a }'; }

if [ "$(psql -X -Atc "SELECT to_regclass('public.orders') IS NOT NULL")" = "t" ]; then
  echo "orders still exists in the live database: run step 03 first, or reset." >&2; exit 1
fi
echo "Recovery target: $TARGET"
t0=$(ts)
pg_ctl -D $SIDE status >/dev/null 2>&1 && pg_ctl -D $SIDE stop -m fast >/dev/null
rm -rf $SIDE
cp -a $BASE/base_backup $SIDE
cat >> $SIDE/postgresql.auto.conf <<CONF
port = 5433
archive_mode = off
restore_command = 'cp $BASE/wal_archive/%f %p'
recovery_target_time = '$TARGET'
recovery_target_action = 'promote'
CONF
touch $SIDE/recovery.signal
t1=$(ts); echo "1. Copied the base backup:            $(secs $t0 $t1) s"

pg_ctl -D $SIDE -l $BASE/restore.log start -w -t 600 >/dev/null
until [ "$(psql -X -p 5433 -Atc 'SELECT pg_is_in_recovery()')" = "f" ]; do sleep 0.5; done
t2=$(ts); echo "2. Replayed WAL up to the target:      $(secs $t1 $t2) s"
grep "recovery stopping" $BASE/restore.log | tail -1 | sed 's/^.*LOG: */   Postgres: /'

pg_dump -p 5433 -t orders onramp | psql -X -q -v ON_ERROR_STOP=1 -p 5432 onramp >/dev/null
t3=$(ts); echo "3. Copied orders back into production: $(secs $t2 $t3) s"

pg_ctl -D $SIDE stop -m fast >/dev/null
echo "Measured RTO: $(secs $t0 $t3) s"
