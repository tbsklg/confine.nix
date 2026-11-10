{ lib, ... }:
let
  inherit (lib) mkOption types;
  paths = description: mkOption {
    type = types.listOf types.str;
    default = [ ];
    description = "${description} Absolute, relative to the working directory, or starting with `~`.";
  };
in
{
  options = {
    name = mkOption {
      type = types.strMatching "[a-z0-9-]+";
      description = "Name of the sandbox env; the launcher becomes `bin/zandy-<name>`.";
      example = "claude";
    };

    preset = mkOption {
      description = "The app to run and the sandbox rules it needs, e.g. `ports.presets.claude` from zandy-ports.";
      type = types.submodule {
        options = {
          name = mkOption { type = types.str; description = "Name of the preset."; };
          binary = mkOption { type = types.str; description = "Binary in `sandbox/bin` to execute."; };
          icon = mkOption { type = types.str; default = ""; description = "Symbol shown in the start banner."; };
          packages = mkOption { type = types.functionTo (types.listOf types.package); description = "Packages the app needs, given `pkgs`."; };
          env = mkOption { type = types.listOf types.str; default = [ ]; description = "Names of the environment variables passed into the sandbox."; };
          args = mkOption { type = types.listOf types.str; default = [ ]; description = "Startup args."; };
          gatewayEnv = mkOption { type = types.attrsOf (types.either (types.attrsOf types.str) (types.functionTo (types.attrsOf types.str))); default = { }; description = "Env vars the app gets per gateway name, or a function of the gateway; `{url}` becomes the gateway's address."; };
          rules = mkOption { type = types.listOf types.attrs; description = "SBPL rules the app needs."; };
        };
      };
    };

    packages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Extra packages on the sandbox `PATH`, e.g. the project's toolchain.";
      example = lib.literalExpression "[ pkgs.ripgrep ]";
    };

    adapters = mkOption {
      type = types.listOf (types.functionTo types.attrs);
      default = [ ];
      description = "Tools the broker runs outside the sandbox on the program's behalf. Their packages must not be in `packages`.";
      example = lib.literalExpression "[ say ]";
    };

    gateway = mkOption {
      type = types.nullOr (types.functionTo types.attrs);
      default = null;
      description = "A proxy to one API that adds its credential outside the sandbox.";
      example = lib.literalExpression ''ports.gateways.bedrock { profile = "acme-bedrock"; region = "eu-west-1"; }'';
    };


    filesystem = {
      allowRead = paths "Extra paths the program may read.";
      denyRead = paths "Paths the program may not read.";
      allowWrite = paths "Extra paths the program may write.";
      denyWrite = paths "Paths the program may not write.";
    };
  };
}
