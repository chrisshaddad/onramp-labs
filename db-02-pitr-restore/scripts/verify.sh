#!/usr/bin/env bash
# Verify db-02 end to end, non-interactively. Prints PASS/FAIL per check and writes a
# transcript of every step to /tmp/recorded-run.md (the fallback for a live demo).
# Ends with a reset, so the lab is ready for the next run.
# Run:  docker exec -u postgres onramp-pitr bash /labs/db-02-pitr-restore/scripts/verify.sh
# Copy: docker cp onramp-pitr:/tmp/recorded-run.md db-02-pitr-restore/recorded-run.md
set -uo pipefail
LAB=/labs/db-02-pitr-restore
BASE=/var/lib/postgresql
OUT=/tmp/recorded-run.md
fails=0
pass() { echo "PASS  $*"; }
fail() { echo "FAIL  $*"; fails=$((fails + 1)); }

step() {  # step "<title>" <command...>
  local title="$1"; shift
  local started; started=$(date -u +%H:%M:%S)
  local out; out=$("$@" 2>&1)
  { echo "## $title"; echo; echo "\`$started UTC\`  \`${*: -1}\`"; echo; echo '```'; echo "$out"; echo '```'; echo; } >> "$OUT"
  printf '%s' "$out"
}
sqlstep() { step "$1" psql -X -v ON_ERROR_STOP=1 -f "$LAB/steps/$2"; }

{ echo "# db-02-pitr-restore: recorded run"; echo; echo "Recorded $(date -u '+%Y-%m-%d %H:%M UTC') on $(psql -X -Atc 'SELECT version()' | cut -d' ' -f1-2)."; echo; } > "$OUT"

out=$(step "Reset (before the session)" bash "$LAB/scripts/reset.sh")
grep -q "db-02 ready" <<<"$out" && [ -f $BASE/base_backup/backup_label ] && pass "reset.sh and base backup" || fail "reset.sh: $out"

out=$(sqlstep "1. Status" 01-status.sql)
[ "$(psql -X -Atc 'SELECT failed_count FROM pg_stat_archiver')" = "0" ] && pass "archiver has no failures" || fail "archiver failed_count > 0"

out=$(sqlstep "2. Marker order" 02-marker.sql)
grep -q "1234.56" <<<"$out" && pass "marker inserted" || fail "marker: $out"

out=$(sqlstep "3. The incident" 03-drop.sql)
[ "$(psql -X -Atc "SELECT to_regclass('public.orders') IS NULL")" = "t" ] && pass "orders dropped" || fail "orders still exists"

{ echo "## Pause: the group guesses the RTO in the chat"; echo; } >> "$OUT"
out=$(step "4. Restore" bash "$LAB/scripts/restore.sh")
grep -q "recovery stopping before commit" <<<"$out" && grep -q "Measured RTO" <<<"$out" && pass "restore: $(grep 'Measured RTO' <<<"$out")" || fail "restore: $out"

out=$(sqlstep "5. Verify" 05-verify.sql)
[ "$(psql -X -Atc "SELECT count(*) FROM orders WHERE customer_id = 4242 AND total = 1234.56")" = "1" ] && pass "marker order is back" || fail "marker order missing"
[ "$(psql -X -Atc "SELECT count(*) = pg_read_file('$BASE/orders_before_drop')::bigint FROM orders")" = "t" ] && pass "order count matches" || fail "order count differs"
[ "$(psql -X -Atc "SELECT count(*) FROM users WHERE id = 200001")" = "1" ] && pass "signup after the drop kept" || fail "signup after the drop lost"
pg_ctl -D $BASE/restore status >/dev/null 2>&1 && fail "side instance still running" || pass "side instance stopped"

bash "$LAB/scripts/reset.sh" >/dev/null 2>&1 && pass "final reset" || fail "final reset"

echo
[[ $fails -eq 0 ]] && echo "db-02 verify: all checks passed. Transcript: $OUT" || echo "db-02 verify: $fails check(s) failed. Transcript: $OUT"
exit $fails
