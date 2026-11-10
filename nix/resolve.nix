lib:
{ catalog, toml }:
let
  fail = message: throw "zandy.toml: ${message}";

  pick = key: ports: name: ports.${name}
    or (fail "${key} \"${name}\" unknown, one of: ${lib.concatStringsSep ", " (lib.attrNames ports)}");
  resolve = key: ports: name: given:
    let port = pick key ports name;
    in { unfree = port.unfree or [ ]; value = builtins.addErrorContext "while reading [${key}.${name}] in zandy.toml" (port.call given); };

  only = at: keys: given:
    let unknown = lib.subtractLists keys (lib.attrNames given);
    in if unknown == [ ] then given else fail "${at}: unknown ${lib.concatStringsSep ", " unknown}, one of: ${lib.concatStringsSep ", " keys}";

  package = pkgs: attr: lib.attrByPath (lib.splitString "." attr) (fail "package \"${attr}\" not in nixpkgs") pkgs;

  define = name: adapter: pkgs:
    let
      at = "define.adapters.${name}";
      param = p:
        if builtins.elem (p.kind or "string") [ "string" "choice" ] then only "${at}: param" [ "name" "kind" "description" "choices" ] p
        else fail "${at}: param ${p.name or "?"}: kind must be string or choice; a list passes anything to the tool";
      capability = c: only "${at}: capability" [ "name" "description" "params" "argv" ] c // { params = map param (c.params or [ ]); };
      tool = package pkgs adapter.package;
    in
    only at [ "package" "binary" "env" "setEnv" "capabilities" ] adapter // {
      inherit name;
      package = tool;
      binary = adapter.binary or tool.meta.mainProgram or (lib.getName tool);
      capabilities = map capability adapter.capabilities;
    };

  defined = only "define" [ "adapters" ] (toml.define or { });
  clashes = lib.intersectLists (lib.attrNames (defined.adapters or { })) (lib.attrNames (toml.adapters or { }));

  preset = resolve "preset" catalog.presets (toml.preset or (fail "no preset")) { };
  gateways = lib.mapAttrsToList (resolve "gateway" catalog.gateways) (toml.gateway or { });
  adapters = lib.mapAttrsToList (resolve "adapters" catalog.adapters) (toml.adapters or { });
in
assert lib.assertMsg (lib.length gateways <= 1) "zandy.toml: at most one gateway";
assert lib.assertMsg (clashes == [ ]) "zandy.toml: ${lib.concatStringsSep ", " clashes} both in [adapters] and [define.adapters]";
builtins.removeAttrs toml [ "define" ] // {
  preset = preset.value;
  gateway = if gateways == [ ] then null else (lib.head gateways).value;
  adapters = map (adapter: adapter.value) adapters ++ lib.mapAttrsToList define (defined.adapters or { });
  packages = pkgs: map (package pkgs) (toml.packages or [ ]);
  unfree = lib.concatMap (picked: picked.unfree) ([ preset ] ++ gateways ++ adapters);
}
