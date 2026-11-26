# 1. The Seatbelt profile is built as typed data and denies by default

Date: 2026-06-17
Status: Accepted

## Context

confine started as a wrapper that ran opencode under `sandbox-exec` with a hand-written `opencode.sb`. A coding agent should not read what it doesn't need, like `.env`, `~/.ssh` or `~/.aws`. A profile written as text is hard to compose from parts, and a mistake shows up only when the sandbox refuses to start or lets too much through.

## Decision

confine builds the SBPL profile itself, as typed data, and applies it in-process with `sandbox_init_with_parameters` instead of `sandbox-exec`. Everything is denied by default; each rule allows one thing.

## Consequences

- Profiles are composed from presets and the env's config, and tested as data.
- confine depends on Seatbelt, which Apple uses for its own apps but doesn't document as an interface for others; a macOS release can change it.
- Rejected: profile files on disk, which can't be composed or checked before they run.
