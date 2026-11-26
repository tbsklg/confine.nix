# 3. An env is a Nix derivation, and only its closure runs

Date: 2026-10-26
Status: Accepted

## Context

A sandbox configured at run time can differ from one run to the next, and the programs it allows can be anything on the machine.

## Decision

An env is a Nix derivation built by `mkSandboxEnv`. The same declaration always gives the same sandbox, and the env is a read-only value in the Nix store. Only programs in its closure may be executed.

## Consequences

- What runs is fixed and reviewable before the program starts.
- confine requires Nix; see [18](0018-the-installer-requires-nix.md).
- Changing an env means rebuilding it.
