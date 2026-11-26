# 4. A broker runs tools outside the sandbox, without a shell

Date: 2026-10-26
Status: Accepted

## Context

A program needs tools like `glab` or `aws`, and those tools need your login. Denying `~/.aws` only hides a secret the program might still need.

## Decision

The program asks over a Unix socket, through `confine-client`, and the broker runs the tool outside the sandbox, with your login. There is no shell in the broker: each placeholder is a whole argv entry, and a value can't start with `-`.

## Consequences

- The credential never enters the sandbox; the broker removes the need for it.
- The broker doesn't judge commands. The token's scopes and the IAM role decide what a call may do.
- An adapter has to describe each command it offers.
