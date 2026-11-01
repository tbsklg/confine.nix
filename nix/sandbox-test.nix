{ pkgs, mkSandboxEnv }:
mkSandboxEnv {
  inherit pkgs;
  name = "sandbox-test";
  preset = (import ./presets/claude.nix) // {
    name = "sandbox-test";
    binary = "sandbox-probe";
    args = [ ];
    packages = pkgs: [ pkgs.bash pkgs.coreutils pkgs.procps ];
  };
  packages = [ (pkgs.writeShellScriptBin "sandbox-probe" (builtins.readFile ../tests/sandbox-probe.sh)) ];
}
