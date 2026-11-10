{ nixpkgs, mkSandboxEnv }:
{ system, catalog, config }:
let
  inherit (nixpkgs) lib;
  toml = builtins.fromTOML (builtins.readFile config);

  pick = key: ports: name: ports.${name}
    or (throw "zandy.toml: ${key} \"${name}\" unknown, one of: ${lib.concatStringsSep ", " (lib.attrNames ports)}");
  resolve = key: ports: name: given:
    let port = pick key ports name;
    in { inherit port; value = builtins.addErrorContext "while reading [${key}.${name}] in zandy.toml" (port.call given); };

  preset = resolve "preset" catalog.presets toml.preset { };
  gateways = lib.mapAttrsToList (resolve "gateway" catalog.gateways) (toml.gateway or { });
  adapters = lib.mapAttrsToList (resolve "adapters" catalog.adapters) (toml.adapters or { });

  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) (lib.concatMap ({ port, ... }: port.unfree or [ ]) ([ preset ] ++ gateways ++ adapters));
  };
in
assert lib.assertMsg (lib.length gateways <= 1) "zandy.toml: at most one gateway";
mkSandboxEnv (toml // {
  inherit pkgs;
  preset = preset.value;
  packages = map (attr: lib.attrByPath (lib.splitString "." attr) (throw "zandy.toml: package \"${attr}\" not in nixpkgs") pkgs) (toml.packages or [ ]);
  gateway = if gateways == [ ] then null else (lib.head gateways).value;
  adapters = map (adapter: adapter.value) adapters;
})
