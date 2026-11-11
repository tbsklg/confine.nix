#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
project=$(mktemp -d)
env_dir=$HOME/.zandy/envs/zandy-probe
trap 'rm -rf "$project" "$env_dir"; rmdir "$HOME/.zandy/envs" 2>/dev/null || true' EXIT

nix build --impure --print-build-logs --out-link "$project/result" --expr "
  let
    flake = builtins.getFlake \"$repo\";
    pkgs = import flake.inputs.nixpkgs { system = \"aarch64-darwin\"; };
  in
  import $repo/nix/sandbox-test.nix { inherit pkgs; inherit (flake.lib) mkSandboxEnv; }"
probe=$project/result/bin/zandy-sandbox-test

echo "--- exit code"
status=0
"$probe" sandbox-probe --exit 3 || status=$?
if [[ $status -ne 3 ]]; then
  echo "FAIL   zandy exited with $status, expected 3"
  exit 1
fi
echo "PASS   zandy passes on the exit code"

cd "$project"
git init -q
touch flake.nix .envrc
mkdir -p "$env_dir" && touch "$env_dir/zandy.toml"
CANARY_ENV=zandy-canary "$probe" sandbox-probe
