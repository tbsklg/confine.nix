# Upgrade

Changes that need you to act, newest first. After each, run `nix flake update && nix profile upgrade --all` in your env's directory.

## 2026-11-11: zandy is now confine

zandy is renamed to confine, and zandy-ports to confine-ports: `confine-<name>`, `confine-client`, `confine.toml`, `~/.confine`, `--confine-secret` and `--confine-config`. The flakes are `github:tbsklg/confine.nix` and `github:tbsklg/confine-ports`.

To move an env:

```sh
mv ~/.zandy ~/.confine
mv ~/.confine/zandy.keychain-db ~/.confine/confine.keychain-db
cd ~/.confine/envs/<name>
mv zandy.toml confine.toml
sed -i "" s/zandy.schema/confine.schema/ confine.toml
rm flake.nix flake.lock zandy.schema.json
nix flake init -t github:tbsklg/confine.nix
nix build .#schema -o confine.schema.json
nix profile remove <name>                    # the old entry, as `nix profile list` names it
nix profile add .
```

Stored secrets are kept: confine finds them by service name. The log subsystem is `tbsklg.confine`.

## 2026-11-11: name the command

`zandy-<name>` no longer starts the preset's program. Name the command; without one, zandy opens a shell in the sandbox.

```sh
zandy-claude claude              # was: zandy-claude
zandy-claude claude -p "hi"      # was: zandy-claude -p "hi"
zandy-shell npm install          # was: zandy-shell -c 'npm install'
```

A preset no longer has `binary` or `args`. A preset of your own in Nix drops both; startup args go into a wrapper script in its `packages`.

## 2026-11-10: envs live in ~/.zandy/envs

An env's directory, with its `flake.nix` and `zandy.toml`, now belongs in `~/.zandy/envs/<name>/`. The sandbox can't read or write `~/.zandy`, so the program can't see or change its own config. Anywhere else, only `flake.nix`, `flake.lock` and `zandy.toml` in the project are protected.

To move an env, e.g. from `~/sandboxes`:

```sh
mkdir -p ~/.zandy/envs
mv ~/sandboxes ~/.zandy/envs/claude
nix profile remove sandboxes                 # the old entry, as `nix profile list` names it
nix profile add ~/.zandy/envs/claude
```

## 2026-11-10: configuration in zandy.toml

The env is configured in `zandy.toml`. `flake.nix` comes from the template and isn't edited. Presets, gateways and adapters moved to [zandy-ports](https://github.com/tbsklg/zandy-ports) and are named in the TOML.

Before, in `flake.nix`:

```nix
default = zandy.lib.mkSandboxEnv {
  inherit pkgs;
  name = "claude";
  preset = zandy.presets.claude;
  packages = [ pkgs.ripgrep ];
  gateway = zandy.gateways.bedrock { profile = "acme-bedrock"; region = "eu-west-1"; };
  adapters = [
    (zandy.adapters.gitlab { })
    (zandy.adapters.aws { profiles = [ "acme-dev" ]; })
  ];
};
```

After, in `zandy.toml`:

```toml
#:schema ./zandy.schema.json

name = "claude"
preset = "claude"
packages = ["ripgrep"]

[gateway.bedrock]
profile = "acme-bedrock"
region = "eu-west-1"

[adapters.gitlab]

[adapters.aws]
profiles = ["acme-dev"]
```

To migrate:

1. Move your old `flake.nix` aside and run `nix flake init -t github:tbsklg/zandy.nix` in the env's directory.
2. Write your settings into `zandy.toml`, as above. `filesystem` keeps its four lists, as a `[filesystem]` table.
3. Build the schema: `nix build .#schema -o zandy.schema.json`.
4. `nix profile upgrade --all`.

Behavior that changed:

- **Dot paths in the project are read-only,** at any depth: `.git`, `.envrc`, `.vscode` and the like. Before, only `.claude/` and `.mcp.json` were. To let the program write one, add it to `[filesystem] allowWrite`.
- **`zandy.toml` in the project is write-protected,** like `flake.nix` and `flake.lock`.
- **The gitlab and aws adapters are open,** as before. A narrow adapter of your own can be defined in `zandy.toml`; see [zandy.toml](zandy.toml.md).

If you need more than the TOML offers, keep using `mkSandboxEnv` in `flake.nix`, with `ports.presets`, `ports.gateways` and `ports.adapters` instead of `zandy.presets` and so on. See [zandy in Nix](nix.md).
