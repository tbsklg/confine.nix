# Architecture decisions

Why confine works the way it does, one decision per record. A record is never rewritten; a later one supersedes it. New records follow the [template](template.md).

1. [The Seatbelt profile is built as typed data and denies by default](0001-seatbelt-profile-as-typed-data.md)
2. [A preset is required; there is no raw mode](0002-a-preset-is-required.md)
3. [An env is a Nix derivation, and only its closure runs](0003-an-env-is-a-nix-derivation.md)
4. [A broker runs tools outside the sandbox, without a shell](0004-a-broker-runs-tools-outside-the-sandbox.md)
5. [Inputs are parsed once, at the boundary](0005-parse-dont-validate.md)
6. [Gateways add credentials; confine speaks no HTTP](0006-gateways-add-credentials.md)
7. [Secrets travel through named pipes, never the environment or argv](0007-secrets-travel-through-named-pipes.md)
8. [Logs go to the macOS unified log](0008-logs-go-to-the-unified-log.md)
9. [macOS on Apple Silicon only](0009-macos-on-apple-silicon-only.md)
10. [Mechanism in confine, policy in confine-ports](0010-mechanism-in-confine-policy-in-ports.md)
11. [Dot paths in the project are read-only](0011-dot-paths-are-read-only.md)
12. [No deny list for commands; an adapter that can print its credential is marked open](0012-no-deny-list-adapters-are-marked-open.md)
13. [An env is configured in confine.toml, not Nix code](0013-configuration-in-toml.md)
14. [The sandbox is built outside what it confines](0014-the-sandbox-is-built-outside-what-it-confines.md)
15. [One command per env](0015-one-command-per-env.md)
16. [A preset is rules, not a launcher](0016-a-preset-is-rules-not-a-launcher.md)
17. [The proxy only logs](0017-the-proxy-only-logs.md)
18. [The installer requires Nix and doesn't install it](0018-the-installer-requires-nix.md)
19. [Release notes and ADRs instead of a changelog](0019-release-notes-and-adrs.md)
