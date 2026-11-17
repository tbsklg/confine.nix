# Stage 6: tunnels run concurrently; a slow or idle client doesn't hold up the others.

start_upstream echo
echo_port="$upstream_port"

# A tunnel that stays open and idle for the whole stage.
idle_out="$(mktemp)"
tunnel "127.0.0.1:$echo_port" hold >"$idle_out" &
cleanup_pids+=($!)
for _ in $(seq 30); do [[ -s "$idle_out" ]] && break; sleep 0.1; done
[[ "$(cat "$idle_out")" == open ]] || fail "an idle tunnel opens" "open" "$(cat "$idle_out")"

got="$(tunnel "127.0.0.1:$echo_port" echo)"
[[ "$got" == ok ]] || fail "a second tunnel while one is open and idle" "ok" "$got"
ok "serves a tunnel while another is open and idle"

# A client that sends half a head and then waits.
{ printf 'CONNECT 127.0.0.1:%s HTTP/1.1\r\n' "$echo_port"; sleep 30; } | nc 127.0.0.1 "$PORT" >/dev/null 2>&1 &
cleanup_pids+=($!)
sleep 0.3

got="$(tunnel "127.0.0.1:$echo_port" echo)"
[[ "$got" == ok ]] || fail "a tunnel while another client is stuck mid-head" "ok" "$got"
ok "serves a tunnel while another client is stuck mid-head"

results="$(mktemp -d)"
for i in $(seq 20); do tunnel "127.0.0.1:$echo_port" echo >"$results/$i" & done
wait_for=$(( $(date +%s) + 20 ))
while (( $(date +%s) < wait_for )); do
  (( $(cat "$results"/* | grep -c '^ok$') == 20 )) && break
  sleep 0.2
done
passed=$(cat "$results"/* | grep -c '^ok$')
(( passed == 20 )) || fail "20 tunnels in parallel" "20 ok" "$passed ok: $(cat "$results"/* | grep -v '^ok$' | head -1)"
ok "relays 20 tunnels in parallel"
rm -rf "$results" "$idle_out"
