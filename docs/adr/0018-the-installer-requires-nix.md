# 18. The installer requires Nix and doesn't install it

Date: 2026-11-26
Status: Accepted

## Context

Setting up an env took four commands of Nix plumbing. Installers commonly bundle everything in one `curl | sh`. OpenBSD installs software with `pkg_add`, never installs a second package manager, and leaves config to you. Apple names the command after the product and picks sensible defaults.

## Decision

Nix is required, as `pkg_add` is on OpenBSD; confine is installed with `nix profile install github:tbsklg/confine.nix`. `confine init [name]` creates `~/.confine/envs/<name>`, builds its schema and installs `confine-<name>`; the name defaults to `dev`. The template is embedded in the binary. `init` never overwrites an env, and removes what it created when a step fails.

## Consequences

- Getting started is two commands, and both name confine.
- `init` writes the env this binary was built with, and works offline up to the Nix build.
- Nix and flakes are a prerequisite the user sets up first.
- Rejected: a script that also installs Nix. Nix's installer changes the system, and running it from ours would make users trust a second source unseen.
