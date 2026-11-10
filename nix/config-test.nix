{ fromConfig, schemaFor, system }:
let
  catalog = import ./test-catalog.nix;
in
{
  config-test = fromConfig {
    inherit system catalog;
    config = ../tests/zandy.toml;
    overlays = [
      (final: prev: {
        greet = prev.writeShellScriptBin "greet" ''echo "$1"'';
        shout = prev.writeShellScriptBin "shout" ''echo "$1!"'';
      })
    ];
  };
  schema-test = schemaFor { inherit system catalog; };
}
