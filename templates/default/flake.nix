{
  inputs.zandy.url = "github:tbsklg/zandy.nix";
  inputs.ports.url = "github:tbsklg/zandy-ports";
  inputs.ports.inputs.zandy.follows = "zandy";

  outputs = { zandy, ports, ... }:
    let
      system = "aarch64-darwin";
      inherit (ports) catalog;
    in
    {
      packages.${system} = {
        default = zandy.lib.fromConfig { inherit system catalog; config = ./zandy.toml; };
        schema = zandy.lib.schemaFor { inherit system catalog; };
      };
    };
}
