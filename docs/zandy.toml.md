# zandy.toml

The configuration of one zandy env.

## Synopsis

```toml
#:schema ./zandy.schema.json

name = "<name>"
preset = "<preset>"
packages = ["<attribute>", …]

[gateway.<gateway>]
<arg> = <value>

[adapters.<adapter>]
<arg> = <value>

[define.adapters.<name>]
package = "<attribute>"
[[define.adapters.<name>.capabilities]]
name = "<method>"
description = "<text>"
params = [{ name = "<param>", description = "<text>" }, …]
argv = ["<literal or {param}>", …]

[filesystem]
allowRead = ["<path>", …]
denyRead = ["<path>", …]
allowWrite = ["<path>", …]
denyWrite = ["<path>", …]
```

## Description

`zandy.toml` lies next to the env's `flake.nix` and is read when the env is built. Changes take effect at the next `nix profile upgrade`, never while an env runs.

Presets, gateways and adapters are named from the catalog, `ports.catalog` from [zandy-ports](https://github.com/tbsklg/zandy-ports) by default. Their tables hold their arguments; each port's README lists them.

- `name` (required): The env's name, `[a-z0-9-]+`. The launcher is `zandy-<name>`.
- `preset` (required): The program to run, with the sandbox rules it needs, e.g. `claude`, `opencode` or `shell`. With the presets from zandy-ports, the program can read the whole project and write it, except dot paths at any depth.
- `packages`: Extra programs the program may run, by nixpkgs attribute, e.g. `ripgrep` or `python3Packages.pytest`.
- `[gateway.<gateway>]`: A proxy that adds an API's credential outside the sandbox, at most one, e.g. `anthropicOauth`, `anthropic`, `bedrock` or `openai`.
- `[adapters.<adapter>]`: A tool the broker runs outside the sandbox, with your login, e.g. `gitlab` or `aws`. Any number.
- `[define.adapters.<name>]`: An adapter of your own. Defining it enables it; `<name>` must not also be in `[adapters]`.

  | Field | Meaning |
  |---|---|
  | `package` | The tool, by nixpkgs attribute (required) |
  | `binary` | The program in the package, if not its main program |
  | `env` | Env vars passed on from the shell that started zandy. Not for secrets |
  | `setEnv` | Env vars set for the tool |
  | `capabilities` | The methods, called as `<name>.<method>` (required) |

  Each capability has `name`, `description`, `params` and `argv`. A param has `name`, `description`, and `kind`: `string` (the default) or `choice` with `choices`. Every param is required, and its value can't start with `-`. An `argv` element is a literal or a whole `{param}`; `"--repo={repo}"` is not substituted.

- `[filesystem]`: Paths the program may or may not read or write, beyond the preset's: `allowRead`, `denyRead`, `allowWrite`, `denyWrite`. A path is absolute, relative to the project, or starts with `~`.

An unknown key, name or argument fails the build and names it.

## Files

- `flake.nix`: Reads `zandy.toml`. Not edited.
- `zandy.schema.json`: Built with `nix build .#schema -o zandy.schema.json`. Editors that read the `#:schema` line use it for completion and checks. It matches the pinned zandy and ports; rebuild it after `nix flake update`.

## Examples

Claude Code with your Claude login:

```toml
name = "claude"
preset = "claude"

[gateway.anthropicOauth]
```

Any command, here an `npm install` you don't trust, with `zandy-shell -c 'npm install --cache "$TMPDIR/npm"'`:

```toml
name = "shell"
preset = "shell"
packages = ["nodejs"]
```

Claude Code on Bedrock, with ripgrep, the GitLab adapter and a writable build cache:

```toml
name = "work"
preset = "claude"
packages = ["ripgrep"]

[gateway.bedrock]
profile = "acme-bedrock"
region = "eu-west-1"

[adapters.gitlab]
host = "gitlab.example.com"

[filesystem]
allowWrite = [".zig-cache"]
```

An adapter that lists and shows GitLab issues, and nothing else:

```toml
[define.adapters.issues]
package = "glab"
setEnv.GITLAB_HOST = "gitlab.example.com"

[[define.adapters.issues.capabilities]]
name = "list"
description = "List open issues of a project"
params = [{ name = "repo", description = "group/name" }]
argv = ["issue", "list", "--repo", "{repo}"]

[[define.adapters.issues.capabilities]]
name = "view"
description = "Show one issue"
params = [{ name = "repo", description = "group/name" }, { name = "id", description = "Issue number" }]
argv = ["issue", "view", "{id}", "--repo", "{repo}"]
```

## See also

[zandy](zandy.md), [zandy-client](zandy-client.md), [Using zandy](README.md), [zandy in Nix](nix.md)

## Caveats

The `gitlab` and `aws` adapters are open: they pass any arguments to the tool, so the program can make it print its credential. Use them only with a login you would hand the program directly. A defined adapter can't be open; a `list` param is refused.

`allowWrite = [".git"]` opens `.git/config` and `.git/hooks`, which git runs as you.

`allowRead` for `~` or `~/.config` hands the program the credentials your tools keep there.
