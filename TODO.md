# TODO

- **Fixed env vars for the sandbox.** A `sandboxEnv` option for non-secret values like `MAVEN_OPTS` or `npm_config_cache`, so toolchains that write to `~` work without project-side workarounds.
- **Refresh OAuth tokens.** `anthropicOauth` reads the token once at launch; a session can outlive it.
- **Known issues.** Allow reading symlinked git config, e.g. from home-manager; document `#!/usr/bin/env` shebangs.
