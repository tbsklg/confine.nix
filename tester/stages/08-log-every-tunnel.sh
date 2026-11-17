# Stage 8: a log line when a tunnel opens and when it closes, with target, status, bytes and duration; never headers.

# log_line <pattern>: the last proxy log line matching pattern, waiting up to 2s for it.
log_line() {
  for _ in $(seq 20); do
    grep -a "$1" "$proxy_log" | tail -1 | grep . && return
    sleep 0.1
  done
}

start_upstream echo
tunnel "127.0.0.1:$upstream_port" echo >/dev/null
line="$(log_line "CONNECT 127.0.0.1:$upstream_port 200")"
[[ "$line" =~ [0-9]+ms$ ]] || fail "a tunnel is logged when it opens" "CONNECT 127.0.0.1:$upstream_port 200, <n>ms" "${line:-no such line}"
ok "logs a tunnel when it opens"

line="$(log_line "CONNECT 127.0.0.1:$upstream_port closed")"
[[ "$line" == *"sent 1048576, received 1048576 bytes"* && "$line" =~ [0-9]+ms$ ]] \
  || fail "a tunnel is logged when it closes" "CONNECT 127.0.0.1:$upstream_port closed, sent 1048576, received 1048576 bytes, <n>ms" "${line:-no such line}"
ok "logs a tunnel when it closes, with its bytes and duration"

closed="$(free_port)"
printf 'CONNECT 127.0.0.1:%s HTTP/1.1\r\nHost: x\r\n\r\n' "$closed" | nc -w 2 127.0.0.1 "$PORT" >/dev/null 2>&1
[[ -n "$(log_line "CONNECT 127.0.0.1:$closed 502")" ]] \
  || fail "a refused tunnel is logged" "CONNECT 127.0.0.1:$closed 502 …" "$(tail -1 "$proxy_log")"
ok "logs a refused tunnel with 502"

printf 'GET / HTTP/1.1\r\nX-Secret: hunter2\r\n\r\n' | nc -w 2 127.0.0.1 "$PORT" >/dev/null 2>&1
sleep 0.2
! grep -aq "hunter2\|X-Secret" "$proxy_log" || fail "headers stay out of the log" "no header names or values" "$(grep -a hunter2 "$proxy_log")"
ok "keeps headers out of the log"
