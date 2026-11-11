## packages



Extra packages on the sandbox ` PATH `, e\.g\. the project’s toolchain\.



*Type:*
list of package



*Default:*

```nix
[ ]
```



*Example:*

```nix
[ pkgs.ripgrep ]
```



## adapters

Tools the broker runs outside the sandbox on the program’s behalf\. Their packages must not be in ` packages `\.



*Type:*
list of function that evaluates to a(n) (attribute set)



*Default:*

```nix
[ ]
```



*Example:*

```nix
[ say ]
```



## filesystem\.allowRead



Extra paths the program may read\. Absolute, relative to the working directory, or starting with ` ~ `\.



*Type:*
list of string



*Default:*

```nix
[ ]
```



## filesystem\.allowWrite



Extra paths the program may write\. Absolute, relative to the working directory, or starting with ` ~ `\.



*Type:*
list of string



*Default:*

```nix
[ ]
```



## filesystem\.denyRead



Paths the program may not read\. Absolute, relative to the working directory, or starting with ` ~ `\.



*Type:*
list of string



*Default:*

```nix
[ ]
```



## filesystem\.denyWrite



Paths the program may not write\. Absolute, relative to the working directory, or starting with ` ~ `\.



*Type:*
list of string



*Default:*

```nix
[ ]
```



## gateway



A proxy to one API that adds its credential outside the sandbox\.



*Type:*
null or (function that evaluates to a(n) (attribute set))



*Default:*

```nix
null
```



*Example:*

```nix
ports.gateways.bedrock { profile = "acme-bedrock"; region = "eu-west-1"; }
```



## name



Name of the sandbox env; the launcher becomes ` bin/zandy-<name> `\.



*Type:*
string matching the pattern \[a-z0-9-]+



*Example:*

```nix
"claude"
```



## preset



The sandbox rules and packages an app needs, e\.g\. ` ports.presets.claude ` from zandy-ports\.



*Type:*
submodule



## preset\.packages



Packages the app needs, given ` pkgs `\.



*Type:*
function that evaluates to a(n) list of package



## preset\.env



Names of the environment variables passed into the sandbox\.



*Type:*
list of string



*Default:*

```nix
[ ]
```



## preset\.gatewayEnv



Env vars the app gets per gateway name, or a function of the gateway; ` {url} ` becomes the gateway’s address\.



*Type:*
attribute set of ((attribute set of string) or function that evaluates to a(n) attribute set of string)



*Default:*

```nix
{ }
```



## preset\.icon



Symbol shown in the start banner\.



*Type:*
string



*Default:*

```nix
""
```



## preset\.name



Name of the preset\.



*Type:*
string



## preset\.rules



SBPL rules the app needs\.



*Type:*
list of (attribute set)



*Default:*

```nix
[ ]
```


