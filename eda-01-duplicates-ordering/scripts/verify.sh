#!/usr/bin/env bash
# Verify eda-01 end to end, non-interactively. Runs the run sheet in order, prints PASS/WARN/FAIL
# per check and writes a transcript of every step to /tmp/recorded-run.md (the fallback for a live demo).
# Run:  docker exec onramp-eda-app bash /lab/scripts/verify.sh
# Copy: docker cp onramp-eda-app:/tmp/recorded-run.md eda-01-duplicates-ordering/recorded-run.md
set -uo pipefail
OUT=/tmp/recorded-run.md
fails=0
pass() { echo "PASS  $*"; }
warn() { echo "WARN  $*"; }
fail() { echo "FAIL  $*"; fails=$((fails + 1)); }
now_ms() { date +%s%3N; }
secs() { awk -v ms="$1" 'BEGIN { printf "%.1f", ms / 1000 }'; }

TIMINGS=()   # "part|label|command|ms" rows for the table at the end
PART_MS=0
PART=""

# step "<label>" <demo args...>: run `demo <args>` as typed live, add it to the transcript, and set
# OUTPUT (what the terminal shows), RC (exit code), MS (duration) and FIRST_MS (ms to the first line).
step() {
  local label="$1"; shift
  local cmd="demo $*" started t0 stamped
  started=$(date -u +%H:%M:%S)
  t0=$(now_ms)
  stamped=$(demo "$@" 2>&1 | while IFS= read -r line; do echo "$(( $(now_ms) - t0 )) $line"; done; exit "${PIPESTATUS[0]}")
  RC=$?
  MS=$(( $(now_ms) - t0 ))
  OUTPUT=$(sed 's/^[0-9]* //' <<<"$stamped")
  FIRST_MS=$(head -1 <<<"$stamped" | cut -d' ' -f1)
  {
    echo "### $label"
    echo
    echo "\`$started UTC\` · $(secs $MS) s$([ "$RC" -ne 0 ] && echo " · exit code $RC")"
    echo
    echo '```'
    echo "\$ $cmd"
    echo "$OUTPUT"
    echo '```'
    echo
  } >> "$OUT"
  TIMINGS+=("$PART|$label|$cmd|$MS")
  PART_MS=$(( PART_MS + MS ))
}
note() { printf '%s\n\n' "$*" >> "$OUT"; }
section() { printf '## %s\n\n' "$1" >> "$OUT"; PART="$2"; PART_MS=0; }
event_ref() { grep -o 'id=[0-9a-f]* offset=[0-9]*' <<<"$1" | head -1; }   # "id=1f3c9a2e offset=0"

