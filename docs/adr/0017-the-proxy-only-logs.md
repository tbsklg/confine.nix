# 17. The proxy only logs

Date: 2026-11-17
Status: Accepted

## Context

Nobody saw where the program connected.

## Decision

confine runs a forward proxy outside the sandbox, set in `HTTPS_PROXY`, and logs each tunnel's host, port, bytes and duration under the `proxy` category. It relays `CONNECT` tunnels without decrypting them. It has no allow or block list, and the preset's network rules are unchanged.

## Consequences

- Where the program goes is visible in the unified log.
- The proxy decides nothing, so it can't become a second, weaker network policy next to the preset's.
