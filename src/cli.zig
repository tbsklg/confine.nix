const std = @import("std");

pub const Command = union(enum) {
    launch: Launch,
    config: []const u8,
    secret: []const u8,
};

pub const Launch = struct {
    env: []const u8,
    args: []const [:0]const u8,
};

pub fn parseArgs(args: []const [:0]const u8) !Command {
    if (args.len < 2) return error.NoEnv;
    if (std.mem.eql(u8, args[1], "--help")) return error.Help;
    if (std.mem.eql(u8, args[1], "secret")) {
        if (args.len != 4 or !std.mem.eql(u8, args[2], "set")) return error.NoService;
        return .{ .secret = args[3] };
    }
    if (std.mem.eql(u8, args[1], "config")) {
        if (args.len != 4 or !std.mem.eql(u8, args[2], "--env")) return error.NoEnv;
        return .{ .config = args[3] };
    }
    if (!std.mem.eql(u8, args[1], "--env")) return error.NoEnv;
    if (args.len < 3) return error.NoEnv;
    if (args.len == 4 and std.mem.eql(u8, args[3], "--confine-config")) return .{ .config = args[2] };
    if (args.len == 5 and std.mem.eql(u8, args[3], "--confine-secret")) return .{ .secret = args[4] };

    return .{ .launch = .{ .env = args[2], .args = args[3..] } };
}

pub const usage =
    \\usage: confine --env <drv> [args...]
    \\       confine config --env <drv>    show the manifest and the methods the agent sees
    \\       confine-<name> --confine-config the same, from the launcher
    \\       confine secret set <service>  store a secret in ~/.confine/confine.keychain-db
    \\       confine-<name> --confine-secret <service>
    \\                                   the same, from the launcher
    \\
    \\  <drv>  sandbox env built by confine.lib.mkSandboxEnv, e.g. ./result
    \\         usually started with its launcher confine-<name> or `nix run`
    \\
;

test "returns error when --env is missing" {
    const args = [_][:0]const u8{ "confine", "claude" };

    try std.testing.expectError(error.NoEnv, parseArgs(&args));
}

test "returns error when --env has no value" {
    const args = [_][:0]const u8{ "confine", "--env" };

    try std.testing.expectError(error.NoEnv, parseArgs(&args));
}

test "returns env and passes args through" {
    const args = [_][:0]const u8{ "confine", "--env", "./result", "-p", "hi" };

    const parsed = try parseArgs(&args);

    try std.testing.expectEqualStrings("./result", parsed.launch.env);
    try std.testing.expectEqual(2, parsed.launch.args.len);
    try std.testing.expectEqualStrings("-p", parsed.launch.args[0]);
}

test "returns config command with its env" {
    const args = [_][:0]const u8{ "confine", "config", "--env", "./result" };

    try std.testing.expectEqualStrings("./result", (try parseArgs(&args)).config);
}

test "returns config command for --confine-config from the launcher" {
    const args = [_][:0]const u8{ "confine", "--env", "./result", "--confine-config" };

    try std.testing.expectEqualStrings("./result", (try parseArgs(&args)).config);
}

test "returns error when config has no env" {
    const args = [_][:0]const u8{ "confine", "config" };

    try std.testing.expectError(error.NoEnv, parseArgs(&args));
}

test "returns help for --help" {
    const long = [_][:0]const u8{ "confine", "--help" };
    try std.testing.expectError(error.Help, parseArgs(&long));
}

test "returns secret command with its service" {
    const args = [_][:0]const u8{ "confine", "secret", "set", "gitlab-token" };

    try std.testing.expectEqualStrings("gitlab-token", (try parseArgs(&args)).secret);
}

test "returns secret command for --confine-secret from the launcher" {
    const args = [_][:0]const u8{ "confine", "--env", "./result", "--confine-secret", "gitlab-token" };

    try std.testing.expectEqualStrings("gitlab-token", (try parseArgs(&args)).secret);
}

test "returns error when secret set has no service" {
    const args = [_][:0]const u8{ "confine", "secret", "set" };

    try std.testing.expectError(error.NoService, parseArgs(&args));
}
