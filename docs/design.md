# Design

Why confine works the way it does.

## The sandbox is built outside what it confines

An env lives in `~/.confine/envs/<name>/`, not in the project. `nix profile add .` builds it into a read-only store path and installs it as `confine-<name>`. You take that sandbox to a project: `cd your-project && confine-<name> claude`.

confine doesn't read a config from the directory it starts in, because:

- **The program can write the project.** A policy kept there could be widened by the program it confines, and the change would apply on the next run.
- **A repo shouldn't choose its own sandbox.** A cloned repo or a pulled change would decide what the program may reach and which tools run with your logins.
- **Evaluating a flake runs its Nix code as you,** outside the sandbox.
- **A changed policy takes effect when you choose.** Editing `confine.toml` does nothing until `nix profile upgrade`, the point to review it.
- **It starts at once.** The installed env needs no evaluation or build at startup.

The policy is fixed before the program runs, and nothing the program can reach can widen it. This is the idea behind OpenBSD's `pledge` and `unveil`, applied from outside: you confine a program you don't trust, instead of a program confining itself.

You can still keep an env in a repo and `nix run .` it; see [Security limits](README.md#security-limits) for what that costs.

## One command per env

Each env is its own command, `confine-<name>`, not `confine <name>`. The name says which policy runs, it completes in the shell, and `nix profile` lists, upgrades and removes each env on its own.
