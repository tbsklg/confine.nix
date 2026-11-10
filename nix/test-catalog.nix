{
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
  gateways.echo = {
    description = "A gateway that needs an unfree package";
    args = { };
    unfree = [ "echo-server" ];
    call = _: pkgs: { name = "echo"; argv = [ "echo" ]; };
  };
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
}
