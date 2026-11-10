# TODO

- **Fixed env vars for the sandbox.** A `sandboxEnv` option for non-secret values like `MAVEN_OPTS` or `npm_config_cache`, so toolchains that write to `~` work without project-side workarounds.
- **Refresh OAuth tokens.** `anthropicOauth` reads the token once at launch; a session can outlive it.
- **Known issues.** Allow reading symlinked git config, e.g. from home-manager; document `#!/usr/bin/env` shebangs.
- **`--rebuild`.** `zandy-<name> --rebuild` runs `nix profile upgrade` for its own entry and rebuilds the schema; `nix profile` already knows where the env lives.
- **Adapters in TOML.** Let users define their own narrow adapters in `zandy.toml`, in a table apart from references to ports.
