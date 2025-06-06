const std = @import("std");
const Num = @import("types.zig").Num;
const Rect = @import("types.zig").Rect;
const Color = @import("types.zig").Color;
const Blend = @import("types.zig").Blend;
const shader = @import("shader.zig");
const Font = @import("Font.zig");
const vec = @import("vector.zig");
const Vector = vec.Vector;
const Text = @This();

string: []const u8,
font: *Font,
size: Vector,

pub fn init(font: *Font, string: []const u8) Text {
    var t: Text = undefined;
    t.string = string;
    t.font = font;
    t.calulateSize();
    return t;
}

pub fn updateString(text: *Text, string: []const u8) void {
    text.string = string;
    text.calulateSize();
}

pub fn updateFont(text: *Text, font: *Font) void {
    text.font = font;
    text.calulateSize();
}

fn calulateSize(text: *Text) void {
    text.size[0] = 0;
    text.size[1] = 0;
    var low: Num = 0;
    var high: Num = 0;
    for (text.string[0 .. text.string.len - 1]) |char| {
        const g = text.font.lookup(char);
        high = @min(high, -g.bearing[1]);
        low = @max(low, -g.bearing[1] + g.bounds.h);
        text.size[0] += g.advance;
    }
    const g = text.font.lookup(text.string[text.string.len - 1]);
    high = @min(high, -g.bearing[1]);
    low = @max(low, -g.bearing[1] + g.bounds.h);
    text.size[0] += g.bearing[0] + g.bounds.w;
    text.size[1] = low - high;
}
