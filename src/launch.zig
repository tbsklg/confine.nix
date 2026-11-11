const std = @import("std");
const macos = @import("macos.zig");
const sbpl = @import("sandbox/sbpl.zig");
const broker = @import("broker/server.zig");
const rpc = @import("broker/rpc.zig");
const registry = @import("broker/registry.zig");
const gateway = @import("gateway.zig");
const secret = @import("secret.zig");

const Env = @import("env/env.zig");
const SandboxEnv = @import("env/sandbox_env.zig");
const Preset = @import("env/manifest.zig").Preset;

const log = std.log.scoped(.zandy);

const Argv = [:null]const ?[*:0]const u8;
const Parameters = [8:null]?[*:0]const u8;

pub fn launch(init: std.process.Init, sandbox_env: SandboxEnv, user_args: []const [:0]const u8, profile: sbpl.Profile, env: Env) !u8 {
    const arena = init.arena.allocator();
    const io = init.io;
    const environ = init.environ_map;
    const manifest = sandbox_env.manifest;
    const preset = manifest.preset;

    const session = std.c.getpid();
    const started = std.Io.Clock.awake.now(io);
    const tag = try std.fmt.allocPrint(arena, "zandy-{d}", .{session});
    log.info("session {d}: env {s}, preset {s}, cwd {s}", .{ session, sandbox_env.root.path, preset.name, env.cwd });

    const command = resolveCommand(arena, sandbox_env.bin, manifest.shell, user_args) catch |err| {
        log.err("command '{s}' is not a program of the env", .{user_args[0]});
        return err;
    };

    var dir_buf: [std.fs.max_name_bytes]u8 = undefined;
    const dir_path = try broker.sessionDirPath(&dir_buf, env.home, session);
    try broker.createSocketDir(io, dir_path);
    defer broker.removeSessionDir(io, dir_path) catch |err| log.warn("session cleanup failed: {t}", .{err});

    const adapter_pipes = try materializeAdapters(arena, io, env.home, dir_path, manifest.adapters);

    var running = try startGateway(arena, io, manifest.gateway, environ, env.home, dir_path);
    defer if (running) |*r| r.stop(io);

    var sock_buf: [std.fs.max_name_bytes]u8 = undefined;
    const sock_path = try std.fmt.bufPrintZ(&sock_buf, "{s}/broker.sock", .{dir_path});
    var server = try broker.listen(io, sock_path);
    const ticket = broker.newTicket(io);

    const profile_z = try finalProfile(arena, profile, running, tag);
    const envp = try sandboxEnviron(arena, environ, preset, sandbox_env.bin, manifest.shell, sock_path, &ticket, running);
    const parameters = profileParameters(env, sock_path);

    const ctx: rpc.Context = .{ .ticket = &ticket, .registry = .{ .capabilities = try registry.parseAdapters(arena, manifest.adapters, adapter_pipes, dir_path) }, .environ = environ };

    const pid = try spawnSandboxed(profile_z, &parameters, command.path, command.argv, envp);

    const thread = try std.Thread.spawn(.{}, broker.serveLoop, .{ io, init.gpa, &server, &ctx });
    thread.detach();

    const status = waitAgent(pid) catch |err| {
        log.err("waiting for agent failed: {t}", .{err});
        return err;
    };
    logExit(status, started.untilNow(io, .awake).toMilliseconds());
    return exitCode(status);
}

fn exitCode(status: u32) u8 {
    if (std.c.W.IFEXITED(status)) return std.c.W.EXITSTATUS(status);
    if (std.c.W.IFSIGNALED(status)) return 128 +| @as(u8, @truncate(@intFromEnum(std.c.W.TERMSIG(status))));
    return 1;
}

test "exitCode passes on the agent's exit code" {
    try std.testing.expectEqual(3, exitCode(3 << 8));
}

test "exitCode reports a signal as 128 plus its number" {
    try std.testing.expectEqual(137, exitCode(9));
}

fn waitAgent(pid: std.c.pid_t) !u32 {
    var status: c_int = 0;
    while (true) {
        switch (std.posix.errno(std.c.waitpid(pid, &status, 0))) {
            .SUCCESS => return @bitCast(status),
            .INTR => continue,
            else => return error.WaitFailed,
        }
    }
}

fn logExit(status: u32, duration_ms: i64) void {
    if (std.c.W.IFEXITED(status)) {
        log.info("agent exited with {d} after {d}ms", .{ std.c.W.EXITSTATUS(status), duration_ms });
    } else if (std.c.W.IFSIGNALED(status)) {
        log.info("agent killed by {t} after {d}ms", .{ std.c.W.TERMSIG(status), duration_ms });
    } else {
        log.info("agent ended with status {d} after {d}ms", .{ status, duration_ms });
    }
}

fn materializeAdapters(arena: std.mem.Allocator, io: std.Io, home: []const u8, dir_path: []const u8, adapters: []const registry.Adapter) ![]const []const secret.Pipe {
    const adapter_pipes = try arena.alloc([]const secret.Pipe, adapters.len);
    for (adapters, adapter_pipes) |adapter, *pipes| {
        log.info("adapter {s}: secrets {f}", .{ adapter.name, secretNames(adapter.secrets) });
        pipes.* = secret.materialize(arena, io, home, try registry.dirFor(arena, dir_path, adapter), adapter.secrets, adapter.files) catch |err| {
            log.err("adapter '{s}' could not get its secrets: {t}", .{ adapter.name, err });
            return err;
        };
    }
    return adapter_pipes;
}

