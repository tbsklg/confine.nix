{ nixpkgs }:
{ system, catalog }:
let
  inherit (nixpkgs) lib;
  pkgs = import nixpkgs { inherit system; };
  options = (lib.evalModules { modules = [ ./options.nix ]; }).options;

  strings = description: { type = "array"; items.type = "string"; inherit description; };
  arg = spec:
    (if spec.type == "list" then strings spec.description else { type = "string"; inherit (spec) description; })
    // lib.optionalAttrs (spec ? default) { inherit (spec) default; }
    // lib.optionalAttrs (spec ? example) { examples = [ spec.example ]; };
  table = ports: {
    type = "object";
    additionalProperties = false;
    properties = lib.mapAttrs
      (_: port: {
        type = "object";
        description = port.description + lib.optionalString (port.open or false) ". Open: the agent can run any command and make the tool print its credential.";
        additionalProperties = false;
        properties = lib.mapAttrs (_: arg) port.args;
        required = lib.attrNames (lib.filterAttrs (_: spec: !(spec ? default)) port.args);
      })
      ports;
  };

  schema = {
    "$schema" = "http://json-schema.org/draft-07/schema#";
    title = "zandy.toml";
    type = "object";
    additionalProperties = false;
    required = [ "name" "preset" ];
    properties = {
      name = { type = "string"; pattern = "^[a-z0-9-]+$"; inherit (options.name) description; };
      preset = {
        description = "The program to run.";
        oneOf = lib.mapAttrsToList (name: port: { const = name; inherit (port) description; }) catalog.presets;
      };
      packages = strings "Extra packages on the sandbox PATH, by nixpkgs attribute, e.g. ripgrep or python3Packages.pytest.";
      gateway = table catalog.gateways // { maxProperties = 1; description = "The model backend, at most one."; };
      adapters = table catalog.adapters // { description = "Tools the broker runs outside the sandbox on the agent's behalf."; };
      filesystem = {
        type = "object";
        additionalProperties = false;
        properties = lib.mapAttrs (_: option: strings option.description) (lib.removeAttrs options.filesystem [ "_type" ]);
      };
    };
  };
in
pkgs.runCommand "zandy.schema.json" { nativeBuildInputs = [ pkgs.jq ]; } ''
  jq --sort-keys . ${pkgs.writeText "schema.json" (builtins.toJSON schema)} > $out
''
