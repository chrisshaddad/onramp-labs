#!/usr/bin/env bash
# Verify db-01 end to end, non-interactively. Prints PASS/WARN/FAIL per check and writes a
# transcript of every step to /tmp/recorded-run.md (the fallback for a live demo).
# Run:  docker exec onramp-db bash /labs/db-01-index-workload/scripts/verify.sh
# Copy: docker cp onramp-db:/tmp/recorded-run.md db-01-index-workload/recorded-run.md
set -uo pipefail
LAB=/labs/db-01-index-workload
OUT=/tmp/recorded-run.md
fails=0
pass() { echo "PASS  $*"; }
warn() { echo "WARN  $*"; }
fail() { echo "FAIL  $*"; fails=$((fails + 1)); }

# Run one step, show it in the transcript, and return its output.
step() {  # step "<title>" <command...>
  local title="$1"; shift
  local started; started=$(date -u +%H:%M:%S)
  local out; out=$("$@" 2>&1)
  { echo "## $title"; echo; echo "\`$started UTC\`  \`${*: -1}\`"; echo; echo '```'; echo "$out"; echo '```'; echo; } >> "$OUT"
  printf '%s' "$out"
}
sqlstep() { step "$1" psql -X -v ON_ERROR_STOP=1 -f "$LAB/steps/$2"; }
insert_ms() { grep -A1 '^INSERT' <<<"$1" | sed -n 's/^Time: \([0-9.]*\) ms.*/\1/p' | head -1; }

{ echo "# db-01-index-workload: recorded run"; echo; echo "Recorded $(date -u '+%Y-%m-%d %H:%M UTC') on $(psql -X -Atc 'SELECT version()' | cut -d' ' -f1-2)."; echo; } > "$OUT"

out=$(step "Reset (before the session)" bash "$LAB/scripts/reset.sh")
grep -q "db-01 ready" <<<"$out" && pass "reset.sh" || fail "reset.sh: $out"

out=$(sqlstep "1. Top statements" 01-top-statements.sql)
top=$(psql -X -Atc "SELECT query FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 1")
[[ "$top" == "SELECT order_id, created_at, total FROM orders WHERE org_id"* ]] && pass "top statement is customer history" || fail "top statement is: $top"

out=$(sqlstep "2. EXPLAIN the top statement" 02-explain-top.sql)
grep -q "Seq Scan on orders" <<<"$out" && pass "plan before: Seq Scan" || fail "plan before has no Seq Scan"

out=$(sqlstep "2b. Same SQL, small tenant (optional)" 02b-explain-small-tenant.sql)
grep -q "idx_orders_org_created" <<<"$out" && pass "small tenant uses idx_orders_org_created" || warn "small tenant plan differs"

out=$(sqlstep "3. Insert batch, baseline" 03-insert-batch.sql); before=$(insert_ms "$out")
[[ -n "$before" ]] && pass "baseline insert: ${before} ms" || fail "no insert timing"

sqlstep "4. The poll: the group votes A, B, C or D in the chat" 04-choose-index.sql >/dev/null
out=$(sqlstep "5. Create option B" 05b-index-org-customer-created.sql)
[ "$(psql -X -Atc "SELECT count(*) FROM pg_indexes WHERE indexname = 'idx_orders_org_customer_created'")" = "1" ] && pass "index B created" || fail "index B: $out"

out=$(sqlstep "6. EXPLAIN again" 02-explain-top.sql)
grep -q "Index Scan Backward using idx_orders_org_customer_created" <<<"$out" && pass "plan after: Index Scan Backward" || fail "plan after does not use index B"

out=$(sqlstep "7. Insert batch, with index B" 03-insert-batch.sql); after=$(insert_ms "$out")
if [[ -n "$after" ]] && awk -v a="$after" -v b="$before" 'BEGIN { exit !(a > 1.2 * b) }'; then
  pass "insert with B: ${after} ms (baseline ${before} ms)"
else
  warn "insert with B: ${after} ms vs baseline ${before} ms (expected > 1.2x)"
fi

step "8. Re-run the workload (optional)" bash "$LAB/scripts/workload.sh" >/dev/null
out=$(sqlstep "8. Top statements again" 01-top-statements.sql)
top=$(psql -X -Atc "SELECT query FROM pg_stat_statements WHERE query NOT ILIKE '%pg_stat_statements%' ORDER BY total_exec_time DESC LIMIT 1")
[[ "$top" == "SELECT count(*) FROM orders"* ]] && pass "bottleneck moved to the open-orders count" || warn "top statement after the fix: $top"

bash "$LAB/scripts/reset.sh" >/dev/null 2>&1
n=$(psql -X -Atc "SELECT count(*) FROM pg_index WHERE indrelid = 'orders'::regclass")
[[ "$n" == "2" ]] && pass "reset leaves only the two baseline indexes" || fail "reset left $n indexes on orders"

echo
[[ $fails -eq 0 ]] && echo "db-01 verify: all checks passed. Transcript: $OUT" || echo "db-01 verify: $fails check(s) failed. Transcript: $OUT"
exit $fails
