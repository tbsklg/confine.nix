# confine.toml

The configuration of one confine env.

## Synopsis

```toml
#:schema ./confine.schema.json

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

`confine.toml` lies next to the env's `flake.nix`, in `~/.confine/envs/<name>/`, and is read when the env is built. Changes take effect at the next `nix profile upgrade`, never while an env runs.

Presets, gateways and adapters are named from the catalog, `ports.catalog` from [confine-ports](https://github.com/tbsklg/confine-ports) by default. Their tables hold their arguments; each port's README lists them.

- `name` (required): The env's name, `[a-z0-9-]+`. The launcher is `confine-<name>`.
- `preset` (required): The sandbox rules and packages a program needs, e.g. `claude`, `opencode` or `shell`. With the presets from confine-ports, the program can read the whole project and write it, except dot paths at any depth.
- `packages`: Extra programs the program may run, by nixpkgs attribute, e.g. `ripgrep` or `python3Packages.pytest`. A package that isn't in nixpkgs is added with an overlay in `flake.nix`; see [your own packages](nix.md#your-own-packages).
- `[gateway.<gateway>]`: A proxy that adds an API's credential outside the sandbox, at most one, e.g. `anthropicOauth`, `anthropic`, `bedrock` or `openai`.
- `[adapters.<adapter>]`: A tool the broker runs outside the sandbox, with your login, e.g. `gitlab` or `aws`. Any number.
- `[define.adapters.<name>]`: An adapter of your own. Defining it enables it; `<name>` must not also be in `[adapters]`.

  | Field | Meaning |
  |---|---|
  | `package` | The tool, by nixpkgs attribute (required) |
  | `binary` | The program in the package, if not its main program |
  | `env` | Env vars passed on from the shell that started confine. Not for secrets |
  | `setEnv` | Env vars set for the tool |
  | `capabilities` | The methods, called as `<name>.<method>` (required) |

  Each capability has `name`, `description`, `params` and `argv`. A param has `name`, `description`, and `kind`: `string` (the default) or `choice` with `choices`. Every param is required, and its value can't start with `-`. An `argv` element is a literal or a whole `{param}`; `"--repo={repo}"` is not substituted.

- `[filesystem]`: Paths the program may or may not read or write, beyond the preset's: `allowRead`, `denyRead`, `allowWrite`, `denyWrite`. A path is absolute, relative to the project, or starts with `~`.

An unknown key, name or argument fails the build and names it.

## Files

- `flake.nix`: Reads `confine.toml`. Not edited.
- `confine.schema.json`: Built with `nix build .#schema -o confine.schema.json`. Editors that read the `#:schema` line use it for completion and checks. It matches the pinned confine and ports; rebuild it after `nix flake update`.

## Examples

Claude Code with your Claude login:

```toml
name = "claude"
preset = "claude"

[gateway.anthropicOauth]
```

Any command, here an `npm install` you don't trust, with `confine-shell npm install --cache "$TMPDIR/npm"`:

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

[confine](confine.md), [confine-client](confine-client.md), [Using confine](README.md), [confine in Nix](nix.md)

## Caveats

The `gitlab` and `aws` adapters are open: they pass any arguments to the tool, so the program can make it print its credential. Use them only with a login you would hand the program directly. A defined adapter can't be open; a `list` param is refused.

`allowWrite = [".git"]` opens `.git/config` and `.git/hooks`, which git runs as you.

`allowRead` for `~` or `~/.config` hands the program the credentials your tools keep there.
