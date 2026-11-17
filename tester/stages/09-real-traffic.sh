# Stage 9: real clients through the proxy.

got="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 -x "http://127.0.0.1:$PORT" https://example.com 2>&1)"
[[ "$got" == 200 ]] || fail "curl https://example.com through the proxy" "200" "$got"
ok "curl reaches https://example.com through the tunnel"

got="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 -x "http://127.0.0.1:$PORT" http://example.com 2>&1)"
[[ "$got" == 405 ]] || fail "plain http through the proxy" "405 (only CONNECT is relayed)" "$got"
ok "plain http is refused with 405"
