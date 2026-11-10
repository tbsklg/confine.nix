{
  description = "zandy";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      lib = import ./nix/lib.nix;
      system = "aarch64-darwin";
      pkgs = import nixpkgs { inherit system; };
      inherit (lib.zandyFor pkgs) zig zandy zandy-client tests;
      config = import ./nix/config.nix { inherit nixpkgs; inherit (lib) mkSandboxEnv; };
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

      checks.${system} = { inherit tests; }
        // import ./nix/config-test.nix { inherit (config) fromConfig schemaFor; inherit system; }
        // {
          resolve-test =
            let failed = import ./nix/resolve-test.nix pkgs.lib;
            in pkgs.runCommand "resolve-test" { } (if failed == [ ] then "touch $out" else "printf 'FAIL %s\\n' ${pkgs.lib.escapeShellArgs failed} >&2; exit 1");
        };

      devShells.${system}.default = pkgs.mkShell {
        packages = [ zig ];
      };
    };
}
