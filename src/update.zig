const std = @import("std");
const init = @import("init.zig");

const fail = init.fail;

pub const release_notes = "https://tbsklg.github.io/confine.nix/release-notes/";

/// Pulls newer confine and ports into `~/.confine/envs/<name>`, upgrades only that env's profile entry
/// and rebuilds its schema. Refuses while `confine.toml` has changes that aren't applied, since Nix would
/// apply them too; restores the old `flake.lock` if a step fails.
pub fn run(arena: std.mem.Allocator, io: std.Io, environ: *std.process.Environ.Map, name: []const u8) !void {
    var dir = try openEnv(arena, io, environ, name);
    defer dir.close(io);

    const installed = (installedPath(arena, io, name) catch |err| report(name, err)) orelse
        fail("confine-{s} isn't installed; run `confine apply {s}`", .{ name, name });
    const configured = configuredPath(arena, io, dir) catch |err| report(name, err);
    if (!std.mem.eql(u8, installed, configured))
        fail("~/.confine/envs/{s}/confine.toml has changes that aren't applied; run `confine apply {s}` first", .{ name, name });

    const old = try dir.readFileAlloc(io, "flake.lock", arena, .unlimited);
    init.nix(io, dir, &.{ "nix", "flake", "update" }) catch |err| return restore(io, dir, old, name, err);
    const new = try dir.readFileAlloc(io, "flake.lock", arena, .unlimited);

    const changed = try changes(arena, old, new);
    if (changed.len == 0) {
        std.debug.print("confine: confine-{s} is up to date\n", .{name});
        return;
    }
    init.nix(io, dir, &.{ "nix", "profile", "upgrade", name }) catch |err| return restore(io, dir, old, name, err);
    init.nix(io, dir, &.{ "nix", "build", ".#schema", "-o", "confine.schema.json" }) catch fail("updated confine-{s}, but its schema failed to build", .{name});

    std.debug.print("confine: updated confine-{s}\n", .{name});
    for (changed) |change| std.debug.print("  {s:<8} {s} → {s}\n", .{ change.input, change.old, change.new });
    std.debug.print("Release notes: {s}\n", .{release_notes});
}

/// Builds `~/.confine/envs/<name>` from its `confine.toml` with the versions it already has, and installs it.
pub fn apply(arena: std.mem.Allocator, io: std.Io, environ: *std.process.Environ.Map, name: []const u8) !void {
    var dir = try openEnv(arena, io, environ, name);
    defer dir.close(io);

    const installed = installedPath(arena, io, name) catch |err| report(name, err);
    const configured = configuredPath(arena, io, dir) catch |err| report(name, err);
    if (installed) |path| if (std.mem.eql(u8, path, configured)) {
        std.debug.print("confine: confine-{s} already matches its confine.toml\n", .{name});
        return;
    };

    const argv: []const []const u8 = if (installed == null) &.{ "nix", "profile", init.profileAdd(io), "." } else &.{ "nix", "profile", "upgrade", name };
    init.nix(io, dir, argv) catch |err| report(name, err);
    std.debug.print("confine: applied ~/.confine/envs/{s}/confine.toml to confine-{s}\n", .{ name, name });
}

fn openEnv(arena: std.mem.Allocator, io: std.Io, environ: *std.process.Environ.Map, name: []const u8) !std.Io.Dir {
    if (!init.validName(name)) fail("'{s}' is not an env name: use a-z, 0-9 and -", .{name});
    const home = environ.get("HOME") orelse return error.NoHome;
    const path = try std.fs.path.join(arena, &.{ home, ".confine", "envs", name });
    return std.Io.Dir.openDirAbsolute(io, path, .{}) catch |err| switch (err) {
        error.FileNotFound => fail("no env ~/.confine/envs/{s}; create it with `confine init {s}`", .{ name, name }),
        else => err,
    };
}

/// The store path of the env's entry in the Nix profile, or null if it isn't installed.
fn installedPath(arena: std.mem.Allocator, io: std.Io, name: []const u8) !?[]const u8 {
    return parseInstalled(arena, try output(arena, io, null, &.{ "nix", "profile", "list", "--json" }), name);
}

/// The store path `confine.toml` builds to now, from evaluation alone.
fn configuredPath(arena: std.mem.Allocator, io: std.Io, dir: std.Io.Dir) ![]const u8 {
    return std.mem.trim(u8, try output(arena, io, dir, &.{ "nix", "eval", "--raw", ".#default.outPath" }), "\n");
}

fn output(arena: std.mem.Allocator, io: std.Io, dir: ?std.Io.Dir, argv: []const []const u8) ![]const u8 {
    const result = std.process.run(arena, io, .{ .argv = argv, .cwd = if (dir) |d| .{ .dir = d } else .inherit }) catch |err| switch (err) {
        error.FileNotFound => return error.NixNotFound,
        else => return err,
    };
    if (result.term != .exited or result.term.exited != 0) {
        std.debug.print("{s}", .{result.stderr});
        return error.NixFailed;
    }
    return result.stdout;
}

