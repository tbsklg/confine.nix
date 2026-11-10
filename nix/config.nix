{ nixpkgs, mkSandboxEnv }:
let
  inherit (nixpkgs) lib;
in
{
  fromConfig = { system, catalog, config }:
    let
      resolved = import ./resolve.nix lib { inherit catalog; toml = builtins.fromTOML (builtins.readFile config); };
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) resolved.unfree;
      };
    in
    mkSandboxEnv (builtins.removeAttrs resolved [ "unfree" ] // {
      inherit pkgs;
      packages = resolved.packages pkgs;
    });

  schemaFor = { system, catalog }:
    let pkgs = import nixpkgs { inherit system; };
    in pkgs.runCommand "zandy.schema.json" { nativeBuildInputs = [ pkgs.jq ]; } ''
      jq --sort-keys . ${pkgs.writeText "schema.json" (builtins.toJSON (import ./schema.nix lib catalog))} > $out
    '';
}
