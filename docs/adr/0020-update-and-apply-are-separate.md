# 20. Update and apply are separate commands

Date: 2026-11-26
Status: Accepted

## Context

Nix can't build newer versions without the current `confine.toml`, so one command could pull versions and apply a policy edit at once.

## Decision

`confine update` pulls newer confine and ports; `confine apply` applies `confine.toml`. `update` refuses while the config has changes that aren't applied, as OpenBSD keeps `pkg_add -u` apart from applying `/etc`.

## Consequences

- A policy change takes effect only when you apply it, as in [14](0014-the-sandbox-is-built-outside-what-it-confines.md).
- Two commands to learn instead of one.
