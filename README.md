<pre>
╔═╗╔═╗╔╗╔╔╦╗╦ ╦
╔═╝╠═╣║║║ ║║╚╦╝
╚═╝╩ ╩╝╚╝═╩╝ ╩ .nix
</pre>

A sandbox for agents and other CLI tools on macOS. The configuration is a TOML file built by Nix, the launcher is written in Zig, and the sandbox is enforced by Seatbelt, the macOS kernel sandbox.

A `zandy.toml` declares which program runs, with which tools, model backend and extra paths. zandy starts it under a profile that denies everything else, and keeps credentials outside the sandbox. This reduces what the program can reach, but it is not a complete isolation boundary; see [Security limits](docs/README.md#security-limits).

Presets for Claude Code and opencode are in [zandy-ports](https://github.com/tbsklg/zandy-ports). Any other program, from a shell to a test runner, runs the same way with a [preset of your own](docs/README.md#your-own-preset).

## How it works

**`zandy.toml`** picks the program, tools, adapters and model backend; **Nix** builds the sandbox from it. **zandy**, written in Zig, turns that into a Seatbelt profile and starts the program. Next to it run a broker, which calls your tools with your credentials, and a gateway, which adds the model's API key, both outside the sandbox. **Seatbelt**, the macOS kernel sandbox, enforces the profile, and the program can't loosen it.

The same config always gives the same sandbox, the built sandbox is read-only, and it holds no secrets.

Apple Silicon only.

## Quickstart

You need [Nix](https://nixos.org/download) with flakes and a Claude login: run `claude` once outside zandy and log in.

1. Create an env in its own directory, outside your projects:

   ```sh
   mkdir ~/sandboxes && cd ~/sandboxes
   nix flake init -t github:tbsklg/zandy.nix
   git init && git add -A
   ```

   You configure it in `zandy.toml`. `flake.nix` stays as it is; it plugs in [zandy-ports](https://github.com/tbsklg/zandy-ports) for the Claude Code preset and the Claude login gateway.

   ```toml
   #:schema ./zandy.schema.json

   name = "claude"
   preset = "claude"

   [gateway.anthropicOauth]
   ```

2. For completion and checks in your editor, build the schema once:

   ```sh
   nix build .#schema -o zandy.schema.json
   ```

   Editors that read the `#:schema` line use it for completion and checks.

3. Install it as `zandy-claude`:

   ```sh
   nix profile add ~/sandboxes
   ```

4. Run Claude Code in a project:

   ```sh
   cd your-project
   zandy-claude
   ```

   `zandy-claude` runs the sandbox as you installed it. A change to `zandy.toml` takes effect only when you upgrade, so nothing can widen the sandbox behind your back.

For other model backends, adapters and secrets, see the [docs](docs/README.md).

## Update

After editing `zandy.toml`, review the change, then upgrade:

```sh
git diff && nix profile upgrade --all
```

To also pull the latest zandy and ports, run in the env's directory:

```sh
nix flake update && nix build .#schema -o zandy.schema.json && nix profile upgrade --all
```

`nix flake update ports` updates only the ports, `nix flake update zandy` only the base.

If your env is in a git repo, `git add` new files first. Flakes only see tracked files.

## Documentation

Everything else is in [docs](docs/README.md): configuration, your own presets, model backends, secrets, writing adapters, security limits and troubleshooting.
