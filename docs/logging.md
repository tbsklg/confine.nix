# Debug log

confine logs to the macOS unified log under the subsystem `tbsklg.confine`, with one category per scope:

- `confine`: the session, the secrets loaded by name, the profile and how the program exited
- `broker`: each method the program called, with its outcome and duration, and for a failed command its exit status
- `gateway`: when the gateway started and stopped
- `proxy`: each connection the program made through the proxy: `CONNECT host:port 200` when the tunnel opens, and the bytes sent and received when it closes; `502` when the host can't be reached, and `400`, `405` or `431` for a request it can't relay. Only the request line is logged, never headers

Each operation the sandbox blocks is logged by macOS itself and tagged `confine-<pid>`, where `<pid>` is the session in the first `confine` line. The log holds no params, output or secret values, except the first stderr line of a failed command at `debug` level, which macOS doesn't keep on disk. The program can't read it. To see the full Seatbelt profile, run `confine-<name> --confine-config`.

Open a second terminal and run one of the following commands.

```sh
/usr/bin/log stream --level debug --predicate 'subsystem == "tbsklg.confine" OR (senderImagePath ENDSWITH "/Sandbox" AND eventMessage CONTAINS "\nconfine-")'
```

To follow one session:

```sh
/usr/bin/log stream --level debug --predicate '(subsystem == "tbsklg.confine" AND processID == <pid>) OR (senderImagePath ENDSWITH "/Sandbox" AND eventMessage MATCHES "(?s).*\nconfine-<pid>([^0-9].*)?")'
```

To follow one scope:

```sh
/usr/bin/log stream --level debug --predicate 'subsystem == "tbsklg.confine" AND category == "broker"'
```

Or look back at past sessions. macOS keeps everything except `debug` on disk for a few days:

```sh
/usr/bin/log show --last 1h --predicate 'subsystem == "tbsklg.confine" OR (senderImagePath ENDSWITH "/Sandbox" AND eventMessage CONTAINS "\nconfine-")'
```

## Where the program connects

The program's HTTPS goes through confine's proxy, which logs each tunnel under the `proxy` category. To follow it live:

```sh
/usr/bin/log stream --level debug --predicate 'subsystem == "tbsklg.confine" AND category == "proxy"'
```

To look back:

```sh
/usr/bin/log show --last 1h --predicate 'subsystem == "tbsklg.confine" AND category == "proxy"'
```

A tunnel is logged when it opens and when it closes:

```
CONNECT example.com:443 200, 33ms
CONNECT example.com:443 closed, sent 1234, received 56789 bytes, 3120ms
CONNECT no-such-host.invalid:443 502 UnknownHostName, 12ms
```

A tunnel still open when the session ends has only its first line. Calls through the gateway don't go through the proxy, and neither does a program that ignores `HTTPS_PROXY`, so they aren't in this log.
