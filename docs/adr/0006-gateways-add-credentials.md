# 6. Gateways add credentials; confine speaks no HTTP

Date: 2026-10-29
Status: Accepted

## Context

The program has to reach a model API, and the API needs a key. A key in the sandbox can be read and sent anywhere.

## Decision

A gateway is a local proxy outside the sandbox. It adds the API key and forwards to one fixed host. The proxy is a ready-made program, like Caddy or `aws-sigv4-proxy`; confine only starts it.

## Consequences

- The program reaches the API without ever holding the key.
- confine has no HTTP code to get wrong; each gateway is an existing, tested program.
- Each new API needs a gateway definition in confine-ports.
