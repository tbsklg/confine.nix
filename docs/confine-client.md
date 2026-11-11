# confine-client

Call your tools from inside the sandbox.

## Synopsis

```
confine-client discover
confine-client call <method> ['<json args>']
```

## Description

`confine-client` talks to the broker of the running env. The broker runs the tool outside the sandbox, with your login, in the directory confine started in.

- `discover`: Print the methods as JSON, with their descriptions and params.
- `call <method> ['<json args>']`: Call `<adapter>.<method>` with a JSON object of params. Every param is required. On success it prints the tool's stdout; if the tool fails, its stderr.

`string` and `choice` values can't start with `-`, so they can't become options.

## Environment

- `BROKER_SOCK`, `BROKER_TICKET`: Set by confine for the session.

## Exit status

| Status | Meaning |
|---|---|
| 0 | The call succeeded |
| 1 | Another error |
| 2 | Wrong usage, args not a JSON object, or not inside a confine sandbox |
| 3 | The broker isn't running |
| 4 | The broker refused the call, or the tool failed |
| 5 | The broker speaks another protocol version |

## Examples

```sh
confine-client discover
confine-client call issues.list '{"repo":"group/name"}'
confine-client call gitlab.cli '{"args":["mr","list"]}'
```

## See also

[confine](confine.md), [confine.toml](confine.toml.md)
