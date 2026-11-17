# Stage 4: connect upstream; 200 Connection Established on success, 502 Bad Gateway when that fails.

connect_status() {
  { printf 'CONNECT %s HTTP/1.1\r\nHost: %s\r\n\r\n' "$1" "$1"; sleep 1; } \
    | nc -w 2 127.0.0.1 "$PORT" 2>/dev/null | head -1 | tr -d '\r'
}

start_upstream echo
upstream="$upstream_port"

want="HTTP/1.1 200 Connection Established"
got="$(connect_status "127.0.0.1:$upstream")"
[[ "$got" == "$want" ]] || fail "CONNECT to a listening upstream" "$want" "${got:-no response}"
ok "answers 200 when the upstream accepts"

got="$(connect_status "localhost:$upstream")"
[[ "$got" == "$want" ]] || fail "CONNECT resolves host names" "$want" "${got:-no response}"
ok "resolves a host name"

want="HTTP/1.1 502 Bad Gateway"
closed="$(free_port)"
got="$(connect_status "127.0.0.1:$closed")"
[[ "$got" == "$want" ]] || fail "CONNECT to a closed port" "$want" "${got:-no response}"
ok "answers 502 when the upstream refuses"

got="$(connect_status "no-such-host.invalid:443")"
[[ "$got" == "$want" ]] || fail "CONNECT to a host that doesn't resolve" "$want" "${got:-no response}"
ok "answers 502 when the host doesn't resolve"
