const std = @import("std");

pub fn listen(io: std.Io, port: u16) !std.Io.net.Server {
    const address = try std.Io.net.IpAddress.parseIp4("127.0.0.1", port);

    var server = try address.listen(io, .{});
    errdefer server.deinit(io);

    return server;
}

const log = std.log.scoped(.proxy);

const accept_retry_delay: std.Io.Duration = .fromMilliseconds(100);

pub fn serve(io: std.Io, server: *std.Io.net.Server) !void {
    var tunnels: std.Io.Group = .init;
    defer tunnels.cancel(io);

    while (true) {
        const conn = server.accept(io) catch |err| switch (err) {
            error.Canceled, error.SocketNotListening => return err,
            else => {
                log.warn("accept: {t}", .{err});
                try io.sleep(accept_retry_delay, .awake);
                continue;
            },
        };
        tunnels.concurrent(io, tunnel, .{ io, conn }) catch |err| {
            log.warn("{t}", .{err});
            conn.close(io);
        };
    }
}

const max_head_len = 8 * 1024;
const head_timeout: std.Io.Duration = .fromSeconds(10);

fn tunnel(io: std.Io, conn: std.Io.net.Stream) void {
    defer conn.close(io);
    const started = std.Io.Clock.awake.now(io);

    var reader_buf: [max_head_len]u8 = undefined;
    var writer_buf: [1024]u8 = undefined;

    var reader = conn.reader(io, &reader_buf);
    var writer = conn.writer(io, &writer_buf);

    var watchdog = io.concurrent(hangUpAfter, .{ io, conn, head_timeout }) catch |err| {
        log.warn("{t}", .{err});
        return;
    };
    var http = std.http.Server.init(&reader.interface, &writer.interface);
    const request = http.receiveHead();
    watchdog.cancel(io);

    const head = (request catch |err| {
        if (err == error.HttpHeadersOversize) reply(&writer.interface, .request_header_fields_too_large);
        log.info("no head: {t}, {d}ms", .{ err, elapsed(io, started) });
        return;
    }).head;

    if (head.method != .CONNECT) {
        reply(&writer.interface, .method_not_allowed);
        log.info("{t} 405, {d}ms", .{ head.method, elapsed(io, started) });
        return;
    }

    const parsed = parseTarget(head.target) catch |err| {
        reply(&writer.interface, .bad_request);
        log.info("CONNECT 400 {t}, {d}ms", .{ err, elapsed(io, started) });
        return;
    };
    var host_buf: [max_host_len]u8 = undefined;
    const target: Target = .{ .host = host_buf[0..parsed.host.len], .port = parsed.port };
    @memcpy(host_buf[0..parsed.host.len], parsed.host);

    const upstream = dial(io, target) catch |err| {
        reply(&writer.interface, .bad_gateway);
        log.info("CONNECT {s}:{d} 502 {t}, {d}ms", .{ target.host, target.port, err, elapsed(io, started) });
        return;
    };
    defer upstream.close(io);
    reply(&writer.interface, .ok);
    log.info("CONNECT {s}:{d} 200, {d}ms", .{ target.host, target.port, elapsed(io, started) });

    var upstream_reader_buf: [16 * 1024]u8 = undefined;
    var upstream_writer_buf: [16 * 1024]u8 = undefined;

    var upstream_reader = upstream.reader(io, &upstream_reader_buf);
    var upstream_writer = upstream.writer(io, &upstream_writer_buf);

    var sending = io.concurrent(pipe, .{ io, &reader.interface, &upstream_writer.interface, upstream }) catch |err| {
        log.warn("{t}", .{err});
        return;
    };
    const received = pipe(io, &upstream_reader.interface, &writer.interface, conn);
    const sent = sending.await(io);

    log.info("CONNECT {s}:{d} closed, sent {d}, received {d} bytes, {d}ms", .{ target.host, target.port, sent, received, elapsed(io, started) });
}

