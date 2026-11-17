# Stage 1: confine-proxy --port N listens on 127.0.0.1:N and accepts connections.

nc -z 127.0.0.1 "$PORT" 2>/dev/null \
  || fail "connect to 127.0.0.1:$PORT" "connection accepted" "refused"
ok "accepts a TCP connection on 127.0.0.1:$PORT"

listen="$(lsof -nP -a -p "$proxy_pid" -iTCP:"$PORT" -sTCP:LISTEN -Fn 2>/dev/null | sed -n 's/^n//p')"
[[ "$listen" == "127.0.0.1:$PORT" ]] \
  || fail "listens on loopback only" "127.0.0.1:$PORT" "${listen:-no listening socket owned by the proxy}"
ok "listens on loopback only"

for _ in 1 2 3; do nc -z 127.0.0.1 "$PORT" 2>/dev/null || fail "keeps accepting" "3 connections in a row" "refused"; done
ok "keeps accepting after a connection closes"
