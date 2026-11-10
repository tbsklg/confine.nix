<pre>
╔═╗╔═╗╔╗╔╔╦╗╦ ╦
╔═╝╠═╣║║║ ║║╚╦╝
╚═╝╩ ╩╝╚╝═╩╝ ╩ .nix
</pre>

A sandbox for agents and other CLI tools on macOS.

You write a `zandy.toml`: which program runs, which tools it may use and which model it talks to. zandy starts the program under a Seatbelt profile that denies everything else. Your credentials stay outside the sandbox: a gateway adds the model's key, and a broker runs your tools with their own logins.

This reduces what the program can reach, but it is not a complete isolation boundary; see [Security limits](docs/README.md#security-limits). Apple Silicon only.

## Quickstart

You need [Nix](https://nixos.org/download) with flakes, and a Claude login: run `claude` once outside zandy and log in.

```sh
nix flake init -t github:tbsklg/zandy.nix
nix profile add .
```

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

After editing it, run `nix profile upgrade --all`. Until then, `zandy-claude` keeps running the sandbox you installed.

## Documentation

- [Using zandy](docs/README.md): configuration, model backends, adapters, updates, security limits, troubleshooting
- [zandy in Nix](docs/nix.md): your own presets, gateways and catalogs
- [Debug log](docs/logging.md)
- [Development](docs/development.md)

Presets, gateways and adapters come from [zandy-ports](https://github.com/tbsklg/zandy-ports).
