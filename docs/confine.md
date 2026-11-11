# confine

Run a program in a confine sandbox.

## Synopsis

```
confine-<name> [command [args …]]
confine-<name> --confine-config
confine-<name> --confine-secret <service>
```

## Description

`confine-<name>` is the launcher of an installed env. It starts the env's gateway and broker outside the sandbox, then runs `command` with `args` in the current directory under a Seatbelt profile. `command` is a program of the env. Without it, confine runs an interactive shell; nothing starts on its own.

Inside the sandbox, the program:

- reads and writes what the preset and `[filesystem]` allow
- can't write `flake.nix`, `flake.lock` or `confine.toml` in the current directory
- can't read `~/.confine` or the keychains
- runs only programs from the env
- reaches an API through the gateway and your tools through the broker, with [confine-client](confine-client.md)

Everything no rule allows is denied.

- `--confine-config`: Print the env's config, the methods the program sees, and the Seatbelt profile. Starts nothing.
- `--confine-secret <service>`: Ask for a secret without echo and store it as `<service>` in confine's keychain.

## Files

- `~/.confine/confine.keychain-db`: confine's keychain, for gateway and adapter secrets. Create it once with `security create-keychain ~/.confine/confine.keychain-db` and `security set-keychain-settings ~/.confine/confine.keychain-db`.
- `~/.confine/envs/<name>/`: The env's `flake.nix`, `confine.toml` and schema. Neither readable nor writable from the sandbox.
- `~/.confine/run/<pid>/`: The session's private directory: the broker socket and the pipes secrets travel through. Removed at exit.

## Exit status

The program's exit status, or 128 plus the signal that ended it. 1 if confine itself fails.

## Examples

```sh
cd your-project
confine-claude
confine-claude claude
confine-claude claude -p "run the tests"
confine-claude --confine-secret anthropic-api-key
```

## See also

[confine.toml](confine.toml.md), [confine-client](confine-client.md), [debug log](logging.md)

## Caveats

On macOS, any process can read the environment and arguments of every other process of the same user. Don't export secrets in the shell that starts confine; use `--confine-secret`.

The env is only as safe as the `confine.toml` it was built from. In `~/.confine/envs/<name>/` the program can't reach it; elsewhere, keep it where the program can't write.

The socket path `~/.confine/run/<pid>/broker.sock` must fit in 104 bytes; with a very long `$HOME`, confine fails with `NameTooLong`.
