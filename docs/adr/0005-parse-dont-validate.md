# 5. Inputs are parsed once, at the boundary

Date: 2026-10-26
Status: Accepted

## Context

confine reads arguments, a manifest, JSON-RPC calls and secrets. Checking a value in one place and using it as a plain string elsewhere lets an unchecked value slip through.

## Decision

Parse, don't validate: every input is parsed into a precise type once, where it enters confine. Code past the boundary takes the typed value.

## Consequences

- A value that reaches the sandbox, the broker or a gateway has already been checked.
- More types to define up front.
