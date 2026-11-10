<pre>
╔═╗╔═╗╔╗╔╔╦╗╦ ╦
╔═╝╠═╣║║║ ║║╚╦╝
╚═╝╩ ╩╝╚╝═╩╝ ╩ .nix
</pre>

A sandbox for any command-line program on macOS: a coding agent, a test runner, an install script you don't trust.

You write a `zandy.toml`: which program runs, which tools it may use and which API it may reach. zandy starts the program under a Seatbelt profile that denies everything else. Your credentials stay outside the sandbox: a gateway adds an API's key, and a broker runs your tools with their own logins.

This reduces what the program can reach, but it is not a complete isolation boundary; see [Security limits](docs/README.md#security-limits). Apple Silicon only.

## Quickstart

This sets up Claude Code as the program. You need [Nix](https://nixos.org/download) with flakes, and a Claude login: run `claude` once outside zandy and log in.

```sh
mkdir ~/sandboxes && cd ~/sandboxes
nix flake init -t github:tbsklg/zandy.nix
nix profile add .
```

Keep this directory outside your projects, so the program can't change its own sandbox.

Then, in a project:

```sh
zandy-[name]
```

The env is configured in `~/sandboxes/zandy.toml`:

```toml
#:schema ./zandy.schema.json

name = "guenther"
preset = "claude"

[gateway.anthropicOauth]
```

After editing it, run `nix profile upgrade --all`. Until then, `zandy-[name]` keeps running the sandbox you installed.

## Documentation

- [Using zandy](docs/README.md): set up, reach an API, give the program tools, update, security limits, troubleshooting
- Reference: [zandy.toml](docs/zandy.toml.md), [zandy](docs/zandy.md), [zandy-client](docs/zandy-client.md), [debug log](docs/logging.md)
- [Upgrade notes](docs/upgrade.md): what to change after an update
- [zandy in Nix](docs/nix.md): your own presets, gateways and catalogs
- [Development](docs/development.md)

Presets, gateways and adapters come from [zandy-ports](https://github.com/tbsklg/zandy-ports).
