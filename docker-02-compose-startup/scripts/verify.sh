#!/bin/sh
# Verify docker-02 end to end, non-interactively. Prints PASS/WARN/FAIL per check (numbered as in the
# build spec), exits non-zero on any FAIL, and writes the commands, their output and timestamps to
# docker-02-compose-startup/recorded-run.md (the fallback for a live demo). Ends with down -v.
# Run from the repo root, in PowerShell or bash:
#   docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "${PWD}:/lab" -w /lab docker:29-cli sh docker-02-compose-startup/scripts/verify.sh
set -u
LAB=$(cd "$(dirname "$0")/.." && pwd)
OUT=$LAB/recorded-run.md
TMP=$(mktemp -d)
LOG=$TMP/out
RUNS=10
fails=0
pass() { echo "PASS  $*"; }
warn() { echo "WARN  $*"; }
fail() { echo "FAIL  $*"; fails=$((fails + 1)); }
now() { awk '{ print $1 }' /proc/uptime; }
since() { awk -v a="$1" -v b="$(now)" 'BEGIN { printf "%.1f", b - a }'; }
cd "$LAB"

# step "<title>" <command...>: run the command and append it, its output and its wall time to the
# transcript. The output is left in $LOG and the exit code is returned.
step() {
  title=$1; shift
  started=$(date -u +%H:%M:%S); t0=$(now)
  "$@" > "$LOG" 2>&1; rc=$?
  took=$(since "$t0")
  { echo "### $title"; echo; echo "\`$started UTC\`  \`$*\`  ($took s)"; echo
    echo '```'; clean; echo '```'; echo; } >> "$OUT"
  return $rc
}
note() { printf '%s\n\n' "$*" >> "$OUT"; }

# api_started <compose file>: when the api container last started (empty or 0001-... if it hasn't).
api_started() { id=$(docker compose -f "$1" ps -a -q api 2>/dev/null); [ -n "$id" ] && docker inspect -f '{{.State.StartedAt}}' "$id" 2>/dev/null; }
# attempt <compose file> <start time>: once the api has (re)started since $prev, poll it for up to
# 20 s until it connects or exits, and set
#   $result: connected | refused (exit 1, ECONNREFUSED) | failed (any other exit) | timeout
#   $line:   the api's first log line of this start   $secs: seconds from <start time> until the result
attempt() {
  t1=$(now); result=timeout; line=
  while awk -v a="$t1" -v b="$(now)" 'BEGIN { exit !(b - a < 20) }'; do
    startedat=$(api_started "$1")
    case $startedat in "" | 0001-* | "$prev") sleep 0.2; continue ;; esac
    state=$(docker compose -f "$1" ps -a --format '{{.State}} {{.ExitCode}}' api 2>/dev/null)
    logs=$(docker compose -f "$1" logs --no-log-prefix --since "$startedat" api 2>/dev/null)
    line=$(printf '%s\n' "$logs" | head -1)
    case $logs in *"connected to Postgres"*) result=connected; break ;; esac
    case $state in
      "exited 1") case $logs in *ECONNREFUSED*) result=refused ;; *) result=failed ;; esac; break ;;
      exited*) result=failed; break ;;
    esac
    sleep 0.2
  done
  secs=$(since "$2")
}
up_and_wait() {
  t0=$(now); prev=$(api_started "$1")
  if docker compose -f "$1" up -d >/dev/null 2>&1; then attempt "$1" "$t0"; else result=up-failed; line=; secs=$(since "$t0"); fi
}
ESC=$(printf '\033')
clean() { sed "s/$ESC\[[0-9;]*[A-Za-z]//g" "$LOG" | tr -d '\r'; }

# live <compose file> "<title>": the live demo's attached `docker compose up`, stopped with
# `docker compose stop` (the instructor's Ctrl+C) once the api has connected or exited and the db is ready.
live() {
  started=$(date -u +%H:%M:%S); t0=$(now); prev=$(api_started "$1")
  docker compose -f "$1" up > "$LOG" 2>&1 &
  pid=$!
  # The api starts at once with the race file, and only once the db is healthy with the fixed one.
  i=0; while [ $i -lt 300 ]; do case $(api_started "$1") in "" | 0001-* | "$prev") sleep 0.2; i=$((i + 1)) ;; *) break ;; esac; done
  attempt "$1" "$t0"
  i=0; until docker compose -f "$1" exec -T db pg_isready -q -h 127.0.0.1 -U postgres || [ $i -ge 60 ]; do sleep 0.5; i=$((i + 1)); done
  sleep 1
  docker compose -f "$1" stop >/dev/null 2>&1
  wait $pid
  { echo "### $2"; echo; echo "\`$started UTC\`  \`docker compose -f $1 up\`, then Ctrl+C (api $result after $secs s)"; echo
    echo '```'; clean; echo '```'; echo; } >> "$OUT"
}

if ! docker compose version >/dev/null 2>&1; then fail "docker compose does not work in this container (is the Docker socket mounted?)"; exit 1; fi

{ echo "# docker-02-compose-startup: recorded run"; echo
  echo "Recorded $(date -u '+%Y-%m-%d %H:%M UTC') with $(docker version --format 'Docker Engine {{.Server.Version}} ({{.Server.Platform.Name}}), client {{.Client.Version}}'), $(docker compose version) by \`scripts/verify.sh\`."
  echo
  echo "The run sheet part runs each \`docker compose up\` attached, like the live demo, and stops it with \`docker compose stop\` where the instructor presses Ctrl+C. The repeated runs use \`up -d\` and read the api's state and logs. Times in parentheses are wall-clock seconds."
  echo; } > "$OUT"

