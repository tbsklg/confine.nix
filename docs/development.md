# Development

```sh
nix develop -c zig build test   # while working on zandy
nix flake check                 # the same tests, built and run by Nix
```

`zandy.toml` is read in two layers. `nix/resolve.nix` is pure: it takes the parsed TOML and the catalog and decides everything; `nix/resolve-test.nix` tests it without files, nixpkgs or a build. `nix/config.nix` is the shell: it reads the file, imports nixpkgs and calls `mkSandboxEnv`.

`tests/run-probe.sh` runs the sandbox probe on this machine.

To try a local checkout in your env, override its `zandy` input:

```sh
cd your-project
nix run --override-input zandy path:$HOME/code/zandy ~/.zandy/envs/claude
```

Use `path:`, not a plain path: a plain path is read as a git repo and leaves out untracked files.

A change ships with its docs, in the same commit: the reference page of what it changes, and an entry in [upgrade.md](upgrade.md) if users have to act. Reference pages keep the same sections, in this order: synopsis, description, environment, files, exit status, examples, see also, caveats; leave out what doesn't apply.

`docs/options.md` is generated with `nix build .#options-doc`. The launch sequence is in [runtime-flow.puml](runtime-flow.puml). Planned work is in [TODO.md](https://github.com/tbsklg/zandy.nix/blob/main/TODO.md).
