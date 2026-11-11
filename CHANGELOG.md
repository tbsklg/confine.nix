# Changelog

Newest first. What you have to do after an update is in [upgrade notes](docs/upgrade.md).

## 0.1.0, unreleased

### 2026-11-11: from a launcher to a sandbox

- A preset no longer starts its program; it is the rules and packages a program needs. `confine-<name>` runs the command you name, or a shell. The tool confines; it doesn't decide what runs.
- Presets get `setEnv`, and lose `binary` and `args`. Startup args go into a wrapper script.
- zandy is renamed to confine, and zandy-ports to confine-ports: a verb that says what it does. The banner is one plain line.

### 2026-11-10: from code to configuration

- One `zandy.toml` per env; the template's `flake.nix` is never edited. Users write configuration, not code.
- The base owns the format and the ports supply what can be named in it. The schema is built in the user's flake, so it matches the pinned versions.
- Adapters of your own are defined in the TOML. Packages outside nixpkgs come in through overlays.
- The config is resolved by pure functions over data; only a thin outer layer reads files or imports nixpkgs.
- Envs live in `~/.zandy/envs`, where the sandbox can't read or change its own config.

### 2026-11-09: from one repo to mechanism and policy

- Presets, gateways and adapters move to zandy-ports and update on their own. The base keeps the launcher, the broker, `mkSandboxEnv` and `mkGateway`.
- Dot paths in the project are read-only at any depth, because tools run them on their own, outside the sandbox.
- A deny list for commands that print credentials was built and reverted: it treated a symptom. An adapter that can print its credential is marked open.
- Preset rules stay plain data; a helper layer was tried and dropped as less clear.

### 2026-10-31

- Renamed to zandy.nix.

### 2026-10-29: from hiding secrets to holding none

- Gateways: a local proxy outside the sandbox adds the API key and forwards to one fixed host. zandy speaks no HTTP; the proxy is a ready-made program, Caddy or `aws-sigv4-proxy`.
- Secrets live in a keychain of zandy's own and reach the gateway and adapters through `0600` named pipes, once per run. Never through the environment or argv: on macOS any process can read those of every other process of the same user, and Seatbelt can't block it. Nothing lands on disk. Encrypting a file instead was rejected, since the consumer needs plaintext anyway.
- Creating the keychain stays two documented `security` commands. Storing a secret gets a command, because it keeps the value out of argv and shell history.
- Sessions, broker calls and the sandbox's denials go to the macOS unified log.
- macOS on Apple Silicon only, by design: it rests on Seatbelt and the keychain.

### 2026-10-26: from a runtime config to a built declaration

- The broker: the agent asks over a Unix socket, and the broker runs the tool outside the sandbox, with your login. Denying `~/.aws` only hides a secret the agent might still need; the broker removes the need.
- No shell in the broker: each placeholder is a whole argv entry, and a value can't start with `-`. The broker doesn't judge commands; the token's scopes and the IAM role do.
- An env is a Nix derivation from `mkSandboxEnv`. The same declaration always gives the same sandbox, and the env is a read-only value in the store. Only its closure may be executed.
- Parse, don't validate: every input is parsed into a precise type once, at the boundary.

## 0.0.8, 2026-09-25: from one agent to any program

- Named presets: one launcher for any CLI coding agent. A preset is required, with no raw mode: without one the program crashes or hangs, because no user can know which mach lookups, IPC or system operations it needs.

## 0.0.7, 2026-06-23

- Zig 0.16.

## 0.0.6, 2026-06-17: from a profile file to a profile as data

- zandy builds the SBPL profile itself, as typed data, and applies it in-process with `sandbox_init_with_parameters` instead of `sandbox-exec`. Everything is denied by default.

## 0.0.5, 2026-04-10

- The network-only profile is reworked.
- 2026-04-16: a first profile for Claude Code.

## 0.0.4, 2026-03-30

- A second profile: network only.

## 0.0.3, 2026-03-17

- Processes hardened, a rename leak closed.
- 2026-03-18: installed with brew.

## 0.0.2, 2026-03-15

- The config is inlined into the binary.

## 0.0.1, 2026-03-10

- zandy: a Zig wrapper that runs opencode under `sandbox-exec` with a hand-written `opencode.sb`. A coding agent should not read what it doesn't need, like `.env`, `~/.ssh` or `~/.aws`.
