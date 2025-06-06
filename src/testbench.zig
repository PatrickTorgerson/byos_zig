const std = @import("std");
const Num = @import("types.zig").Num;
const Point = @import("types.zig").Point;
const Rect = @import("types.zig").Rect;
const Color = @import("types.zig").Color;
const shader = @import("shader.zig");
const Surface = @import("Surface.zig");
const Font = @import("Font.zig");
const Text = @import("Text.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    try Font.initFreeType();
    defer Font.deinitFreeType();

    const file = try std.fs.cwd().openFile("img/test2.bmp", .{});
    defer file.close();
    var s1 = try Surface.decode(gpa.allocator(), file.reader().any());
    defer s1.deinit(gpa.allocator());

    s1.drawRect(.fromScalars(20, 20, 800 - 40, 480 - 40), .white, .{
        .func = shader.roundedBlackOutline,
        .args = &.{ 15, 3 },
    });

    var font = try Font.init(gpa.allocator(), "lucida.ttf", 25);
    defer font.deinit(gpa.allocator());
    const text = Text.init(&font, "Hello World! JK lololol");
    const x: Num = 400 - (text.size[0] / 2);
    const y: Num = 240 + (text.size[1] / 2);
    s1.drawText(text, .{ x, y });

    const newfile = try std.fs.cwd().createFile("new.bmp", .{});
    _ = try s1.encode(gpa.allocator(), newfile.writer().any());
}
