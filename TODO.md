# TODO

- **Fixed env vars for the sandbox.** A `sandboxEnv` option, and a `[env]` table in `confine.toml`, for non-secret values like `MAVEN_OPTS`, `npm_config_cache` or `NIX_SSL_CERT_FILE`, so toolchains that write to `~` or need Nix's CA bundle work without wrappers or flags. The `shell` preset in confine-ports wraps bash for `NIX_SSL_CERT_FILE` until then, and npm needs `--cache "$TMPDIR/npm"`.
- **Refresh OAuth tokens.** `anthropicOauth` reads the token once at launch; a session can outlive it.
- **Known issues.** Allow reading symlinked git config, e.g. from home-manager; document `#!/usr/bin/env` shebangs.
- **`--rebuild`.** `confine-<name> --rebuild` runs `nix profile upgrade` for its own entry and rebuilds the schema; `nix profile` already knows where the env lives.
