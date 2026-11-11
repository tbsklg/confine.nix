# TODO

- **Fixed env vars in confine.toml.** Presets set them with `setEnv`; an `[env]` table in `confine.toml` would let you set non-secret values like `MAVEN_OPTS` or `npm_config_cache`, so toolchains that write to `~` work without flags. npm needs `--cache "$TMPDIR/npm"` until then.
- **Refresh OAuth tokens.** `anthropicOauth` reads the token once at launch; a session can outlive it.
- **Known issues.** Allow reading symlinked git config, e.g. from home-manager; document `#!/usr/bin/env` shebangs.
- **`--rebuild`.** `confine-<name> --rebuild` runs `nix profile upgrade` for its own entry and rebuilds the schema; `nix profile` already knows where the env lives.
