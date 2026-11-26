# AGENTS.md

confine runs a command-line program under a macOS Seatbelt sandbox, built with Nix. Start with the [README](README.md) and [Using confine](docs/README.md).

## Build and test

```sh
nix develop -c zig build test   # Zig 0.16, from the dev shell
nix flake check                 # the same tests and the Nix checks, built by Nix
```

More in [Development](docs/development.md).

## Before you change something

- **Read the [architecture decisions](docs/adr/README.md).** They say why confine works the way it does. Don't undo one by accident; if a change goes against one, write a new ADR that supersedes it.
- **Design question?** Ask how OpenBSD would provide it (`pkg_add`, plain sane defaults, never touching the user's config, no magic) and how Apple would (the product's name is the command, defaults instead of questions, one obvious path). Then decide.

## A change ships with its docs, in the same commit

- The reference page of what it changes, in `docs/`.
- An entry in the next version's [release notes](docs/release-notes/README.md), under its area: New Features, Resolved Issues, Known Issues or Deprecations. Present tense, one or two sentences. What users must change goes under Deprecations, with the commands.
- An [ADR](docs/adr/template.md) if the change is a decision: Context, Decision, Consequences, with rejected options under Consequences. Number it next, add it to the index, never rewrite an accepted one.

There is no changelog: what changed is in the release notes, why is in the ADRs.