fn parseInstalled(arena: std.mem.Allocator, json: []const u8, name: []const u8) !?[]const u8 {
    const profile = try std.json.parseFromSliceLeaky(std.json.Value, arena, json, .{});
    const elements = profile.object.get("elements") orelse return null;
    if (elements != .object) return null;
    const element = elements.object.get(name) orelse return null;
    const paths = element.object.get("storePaths") orelse return null;
    if (paths != .array or paths.array.items.len == 0 or paths.array.items[0] != .string) return null;
    return paths.array.items[0].string;
}

fn restore(io: std.Io, dir: std.Io.Dir, old: []const u8, name: []const u8, err: anyerror) !void {
    dir.writeFile(io, .{ .sub_path = "flake.lock", .data = old }) catch {};
    report(name, err);
}

fn report(name: []const u8, err: anyerror) noreturn {
    switch (err) {
        error.NixNotFound => fail("nix not found; confine needs Nix with flakes: https://nixos.org/download", .{}),
        error.NixFailed => fail("nix failed; confine-{s} is unchanged", .{name}),
        else => fail("{t}; confine-{s} is unchanged", .{ err, name }),
    }
}

const Change = struct { input: []const u8, old: []const u8, new: []const u8 };

/// The env's direct inputs whose locked revision moved, with short revisions.
fn changes(arena: std.mem.Allocator, old_lock: []const u8, new_lock: []const u8) ![]const Change {
    const old = try std.json.parseFromSliceLeaky(std.json.Value, arena, old_lock, .{});
    const new = try std.json.parseFromSliceLeaky(std.json.Value, arena, new_lock, .{});
    var list: std.ArrayList(Change) = .empty;
    var inputs = (try rootInputs(new)).iterator();
    while (inputs.next()) |input| {
        const node = switch (input.value_ptr.*) {
            .string => |node| node,
            else => continue, // follows another input
        };
        const new_rev = rev(new, node) orelse continue;
        const old_rev = rev(old, node) orelse "none";
        if (std.mem.eql(u8, old_rev, new_rev)) continue;
        try list.append(arena, .{ .input = input.key_ptr.*, .old = short(old_rev), .new = short(new_rev) });
    }
    return list.items;
}

fn rootInputs(lock: std.json.Value) !std.json.ObjectMap {
    const nodes = lock.object.get("nodes") orelse return error.InvalidLock;
    const root = nodes.object.get("root") orelse return error.InvalidLock;
    const inputs = root.object.get("inputs") orelse return error.InvalidLock;
    return inputs.object;
}

fn rev(lock: std.json.Value, node: []const u8) ?[]const u8 {
    const entry = lock.object.get("nodes").?.object.get(node) orelse return null;
    const locked = entry.object.get("locked") orelse return null;
    const value = locked.object.get("rev") orelse return null;
    return if (value == .string) value.string else null;
}

fn short(full: []const u8) []const u8 {
    return full[0..@min(full.len, 7)];
}

fn lockWith(comptime confine_rev: []const u8, comptime ports_rev: []const u8) []const u8 {
    return
    \\{"nodes":{
    \\ "confine":{"locked":{"rev":"
    ++ confine_rev ++
        \\"}},
        \\ "ports":{"inputs":{"confine":["confine"]},"locked":{"rev":"
    ++ ports_rev ++
        \\"}},
        \\ "root":{"inputs":{"confine":"confine","ports":"ports"}}},
        \\ "root":"root","version":7}
    ;
}

test "reports nothing when no input moved" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const lock = lockWith("c25035d4f160", "aa4b1fd23d0f");

    try std.testing.expectEqual(0, (try changes(arena_state.allocator(), lock, lock)).len);
}

test "reports each moved input with short revisions" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();

    const changed = try changes(arena_state.allocator(), lockWith("c25035d4f160", "aa4b1fd23d0f"), lockWith("a994890aaaaa", "aa4b1fd23d0f"));

    try std.testing.expectEqual(1, changed.len);
    try std.testing.expectEqualStrings("confine", changed[0].input);
    try std.testing.expectEqualStrings("c25035d", changed[0].old);
    try std.testing.expectEqualStrings("a994890", changed[0].new);
}

test "rejects a lock without a root" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();

    try std.testing.expectError(error.InvalidLock, changes(arena_state.allocator(), "{\"nodes\":{}}", "{\"nodes\":{}}"));
}

test "finds the store path of an installed env" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const json =
        \\{"elements":{"dev":{"storePaths":["/nix/store/ap08z9l-dev"]}},"version":3}
    ;

    try std.testing.expectEqualStrings("/nix/store/ap08z9l-dev", (try parseInstalled(arena_state.allocator(), json, "dev")).?);
    try std.testing.expectEqual(null, try parseInstalled(arena_state.allocator(), json, "work"));
}
