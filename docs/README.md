# Using confine

- [Set up an env](#set-up-an-env)
- [Reach an API](#reach-an-api)
- [Give the program a tool](#give-the-program-a-tool)
- [Open a path](#open-a-path)
- [Change and update](#change-and-update)
- [One env per project](#one-env-per-project)
- [Security limits](#security-limits)
- [Troubleshooting](#troubleshooting)

Reference: [confine.toml](confine.toml.md), [confine](confine.md), [confine-client](confine-client.md), [debug log](logging.md), [upgrade notes](upgrade.md), [confine in Nix](nix.md)

```
~/.confine/envs/<name>/confine.toml
   │ nix profile add
   ▼
confine-<name> ── starts gateway and broker, then the program
   │
   ▼
┌─ Seatbelt sandbox ───────────┐       outside, with your credentials
│                              │
│  program                     │── HTTP, no key ──▶ gateway ── adds key ──▶ API
│  confine-client                │── JSON-RPC ──────▶ broker ─── runs ──────▶ glab, aws
│  project directory           │
│                              │
└──────────────────────────────┘
```

## Set up an env

Install Nix and enable flakes:

```sh
sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install)
mkdir -p ~/.config/nix && echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

Create the env in `~/.confine/envs/<name>/` and install it:

```sh
mkdir -p ~/.confine/envs/claude && cd ~/.confine/envs/claude
nix flake init -t github:tbsklg/confine.nix
nix build .#schema -o confine.schema.json
nix profile add .                  # older Nix: nix profile install
```

You edit `confine.toml`; `flake.nix` stays as it is. The sandbox can't read or write anything in `~/.confine`, so the program can't see or change its own config. The schema gives completion and checks in editors that read the `#:schema` line. If you keep the directory in git, `git add` new files: a flake in git only sees tracked files.

Run it from a project:

```sh
cd your-project
confine-claude claude
```

Without a command, `confine-claude` opens a shell in the sandbox. The template sets up Claude Code. For any other command, use the `shell` preset with what the command needs in `packages`, and run e.g. `confine-shell make test`. See [confine.toml](confine.toml.md#examples).

## Reach an API

A gateway lets the program reach one API without seeing its key: it adds the credential outside the sandbox. confine-ports has gateways for model APIs:

| In `confine.toml` | Backend | Needs |
|---|---|---|
| `[gateway.anthropicOauth]` | Claude subscription | your Claude login |
| `[gateway.anthropic]` | Anthropic API | the key in confine's keychain as `anthropic-api-key` |
| `[gateway.bedrock]` with `profile` and `region` | Amazon Bedrock | `aws sso login --profile <profile>` |
| `[gateway.openai]` | OpenAI or compatible | the key in confine's keychain as `openai-api-key` |

Optional arguments are in each gateway's README in [confine-ports](https://github.com/tbsklg/confine-ports).

To store a key, create confine's keychain once, then store it; confine asks for it without echo:

```sh
security create-keychain ~/.confine/confine.keychain-db
security set-keychain-settings ~/.confine/confine.keychain-db
confine-claude --confine-secret anthropic-api-key
```

## Give the program a tool

An adapter runs a tool outside the sandbox, with the tool's own login, e.g. `glab auth login`. The program calls it with [confine-client](confine-client.md).

Define a narrow one, which can do only what you list:

```toml
[define.adapters.issues]
package = "glab"
setEnv.GITLAB_HOST = "gitlab.example.com"

[[define.adapters.issues.capabilities]]
name = "list"
description = "List open issues of a project"
params = [{ name = "repo", description = "group/name" }]
argv = ["issue", "list", "--repo", "{repo}"]
```

The program then runs `confine-client call issues.list '{"repo":"group/name"}'`. All fields are in [confine.toml](confine.toml.md).

Or use an open one from confine-ports, which passes any arguments to the tool:

```toml
[adapters.gitlab]
host = "gitlab.example.com"

[adapters.aws]
profiles = ["acme-dev"]
```

An open adapter lets the program do whatever your login can, including printing its credential. Use it only with a login you would hand the program directly.

Avoid tools that read the project, like `git` or `make`: the program can write there, and the tool would run what the project configures, outside the sandbox.

## Open a path

With the presets from confine-ports, the program can read the whole project and write it, except dot paths like `.git`, `.envrc` or `.vscode`, which your tools run on their own. To open one, e.g. a build cache, or a path outside the project:

```toml
[filesystem]
allowWrite = [".zig-cache"]
allowRead = ["~/notes"]
```

`allowWrite = [".git"]` lets the program commit, but also opens `.git/config` and `.git/hooks`, which git runs as you.

## Change and update

After editing `confine.toml`, upgrade. Until then, the installed env runs unchanged:

```sh
cd ~/.confine/envs/claude && nix profile upgrade --all
```

To pull the latest confine and ports, then check the [upgrade notes](upgrade.md):

```sh
nix flake update && nix build .#schema -o confine.schema.json && nix profile upgrade --all
```

`nix run ~/.confine/envs/claude` builds and runs the env as it is right now, without installing. Use it only to try out a change.

## One env per project

If a project needs its own toolchain, give it its own env with the tools in `packages`:

```sh
mkdir -p ~/.confine/envs/your-project && cd ~/.confine/envs/your-project
nix flake init -t github:tbsklg/confine.nix
# set name = "your-project" and packages in confine.toml
nix profile add .
cd ~/code/your-project && confine-your-project
```

## Security limits

- **The sandbox is only as safe as its config.** The installed env is read-only, but its `confine.toml` is not. In `~/.confine/envs/` the program can't reach it. Elsewhere, keep it where the program can't write; confine write-protects `flake.nix`, `flake.lock` and `confine.toml` only in the project. Review changes before upgrading, and run the installed `confine-<name>`.
- **Environment variables are readable.** On macOS, any process can read the environment and arguments of every other process of the same user. Don't export secrets in the shell that starts confine; use `--confine-secret`.
- **Open adapters can print their credential:** `glab config get token`, `aws configure export-credentials`. Narrow adapters can't.
- **Tools keep credentials in your home:** glab in `~/.config/glab-cli`, aws in `~/.aws`. The sandbox can't read them; an `allowRead` for `~` or `~/.config` would hand them to the program.
- **Tools run in the project directory.** The program can write there, and a tool outside the sandbox may read config from it: e.g. a planted git repo with `core.fsmonitor` runs a command as you when an adapter calls `git`.
- **The program shares your terminal.** confine doesn't start it in a separate session, so a preset that allows `file-ioctl` may let it type into your shell.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `confine.toml: …` at build | The key it names is wrong; the schema shows it in your editor too |
| `Operation not permitted` | Look up the blocked operation in the [debug log](logging.md) |
| git: `unable to access '~/.config/git/config'` | The config is a symlink, e.g. from home-manager. Add its target to `allowRead` |
| `NameTooLong` at start | `$HOME` is too long: `~/.confine/run/<pid>/broker.sock` must fit in 104 bytes |
| Info lines on stderr at start | The gateway starting, e.g. `aws-sigv4-proxy`. Harmless |
| A problem with one program | See its preset's README in [confine-ports](https://github.com/tbsklg/confine-ports) |
