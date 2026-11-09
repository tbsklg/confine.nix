{
  description = "zandy";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      lib = import ./nix/lib.nix;
      system = "aarch64-darwin";
      pkgs = import nixpkgs { inherit system; };
      inherit (lib.zandyFor pkgs) zig zandy zandy-client tests;
    in
    {
      lib = {
        inherit (lib) mkSandboxEnv;
        mkGateway = import ./nix/gateway.nix;
      };

      packages.${system} = {
        inherit zandy zandy-client;
        default = zandy;
        options-doc = (pkgs.nixosOptionsDoc {
          options = builtins.removeAttrs (pkgs.lib.evalModules { modules = [ ./nix/options.nix ]; }).options [ "_module" ];
          transformOptions = opt: opt // { declarations = [ ]; };
        }).optionsCommonMark;
      };

      checks.${system} = { inherit tests; };

      devShells.${system}.default = pkgs.mkShell {
        packages = [ zig ];
      };
    };
}
