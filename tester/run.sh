#!/usr/bin/env bash
# Black-box tester for confine-proxy, CodeCrafters style.
# Usage: tester/run.sh <stage>   runs stages 1..<stage>
#        tester/run.sh all       runs every stage there is
set -uo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
bin="$root/zig-out/bin/confine-proxy"
stages=("$root"/tester/stages/*.sh)
last="${1:-all}"
[[ "$last" == all ]] && last="${#stages[@]}"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
dim() { printf '\033[2m%s\033[0m\n' "$*"; }

fail() {
  red "  ✗ $1"
  [[ $# -ge 2 ]] && echo "    expected: $2"
  [[ $# -ge 3 ]] && echo "    got:      $3"
  exit 1
}
ok() { green "  ✓ $1"; }

free_port() {
  local port
  while :; do
    port=$((20000 + RANDOM % 20000))
    nc -z 127.0.0.1 "$port" 2>/dev/null || { echo "$port"; return; }
  done
}

# Build with the dev shell's Zig unless we are already in it.
build=(zig build proxy)
[[ -n "${IN_NIX_SHELL:-}" ]] || build=(nix develop "$root" -c zig build proxy)
dim "building: ${build[*]}"
(cd "$root" && "${build[@]}") || fail "zig build proxy failed"
[[ -x "$bin" ]] || fail "no binary" "$bin" "nothing there (does 'zig build proxy' install confine-proxy?)"

PORT="$(free_port)"
proxy_log="$(mktemp)"
"$bin" --port "$PORT" 2>"$proxy_log" &
proxy_pid=$!
cleanup_pids=()
trap 'kill "$proxy_pid" "${cleanup_pids[@]}" 2>/dev/null; wait "$proxy_pid" 2>/dev/null; rm -f "$proxy_log"' EXIT

for _ in $(seq 30); do
  nc -z 127.0.0.1 "$PORT" 2>/dev/null && break
  kill -0 "$proxy_pid" 2>/dev/null || fail "confine-proxy exited at start" "listening on 127.0.0.1:$PORT" "process gone"
  sleep 0.1
done

# start_upstream echo|greet: starts tester/upstream.py on a free port, which it leaves in $upstream_port.
start_upstream() {
  upstream_port="$(free_port)"
  python3 -I "$root/tester/upstream.py" "$upstream_port" "$1" >/dev/null 2>&1 &
  cleanup_pids+=($!)
  for _ in $(seq 30); do nc -z 127.0.0.1 "$upstream_port" 2>/dev/null && break; sleep 0.1; done
}

tunnel() { python3 -I "$root/tester/tunnel.py" "$PORT" "$@"; }

export PORT proxy_pid proxy_log
for i in $(seq "$last"); do
  stage="${stages[$((i - 1))]:-}"
  [[ -n "$stage" ]] || fail "no stage $i yet"
  echo "stage $i: $(basename "$stage" .sh | cut -d- -f2- | tr - ' ')"
  # shellcheck source=/dev/null
  source "$stage"
  kill -0 "$proxy_pid" 2>/dev/null || fail "confine-proxy crashed during stage $i"
done
green "all $last stage(s) passed"
