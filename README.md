# confine.nix

A sandbox for any command-line program on macOS: a coding agent, a test runner, an install script you don't trust.

You write a `confine.toml`: which program runs, which tools it may use and which API it may reach. confine starts the program under a Seatbelt profile that denies everything else. Your credentials stay outside the sandbox: a gateway adds an API's key, and a broker runs your tools with their own logins.

confine uses [Nix](https://nixos.org) to build the programs the sandbox may run and to keep them read-only.

This reduces what the program can reach, but it is not a complete isolation boundary; see [Security limits](docs/README.md#security-limits). Apple Silicon only.

## Quickstart

This sets up Claude Code as the program. You need [Nix](https://nixos.org/download) with flakes, and a Claude login: run `claude` once outside confine and log in.

```sh
mkdir -p ~/.confine/envs/claude && cd ~/.confine/envs/claude
nix flake init -t github:tbsklg/confine.nix
nix profile add .
```

Then, in a project:

```sh
confine-claude claude
```

The env is configured in `~/.confine/envs/claude/confine.toml`, where the sandbox can't read or change it:

```toml
#:schema ./confine.schema.json

name = "claude"
preset = "claude"

[gateway.anthropicOauth]
```

After editing it, run `nix profile upgrade --all`. Until then, `confine-claude` keeps using the sandbox you installed.

## Documentation

- [Using confine](docs/README.md): set up, reach an API, give the program tools, update, security limits, troubleshooting
- Reference: [confine.toml](docs/confine.toml.md), [confine](docs/confine.md), [confine-client](docs/confine-client.md), [debug log](docs/logging.md)
- [Upgrade notes](docs/upgrade.md): what to change after an update
- [confine in Nix](docs/nix.md): your own presets, gateways and catalogs
- [Development](docs/development.md)

Presets, gateways and adapters come from [confine-ports](https://github.com/tbsklg/confine-ports).
