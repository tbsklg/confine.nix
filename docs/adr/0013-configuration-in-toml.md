# 13. An env is configured in confine.toml, not Nix code

Date: 2026-11-10
Status: Accepted

## Context

An env was a `flake.nix` that called `mkSandboxEnv`. Users had to write Nix to change a sandbox.

## Decision

One `confine.toml` per env; the template's `flake.nix` is never edited. confine owns the format, and the ports supply what can be named in it. The schema is built in the user's flake, so it matches the pinned versions. The config is resolved by pure functions over data; only a thin outer layer reads files or imports nixpkgs.

## Consequences

- Users write configuration, not code, with completion and checks from the schema.
- Adapters of their own are defined in the TOML, and packages outside nixpkgs come in through overlays.
- Anything beyond the TOML still works through `mkSandboxEnv`; see [confine in Nix](../nix.md).