fn startGateway(arena: std.mem.Allocator, io: std.Io, config: ?gateway.Gateway, environ: *const std.process.Environ.Map, home: []const u8, dir_path: []const u8) !?gateway.Running {
    const c = config orelse return null;
    log.info("gateway {s}: secrets {f}", .{ c.name, secretNames(c.secrets) });
    return gateway.start(arena, io, c, environ, home, try secret.dirFor(arena, dir_path, "gateway")) catch |err| {
        log.err("gateway '{s}' could not start: {t}", .{ c.name, err });
        return err;
    };
}

fn secretNames(sources: secret.Sources) std.fmt.Alt(secret.Sources, writeSecretNames) {
    return .{ .data = sources };
}

fn writeSecretNames(sources: secret.Sources, w: *std.Io.Writer) std.Io.Writer.Error!void {
    for (sources.map.keys(), 0..) |name, i| {
        if (i > 0) try w.writeAll(", ");
        try w.writeAll(name);
    }
}

fn finalProfile(arena: std.mem.Allocator, profile: sbpl.Profile, running: ?gateway.Running, tag: []const u8) ![:0]u8 {
    const gateway_rules: []const sbpl.Rule = if (running) |r| try arena.dupe(sbpl.Rule, &.{
        sbpl.Rule.allow(.network_outbound, .{ .remote_tcp = try std.fmt.allocPrint(arena, "localhost:{d}", .{r.port}) }),
    }) else &.{};

    const final: sbpl.Profile = .{
        .rules = try std.mem.concat(arena, sbpl.Rule, &.{ profile.rules, gateway_rules }),
        .message = tag,
    };

    var aw = std.Io.Writer.Allocating.init(arena);
    try final.write(&aw.writer);

    return arena.dupeZ(u8, aw.written());
}

const Command = struct {
    path: [:0]const u8,
    argv: Argv,
};

fn resolveCommand(arena: std.mem.Allocator, bin_dir: []const u8, shell: [:0]const u8, user_args: []const [:0]const u8) !Command {
    if (user_args.len == 0) return .{ .path = shell, .argv = try buildArgv(arena, &.{shell}) };
    const name = user_args[0];
    if (name.len == 0 or std.mem.indexOfScalar(u8, name, '/') != null) return error.CommandNotInEnv;
    return .{ .path = try std.fs.path.joinZ(arena, &.{ bin_dir, name }), .argv = try buildArgv(arena, user_args) };
}

fn buildArgv(arena: std.mem.Allocator, args: []const [:0]const u8) !Argv {
    const argv = try arena.allocSentinel(?[*:0]const u8, args.len, null);
    for (args, argv) |arg, *slot| slot.* = arg.ptr;
    return argv;
}

test "resolveCommand runs the shell without a command" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();

    const command = try resolveCommand(arena_state.allocator(), "/env/sandbox/bin", "/nix/store/x-bash/bin/bash", &.{});

    try std.testing.expectEqualStrings("/nix/store/x-bash/bin/bash", command.path);
    try std.testing.expectEqual(1, command.argv.len);
}

test "resolveCommand runs the command from the env with its args" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();

    const command = try resolveCommand(arena_state.allocator(), "/env/sandbox/bin", "/bin/sh", &.{ "claude", "-p", "hi" });

    try std.testing.expectEqualStrings("/env/sandbox/bin/claude", command.path);
    try std.testing.expectEqualStrings("claude", std.mem.span(command.argv[0].?));
    try std.testing.expectEqualStrings("hi", std.mem.span(command.argv[2].?));
}

test "resolveCommand refuses a path or an empty name" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();

    try std.testing.expectError(error.CommandNotInEnv, resolveCommand(arena_state.allocator(), "/env/sandbox/bin", "/bin/sh", &.{"../../bin/sh"}));
    try std.testing.expectError(error.CommandNotInEnv, resolveCommand(arena_state.allocator(), "/env/sandbox/bin", "/bin/sh", &.{""}));
}

fn sandboxEnviron(arena: std.mem.Allocator, environ: *const std.process.Environ.Map, preset: Preset, bin_dir: []const u8, shell: []const u8, sock_path: []const u8, ticket: []const u8, running: ?gateway.Running) !Argv {
    var map = std.process.Environ.Map.init(arena);
    for (preset.env) |name| {
        if (environ.get(name)) |value| try map.put(name, value);
    }
    try map.put("PATH", bin_dir);
    try map.put("SHELL", shell);
    try map.put("BROKER_SOCK", sock_path);
    try map.put("BROKER_TICKET", ticket);
    if (running) |r| for (try gateway.environFor(arena, preset.gatewayEnv, r)) |entry| try map.put(entry.name, entry.value);
    return (try map.createPosixBlock(arena, .{})).slice;
}

fn profileParameters(env: Env, sock_path: [:0]const u8) Parameters {
    return .{
        "CWD",         env.cwd.ptr,
        "HOME",        env.home.ptr,
        "TMPDIR",      env.tmpdir.ptr,
        "BROKER_SOCK", sock_path.ptr,
    };
}

fn spawnSandboxed(profile: [:0]const u8, parameters: *const Parameters, path: [:0]const u8, argv: Argv, envp: Argv) !std.c.pid_t {
    const pid = std.c.fork();
    if (pid == -1) return error.ForkFailed;
    if (pid != 0) return pid;

    var errbuf: ?[*:0]u8 = null;
    const rc = macos.sandbox_init_with_parameters(profile.ptr, 0, parameters, &errbuf);
    defer if (errbuf) |buf| macos.sandbox_free_error(buf);

    if (rc != 0) {
        if (errbuf) |buf| {
            const msg = std.mem.span(buf);
            _ = std.c.write(2, "sandbox initialization failed: ", 31);
            _ = std.c.write(2, msg.ptr, msg.len);
            _ = std.c.write(2, "\n", 1);
        }
        std.c._exit(1);
    }

    _ = std.c.execve(path.ptr, argv.ptr, envp.ptr);
    std.c._exit(127);
}
