# Stage 5: after the 200, relay bytes verbatim both ways until either side closes.

start_upstream echo
echo_port="$upstream_port"
start_upstream greet
greet_port="$upstream_port"

got="$(tunnel "127.0.0.1:$echo_port" echo)"
[[ "$got" == ok ]] || fail "1 MiB through the tunnel and back" "the same 1 MiB" "$got"
ok "relays 1 MiB both ways"

got="$(tunnel "127.0.0.1:$echo_port" early)"
[[ "$got" == ok ]] || fail "bytes sent together with the head" "relayed upstream" "$got"
ok "relays bytes that arrived with the head"

got="$(tunnel "127.0.0.1:$greet_port" greet)"
[[ "$got" == ok ]] || fail "upstream speaks first" "the client gets \"hello\" without sending anything" "$got"
ok "relays an upstream that speaks first"
