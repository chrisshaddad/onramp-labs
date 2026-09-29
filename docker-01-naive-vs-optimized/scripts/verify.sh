#!/bin/sh
# Verify docker-01 end to end, non-interactively. Prints PASS/WARN/FAIL per check (numbered as in
# the build spec), exits non-zero on any FAIL, and writes every command, its output and its time to
# docker-01-naive-vs-optimized/recorded-run.md (the fallback for a live demo). Ends with a reset.
# Run from the repo root, in PowerShell or bash:
#   docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "${PWD}:/lab" -w /lab docker:29-cli sh docker-01-naive-vs-optimized/scripts/verify.sh
set -u
LAB=$(cd "$(dirname "$0")/.." && pwd)
APP=$LAB/app
OUT=$LAB/recorded-run.md
TMP=$(mktemp -d)
LOG=$TMP/out
fails=0
pass() { echo "PASS  $*"; }
warn() { echo "WARN  $*"; }
fail() { echo "FAIL  $*"; fails=$((fails + 1)); }
now() { awk '{ print $1 }' /proc/uptime; }
since() { awk -v a="$1" -v b="$(now)" 'BEGIN { printf "%.1f", b - a }'; }
show() { for a in "$@"; do case $a in *'"'*) printf "'%s' " "$a" ;; *" "*) printf '"%s" ' "$a" ;; *) printf '%s ' "$a" ;; esac; done; }

# step "<title>" <command...>: run the command in app/ and append it, its output and its wall time
# to the transcript. The output is left in $LOG, the time in $took, and the exit code is returned.
step() {
  title=$1; shift
  started=$(date -u +%H:%M:%S); t0=$(now)
  (cd "$APP" && "$@") > "$LOG" 2>&1; rc=$?
  took=$(since "$t0")
  { echo "### $title"; echo; echo "\`$started UTC\`  \`$(show "$@" | sed 's/ $//')\`  ($took s)"; echo
    echo '```'; cat "$LOG"; echo '```'; echo; } >> "$OUT"
  return $rc
}
note() { printf '%s\n\n' "$*" >> "$OUT"; }

# cached <instruction>: 0 if the build in $LOG reports that step as CACHED.
stepno() { awk -v s="] $1" 'index($0, s) && substr($0, length($0) - length(s) + 1) == s { print $1; exit }' "$LOG"; }
cached() { n=$(stepno "$1"); [ -n "$n" ] && grep -q "^$n CACHED" "$LOG"; }
steptime() { n=$(stepno "$1"); awk -v n="$n" '$1 == n && $2 == "DONE" { print $3; exit }' "$LOG"; }

# 1. The Docker CLI and buildx work inside this container.
if ! docker buildx version >/dev/null 2>&1; then
  fail "1 docker buildx version does not work in this container (is the Docker socket mounted?)"
  exit 1
fi
pass "1 $(docker buildx version | cut -d' ' -f1-2)"

{ echo "# docker-01-naive-vs-optimized: recorded run"; echo
  echo "Recorded $(date -u '+%Y-%m-%d %H:%M UTC') with $(docker version --format 'Docker Engine {{.Server.Version}} ({{.Server.Platform.Name}}), client {{.Client.Version}}') by \`scripts/verify.sh\`."
  echo
  echo "The run is non-interactive: \`verify.sh\` makes the greeting edits with \`sed\` where the instructor edits \`src/server.ts\` in the editor, and runs \`touch\` directly where the run sheet uses a throwaway alpine container. Every other command is the run sheet's, plus \`--progress=plain\` on builds. Times in parentheses are wall-clock seconds."
  echo; } > "$OUT"

echo "## Before the session" >> "$OUT"; echo >> "$OUT"
docker rm -f onramp-api-verify >/dev/null 2>&1
if step "Reset" sh "$LAB/scripts/reset.sh" && grep -q "docker-01 ready" "$LOG"; then pass "2 reset.sh"; else fail "2 reset.sh: $(cat "$LOG")"; fi

