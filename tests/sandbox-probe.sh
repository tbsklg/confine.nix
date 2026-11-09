#!/usr/bin/env bash
set -u

if [[ ${1-} == --exit ]]; then exit "$2"; fi

failed=0

outcome() {
  local out
  if out=$("$@" 2>&1); then echo allowed
  elif [[ $out == *"not permitted"* ]]; then echo denied
  else echo missing
  fi
}

can_read() { head -c0 -- "$1"; }
can_list() { ls -A -- "$1" >/dev/null; }
can_write() { : >"$1" && rm -f -- "$1"; }
can_mkdir() { mkdir -- "$1" && rmdir -- "$1"; }
can_rename() { mv -- "$1" "$2" && mv -- "$2" "$1"; }
can_exec() { "$1"; }
can_connect() { timeout 5 bash -c "exec 3<>/dev/tcp/$1/$2"; }
can_see_env() { ps -E -ww -o command= -p "$1" | grep -q "$2"; }

expect() {
  local want=$1 label=$2 got
  shift 2
  got=$(outcome "$@")
  if [[ $got == "$want" ]]; then echo "PASS   $want  $label"
  else echo "FAIL   $want  $label  (was: $got)"; failed=1
  fi
}

known_gap() {
  local label=$1 got
  shift
  got=$(outcome "$@")
  case $got in
    allowed) echo "OPEN   allowed $label" ;;
    denied) echo "FIXED  denied  $label  (move it to the expected checks)" ;;
    *) echo "SKIP   $label  ($got)" ;;
  esac
}

echo "--- project"
mkdir -p ./zandy-probe-dir
expect allowed "write a file in the project" can_write ./zandy-probe
expect allowed "write a file in a subdirectory" can_write ./zandy-probe-dir/zandy-probe
expect denied "write git objects" can_write ./.git/objects/zandy-probe
expect denied "write git refs" can_write ./.git/refs/heads/zandy-probe
expect denied "write flake.nix" can_write ./flake.nix
expect denied "write a dot file" can_write ./.zandy-probe
expect allowed "write a dot file in allowWrite" can_write ./.zandy-allowed
expect denied "write .envrc, even in allowWrite" can_write ./.envrc
expect denied "write .envrc in a subdirectory" can_write ./zandy-probe-dir/.envrc
expect denied "create .git in a subdirectory" can_mkdir ./zandy-probe-dir/.git
expect denied "write .git/config" can_write ./.git/config
expect denied "write .git/hooks/" can_write ./.git/hooks/zandy-probe
expect denied "write .git/ outside git data" can_write ./.git/zandy-probe
expect denied "rename .git" can_rename ./.git ./zandy-probe-git
rm -rf ./zandy-probe-dir

echo "--- secrets"
expect denied "list ~/.zandy" can_list ~/.zandy
expect denied "list ~/Library/Keychains" can_list ~/Library/Keychains
expect denied "read ~/.aws/credentials" can_read ~/.aws/credentials
expect denied "list ~/.ssh" can_list ~/.ssh
expect denied "read glab config" can_read ~/.config/glab-cli/config.yml
expect denied "read ~/canary.txt" can_read ~/canary.txt
known_gap "environment of processes outside the sandbox" can_see_env "$PPID" "${CANARY_ENV:-HOME=}"

echo "--- programs"
expect denied "run /usr/bin/true" can_exec /usr/bin/true

echo "--- shared temp"
known_gap "list /private/var/folders" can_list /private/var/folders
known_gap "write /private/tmp" can_write /private/tmp/zandy-probe

echo "--- network"
expect denied "connect to port 80" can_connect 1.1.1.1 80
known_gap "connect to any host on port 443" can_connect 1.1.1.1 443

exit $failed
