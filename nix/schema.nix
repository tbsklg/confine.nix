lib: catalog:
let
  options = (lib.evalModules { modules = [ ./options.nix ]; }).options;

  strings = description: { type = "array"; items.type = "string"; inherit description; };
  object = required: properties: { type = "object"; additionalProperties = false; inherit required properties; };
  arg = spec:
    (if spec.type == "list" then strings spec.description else { type = "string"; inherit (spec) description; })
    // lib.optionalAttrs (spec ? default) { inherit (spec) default; }
    // lib.optionalAttrs (spec ? example) { examples = [ spec.example ]; };
  table = ports: {
    type = "object";
    additionalProperties = false;
    properties = lib.mapAttrs
      (_: port: {
        type = "object";
        description = port.description + lib.optionalString (port.open or false) ". Open: the agent can run any command and make the tool print its credential.";
        additionalProperties = false;
        properties = lib.mapAttrs (_: arg) port.args;
        required = lib.attrNames (lib.filterAttrs (_: spec: !(spec ? default)) port.args);
      })
      ports;
  };

  schema = {
    "$schema" = "http://json-schema.org/draft-07/schema#";
    title = "zandy.toml";
    type = "object";
    additionalProperties = false;
    required = [ "name" "preset" ];
    properties = {
      name = { type = "string"; pattern = "^[a-z0-9-]+$"; inherit (options.name) description; };
      preset = {
        description = "The program to run.";
        oneOf = lib.mapAttrsToList (name: port: { const = name; inherit (port) description; }) catalog.presets;
      };
      packages = strings "Extra packages on the sandbox PATH, by nixpkgs attribute, e.g. ripgrep or python3Packages.pytest.";
      gateway = table catalog.gateways // { maxProperties = 1; description = "The model backend, at most one."; };
      adapters = table catalog.adapters // { description = "Tools the broker runs outside the sandbox on the agent's behalf."; };
      define = {
        type = "object";
        additionalProperties = false;
        description = "Your own ports.";
        properties.adapters = {
          type = "object";
          description = "Your own adapters, enabled by defining them.";
          additionalProperties = object [ "package" "capabilities" ] {
            package = { type = "string"; description = "The tool, by nixpkgs attribute."; };
            binary = { type = "string"; description = "The program in the package's bin, if not its main program."; };
            env = strings "Env vars passed on from the shell that started zandy. Not for secrets.";
            setEnv = { type = "object"; additionalProperties.type = "string"; description = "Env vars set for the command."; };
            capabilities = {
              type = "array";
              description = "The methods the agent can call, as <adapter>.<name>.";
              items = object [ "name" "description" "argv" ] {
                name = { type = "string"; description = "Method name."; };
                description = { type = "string"; description = "What the method does, shown to the agent."; };
                params = {
                  type = "array";
                  items = object [ "name" "description" ] {
                    name = { type = "string"; description = "Param name, used as {name} in argv."; };
                    kind = { enum = [ "string" "choice" ]; default = "string"; description = "string or choice; values can't start with -."; };
                    description = { type = "string"; description = "What the param is, shown to the agent."; };
                    choices = strings "The allowed values of a choice.";
                  };
                };
                argv = strings "Arguments to the tool. Each is a literal or a whole {param}.";
              };
            };
          };
        };
      };
      filesystem = {
        type = "object";
        additionalProperties = false;
        properties = lib.mapAttrs (_: option: strings option.description) (lib.removeAttrs options.filesystem [ "_type" ]);
      };
    };
  };
in
schema