echo "## Run sheet" >> "$OUT"; echo >> "$OUT"
step "0. Shared kernel (optional), node:24-slim" docker run --rm node:24-slim sh -c "uname -r; grep PRETTY_NAME /etc/os-release"; k1=$(head -1 "$LOG"); o1=$(grep PRETTY "$LOG")
step "0. Shared kernel (optional), alpine:3" docker run --rm alpine:3 sh -c "uname -r; grep PRETTY_NAME /etc/os-release"; k2=$(head -1 "$LOG"); o2=$(grep PRETTY "$LOG")
if [ -n "$k1" ] && [ "$k1" = "$k2" ] && [ "$o1" != "$o2" ]; then pass "0 same kernel ($k1), different OS files"; else warn "0 kernels '$k1' / '$k2', OS '$o1' / '$o2'"; fi

if step "1. Naive build" docker build --progress=plain -f naive.Dockerfile -t onramp-api:naive .; then naive_first=$took; pass "3 naive build (${took} s)"; else fail "3 naive build: $(tail -20 "$LOG")"; fi
step "1. Image list" docker image ls onramp-api
step "1. History" docker history onramp-api:naive
cmd_row=$(docker history --format '{{.CreatedBy}}|{{.Size}}' onramp-api:naive | grep '^CMD' | head -1)
case $cmd_row in *"|0B") pass "3 docker history: $cmd_row" ;; *) fail "3 CMD row is not 0B: $cmd_row" ;; esac

note "2. Pause: (chat) which steps rerun after a one-line edit?"
step "2. Touch the file, contents unchanged" touch src/server.ts
step "2. Rebuild naive after touch" docker build --progress=plain -f naive.Dockerfile -t onramp-api:naive .
if cached "RUN npm ci" && cached "COPY . ." && cached "RUN npm run build"; then pass "5 after touch: COPY . ., RUN npm ci and RUN npm run build all CACHED (${took} s)"
else fail "5 after touch: not all steps CACHED"; fi

step "2. Edit src/server.ts: hello v1 -> hello v2" sed -i 's/"hello v1"/"hello v2"/' src/server.ts
if step "2. Rebuild naive after the edit" docker build --progress=plain -f naive.Dockerfile -t onramp-api:naive . && ! cached "RUN npm ci"; then
  naive_rebuild=$took; npm_ci=$(steptime "RUN npm ci")
  pass "6 after the edit: RUN npm ci reran (npm ci ${npm_ci}, whole rebuild ${took} s)"
else fail "6 after the edit: RUN npm ci was CACHED or the build failed"; fi

if step "3. Optimized build" docker build --progress=plain -t onramp-api:optimized .; then pass "7 optimized build (${took} s)"; else fail "7 optimized build: $(tail -20 "$LOG")"; fi
step "3. Edit src/server.ts: hello v2 -> hello v3" sed -i 's/"hello v2"/"hello v3"/' src/server.ts
if step "3. Rebuild optimized after the edit" docker build --progress=plain -t onramp-api:optimized . && cached "RUN npm ci" && cached "COPY package*.json ./" && ! cached "RUN npm run build && npm prune --omit=dev"; then
  opt_rebuild=$took
  pass "7 after the edit: COPY package*.json and RUN npm ci CACHED, the build reran (whole rebuild ${took} s)"
else fail "7 after the edit: expected RUN npm ci CACHED and the build step to rerun"; fi

step "4. Image list: sizes for the table" docker image ls onramp-api
step "4. whoami, naive" docker run --rm onramp-api:naive whoami; who_n=$(cat "$LOG")
step "4. whoami, optimized" docker run --rm onramp-api:optimized whoami; who_o=$(cat "$LOG")
if [ "$who_n" = root ] && [ "$who_o" = node ]; then pass "8 whoami: naive root, optimized node"; else fail "8 whoami: naive '$who_n', optimized '$who_o'"; fi

disk_n=$(docker image ls --format '{{.Size}}' onramp-api:naive); disk_o=$(docker image ls --format '{{.Size}}' onramp-api:optimized)
bytes_n=$(docker image inspect -f '{{.Size}}' onramp-api:naive); bytes_o=$(docker image inspect -f '{{.Size}}' onramp-api:optimized)
mb() { awk -v b="$1" 'BEGIN { if (b >= 1e9) printf "%.3gGB", b / 1e9; else printf "%.3gMB", b / 1e6 }'; }
if [ "$bytes_o" -lt "$bytes_n" ]; then
  pass "9 optimized is smaller: naive $disk_n on disk ($(mb "$bytes_n") content), optimized $disk_o on disk ($(mb "$bytes_o") content)"
