# 7. Secrets travel through named pipes, never the environment or argv

Date: 2026-10-29
Status: Accepted

## Context

On macOS any process can read the environment and arguments of every other process of the same user, and Seatbelt can't block it.

## Decision

Secrets live in a keychain of confine's own and reach the gateway and adapters through `0600` named pipes, once per run. Nothing lands on disk.

## Consequences

- A secret is never visible in `ps` or the environment.
- Creating the keychain stays two documented `security` commands. Storing a secret gets a command, `--confine-secret`, because it keeps the value out of argv and shell history.
- Rejected: an encrypted file, since the consumer needs the plaintext anyway.
