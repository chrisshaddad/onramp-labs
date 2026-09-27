#!/usr/bin/env bash
# Reset db-01: seed if needed (or with --full), baseline indexes, fresh stats, fresh workload.
# Run: docker exec onramp-db bash /labs/db-01-index-workload/scripts/reset.sh [--full]
set -euo pipefail
LAB=/labs/db-01-index-workload
SQL=/labs/db-shared/sql
q() { psql -X -q -v ON_ERROR_STOP=1 "$@"; }

rows=0
if [ "$(psql -X -Atc "SELECT to_regclass('public.orders') IS NOT NULL")" = "t" ]; then
  rows=$(psql -X -Atc "SELECT count(*) FROM orders")
fi
if [[ "${1:-}" == "--full" || "$rows" -lt 2000000 ]]; then
  echo "Seeding 2M orders (about 20-40 s)..."
  q -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements"
  q -f $SQL/schema.sql
  q -f $SQL/seed.sql >/dev/null
fi
q -f $LAB/scripts/drop-lab-indexes.sql
q -c "VACUUM ANALYZE orders"
echo "Running 20 s of app traffic..."
bash $LAB/scripts/workload.sh
echo "db-01 ready: indexes on orders are orders_pkey and idx_orders_org_created."
