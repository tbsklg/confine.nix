{ fromConfig, schemaFor, system }:
let
  catalog = import ./test-catalog.nix;
in
{
  config-test = fromConfig { inherit system catalog; config = ../tests/zandy.toml; };
  schema-test = schemaFor { inherit system catalog; };
}
