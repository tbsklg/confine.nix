const std = @import("std");
const template = @import("template");

pub const default_name = "dev";

/// Creates `~/.confine/envs/<name>` from the template, builds its schema and adds it to the Nix profile.
/// Refuses an env that exists; removes what it created if a step fails, so it can be run again.
pub fn run(arena: std.mem.Allocator, io: std.Io, environ: *std.process.Environ.Map, name: []const u8) !void {
    if (!validName(name)) fail("'{s}' is not an env name: use a-z, 0-9 and -", .{name});
    const home = environ.get("HOME") orelse return error.NoHome;
    const envs = try std.fs.path.join(arena, &.{ home, ".confine", "envs" });
    const path = try std.fs.path.join(arena, &.{ envs, name });
    const shown = try std.fmt.allocPrint(arena, "~/.confine/envs/{s}", .{name});

    try std.Io.Dir.cwd().createDirPath(io, envs);
    std.Io.Dir.createDirAbsolute(io, path, .default_dir) catch |err| switch (err) {
        error.PathAlreadyExists => fail("{s} exists; edit its confine.toml, or remove it to start over", .{shown}),
        else => return err,
    };
    var dir = try std.Io.Dir.openDirAbsolute(io, path, .{});
    defer dir.close(io);

    write(arena, io, dir, name) catch |err| return undo(io, path, err);
    nix(io, dir, &.{ "nix", "build", ".#schema", "-o", "confine.schema.json" }) catch |err| return undo(io, path, err);
    nix(io, dir, &.{ "nix", "profile", profileAdd(io), "." }) catch |err| return undo(io, path, err);

    std.debug.print(
        \\confine: installed confine-{s}
        \\
        \\  cd your-project && confine-{s}
        \\
        \\opens a shell in the sandbox. Add what your program needs to packages in
        \\{s}/confine.toml, then run `nix profile upgrade --all`.
        \\
    , .{ name, name, shown });
}

fn write(arena: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, name: []const u8) !void {
    try dir.writeFile(io, .{ .sub_path = "flake.nix", .data = template.flake });
    try dir.writeFile(io, .{ .sub_path = "confine.toml", .data = try configFor(arena, name) });
}

fn nix(io: std.Io, dir: std.Io.Dir, argv: []const []const u8) !void {
    var child = std.process.spawn(io, .{ .argv = argv, .cwd = .{ .dir = dir }, .stdin = .ignore }) catch |err| switch (err) {
        error.FileNotFound => return error.NixNotFound,
        else => return err,
    };
    const term = try child.wait(io);
    if (term != .exited or term.exited != 0) return error.NixFailed;
}

/// Nix renamed `profile install` to `profile add`; the old name warns on new Nix and the new one fails on old Nix.
fn profileAdd(io: std.Io) []const u8 {
    var child = std.process.spawn(io, .{ .argv = &.{ "nix", "profile", "add", "--help" }, .stdin = .ignore, .stdout = .ignore, .stderr = .ignore }) catch return "install";
    const term = child.wait(io) catch return "install";
    return if (term == .exited and term.exited == 0) "add" else "install";
}

fn undo(io: std.Io, path: []const u8, err: anyerror) !void {
    std.Io.Dir.cwd().deleteTree(io, path) catch {};
    switch (err) {
        error.NixNotFound => fail("nix not found; confine needs Nix with flakes: https://nixos.org/download", .{}),
        error.NixFailed => fail("nix failed; nothing was installed", .{}),
        else => return err,
    }
}

fn fail(comptime format: []const u8, args: anytype) noreturn {
    std.debug.print("confine: " ++ format ++ "\n", args);
    std.process.exit(1);
}

fn configFor(arena: std.mem.Allocator, name: []const u8) ![]const u8 {
    const line = "name = \"" ++ default_name ++ "\"";
    return std.mem.replaceOwned(u8, arena, template.config, line, try std.fmt.allocPrint(arena, "name = \"{s}\"", .{name}));
}

/// The name becomes a directory and the launcher `confine-<name>`.
fn validName(name: []const u8) bool {
    if (name.len == 0 or name[0] == '-') return false;
    for (name) |c| switch (c) {
        'a'...'z', '0'...'9', '-' => {},
        else => return false,
    };
    return true;
}

test "accepts lowercase names with digits and dashes" {
    try std.testing.expect(validName("dev"));
    try std.testing.expect(validName("work-2"));
}

test "rejects names that are not a plain launcher suffix" {
    try std.testing.expect(!validName(""));
    try std.testing.expect(!validName("-dev"));
    try std.testing.expect(!validName("../dev"));
    try std.testing.expect(!validName("Dev"));
}

test "sets the env name in the template config" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();

    const config = try configFor(arena_state.allocator(), "work");

    try std.testing.expect(std.mem.indexOf(u8, config, "name = \"work\"\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, config, "name = \"dev\"") == null);
}

test "writes the template into the env directory" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try write(arena_state.allocator(), std.testing.io, tmp.dir, "work");

    const flake = try tmp.dir.readFileAlloc(std.testing.io, "flake.nix", arena_state.allocator(), .unlimited);
    try std.testing.expectEqualStrings(template.flake, flake);
    const config = try tmp.dir.readFileAlloc(std.testing.io, "confine.toml", arena_state.allocator(), .unlimited);
    try std.testing.expect(std.mem.indexOf(u8, config, "name = \"work\"") != null);
}
