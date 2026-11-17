const std = @import("std");
const server = @import("server.zig");

const Args = struct {
    port: u16,
};

pub fn main(init: std.process.Init) !void {
    const args = try parseArgs(init.minimal.args);

    var _server = try server.listen(init.io, args.port);
    try server.serve(init.io, &_server);
}

fn parseArgs(args: std.process.Args) !Args {
    var iter = args.iterate();
    _ = iter.next();

    const port: u16 = while (iter.next()) |arg| {
        if (std.mem.eql(u8, "--port", arg)) {
            const port = iter.next().?;
            break try std.fmt.parseInt(u16, port, 10);
        }
    } else return error.NoPortProvided;

    return .{
        .port = port,
    };
}
