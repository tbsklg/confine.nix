lib:
let
  resolve = toml: import ./resolve.nix lib { catalog = import ./test-catalog.nix; inherit toml; };
  pkgs = { hello = { name = "hello"; meta.mainProgram = "hello"; }; };
  force = resolved: resolved // { adapters = map (adapter: adapter pkgs) resolved.adapters; packages = resolved.packages pkgs; };
  fails = toml: !(builtins.tryEval (builtins.deepSeq (force (resolve toml)) true)).success;

  base = { name = "t"; preset = "shell"; };
  define = params: base // {
    define.adapters.mine = { package = "hello"; capabilities = [{ name = "say"; description = "Say"; inherit params; argv = [ "{text}" ]; }]; };
  };
  mine = lib.last (force (resolve (define [{ name = "text"; }]))).adapters;

  cases = {
    "minimal config resolves" = !fails base;
    "unknown preset fails" = fails (base // { preset = "nope"; });
    "unknown adapter fails" = fails (base // { adapters.nope = { }; });
    "two gateways fail" = fails (base // { gateway = { echo = { }; other = { }; }; });
    "adapter defaults apply" = ((lib.head (force (resolve (base // { adapters.hello = { }; }))).adapters).capabilities == [{ name = "greet"; description = "Greet"; params = [ ]; argv = [ "--greeting" "hi" ]; }]);
    "unfree comes from the chosen ports" = (resolve (base // { gateway.echo = { }; })).unfree == [ "echo-server" ];
    "nothing unfree by default" = (resolve base).unfree == [ ];
    "defined adapter gets its name" = mine.name == "mine";
    "defined adapter binary is the main program" = mine.binary == "hello";
    "defined param kind defaults to string" = !fails (define [{ name = "text"; }]);
    "defined choice param is allowed" = !fails (define [{ name = "text"; kind = "choice"; choices = [ "a" ]; }]);
    "defined list param fails" = fails (define [{ name = "text"; kind = "list"; }]);
    "defined unknown key fails" = fails (base // { define.adapters.mine = { package = "hello"; packages = "x"; capabilities = [ ]; }; });
    "defined unknown kind of port fails" = fails (base // { define.gateways.mine = { }; });
    "defined and referenced name clash fails" = fails (define [ ] // { adapters.mine = { }; });
  };
in
lib.attrNames (lib.filterAttrs (_: passed: !passed) cases)
