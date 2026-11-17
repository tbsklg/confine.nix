# Stage 3: CONNECT host:port — a malformed target gets 400 Bad Request.

connect_status() {
  { printf 'CONNECT %s HTTP/1.1\r\nHost: %s\r\n\r\n' "$1" "$1"; sleep 1; } \
    | nc -w 2 127.0.0.1 "$PORT" 2>/dev/null | head -1 | tr -d '\r'
}

want="HTTP/1.1 400 Bad Request"
for target in "example.com" "example.com:" ":443" "example.com:https" "example.com:65536" "example.com:-1" "[::1]" "[::1:443"; do
  got="$(connect_status "$target")"
  [[ "$got" == "$want" ]] || fail "CONNECT $target is malformed" "$want" "${got:-no response}"
done
ok "answers malformed targets with 400"

for target in "localhost:1" "127.0.0.1:1" "[::1]:1" "localhost:65535"; do
  got="$(connect_status "$target")"
  [[ "$got" != "$want" ]] || fail "CONNECT $target is valid" "anything but 400" "$got"
done
ok "accepts host:port, IPv4 and [IPv6]:port"