else fail "9 optimized is not smaller: naive $disk_n ($bytes_n B), optimized $disk_o ($bytes_o B)"; fi

echo "## Extra checks (not in the run sheet)" >> "$OUT"; echo >> "$OUT"
step "Naive image: the whole folder was copied in" docker run --rm onramp-api:naive ls -A /app
grep -qx "naive.Dockerfile" "$LOG" && in_naive=yes || in_naive=no
docker rm -f onramp-api-verify >/dev/null 2>&1
step "Optimized build stage, built on its own" docker build -q --target build -t onramp-api:build-stage .
step "Optimized build stage: .dockerignore applied" docker run --rm onramp-api:build-stage ls -A /app
grep -qx "naive.Dockerfile" "$LOG" && in_opt=yes || in_opt=no
docker image rm onramp-api:build-stage >/dev/null 2>&1
if [ $in_naive = yes ] && [ $in_opt = no ]; then pass "4 per-Dockerfile ignore: naive.Dockerfile is in the naive image, not in the optimized build context"
else fail "4 per-Dockerfile ignore: naive.Dockerfile in naive image: $in_naive, in optimized build stage: $in_opt"; fi

step "Run the optimized image" docker run -d --name onramp-api-verify onramp-api:optimized
i=0; until docker logs onramp-api-verify 2>&1 | grep -q "listening on 3000" || [ $i -ge 50 ]; do sleep 0.2; i=$((i + 1)); done
step "Call it (slim has no curl or wget)" docker exec onramp-api-verify node -e "fetch('http://localhost:3000').then(r=>r.text()).then(console.log)"
if grep -qx '{"greeting":"hello v3"}' "$LOG"; then pass "10 response: $(cat "$LOG")"; else fail "10 response: $(cat "$LOG")"; fi
step "docker stop: SIGTERM, graceful shutdown" docker stop onramp-api-verify; stop_s=$took
code=$(docker inspect -f '{{.State.ExitCode}}' onramp-api-verify)
docker rm onramp-api-verify >/dev/null 2>&1
if [ "$code" != 0 ]; then fail "10 docker stop: exit code $code after ${stop_s} s (the SIGTERM handler did not exit cleanly)"
elif awk -v s="$stop_s" 'BEGIN { exit !(s < 2) }'; then pass "10 docker stop: exit code 0 in ${stop_s} s"
else warn "10 docker stop: exit code 0 but took ${stop_s} s (expected under 2 s)"; fi

echo "## After the session" >> "$OUT"; echo >> "$OUT"
step "Reset" sh "$LAB/scripts/reset.sh"
left=$(docker image ls -q onramp-api:naive; docker image ls -q onramp-api:optimized)
if [ -z "$left" ] && grep -q 'const GREETING = "hello v1";' "$APP/src/server.ts"; then pass "11 reset: lab images gone, greeting back to v1"
else fail "11 reset: images left '$left' or greeting not v1"; fi

{ echo "## Numbers for the slide table"; echo
  echo "| | Naive | Optimized |"; echo "|---|---|---|"
  echo "| Base image | node:24 | node:24-slim |"
  echo "| Image size, DISK USAGE column | $disk_n | $disk_o |"
  echo "| Image size, CONTENT SIZE column | $(mb "$bytes_n") | $(mb "$bytes_o") |"
  echo "| Rebuild after a one-line edit | ${naive_rebuild:-?} s (npm ci ${npm_ci:-?}) | ${opt_rebuild:-?} s (npm ci CACHED) |"
  echo "| whoami | $who_n | $who_o |"; echo; } >> "$OUT"
rm -rf "$TMP"
echo
if [ $fails -eq 0 ]; then echo "docker-01 verify: all checks passed. Transcript: docker-01-naive-vs-optimized/recorded-run.md"
else echo "docker-01 verify: $fails check(s) failed. Transcript: docker-01-naive-vs-optimized/recorded-run.md"; fi
exit $fails
