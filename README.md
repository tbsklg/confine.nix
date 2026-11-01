# zandy.nix for macOS

**A sandbox for any program on macOS: declared in Nix, run by Zig, enforced by the macOS kernel.**

You declare in a flake what a program may touch. zandy starts it so it can't touch anything else:

- your project, not the rest of `$HOME`
- your flake's tools, not your machine's
- port 443 and the gateway, nothing else
- no credentials inside the sandbox

zandy comes with presets for Claude Code and opencode. Any other program, from a shell to a test runner, runs the same way with a [preset of your own](docs/README.md#your-own-preset).

## How it works

**Nix** declares the sandbox: the program, tools, files, network, adapters and the model backend. **zandy**, written in Zig, turns that into a Seatbelt profile and starts the program. Next to it run a broker, which calls your tools with your credentials, and a gateway, which adds the model's API key, both outside the sandbox. **Seatbelt**, the macOS kernel sandbox, enforces the profile, and the program can't loosen it.

The same flake always gives the same sandbox, the built sandbox is read-only, and it holds no secrets.

Apple Silicon only.

## Quickstart

With [Nix](https://nixos.org/download) and flakes enabled:

```sh
mkdir -p ~/.config/zandy && cd ~/.config/zandy
nix flake init -t github:tbsklg/zandy.nix
$EDITOR flake.nix
git init && git add -A
nix profile add ~/.config/zandy
```

Then start Claude Code in any project:

```sh
cd ~/code/widgets
zandy-claude
```

The template uses Bedrock and the GitLab and AWS adapters. To switch the model backend or set up secrets, see the [docs](docs/README.md).

## Update

After editing your flake:

```sh
nix profile upgrade --all
```

To also pull the latest zandy, run in the flake's directory:

```sh
nix flake update zandy && nix profile upgrade --all
```

If your flake is in a git repo, `git add` new files first. Flakes only see tracked files.

## Documentation

Everything else is in [docs](docs/README.md): configuration, your own presets, model backends, secrets, writing adapters, security limits and troubleshooting.
