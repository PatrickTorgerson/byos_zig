const std = @import("std");
const gen = @import("image-gen.zig");
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
    try gen.newImage(gpa.allocator(), "img/testbench.bmp");
}
