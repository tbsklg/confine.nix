# 12. No deny list for commands; an adapter that can print its credential is marked open

Date: 2026-11-09
Status: Accepted

## Context

Some tools print their own credential: `glab config get token`, `aws configure export-credentials`. A deny list for those commands was built.

## Decision

The deny list was reverted. An adapter that can print its credential is marked open; a narrow adapter offers only commands that can't.

## Consequences

- The docs say plainly which adapters hand the program a way to the credential.
- Rejected: a deny list, which treated a symptom and could never be complete.
