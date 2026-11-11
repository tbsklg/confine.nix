# zandy

Run a program in a zandy sandbox.

## Synopsis

```
zandy-<name> [command [args …]]
zandy-<name> --zandy-config
zandy-<name> --zandy-secret <service>
```

## Description

`zandy-<name>` is the launcher of an installed env. It starts the env's gateway and broker outside the sandbox, then runs `command` with `args` in the current directory under a Seatbelt profile. `command` is a program of the env. Without it, zandy runs an interactive shell; nothing starts on its own.

Inside the sandbox, the program:

- reads and writes what the preset and `[filesystem]` allow
- can't write `flake.nix`, `flake.lock` or `zandy.toml` in the current directory
- can't read `~/.zandy` or the keychains
- runs only programs from the env
- reaches an API through the gateway and your tools through the broker, with [zandy-client](zandy-client.md)

Everything no rule allows is denied.

- `--zandy-config`: Print the env's config, the methods the program sees, and the Seatbelt profile. Starts nothing.
- `--zandy-secret <service>`: Ask for a secret without echo and store it as `<service>` in zandy's keychain.

## Files

- `~/.zandy/zandy.keychain-db`: zandy's keychain, for gateway and adapter secrets. Create it once with `security create-keychain ~/.zandy/zandy.keychain-db` and `security set-keychain-settings ~/.zandy/zandy.keychain-db`.
- `~/.zandy/envs/<name>/`: The env's `flake.nix`, `zandy.toml` and schema. Neither readable nor writable from the sandbox.
- `~/.zandy/run/<pid>/`: The session's private directory: the broker socket and the pipes secrets travel through. Removed at exit.

## Exit status

The program's exit status, or 128 plus the signal that ended it. 1 if zandy itself fails.

## Examples

```sh
cd your-project
zandy-claude
zandy-claude claude
zandy-claude claude -p "run the tests"
zandy-claude --zandy-secret anthropic-api-key
```

## See also

[zandy.toml](zandy.toml.md), [zandy-client](zandy-client.md), [debug log](logging.md)

## Caveats

On macOS, any process can read the environment and arguments of every other process of the same user. Don't export secrets in the shell that starts zandy; use `--zandy-secret`.

The env is only as safe as the `zandy.toml` it was built from. In `~/.zandy/envs/<name>/` the program can't reach it; elsewhere, keep it where the program can't write.

The socket path `~/.zandy/run/<pid>/broker.sock` must fit in 104 bytes; with a very long `$HOME`, zandy fails with `NameTooLong`.
