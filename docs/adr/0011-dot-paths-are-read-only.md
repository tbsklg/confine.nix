# 11. Dot paths in the project are read-only

Date: 2026-11-09
Status: Accepted

## Context

Tools run files like `.envrc`, `.git/hooks` and `.vscode` settings on their own, outside the sandbox. A program that writes one gets code run as you.

## Decision

Dot paths in the project are read-only at any depth. `[filesystem] allowWrite` opens one where needed.

## Consequences

- A confined program can't plant code that runs outside the sandbox.
- Some workflows need an explicit `allowWrite`, like `.git` to commit, which also opens `.git/config` and `.git/hooks`.
