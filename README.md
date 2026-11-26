# confine.nix

[![tests](https://github.com/tbsklg/confine.nix/actions/workflows/sandbox.yml/badge.svg)](https://github.com/tbsklg/confine.nix/actions/workflows/sandbox.yml) [![version](https://img.shields.io/github/v/tag/tbsklg/confine.nix?sort=semver&label=version)](https://tbsklg.github.io/confine.nix/release-notes/)

Run any command-line program on macOS as a minimally privileged application, with capabilities you grant explicitly and declaratively: a coding agent, a test runner, an install script you don't trust.

You write a `confine.toml`: which program runs, which tools it may use and which API it may reach. confine starts the program under a Seatbelt profile that denies everything else. Your credentials stay outside the sandbox: a gateway adds an API's key, and a broker runs your tools with their own logins.

confine uses [Nix](https://nixos.org) to build the programs the sandbox may run and to keep them read-only.

This reduces what the program can reach, but it is not a complete isolation boundary; see [Security limits](docs/README.md#security-limits). Apple Silicon only.

## Quickstart

You need [Nix](https://nixos.org/download) with flakes.

```sh
nix profile add github:tbsklg/confine.nix    # older Nix: nix profile install
confine init
```

Then, in a project:

```sh
confine-dev
```

This opens a shell in the sandbox, with bash and coreutils. It can read and write the project, except dot paths, and can't read the rest of your home. Give it what your program needs in `~/.confine/envs/dev/confine.toml`, where the sandbox can't read or change it:

```toml
#:schema ./confine.schema.json

name = "dev"
preset = "shell"
packages = ["gnumake"]
```

After editing it, run `confine apply`. Until then, `confine-dev` keeps using the sandbox you installed. Then run the program: `confine-dev make test`.

For a coding agent, use its preset and a gateway for its API; see [Reach an API](docs/README.md#reach-an-api) and the [examples](docs/confine.toml.md#examples).

## Documentation

- [Using confine](docs/README.md): set up, reach an API, give the program tools, update, security limits, troubleshooting
- Reference: [confine.toml](docs/confine.toml.md), [confine](docs/confine.md), [confine-client](docs/confine-client.md), [debug log](docs/logging.md)
- [confine in Nix](docs/nix.md): your own presets, gateways and catalogs
- [Release notes](docs/release-notes/README.md): what changed in each version, and what to change after an update
- [Architecture decisions](docs/adr/README.md): why confine works the way it does
- [Development](docs/development.md)

Presets, gateways and adapters come from [confine-ports](https://github.com/tbsklg/confine-ports).
