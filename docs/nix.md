# zandy in Nix

`zandy.toml` covers picking ports. For a preset, gateway or adapter of your own, or one that needs secrets, use Nix in your env's `flake.nix`.

- [Your own packages](#your-own-packages)
- [mkSandboxEnv](#mksandboxenv)
- [Presets](#presets)
- [Rules](#rules)
- [Gateways](#gateways)
- [Adapters](#adapters)
- [Catalogs](#catalogs)

## Your own packages

`zandy.toml` names packages; it doesn't build them. To use one that isn't in nixpkgs, add it with an overlay in `flake.nix`, and name it in `packages` or as an adapter's `package`:

```nix
default = zandy.lib.fromConfig {
  inherit system catalog;
  config = ./zandy.toml;
  overlays = [
    (final: prev: {
      say = prev.writeShellScriptBin "say" ''exec /usr/bin/say -v "$1" "$2"'';
    })
  ];
};
```

```toml
[define.adapters.mac]
package = "say"

[[define.adapters.mac.capabilities]]
name = "say"
description = "Speak a text out loud on the user's Mac"
params = [
  { name = "voice", kind = "choice", choices = ["Bad News", "Good News"], description = "Voice" },
  { name = "text", description = "Text to speak" },
]
argv = ["{voice}", "{text}"]
```

## mkSandboxEnv

`zandy.toml` is read by `zandy.lib.fromConfig`, which calls `zandy.lib.mkSandboxEnv`. You can call it directly:

```nix
packages.aarch64-darwin.default = zandy.lib.mkSandboxEnv {
  inherit pkgs;
  name = "claude";
  preset = ports.presets.claude // { rules = ports.rules.project ++ ports.presets.claude.rules; };
  packages = [ pkgs.ripgrep ];
  gateway = ports.gateways.bedrock { profile = "acme-bedrock"; region = "eu-west-1"; };
  adapters = [ say ];
  filesystem.allowRead = [ "~/notes" ];
};
```

`pkgs` needs `claude-code` allowed as unfree. All options, with types and defaults, are in [options.md](options.md).

## Presets

A preset is a plain attrset: the packages a program needs, the env vars it gets or is set and its Seatbelt rules. Any program can have one. This one is for curl, which may reach HTTPS hosts and nothing else, not even the project:

```nix
packages.aarch64-darwin.curl = zandy.lib.mkSandboxEnv {
  inherit pkgs;
  name = "curl";
  preset = {
    name = "curl";
    packages = pkgs: [ pkgs.curl pkgs.cacert ];
    setEnv = pkgs: { CURL_CA_BUNDLE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"; };
    rules = [
      { action = "allow"; operation = "file_read_metadata"; }
      { action = "allow"; operation = "file_map_executable"; }
      { action = "allow"; operation = "sysctl_all"; }
      { action = "allow"; operation = "network_outbound"; filter = { remote_tcp = "*:443"; }; }
      { action = "allow"; operation = "network_outbound"; filter = { remote_unix_socket = { literal = "/private/var/run/mDNSResponder"; }; }; }
    ];
  };
};
```

```sh
nix run ~/.zandy/envs/claude#curl -- curl https://example.com
```

To start from an existing preset, override it: `ports.presets.claude // { name = "mine"; }` gives Claude Code's rules to adjust. Start with few rules and add what the [debug log](logging.md) shows as denied.

## Rules

The sandbox denies everything no rule allows. zandy adds rules in this order:

1. zandy's own allows: the broker socket
2. the preset's `rules`
3. read and execute for the env's store paths
4. `filesystem`
5. zandy's own denies: `flake.nix`, `flake.lock` and `zandy.toml` in the project, `~/.zandy` and the keychain

For the same operation, a later rule wins. A rule for a specific operation, like `file-write-data`, wins over a wildcard, like `file-write*`, wherever it stands. So a deny on `file-write*` alone doesn't hold. zandy denies its own paths for `file-write*` and every specific write operation, so neither a preset nor `filesystem` can open them.

zandy's own rules are in [base.zon](https://github.com/tbsklg/zandy.nix/blob/main/src/sandbox/base.zon); the operations and filters a rule may use are in [sbpl.zig](https://github.com/tbsklg/zandy.nix/blob/main/src/sandbox/sbpl.zig). Rules for the project directory are policy and come from zandy-ports: `ports.rules.project`.

## Gateways

`zandy.lib.mkGateway` builds a gateway on Caddy:

```nix
gateway = zandy.lib.mkGateway {
  name = "anthropic";
  host = "api.anthropic.com";
  headers.X-Api-Key = [ "{env.ANTHROPIC_API_KEY}" ];
  secrets.ANTHROPIC_API_KEY.keychain = { service = "anthropic-api-key"; };
};
```

| Field | Meaning |
|---|---|
| `name` | Picks the preset's `gatewayEnv` entry |
| `host` | The one upstream, over HTTPS on port 443 |
| `headers` | Request headers to set. `{env.NAME}` is replaced with the secret `NAME` |
| `addHeaders` | Request headers to add next to the client's own |
| `secrets` | Where each secret lives, as for [adapters](#adapters) |

The gateway drops the client's own `Authorization` and `X-Api-Key` headers.

A gateway that isn't Caddy is an attrset with `name`, an `argv` in which `{port}` is replaced with the port zandy picks, and optionally `env`, `secrets` and `files`. The Bedrock gateway in zandy-ports is one.

## Adapters

An adapter is a function from `pkgs` to an attrset, with the same fields as [in TOML](zandy.toml.md) plus `secrets` and `files`, for a tool without a login of its own:

```nix
say = pkgs: {
  name = "mac";
  package = pkgs.writeShellScriptBin "say" ''exec /usr/bin/say -v "$1" "$2"'';
  binary = "say";
  capabilities = [
    {
      name = "say";
      description = "Speak a text out loud on the user's Mac.";
      params = [
        { name = "voice"; kind = "choice"; choices = [ "Bad News" "Good News" "Cellos" "Zarvox" ]; description = "Voice to speak with"; }
        { name = "text"; description = "Text to speak"; }
      ];
      argv = [ "{voice}" "{text}" ];
    }
  ];
};
```

| Field | Meaning |
|---|---|
| `name` | Prefix of the method names: `<name>.<capability>` |
| `package` | The derivation the broker runs. Must not also be in `packages` |
| `binary` | The program in `package/bin` |
| `capabilities` | The methods: `name`, `description`, `params`, `argv` |
| `env` | Env vars passed on from the shell that started zandy. Not for secrets |
| `setEnv` | Env vars set for the command. `{dir}` is replaced with the adapter's private directory |
| `secrets` | Where each secret lives, e.g. `secrets.ACME_TOKEN.keychain = { service = "acme-token"; }`. `store = "login"` reads the login keychain, `field` picks a path inside a JSON value |
| `files` | Files the tool reads. `{secret.NAME}` is replaced with the secret. At most 4096 bytes in total |

In Nix a param can also be a `list`, which expands to several arguments, unchecked. It passes anything to the tool; prefer `string` and `choice`.

## Catalogs

`zandy.toml` names ports from a catalog: `zandy.lib.fromConfig { system, catalog, config }`. The template passes `ports.catalog`. A catalog has `presets`, `gateways` and `adapters`; each entry is:

| Field | Meaning |
|---|---|
| `description` | One line, shown in completion |
| `args` | The table's keys: `{ <name> = { type = "string" or "list"; description; default or example; }; }` |
| `call` | Takes the table, fills in the defaults, and returns a preset, or what `gateway` or `adapters` take |
| `open` | `true` if the port can leak its credential; shown in the schema |
| `unfree` | Unfree package names the port needs, e.g. `[ "claude-code" ]` |

To use your own ports by name, merge them in `flake.nix`, for both the env and the schema:

```nix
catalog = ports.catalog // { adapters = ports.catalog.adapters // { mine = …; }; };
```
