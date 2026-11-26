# 15. One command per env

Date: 2026-11-10
Status: Accepted

## Context

There can be several envs, one per toolchain or project.

## Decision

Each env is its own command, `confine-<name>`, not `confine <name>`.

## Consequences

- The name says which policy runs, and it completes in the shell.
- `nix profile` lists, upgrades and removes each env on its own.
