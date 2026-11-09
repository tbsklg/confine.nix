{
  inputs.zandy.url = "github:tbsklg/zandy.nix";
  inputs.ports.url = "github:tbsklg/zandy-ports";
  inputs.ports.inputs.zandy.follows = "zandy";
  inputs.nixpkgs.follows = "zandy/nixpkgs";

  outputs = { zandy, ports, nixpkgs, ... }:
    let
      systems = [ "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg: nixpkgs.lib.getName pkg == "claude-code";
      }));
    in
    {
      packages = forAllSystems (pkgs: {
        default = zandy.lib.mkSandboxEnv {
          inherit pkgs;
          name = "claude";
          preset = ports.presets.claude;
          gateway = ports.gateways.anthropicOauth { };
        };
      });
    };
}
