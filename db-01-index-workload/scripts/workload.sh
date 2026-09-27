#!/usr/bin/env bash
# Reset statement statistics, then simulate 20 seconds of app traffic:
# 4 concurrent clients, fixed mix of endpoints.
set -euo pipefail
psql -X -q -c "SELECT pg_stat_statements_reset()" >/dev/null
W=/labs/db-01-index-workload/workload
pgbench -n -c 4 -j 2 -T 20 --random-seed=42 \
  -f $W/customer_history.sql@120 \
  -f $W/order_list.sql@160 \
  -f $W/login.sql@80 \
  -f $W/open_orders.sql@32 \
  -f $W/finance_report.sql@1 \
  onramp 2>&1 | grep -E "^(number of transactions actually processed|tps)"
