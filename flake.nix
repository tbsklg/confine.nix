{
  description = "zandy";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      lib = import ./nix/lib.nix;
      system = "aarch64-darwin";
      pkgs = import nixpkgs { inherit system; };
      inherit (lib.zandyFor pkgs) zig zandy zandy-client tests;
      config = {
        fromConfig = import ./nix/config.nix { inherit nixpkgs; inherit (lib) mkSandboxEnv; };
        schemaFor = import ./nix/schema.nix { inherit nixpkgs; };
      };
    in
    {
      lib = {
        inherit (lib) mkSandboxEnv;
        inherit (config) fromConfig schemaFor;
        mkGateway = import ./nix/gateway.nix;
      };

      templates.default = {
        path = ./templates/default;
        description = "A zandy env configured in zandy.toml, with zandy-ports plugged in";
      };

      packages.${system} = {
        inherit zandy zandy-client;
        default = zandy;
        options-doc = (pkgs.nixosOptionsDoc {
          options = builtins.removeAttrs (pkgs.lib.evalModules { modules = [ ./nix/options.nix ]; }).options [ "_module" ];
          transformOptions = opt: opt // { declarations = [ ]; };
        }).optionsCommonMark;
      };

      checks.${system} = { inherit tests; } // import ./nix/config-test.nix { inherit (config) fromConfig schemaFor; inherit system; };

      devShells.${system}.default = pkgs.mkShell {
        packages = [ zig ];
      };
    };
}
