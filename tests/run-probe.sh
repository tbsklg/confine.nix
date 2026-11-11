#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
project=$(mktemp -d)
env_dir=$HOME/.confine/envs/confine-probe
trap 'rm -rf "$project" "$env_dir"; rmdir "$HOME/.confine/envs" 2>/dev/null || true' EXIT

nix build --impure --print-build-logs --out-link "$project/result" --expr "
  let
    flake = builtins.getFlake \"$repo\";
    pkgs = import flake.inputs.nixpkgs { system = \"aarch64-darwin\"; };
  in
  import $repo/nix/sandbox-test.nix { inherit pkgs; inherit (flake.lib) mkSandboxEnv; }"
probe=$project/result/bin/confine-sandbox-test

echo "--- exit code"
status=0
"$probe" sandbox-probe --exit 3 || status=$?
if [[ $status -ne 3 ]]; then
  echo "FAIL   confine exited with $status, expected 3"
  exit 1
fi
echo "PASS   confine passes on the exit code"

cd "$project"
git init -q
touch flake.nix .envrc
mkdir -p "$env_dir" && touch "$env_dir/confine.toml"
CANARY_ENV=confine-canary "$probe" sandbox-probe
