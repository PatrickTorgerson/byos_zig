const std = @import("std");
const vec = @import("vector.zig");
const Vector = vec.Vector;
pub const Num = f32;

pub const Rect = struct {
    x: Num,
    y: Num,
    w: Num,
    h: Num,
    pub fn fromScalars(x: Num, y: Num, w: Num, h: Num) Rect {
        return .{ .x = x, .y = y, .w = w, .h = h };
    }
    pub fn init(pos: Vector, sz: Vector) Rect {
        return .{ .x = pos[0], .y = pos[1], .w = sz[0], .h = sz[1] };
    }
    pub fn position(rect: Rect) Vector {
        return .{ rect.x, rect.y };
    }
    pub fn size(rect: Rect) Vector {
        return .{ rect.w, rect.h };
    }
};

pub const Color = enum(u8) {
    black = 0,
    white = 1,

    pub fn value(self: Color) u8 {
        return @intFromEnum(self);
    }
};
pub const Blend = enum(u8) {
    white_alpha = 0,
    black_alpha = 1,
    no_alpha,

    pub fn color(self: Blend) Color {
        std.debug.assert(self != .no_alpha);
        return @enumFromInt(@intFromEnum(self));
    }
};
