# zandy.nix docs

- [Architecture](#architecture)
- [Install](#install)
- [Per project](#per-project)
- [Configuration](#configuration)
- [Your own preset](#your-own-preset)
- [Model backends](#model-backends)
- [Secrets](#secrets)
- [Inside the sandbox](#inside-the-sandbox)
- [Write your own adapter](#write-your-own-adapter)
- [Debug log](logging.md)
- [Security limits](#security-limits)
- [Troubleshooting](#troubleshooting)
- [Development](#development)

## Architecture

```
flake.nix
   │ nix build
   ▼
env, bin/zandy-<name>
   │
   ▼
zandy ── starts gateway and broker, then sandbox_init + exec
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

zandy is the base: the launcher, the broker, `mkSandboxEnv` and `mkGateway`. Presets for programs like Claude Code and opencode and gateways for model backends live in [zandy-ports](https://github.com/tbsklg/zandy-ports) and are updated on their own.

Nix builds the env and the launcher. zandy reads the env, starts the gateway and the broker, and runs the program under a Seatbelt profile. Credentials stay outside: the gateway adds the model key, and the broker runs your tools with their own logins. The sequence of a launch is in [runtime-flow.puml](runtime-flow.puml).

## Install

zandy runs on macOS on Apple Silicon. Everything it needs comes from Nix: Zig, the program you run, your adapters' tools and the gateway proxies.

Install Nix and enable flakes:

```sh
sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install)
mkdir -p ~/.config/nix && echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

Create your env from the template:

```sh
mkdir ~/sandboxes && cd ~/sandboxes
nix flake init -t github:tbsklg/zandy.nix
```

The template has two inputs: `zandy`, the base, and `ports`, [zandy-ports](https://github.com/tbsklg/zandy-ports) with its presets and gateways. `ports` follows your `zandy`, so both use the same base. Drop `ports` if you write your own preset and gateway.

Edit `flake.nix`: pick a [model backend](#model-backends) and add any adapters you need. Then install it:

```sh
git init && git add -A            # flakes only see files git tracks
nix profile add ~/sandboxes       # older Nix: nix profile install
```

Before the first run you need:

- a [model backend](#model-backends), e.g. your Claude login
- a login for your adapters' tools, e.g. `glab auth login` for glab

Start the agent from a project directory:

```sh
cd your-project
zandy-claude
```

To see the env's config, the broker methods and the Seatbelt profile without starting the agent, run `zandy-claude --zandy-config`.

After changing `flake.nix`, review the change, then upgrade. Until then, `zandy-claude` keeps running the sandbox you installed:

```sh
git diff && git add -A && nix flake update && nix profile upgrade --all
```

Use `nix run ~/sandboxes` only to try out a flake you're editing. It builds the sandbox from the flake as it is right now, on every start.

## Per project

If a project needs its own toolchain, give it its own env and add the tools to `packages`.

Keep that flake in its own directory outside the project. Then it doesn't have to be committed, and the agent can't edit it. Give it its own `name`, install it, and start it from the project root:

```sh
nix profile add ~/sandboxes/your-project
cd your-project
zandy-your-project
```

## Configuration

```nix
zandy.lib.mkSandboxEnv {
  inherit pkgs;
  name = "claude";
  preset = ports.presets.claude;
  packages = [ pkgs.ripgrep ];
  gateway = ports.gateways.bedrock { profile = "acme-bedrock"; region = "eu-west-1"; };
  adapters = [ say ];
  filesystem.allowRead = [ "~/notes" ];
}
```

| Option | What it sets |
|---|---|
| `name` | The env's name. The launcher is called `zandy-<name>` |
| `preset` | The program to run and the sandbox rules it needs: one from [zandy-ports](https://github.com/tbsklg/zandy-ports), e.g. `ports.presets.claude`, or [your own](#your-own-preset) |
| `packages` | Extra programs the agent may run |
| `gateway` | The [model backend](#model-backends) |
| `adapters` | Tools the broker runs outside the sandbox for the agent, e.g. [your own](#write-your-own-adapter) |
| `filesystem` | Extra paths the agent may read or write, or may not |

A mistyped or unknown option fails at build time. For all options with their types and defaults, see [options.md](options.md). It is generated with `nix build .#options-doc`.

## Your own preset

A preset is a plain attrset: the program to start, the packages it needs, the env vars it gets and its Seatbelt rules. Any program can be one.

A shell with Claude Code's rules, to try things inside the sandbox by hand:

```nix
packages.aarch64-darwin.shell = zandy.lib.mkSandboxEnv {
  inherit pkgs;
  name = "shell";
  preset = ports.presets.claude // { name = "shell"; binary = "bash"; args = [ ]; };
};
```

```sh
nix run ~/sandboxes#shell
```

To change the rules, extend a preset's list:

```nix
rules = ports.presets.claude.rules ++ [
  { action = "deny"; operation = "file_read_data"; filter = { subpath = { literal = "/private/var/folders"; }; }; }
];
```

Or filter it:

```nix
rules = builtins.filter (rule: rule.operation != "sysctl_all") ports.presets.claude.rules;
```

Or write one from scratch. This one runs curl, which may reach HTTPS hosts and nothing else, not even your project:

```nix
packages.aarch64-darwin.curl = zandy.lib.mkSandboxEnv {
  inherit pkgs;
  name = "curl";
  preset = {
    name = "curl";
    binary = "curl";
    args = [ "--cacert" "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" ];
    packages = pkgs: [ pkgs.curl pkgs.cacert ];
    rules = [
      { action = "allow"; operation = "file_read_metadata"; }
      { action = "allow"; operation = "file_map_executable"; }
      { action = "allow"; operation = "sysctl_all"; }
      { action = "allow"; operation = "network_outbound"; filter = { remote_tcp = "*:443"; }; }
      { action = "allow"; operation = "network_outbound"; filter = { remote_unix_socket = { literal = "/private/var/run/mDNSResponder"; }; }; }
    ];
  };
};
```

```sh
nix run ~/sandboxes#curl -- https://example.com
```

Start with few rules and add what the [debug log](logging.md) shows as denied.

The sandbox denies everything that no rule allows. zandy adds rules in this order, and a later rule wins:

1. the preset's `rules`
2. read and execute for the env's store paths
3. `filesystem` from your flake
4. zandy's own denies: `flake.nix`, `flake.lock`, `.envrc`, `.git/config`, `.git/hooks`, `~/.zandy` and the keychain

So no preset can open what zandy protects. The operations and filters a rule may use are in [src/sandbox/sbpl.zig](../src/sandbox/sbpl.zig).

## Model backends

The agent reaches its model through a gateway. That's a local proxy that zandy starts outside the sandbox. It adds the credentials and forwards requests to one fixed upstream. The sandbox can reach the gateway's port, but never sees the key.

You pick one gateway per env. Without one, the agent reaches no model through zandy.

Gateways for Bedrock, the Anthropic API, a Claude subscription and OpenAI are in [zandy-ports](https://github.com/tbsklg/zandy-ports#model-backends), e.g. `gateway = ports.gateways.anthropicOauth { };`.

### Your own gateway

`zandy.lib.mkGateway` builds a gateway on Caddy. This one sends every request to `api.anthropic.com` with an API key from zandy's keychain:

```nix
gateway = zandy.lib.mkGateway {
  name = "anthropic";
  host = "api.anthropic.com";
  headers.X-Api-Key = [ "{env.ANTHROPIC_API_KEY}" ];
  secrets.ANTHROPIC_API_KEY.keychain = { service = "anthropic-api-key"; };
};
```

| Field | Meaning |
|---|---|
| `name` | Picks the preset's `gatewayEnv` entry |
| `host` | The one upstream, reached over HTTPS on port 443 |
| `headers` | Request headers to set. `{env.NAME}` is replaced with the secret `NAME` |
| `addHeaders` | Request headers to add next to the client's own |
| `secrets` | Where each secret lives, as for [adapters](#fields) |

The gateway drops the client's own `Authorization` and `X-Api-Key` headers, so the agent can't send credentials of its own.

A gateway that isn't Caddy is an attrset with `name`, an `argv` in which `{port}` is replaced with the port zandy picks, and optionally `env`, `secrets` and `files`. The Bedrock gateway in zandy-ports is one.

## Secrets

Adapters use the tool's own login, e.g. `aws sso login` for aws or `glab auth login` for glab. The tool keeps its credentials where it always does, and the sandbox can't read them. You chose the tool, so how it stores its token is up to you and the tool.

zandy only keeps the secrets of its own gateways, in its own keychain, `~/.zandy/zandy.keychain-db`, outside the sandbox.

Create the keychain once. `security` asks you for a password for it:

```sh
security create-keychain ~/.zandy/zandy.keychain-db
security set-keychain-settings ~/.zandy/zandy.keychain-db   # no auto-lock
```

Store a secret:

```sh
zandy-claude --zandy-secret anthropic-api-key
```

zandy asks for the secret without echoing it, so it doesn't end up in your shell history. The keychain doesn't lock on its own. After a reboot, macOS asks for its password the first time zandy reads it.

At launch, zandy reads the secrets that the gateway needs. They reach the proxy through named pipes in a private directory that the sandbox can't open. They never touch the disk and are never passed through an environment variable.

Don't export secrets in the shell that starts zandy. See [Security limits](#security-limits) for why.

## Inside the sandbox

The agent:

- can write to the project directory, except `flake.nix`, `flake.lock`, `.envrc`, `.git/config` and `.git/hooks`, and the agent's own project config, which would run outside the sandbox the next time you start the agent without zandy: `.claude/` and `.mcp.json` for Claude Code, `.opencode/` and `opencode.json` for opencode
- can run only programs from the env, so no Homebrew, `/usr/bin` or downloaded binaries
- can connect only to port 443, DNS and the gateway
- can't read the keychain or `~/.zandy`

It reaches your tools through the broker:

```sh
zandy-client discover
zandy-client call mac.say '{"voice":"Bad News","text":"the tests failed"}'
```

The broker runs the command outside the sandbox. zandy doesn't judge what the command does. The token's scopes and the profile's IAM permissions decide that.

## Write your own adapter

An adapter is a function that takes `pkgs` and returns an attrset. Define it in your flake and add it to `adapters`.

This one lets the agent use macOS text-to-speech, which the sandbox can't reach:

```nix
let
  say = pkgs: {
    name = "mac";
    package = pkgs.writeShellScriptBin "say" ''exec /usr/bin/say -v "$1" "$2"'';
    binary = "say";
    capabilities = [
      {
        name = "say";
        description = "Speak a text out loud on the user's Mac.";
        params = [
          { name = "voice"; kind = "choice"; choices = [ "Bad News" "Good News" "Cellos" "Zarvox" ]; description = "Voice to speak with"; }
          { name = "text"; description = "Text to speak"; }
        ];
        argv = [ "{voice}" "{text}" ];
      }
    ];
  };
in
zandy.lib.mkSandboxEnv {
  # …
  adapters = [ say ];
}
```

The agent then calls:

```sh
zandy-client call mac.say '{"voice":"Bad News","text":"the tests failed"}'
```

If the tool has its own login, let it use that. Only for a tool without one, hand it a secret from zandy's keychain with `secrets` and `files`.

### Fields

| Field | Meaning |
|---|---|
| `name` | Prefix of the method names: `<name>.<capability>` |
| `package` | The derivation the broker runs. Must not also be in `packages` |
| `binary` | The program in `package/bin` |
| `capabilities` | The methods: `name`, `description`, `params`, `argv` |
| `env` | Env vars passed on from the shell that started zandy. Not for secrets |
| `secrets` | Where each secret lives, e.g. `secrets.ACME_TOKEN.keychain = { service = "acme-token"; }`. Add `store = "login"` to read from the login keychain, or `field` to pick a path inside a JSON value |
| `files` | Files the tool reads. `{secret.NAME}` is replaced with the secret. At most 4096 bytes in total |
| `setEnv` | Env vars set for the command. `{dir}` is replaced with the adapter's private directory |

### How a call runs

- **argv:** each element is either a literal or a whole `{param}`. `"--repo={param}"` is not substituted. A `list` param expands to several arguments.
- **params:** all params are required. `string` and `choice` values can't start with `-`, so they can't become options. `list` values are passed through unchecked.
- **result:** the command runs outside the sandbox, in the directory zandy started in. On exit 0 the agent gets stdout, otherwise stderr.

Whatever the command can do, the agent can do too. Prefer narrow methods with `string` and `choice` params over a `list` that passes anything through. Avoid tools that read the project directory, like `git` or `make`. The agent can write there, and the tool would run whatever the project configures, outside the sandbox.

## Security limits

- **The sandbox is only as safe as its flake.** zandy runs the env from the Nix store, which the agent can't change. But the flake it was built from can, if the agent can write to it: an edited preset or rule takes effect at the next build. zandy can't check this, because the built env doesn't know where its flake lives. So keep the flake outside every directory the agent can write to: not in the project, not in `allowWrite`. Run the installed `zandy-<name>`, and review changes to the flake before `nix profile upgrade`. zandy denies writes to `flake.nix` and `flake.lock` in the project, but that doesn't cover the files a flake imports.
- **Environment variables are readable.** On macOS, any process can read the environment and arguments of every other process run by the same user. Seatbelt can't block that. So don't export secrets in the shell that starts zandy. Store them with `--zandy-secret` instead.
- **Tools can print their own credentials.** A `list` param that passes its items to glab lets the agent run `glab config get token`, and to aws `aws configure export-credentials`. Narrow methods with `string` and `choice` params avoid this.
- **Tools keep their credentials in your home.** glab keeps its token in `~/.config/glab-cli/config.yml`, aws in `~/.aws`. The sandbox can't read them. Keep it that way: an `allowRead` for `~` or `~/.config` hands them to the agent, and then it can bypass the broker.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Operation not permitted` | Look up the blocked operation in the [debug log](logging.md) |
| git: `unable to access '~/.config/git/config': Operation not permitted` | Your config is a symlink, e.g. from home-manager. The sandbox checks the target, so add it to `filesystem.allowRead` |
| claude tries to resolve AWS credentials inside the sandbox | Remove `AWS_PROFILE` and `awsCredentialExport` from `~/.claude/settings.json` |
| `NameTooLong` at start | Your `$HOME` path is too long. `~/.zandy/run/<pid>/broker.sock` must fit in 104 bytes |
| opencode: `operation not permitted mkdir '/var/folders/…'` | Start opencode once without zandy, then with zandy |
| A few info lines on stderr before the agent starts | That's the gateway starting up, e.g. `aws-sigv4-proxy` for Bedrock. They're harmless |

## Development

```sh
nix develop -c zig build test   # while working on zandy
nix flake check                 # the same tests, built and run by Nix
```

To try a local checkout of zandy in your env, override its `zandy` input:

```sh
cd your-project
nix run --override-input zandy path:$HOME/code/zandy ~/sandboxes
```

Use `path:`, not a plain path: a plain path is read as a git repo, which leaves out files git doesn't track yet.

Planned work is in [TODO.md](../TODO.md).
