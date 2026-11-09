{ pkgs, mkSandboxEnv }:
mkSandboxEnv {
  inherit pkgs;
  name = "sandbox-test";
  preset = {
    name = "sandbox-test";
    binary = "sandbox-probe";
    packages = pkgs: [ pkgs.bash pkgs.coreutils pkgs.procps ];
    env = [ "HOME" "TMPDIR" "USER" ];
    rules = [
      { action = "allow"; operation = "process_fork"; }
      { action = "allow"; operation = "sysctl_all"; }
      { action = "allow"; operation = "file_ioctl"; }
      { action = "allow"; operation = "file_read_metadata"; }
      { action = "allow"; operation = "file_map_executable"; }
      { action = "allow"; operation = "process_info_all"; filter = { target = "same-sandbox"; }; }
      { action = "allow"; operation = "signal"; filter = { target = "same-sandbox"; }; }
      { action = "allow"; operation = "network_outbound"; filter = { remote_tcp = "*:443"; }; }
      { action = "allow"; operation = "file_all"; filter = { subpath = { param = "CWD"; }; }; }
      { action = "allow"; operation = "file_all"; filter = { literal = { literal = "/dev/null"; }; }; }
      { action = "allow"; operation = "file_read_data"; filter = { literal = { literal = "/"; }; }; }
      { action = "allow"; operation = "file_read_data"; filter = { subpath = { literal = "/private/var"; }; }; }
      { action = "allow"; operation = "file_write_all"; filter = { subpath = { param = "TMPDIR"; }; }; }
      { action = "allow"; operation = "file_read_data"; filter = { subpath = { literal = "/private/tmp"; }; }; }
      { action = "allow"; operation = "file_write_all"; filter = { subpath = { literal = "/private/tmp"; }; }; }
    ];
  };
  filesystem.allowWrite = [ ".zandy-allowed" ".envrc" ];
  packages = [ (pkgs.writeShellScriptBin "sandbox-probe" (builtins.readFile ../tests/sandbox-probe.sh)) ];
}
