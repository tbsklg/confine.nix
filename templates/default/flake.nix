{
  inputs.confine.url = "github:tbsklg/confine.nix";
  inputs.ports.url = "github:tbsklg/confine-ports";
  inputs.ports.inputs.confine.follows = "confine";

  outputs = { confine, ports, ... }:
    let
      system = "aarch64-darwin";
      inherit (ports) catalog;
    in
    {
      packages.${system} = {
        default = confine.lib.fromConfig { inherit system catalog; config = ./confine.toml; };
        schema = confine.lib.schemaFor { inherit system catalog; };
      };
    };
}
