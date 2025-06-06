const std = @import("std");

pub fn main() !void {
    const stdin = std.io.getStdIn();
    const reader = stdin.reader();
    var input_buffer: [128]u8 = undefined;
    var stream_buffer: [4096]u8 = undefined;

    std.debug.print("Starting client\n", .{});
    const server_addr = try std.net.Address.parseIp("127.0.0.1", 42069);
    std.debug.print("connecting to {}\n", .{server_addr});

    const stream = try std.net.tcpConnectToAddress(server_addr);
    defer stream.close();
    std.debug.print("connected\n", .{});

    const bytes_recv = try stream.read(&stream_buffer);
    std.debug.print("  '{s}'\n", .{stream_buffer[0..bytes_recv]});

    while (true) {
        std.debug.print("> ", .{});
        if (try reader.readUntilDelimiterOrEof(input_buffer[0..], '\n')) |input| {
            const msg = input[0 .. input.len - 1];
            if (msg.len == 0) continue;
            if (std.mem.eql(u8, msg, "exit")) break;
            _ = try stream.write(msg);
            const reply = try stream.reader().readUntilDelimiterOrEof(&stream_buffer, '\n') orelse "NOP";
            std.debug.print("  '{s}'\n", .{reply});
        }
    }
}
