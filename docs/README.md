# Using zandy

- [Setup](#setup)
- [zandy.toml](#zandytoml)
- [Model backends](#model-backends)
- [Adapters](#adapters)
- [Inside the sandbox](#inside-the-sandbox)
- [Update](#update)
- [One env per project](#one-env-per-project)
- [Security limits](#security-limits)
- [Troubleshooting](#troubleshooting)

```
~/sandboxes/zandy.toml
   │ nix profile add
   ▼
zandy-claude ── starts gateway and broker, then the program
   │
   ▼
┌─ Seatbelt sandbox ───────────┐       outside, with your credentials
│                              │
│  program (claude, opencode)  │── HTTP, no key ──▶ gateway ── adds key ──▶ model API
│  zandy-client                │── JSON-RPC ──────▶ broker ─── runs ──────▶ glab, aws
│  project directory           │
│                              │
└──────────────────────────────┘
```

## Setup

Install Nix and enable flakes:

```sh
sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install)
mkdir -p ~/.config/nix && echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

Create an env in its own directory, outside your projects:

```sh
mkdir ~/sandboxes && cd ~/sandboxes
nix flake init -t github:tbsklg/zandy.nix
```

If you keep it in git, `git add` new files: a flake in a git repo only sees tracked files.

You edit `zandy.toml`. `flake.nix` stays as it is.

For completion and checks in your editor, build the schema:

```sh
nix build .#schema -o zandy.schema.json
```

Editors that read the `#:schema` line in `zandy.toml` pick it up. It lists exactly the presets, gateways and adapters your pinned versions have.

Install the env and run it from a project:

```sh
nix profile add ~/sandboxes       # older Nix: nix profile install
cd your-project
zandy-claude
```

`zandy-claude --zandy-config` shows the env's config, the broker methods and the Seatbelt profile without starting anything.

## zandy.toml

```toml
#:schema ./zandy.schema.json

name = "claude"
preset = "claude"
packages = ["ripgrep", "python3Packages.pytest"]

[gateway.bedrock]
profile = "acme-bedrock"
region = "eu-west-1"

[adapters.gitlab]
host = "gitlab.example.com"

[filesystem]
allowRead = ["~/notes"]
```

| Key | Meaning |
|---|---|
| `name` | The launcher becomes `zandy-<name>` |
| `preset` | The program to run: `claude` or `opencode` |
| `packages` | Extra programs the agent may run, by nixpkgs attribute |
| `[gateway.<name>]` | The [model backend](#model-backends), at most one |
| `[adapters.<name>]` | [Tools](#adapters) the broker runs for the agent, any number |
| `[define.adapters.<name>]` | [Your own adapter](#your-own-adapter) |
| `[filesystem]` | `allowRead`, `denyRead`, `allowWrite`, `denyWrite`: paths that are absolute, relative to the project, or start with `~` |

A gateway's or adapter's table holds its arguments; each port's README in [zandy-ports](https://github.com/tbsklg/zandy-ports) lists them. A mistake fails the build and names the key:

```
error: zandy.toml: preset "claud" unknown, one of: claude, opencode
```

The agent can read and write the project, except dot paths like `.git`, `.envrc` or `.vscode`, which your tools run on their own. To open one, e.g. a build cache:

```toml
[filesystem]
allowWrite = [".zig-cache"]
```

`allowWrite = [".git"]` lets the agent commit, but also opens `.git/config` and `.git/hooks`, which git runs as you.

## Model backends

The agent reaches its model through a gateway: a local proxy outside the sandbox that adds the credential and forwards to one fixed host. The agent never sees the key. Without a gateway, the agent reaches no model.

| Table | Backend | Needs |
|---|---|---|
| `[gateway.anthropicOauth]` | Claude subscription | your Claude login |
| `[gateway.anthropic]` | Anthropic API | the key, stored with `zandy-claude --zandy-secret anthropic-api-key` |
| `[gateway.bedrock]` | Amazon Bedrock | `profile` and `region`; `aws sso login --profile <profile>` |
| `[gateway.openai]` | OpenAI or compatible | the key, stored with `zandy-claude --zandy-secret openai-api-key` |

### Secrets

API keys live in zandy's own keychain, `~/.zandy/zandy.keychain-db`, outside the sandbox. Create it once; `security` asks for a password:

```sh
security create-keychain ~/.zandy/zandy.keychain-db
security set-keychain-settings ~/.zandy/zandy.keychain-db   # no auto-lock
```

Then store a key:

```sh
zandy-claude --zandy-secret anthropic-api-key
```

zandy asks for it without echo. At launch it hands the key to the gateway through a named pipe the sandbox can't open; it never touches the disk or an environment variable. After a reboot, macOS asks for the keychain password once.

## Adapters

An adapter lets the agent use a tool outside the sandbox, with your login. The agent lists and calls them with `zandy-client`:

```sh
zandy-client discover
zandy-client call issues.list '{"repo":"group/name"}'
```

The tool uses its own login, e.g. `glab auth login`, and keeps its credentials where it always does. The sandbox can't read them.

From zandy-ports:

```toml
[adapters.gitlab]
host = "gitlab.example.com"

[adapters.aws]
profiles = ["acme-dev"]
```

Both are **open**: they pass any arguments to the tool, so the agent can do whatever your login can, and can make the tool print its credential. Use them only with a login you would hand the agent directly. A narrow adapter of your own is safer.

### Your own adapter

Defining it enables it. This one lets the agent list and read GitLab issues, and nothing else:

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

| Field | Meaning |
|---|---|
| `package` | The tool, by nixpkgs attribute |
| `binary` | The program in the package, if not its main one |
| `env` | Env vars passed on from your shell. Not for secrets |
| `setEnv` | Env vars set for the tool |
| `capabilities` | The methods: `name`, `description`, `params`, `argv` |

A call runs like this:

- **params** are all required. A param is a `string` (the default) or a `choice` with `choices`. Values can't start with `-`, so they can't become options.
- **argv** elements are literals or a whole `{param}`; `"--repo={repo}"` is not substituted.
- **The tool runs** outside the sandbox, in the directory zandy started in. On exit 0 the agent gets stdout, otherwise stderr.

Whatever the command can do, the agent can do. Avoid tools that read the project, like `git` or `make`: the agent can write there, and the tool would run what the project configures, outside the sandbox.

## Inside the sandbox

The agent:

- can read and write the project, except dot paths and its own config that would run outside the sandbox: `.claude/` and `.mcp.json` for Claude Code, `.opencode/` and `opencode.json` for opencode
- can't write `flake.nix` and `flake.lock` in the project
- can run only programs from the env: no Homebrew, `/usr/bin` or downloaded binaries
- can connect only to port 443, DNS and the gateway
- can't read the keychain or `~/.zandy`

## Update

After editing `zandy.toml`, upgrade:

```sh
cd ~/sandboxes && nix profile upgrade --all
```

To pull the latest zandy and ports:

```sh
nix flake update && nix build .#schema -o zandy.schema.json && nix profile upgrade --all
```

`nix flake update ports` updates only the ports, `nix flake update zandy` only zandy.

`nix run ~/sandboxes` builds and runs the env as it is right now, without installing. Use it only to try out a change.

## One env per project

If a project needs its own toolchain, give it its own env with the tools in `packages`. Keep it outside the project, so the agent can't edit it:

```sh
mkdir ~/sandboxes/your-project && cd ~/sandboxes/your-project
nix flake init -t github:tbsklg/zandy.nix
# set name = "your-project" in zandy.toml
nix profile add .
cd ~/code/your-project && zandy-your-project
```

## Security limits

- **The sandbox is only as safe as its config.** The installed env is read-only, but the `zandy.toml` it was built from is not. Keep it outside every directory the agent can write to, review changes before upgrading, and run the installed `zandy-<name>`.
- **Environment variables are readable.** On macOS, any process can read the environment and arguments of every other process of the same user. Don't export secrets in the shell that starts zandy; use `--zandy-secret`.
- **Open adapters can print their credential.** `glab config get token`, `aws configure export-credentials`. Narrow adapters with `string` and `choice` params can't.
- **Tools keep credentials in your home.** glab in `~/.config/glab-cli`, aws in `~/.aws`. The sandbox can't read them; an `allowRead` for `~` or `~/.config` would hand them to the agent.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Operation not permitted` | Look up the blocked operation in the [debug log](logging.md) |
| git: `unable to access '~/.config/git/config'` | The config is a symlink, e.g. from home-manager. Add its target to `filesystem.allowRead` |
| claude tries to resolve AWS credentials | Remove `AWS_PROFILE` and `awsCredentialExport` from `~/.claude/settings.json` |
| `NameTooLong` at start | `$HOME` is too long: `~/.zandy/run/<pid>/broker.sock` must fit in 104 bytes |
| opencode: `operation not permitted mkdir '/var/folders/…'` | Start opencode once without zandy |
| Info lines on stderr at start | The gateway starting, e.g. `aws-sigv4-proxy`. Harmless |
| `zandy.toml: …` | The key it names is wrong; the schema in your editor shows it too |
