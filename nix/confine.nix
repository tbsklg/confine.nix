{ pkgs }:
let
  zig = pkgs.zig_0_16;

  confine = pkgs.stdenvNoCC.mkDerivation {
    pname = "confine";
    version = builtins.head (builtins.match ".*\n[[:space:]]*\.version = \"([^\"]+)\".*" (builtins.readFile ../build.zig.zon));
    src = pkgs.lib.fileset.toSource {
      root = ../.;
      fileset = pkgs.lib.fileset.unions [ ../build.zig ../build.zig.zon ../src ];
    };
    nativeBuildInputs = [ zig.hook pkgs.removeReferencesTo ];
    zigBuildFlags = [ "--sysroot" pkgs.apple-sdk.sdkroot ];
    postFixup = ''
      remove-references-to -t ${zig} $out/bin/*
    '';
    disallowedReferences = [ zig ];
    meta.platforms = [ "aarch64-darwin" ];
  };

  tests = confine.overrideAttrs {
    pname = "confine-tests";
    doCheck = true;
    __darwinAllowLocalNetworking = true;
  };

  confine-client = pkgs.runCommand "confine-client" { } ''
    mkdir -p $out/bin
    cp ${confine}/bin/confine-client $out/bin/
  '';
in
{
  inherit zig confine confine-client tests;
}
