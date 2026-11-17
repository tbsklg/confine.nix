# Stage 2: read the request head; answer anything that isn't CONNECT with 405 and close.

# send <delay-between-parts> <part>...: writes the parts to the proxy, prints the first response line.
send() {
  local delay="$1"; shift
  { for part in "$@"; do printf '%b' "$part"; sleep "$delay"; done; sleep 2; } \
    | nc -w 3 127.0.0.1 "$PORT" 2>/dev/null | head -1 | tr -d '\r'
}

want="HTTP/1.1 405 Method Not Allowed"

got="$(send 0 'GET / HTTP/1.1\r\nHost: example.com\r\n\r\n')"
[[ "$got" == "$want" ]] || fail "GET is refused" "$want" "${got:-no response}"
ok "answers GET with 405"

got="$(send 0 'POST /x HTTP/1.1\r\nHost: example.com\r\nContent-Length: 0\r\n\r\n')"
[[ "$got" == "$want" ]] || fail "POST is refused" "$want" "${got:-no response}"
ok "answers POST with 405"

got="$(send 0.3 'GET / HTTP/1.1\r\n' 'Host: example.com\r\n' '\r\n')"
[[ "$got" == "$want" ]] || fail "a head sent in pieces is read whole" "$want" "${got:-no response}"
ok "reads a head that arrives in pieces"

got="$(send 0 'GET / HTTP/1.1\r\nHost: example.com\r\n')"
[[ -z "$got" ]] || fail "waits for the blank line that ends the head" "no response yet" "$got"
ok "doesn't answer before the head is complete"

start=$(date +%s)
printf 'GET / HTTP/1.1\r\nHost: example.com\r\n\r\n' | nc -w 5 127.0.0.1 "$PORT" >/dev/null 2>&1
(( $(date +%s) - start < 3 )) || fail "closes after the 405" "connection closed by the proxy" "still open after 3s"
ok "closes the connection after answering"