echo "## Before the session" >> "$OUT"; echo >> "$OUT"
if step "Reset" sh "$LAB/scripts/reset.sh" && grep -q "docker-02 ready" "$LOG"; then pass "reset.sh"; else fail "reset.sh: $(cat "$LOG")"; fi

echo "## Run sheet" >> "$OUT"; echo >> "$OUT"
live race.compose.yaml "1. Race on a fresh volume"
[ "$result" = refused ] && pass "run sheet 1: api exits 1 with ECONNREFUSED ($line)" || warn "run sheet 1: api $result ($line)"
note "Pause: (chat) why does it fail the first time?"
live race.compose.yaml "2. Race again, data exists now"
[ "$result" = connected ] && pass "run sheet 2: api connects" || warn "run sheet 2: api $result ($line)"
step "3. Back to a fresh volume" docker compose -f race.compose.yaml down -v
live fixed.compose.yaml "4. Healthcheck on a fresh volume"
[ "$result" = connected ] && pass "run sheet 4: api connects after db is healthy" || fail "run sheet 4: api $result ($line)"
step "5. Clean up" docker compose -f fixed.compose.yaml down -v

echo "## Repeated runs" >> "$OUT"; echo >> "$OUT"
note "Each run: \`docker compose -f <file> up -d\`, then read \`docker compose ps -a\` and the api's logs for up to 20 s. \"Seconds\" is the time from starting \`up -d\` until the api connected or exited."
table_head() { { echo "### $1"; echo; echo "| Run | api | Seconds | api's first log line |"; echo "|---|---|---|---|"; } >> "$OUT"; }
row() { echo "| $1 | $result | $secs | \`$line\` |" >> "$OUT"; }

# 1. Fresh volume: down -v between runs.
table_head "1. race.compose.yaml, fresh volume (down -v between runs)"
refused=0; n=1
while [ $n -le $RUNS ]; do
  docker compose -f race.compose.yaml down -v >/dev/null 2>&1
  up_and_wait race.compose.yaml; row $n
  [ "$result" = refused ] && refused=$((refused + 1))
  n=$((n + 1))
done
echo >> "$OUT"
docker compose -f race.compose.yaml down -v >/dev/null 2>&1
if [ $refused -ge 8 ]; then pass "1 fresh-volume race: api exits 1 with ECONNREFUSED in $refused of $RUNS runs"
else fail "1 fresh-volume race: api exits 1 with ECONNREFUSED in only $refused of $RUNS runs (expected at least 8)"; fi

# 2. Warm volume: one run initialises it, then down (keeps the volume) between runs.
docker compose -f race.compose.yaml up -d >/dev/null 2>&1
i=0; until docker compose -f race.compose.yaml exec -T db pg_isready -q -h 127.0.0.1 -U postgres || [ $i -ge 60 ]; do sleep 0.5; i=$((i + 1)); done
docker compose -f race.compose.yaml down >/dev/null 2>&1
table_head "2. race.compose.yaml, warm volume (down without -v between runs)"
connected=0; n=1
while [ $n -le $RUNS ]; do
  up_and_wait race.compose.yaml; row $n
  [ "$result" = connected ] && connected=$((connected + 1))
  docker compose -f race.compose.yaml down >/dev/null 2>&1
  n=$((n + 1))
done
echo >> "$OUT"
warm=$connected
if [ $connected -ge 8 ]; then pass "2 warm race: api connects in $connected of $RUNS runs"
else warn "2 warm race: api connects in only $connected of $RUNS runs (the slide says it works on the second try)"; fi

# 3. Healthcheck on a fresh volume: down -v between runs.
table_head "3. fixed.compose.yaml, fresh volume (down -v between runs)"
connected=0; n=1
while [ $n -le $RUNS ]; do
  docker compose -f fixed.compose.yaml down -v >/dev/null 2>&1
  up_and_wait fixed.compose.yaml; row $n
  [ "$result" = connected ] && connected=$((connected + 1))
  n=$((n + 1))
done
echo >> "$OUT"
if [ $connected -eq $RUNS ]; then pass "3 healthcheck: api connects in $connected of $RUNS runs"
else fail "3 healthcheck: api connects in only $connected of $RUNS runs"; fi

# 4. Clean up.
echo "## After the session" >> "$OUT"; echo >> "$OUT"
if step "Clean up" docker compose -f fixed.compose.yaml down -v && [ -z "$(docker volume ls -q --filter name=onramp-docker02_pgdata)" ]; then pass "4 down -v: containers and volume removed"
else fail "4 down -v: the volume is still there"; fi

{ echo "## Success rates"; echo
  echo "| Series | Result |"; echo "|---|---|"
  echo "| Fresh volume, short-form depends_on | api exits 1 with ECONNREFUSED in $refused of $RUNS runs |"
  echo "| Warm volume, short-form depends_on | api connects in $warm of $RUNS runs |"
  echo "| Fresh volume, healthcheck + service_healthy | api connects in $connected of $RUNS runs |"; echo; } >> "$OUT"
rm -rf "$TMP"
echo
if [ $fails -eq 0 ]; then echo "docker-02 verify: all checks passed. Transcript: docker-02-compose-startup/recorded-run.md"
else echo "docker-02 verify: $fails check(s) failed. Transcript: docker-02-compose-startup/recorded-run.md"; fi
exit $fails
