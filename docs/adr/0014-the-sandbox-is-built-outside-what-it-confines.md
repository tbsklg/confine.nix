# 14. The sandbox is built outside what it confines

Date: 2026-11-10
Status: Accepted

## Context

A sandbox's policy has to live somewhere. The obvious place, the project, is the one place the confined program can write.

## Decision

An env lives in `~/.confine/envs/<name>/`, not in the project. It is built into a read-only store path and installed as `confine-<name>`, and you take that sandbox to a project. confine doesn't read a config from the directory it starts in, and the sandbox can't read or write `~/.confine`.

## Consequences

- The program can't widen its own policy for the next run.
- A cloned repo or a pulled change can't choose its own sandbox, or which tools run with your logins.
- No flake from the project is evaluated, which would run its Nix code as you, outside the sandbox.
- A changed policy takes effect when you choose: editing `confine.toml` does nothing until `nix profile upgrade`, the point to review it.
- It starts at once: the installed env needs no evaluation or build.
- This is the idea behind OpenBSD's `pledge` and `unveil`, applied from outside: you confine a program you don't trust, instead of a program confining itself.
- An env can still be kept in a repo and run with `nix run .`; see [Security limits](../README.md#security-limits) for what that costs.
