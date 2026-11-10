{ fromConfig, schemaFor, system }:
let
  catalog = {
    presets.shell = {
      description = "A shell";
      args = { };
      call = _: {
        name = "shell";
        binary = "bash";
        packages = pkgs: [ pkgs.bash ];
        rules = [ ];
      };
    };
    gateways = { };
    adapters.hello = {
      description = "GNU hello";
      args.greeting = { type = "string"; default = "hi"; description = "Greeting"; };
      call = { greeting ? "hi" }: pkgs: {
        name = "hello";
        package = pkgs.hello;
        binary = "hello";
        capabilities = [{ name = "greet"; description = "Greet"; params = [ ]; argv = [ "--greeting" greeting ]; }];
      };
    };
  };
in
{
  config-test = fromConfig { inherit system catalog; config = ../tests/zandy.toml; };
  schema-test = schemaFor { inherit system catalog; };
}
