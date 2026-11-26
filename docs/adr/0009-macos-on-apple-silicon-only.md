# 9. macOS on Apple Silicon only

Date: 2026-10-29
Status: Accepted

## Context

confine rests on Seatbelt and the keychain.

## Decision

confine supports macOS on Apple Silicon only, by design.

## Consequences

- Every mechanism is native; there is no portability layer.
- Linux would need other mechanisms, like Landlock and namespaces: a different program, not a port.
