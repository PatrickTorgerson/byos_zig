const std = @import("std");
const gen = @import("image-gen.zig");

const friendly_id = "2EE08C";
const api_key = "MnuhaudSb-PTgBueN7y62Q";
const setup_img = "https://usetrmnl.com/images/setup/setup-logo.bmp";

const Font = @import("Font.zig");
const Server = @This();
const log = std.log.scoped(.server);

/// date
/// battery
/// reminders : custom
/// routine : custom
///
/// weather : https://openweathermap.org/current
/// spanish vocab : ??
/// riddle : https://riddles-api.vercel.app/
/// cpu temps : https://stackoverflow.com/questions/23314886/get-cpu-temperature
/// github commits : https://wakatime.com/developers
pub fn main() !void {
    try Font.initFreeType();
    defer Font.deinitFreeType();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var server = Server.init(gpa.allocator());
    defer server.deinit();
    try server.run();
}

allocator: std.mem.Allocator,
log_arena: std.heap.ArenaAllocator,

pub fn init(allocator: std.mem.Allocator) Server {
    return .{
        .allocator = allocator,
        .log_arena = std.heap.ArenaAllocator.init(allocator),
    };
}

pub fn deinit(self: Server) void {
    self.log_arena.deinit();
}

pub fn run(self: *Server) !void {
    var http_buffer: [4096]u8 = undefined;
    var bmp_buffer: [50000]u8 = undefined;

    const server_addr = try std.net.Address.parseIp("192.168.0.21", 2300);
    var listener = try server_addr.listen(.{ .reuse_address = true });
    defer listener.deinit();
    log.info("starting server on {}", .{server_addr});

    while (listener.accept()) |conn| {
        defer conn.stream.close();
        log.info("Accepted connection from: {}", .{conn.address});
        var http = std.http.Server.init(conn, &http_buffer);
        var request = try http.receiveHead();

        log.info("request at {} {s}", .{ request.head.method, request.head.target });
        var it = request.iterateHeaders();
        while (it.next()) |header| {
            log.info("header '{s}' = {s}", .{ header.name, header.value });
        }

        if (std.mem.eql(u8, request.head.target, "/api/setup/")) {
            try self.apiSetup(&request);
        } else if (std.mem.eql(u8, request.head.target, "/api/display")) {
            try self.apiDisplay(&request);
        } else if (std.mem.eql(u8, request.head.target, "/img/new.bmp")) {
            const bmp: []const u8 = try std.fs.cwd().readFile("img/new.bmp", &bmp_buffer);
            try request.respond(bmp, .{ .keep_alive = false });
        } else if (std.mem.eql(u8, request.head.target, "/api/log")) {
            try self.apiLog(&request);
        } else try request.respond("", .{ .keep_alive = false, .status = .not_implemented });
    } else |err| return err;
}

fn apiSetup(self: *Server, request: *std.http.Server.Request) !void {
    _ = self;
    try request.respond(
        \\{
        \\  "status": 200,
        \\  "api_key": "MnuhaudSb-PTgBueN7y62Q",
        \\  "friendly_id": "2EE08C",
        \\  "image_url": "https://usetrmnl.com/images/setup/setup-logo.bmp",
        \\  "message": "Welcome to TRMNL BYOS"
        \\}
    , .{ .keep_alive = false });
}

fn apiDisplay(self: *Server, request: *std.http.Server.Request) !void {
    try gen.newImage(self.allocator, "img/new.bmp");
    try request.respond(
        \\{
        \\  "status": 0,
        \\  "filename": "new.bmp",
        \\  "firmware_url": "nope",
        \\  "image_url": "http://192.168.0.21:2300/img/new.bmp",
        \\  "image_url_timeout": 0,
        \\  "refresh_rate": 900,
        \\  "reset_firmware": false,
        \\  "special_function": "sleep",
        \\  "update_firmware": false
        \\}
    , .{ .keep_alive = false });
}

fn apiLog(self: *Server, request: *std.http.Server.Request) !void {
    const reader = try request.reader();
    const body = try reader.readAllAlloc(self.log_arena.allocator(), 4096);
    const logs = try std.json.parseFromSliceLeaky(std.json.Value, self.log_arena.allocator(), body, .{});
    const log_array = logs.object.get("log").?.object.get("logs_array").?.array;
    for (log_array.items) |log_value| {
        // todo: write to file
        log.err("{s}", .{log_value.object.get("log_message").?.string});
    }
    if (!self.log_arena.reset(.retain_capacity)) return error.ArenaResetFailed;
    try request.respond("", .{ .keep_alive = false, .status = .no_content });
}
