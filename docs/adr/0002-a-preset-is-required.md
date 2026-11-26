# 2. A preset is required; there is no raw mode

Date: 2026-09-25
Status: Accepted

## Context

confine grew from one agent to any command-line program. Each program needs its own mach lookups, IPC and system operations to start at all, and no user can know which.

## Decision

Every env names a preset: the rules a kind of program needs. There is no mode that runs a program without one.

## Consequences

- A program crashes or hangs less often under a fresh config, because its preset already knows what it needs.
- Supporting a new kind of program means writing a preset.
- Rejected: a raw mode with no preset; without one the program crashes or hangs, and the user can't tell why.