fn hangUpAfter(io: std.Io, conn: std.Io.net.Stream, duration: std.Io.Duration) void {
    io.sleep(duration, .awake) catch return;
    conn.shutdown(io, .both) catch {};
}

fn reply(w: *std.Io.Writer, status: std.http.Status) void {
    const written = if (status == .ok)
        w.writeAll("HTTP/1.1 200 Connection Established\r\n\r\n")
    else
        w.print("HTTP/1.1 {d} {s}\r\nconnection: close\r\ncontent-length: 0\r\n\r\n", .{ @intFromEnum(status), status.phrase() orelse "" });
    written catch return;
    w.flush() catch {};
}

fn elapsed(io: std.Io, started: std.Io.Timestamp) i64 {
    return started.untilNow(io, .awake).toMilliseconds();
}

fn pipe(io: std.Io, from: *std.Io.Reader, to: *std.Io.Writer, to_stream: std.Io.net.Stream) usize {
    defer to_stream.shutdown(io, .send) catch {};

    var total: usize = 0;
    while (true) {
        total += from.stream(to, .unlimited) catch return total;
        to.flush() catch return total;
    }
}

fn dial(io: std.Io, target: Target) !std.Io.net.Stream {
    if (std.Io.net.IpAddress.parse(target.host, target.port)) |address| {
        return address.connect(io, .{ .mode = .stream });
    } else |_| {}
    const host = try std.Io.net.HostName.init(target.host);
    return host.connect(io, target.port, .{ .mode = .stream });
}

const max_host_len = 255;

pub const Target = struct {
    host: []const u8,
    port: u16,
};

pub fn parseTarget(target: []const u8) !Target {
    const colon = std.mem.lastIndexOfScalar(u8, target, ':') orelse return error.MissingPort;
    const host = try parseHost(target[0..colon]);
    const port = std.fmt.parseInt(u16, target[colon + 1 ..], 10) catch return error.InvalidPort;
    if (port == 0) return error.InvalidPort;
    return .{ .host = host, .port = port };
}

fn parseHost(text: []const u8) ![]const u8 {
    if (std.mem.startsWith(u8, text, "[")) {
        if (text.len < 3 or text.len > max_host_len + 2 or !std.mem.endsWith(u8, text, "]")) return error.InvalidHost;
        return text[1 .. text.len - 1];
    }
    if (text.len == 0 or text.len > max_host_len or std.mem.indexOfScalar(u8, text, ':') != null) return error.InvalidHost;
    return text;
}

test "parseTarget splits host and port" {
    const target = try parseTarget("example.com:443");
    try std.testing.expectEqualStrings("example.com", target.host);
    try std.testing.expectEqual(443, target.port);
}

test "parseTarget takes an IPv6 host out of its brackets" {
    const target = try parseTarget("[::1]:443");
    try std.testing.expectEqualStrings("::1", target.host);
    try std.testing.expectEqual(443, target.port);
}

test "parseTarget refuses a missing or invalid port" {
    try std.testing.expectError(error.MissingPort, parseTarget("example.com"));
    try std.testing.expectError(error.InvalidPort, parseTarget("example.com:"));
    try std.testing.expectError(error.InvalidPort, parseTarget("example.com:https"));
    try std.testing.expectError(error.InvalidPort, parseTarget("example.com:65536"));
    try std.testing.expectError(error.InvalidPort, parseTarget("example.com:-1"));
    try std.testing.expectError(error.InvalidPort, parseTarget("example.com:0"));
}

test "parseTarget refuses an empty or malformed host" {
    try std.testing.expectError(error.InvalidHost, parseTarget(":443"));
    try std.testing.expectError(error.InvalidHost, parseTarget("[]:443"));
    try std.testing.expectError(error.InvalidHost, parseTarget("[::1:443"));
    try std.testing.expectError(error.InvalidHost, parseTarget("::1:443"));
    try std.testing.expectError(error.InvalidHost, parseTarget("[::1]"));
    try std.testing.expectError(error.InvalidHost, parseTarget("a" ** 256 ++ ":443"));
}
