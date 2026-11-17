# Stage 7: a head over 8 KiB gets 431; a client that doesn't finish its head within 10 s is hung up on.

want="HTTP/1.1 431 Request Header Fields Too Large"
padding="$(head -c 9000 /dev/zero | tr '\0' a)"
got="$({ printf 'CONNECT 127.0.0.1:1 HTTP/1.1\r\nX-Padding: %s\r\n\r\n' "$padding"; sleep 1; } \
  | nc -w 2 127.0.0.1 "$PORT" 2>/dev/null | head -1 | tr -d '\r')"
[[ "$got" == "$want" ]] || fail "a 9000 byte header" "$want" "${got:-no response}"
ok "answers an oversized head with 431"

dim "  (waiting for the head timeout)"
got="$(tunnel "127.0.0.1:1" stall)"
[[ "$got" =~ ^[0-9]+$ ]] && (( got >= 9 && got <= 12 )) \
  || fail "a client that stops mid-head" "hung up on after about 10s" "${got}"
ok "hangs up on a client that stops mid-head after ${got}s"

start_upstream echo
got="$(tunnel "127.0.0.1:$upstream_port" late)"
[[ "$got" == ok ]] || fail "the head timeout ends with the head" "an open tunnel outlives 10s" "$got"
ok "doesn't time out a tunnel once its head is in"