versions=$(cd /app && node -e '
  const k = require("@confluentinc/kafka-javascript"), pg = require("pg");
  const c = new pg.Client(process.env.DATABASE_URL);
  c.connect().then(() => c.query("SHOW server_version")).then((r) => {
    const v = require("@confluentinc/kafka-javascript/package.json").version;
    console.log(`Postgres ${r.rows[0].server_version}, Node ${process.versions.node}, @confluentinc/kafka-javascript ${v} (librdkafka ${k.librdkafkaVersion})`);
    return c.end();
  });')
kafka_image=$(grep -o 'apache/kafka:[^ ]*' /lab/compose.yaml | head -1)

{
  echo "# eda-01-duplicates-ordering: recorded run"
  echo
  echo "Recorded $(date -u '+%Y-%m-%d %H:%M UTC') by \`scripts/verify.sh\`: $kafka_image, $versions."
  echo
  echo "Each block is one run-sheet command, typed in \`docker exec -it onramp-eda-app bash\`, and its output. The line above it gives the start time and how long the command took."
  echo
} > "$OUT"

# ------------------------------------------------------------------ before the session
section "Before the session" "Before"
step "Reset" reset
reset_ms=$MS
[[ $RC -eq 0 && "$OUTPUT" == *"eda-01 ready"* ]] && pass "demo reset ($(secs $MS) s)" || fail "demo reset: $OUTPUT"
(( reset_ms < 30000 )) || warn "demo reset took $(secs $reset_ms) s (target under 30 s)"

# ------------------------------------------------------------------ part 1
section 'Part 1 - Duplicates (after "Duplicates are normal")' "Part 1"
step "1. Fresh start" setup dup
[[ $RC -eq 0 ]] || fail "demo setup dup: $OUTPUT"
(( MS < 10000 )) || warn "demo setup dup took $(secs $MS) s (target under 10 s)"
step "2. Publish order o_42" send o_42
step "3. Naive consumer, crash before the offset commit" consume naive --crash
crash1="$OUTPUT"; crash1_rc=$RC; crash1_ref=$(event_ref "$OUTPUT")
step "4. Invoices for o_42" invoices o_42
inv1="$OUTPUT"
note "> (chat) how many after the restart?"
step "5. Restart the naive consumer" consume naive
restart1="$OUTPUT"; restart1_first=$FIRST_MS; restart1_ref=$(event_ref "$OUTPUT")
step "6. Invoices for o_42" invoices o_42
inv2="$OUTPUT"
if [[ $crash1_rc -eq 1 && "$crash1" == *"-> invoice inserted"* && "$crash1" == *"CRASH before offset commit"* \
      && "$inv1" == "o_42: 1 invoice"* && "$inv2" == "o_42: 2 invoices"* ]]; then
  pass "naive: 1 invoice after the crash, 2 after the restart"
else
  fail "naive: crash exit $crash1_rc / '${inv1%%$'\n'*}' / '${inv2%%$'\n'*}'"
fi
[[ -n "$crash1_ref" && "$crash1_ref" == "$restart1_ref" && "$restart1" == *"idle, exiting"* ]] \
  && pass "naive: the restart got the same event ($restart1_ref)" \
  || fail "naive: crash run '$crash1_ref', restart '$restart1_ref'"

step "7. Publish order o_43" send o_43
step "8. Dedup consumer, crash before the offset commit" consume dedup --crash
crash2="$OUTPUT"; crash2_rc=$RC; crash2_ref=$(event_ref "$OUTPUT")
step "9. Restart the dedup consumer" consume dedup
restart2="$OUTPUT"; restart2_first=$FIRST_MS; restart2_ref=$(event_ref "$OUTPUT")
step "10. Invoices for o_43" invoices o_43
inv3="$OUTPUT"
part1_ms=$PART_MS
if [[ $crash2_rc -eq 1 && "$crash2" == *"invoice inserted, transaction committed"* && "$crash2" == *"CRASH before offset commit"* \
      && "$restart2" == *"duplicate, skipped"* && "$crash2_ref" == "$restart2_ref" && "$inv3" == "o_43: 1 invoice"* ]]; then
  pass "dedup: redelivery of $restart2_ref skipped, 1 invoice for o_43"
else
  fail "dedup: crash '$crash2_ref' exit $crash2_rc, restart '$restart2_ref', '${inv3%%$'\n'*}'"
fi

# ------------------------------------------------------------------ part 2
section 'Part 2 - Out of order (after "Scenario - The fix")' "Part 2"
step "1. Fresh start" setup order
[[ $RC -eq 0 ]] || fail "demo setup order: $OUTPUT"
(( MS < 10000 )) || warn "demo setup order took $(secs $MS) s (target under 10 s)"
step "2. Publish cancelled #2, then placed #1" send-out-of-order o_7
sent="$OUTPUT"
[[ "$sent" == *"order.cancelled #2 "*"partition=0 offset=0"*"order.placed #1 "*"partition=0 offset=1"* ]] \
  && pass "cancelled #2 at offset 0, placed #1 at offset 1, same partition" || fail "send-out-of-order: $sent"
step "3. Naive notifier" consume notify-naive
naive="$OUTPUT"
note "> (chat) what does the version-check consumer send?"
step "4. Version-check notifier" consume notify-versioned
versioned="$OUTPUT"
step "5. The order_state row" state o_7
state="$OUTPUT"
part2_ms=$PART_MS
step "Check (not on the run sheet): emails sent for o_7" emails o_7
emails="$OUTPUT"
n_naive=$(grep -c '^  notify-naive ' <<<"$emails")
n_versioned=$(grep -c '^  notify-versioned ' <<<"$emails")
if [[ "$n_naive" == 2 && "$naive" == *'cancelled #2 -> email: "Your order is cancelled"'*'placed #1 -> email: "Your order is confirmed"'* ]] \
   && grep -q '^  notify-naive .*confirmed' <<<"$emails"; then
  pass "notify-naive: 2 emails, cancelled then confirmed"
else
  fail "notify-naive: $n_naive emails; log: $naive"
fi
if [[ "$n_versioned" == 1 && "$versioned" == *"skipped (have #2)"* && "$state" == "o_7 | 2 | cancelled" ]] \
   && grep -q '^  notify-versioned .*cancelled' <<<"$emails"; then
  pass "notify-versioned: 1 email (cancelled), placed #1 skipped, state o_7 | 2 | cancelled"
else
  fail "notify-versioned: $n_versioned emails, state '$state'; log: $versioned"
fi

# ------------------------------------------------------------------ timing
for r in "naive:$restart1_first" "dedup:$restart2_first"; do
  name=${r%%:*}; ms=${r#*:}
  if [[ -n "$ms" ]] && (( ms < 5000 )); then
    pass "$name: redelivered message $(secs $ms) s after the restart"
  else
    warn "$name: redelivered message after ${ms:-?} ms (target under 5 s; is static membership in effect?)"
  fi
done

# ------------------------------------------------------------------ after the session
section "After the session" "After"
step "Reset for the next run" reset
[[ $RC -eq 0 && "$OUTPUT" == *"eda-01 ready"* ]] && pass "final demo reset ($(secs $MS) s)" || fail "final demo reset: $OUTPUT"

{
  echo "## Timings"
  echo
  echo "| Part | Step | Command | Time |"
  echo "|---|---|---|---|"
  for t in "${TIMINGS[@]}"; do
    IFS='|' read -r part label cmd ms <<<"$t"
    echo "| $part | $label | \`$cmd\` | $(secs "$ms") s |"
  done
  echo
  echo "- Part 1 machine time (steps 1 to 10): $(secs $part1_ms) s. Part 2 (steps 1 to 5): $(secs $part2_ms) s."
  echo "- Restart to redelivered message: naive $(secs "${restart1_first:-0}") s, dedup $(secs "${restart2_first:-0}") s (from Enter to the first output line)."
  echo "- Each consumer run includes about 3 s of waiting for more messages before \`idle, exiting\`."
} >> "$OUT"

echo
echo "Part 1: $(secs $part1_ms) s, part 2: $(secs $part2_ms) s of machine time. Restart to redelivery: naive $(secs "${restart1_first:-0}") s, dedup $(secs "${restart2_first:-0}") s."
[[ $fails -eq 0 ]] && echo "eda-01 verify: all checks passed. Transcript: $OUT" || echo "eda-01 verify: $fails check(s) failed. Transcript: $OUT"
exit $fails
