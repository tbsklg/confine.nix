<pre>
╔═╗╔═╗╔╗╔╔╦╗╦ ╦
╔═╝╠═╣║║║ ║║╚╦╝
╚═╝╩ ╩╝╚╝═╩╝ ╩ .nix
</pre>

A sandbox for agents and other CLI tools on macOS. The configuration is declared in Nix, the launcher is written in Zig, and the sandbox is enforced by Seatbelt, the macOS kernel sandbox.

A flake declares which files, programs and network destinations a program may use. zandy starts it under a profile that denies everything else, and keeps credentials outside the sandbox. This reduces what the program can reach, but it is not a complete isolation boundary; see [Security limits](docs/README.md#security-limits).

Presets for Claude Code and opencode are in [zandy-ports](https://github.com/tbsklg/zandy-ports). Any other program, from a shell to a test runner, runs the same way with a [preset of your own](docs/README.md#your-own-preset).

## How it works

**Nix** declares the sandbox: the program, tools, files, network, adapters and the model backend. **zandy**, written in Zig, turns that into a Seatbelt profile and starts the program. Next to it run a broker, which calls your tools with your credentials, and a gateway, which adds the model's API key, both outside the sandbox. **Seatbelt**, the macOS kernel sandbox, enforces the profile, and the program can't loosen it.

The same flake always gives the same sandbox, the built sandbox is read-only, and it holds no secrets.

Apple Silicon only.

## Quickstart

You need [Nix](https://nixos.org/download) with flakes and a Claude login: run `claude` once outside zandy and log in.

1. Create a flake in any directory:

   ```sh
   mkdir ~/sandboxes && cd ~/sandboxes
   nix flake init -t github:tbsklg/zandy.nix
   git init && git add -A
   ```

   The template plugs in [zandy-ports](https://github.com/tbsklg/zandy-ports) as the `ports` input, for the Claude Code preset and the Claude login gateway. Remove it if you bring your own preset and gateway.

2. Install it as `zandy-claude`:

   ```sh
   nix profile add ~/sandboxes
   ```

3. Run Claude Code in a project:

   ```sh
   cd your-project
   zandy-claude
   ```

   `zandy-claude` runs the sandbox as you installed it. A change to `~/sandboxes` takes effect only when you upgrade, so nothing can widen the sandbox behind your back. Use `nix run ~/sandboxes` only to try out a flake you're editing.

For other model backends, adapters and secrets, see the [docs](docs/README.md).

## Update

After editing your flake, review the change, then upgrade:

```sh
git diff && nix profile upgrade --all
```

To also pull the latest zandy and presets, run in the flake's directory:

```sh
nix flake update && nix profile upgrade --all
```

`nix flake update ports` updates only the presets, `nix flake update zandy` only the base.

If your flake is in a git repo, `git add` new files first. Flakes only see tracked files.

## Documentation

Everything else is in [docs](docs/README.md): configuration, your own presets, model backends, secrets, writing adapters, security limits and troubleshooting.
