const std = @import("std");
const Num = @import("types.zig").Num;
const Rect = @import("types.zig").Rect;
const Color = @import("types.zig").Color;
const Blend = @import("types.zig").Blend;
const Surface = @import("Surface.zig");
const vec = @import("vector.zig");
const Vector = vec.Vector;

pub const Fn = *const fn (Input, []const Num) Color;

pub const Options = struct {
    blend: Blend = .no_alpha,
    func: Fn = draw,
    args: []const Num = &.{},
};

pub const Sampler = union(enum) {
    surface: *const Surface,
    white: Vector,
    black: Vector,
    pub fn initSurface(s: *const Surface) Sampler {
        return .{ .surface = s };
    }
    pub fn initWhite(sz: Vector) Sampler {
        return .{ .white = sz };
    }
    pub fn initBlack(sz: Vector) Sampler {
        return .{ .black = sz };
    }
    pub fn sample(sampler: Sampler, point: Vector) Color {
        return switch (sampler) {
            .surface => |surface| surface.readPixel(point),
            .white => .white,
            .black => .black,
        };
    }
    pub fn size(sampler: Sampler) Vector {
        return switch (sampler) {
            .surface => |surface| surface.size(),
            .white => sampler.white,
            .black => sampler.black,
        };
    }
};

pub const Input = struct {
    p: Vector,
    src_sampler: Sampler,
    src_point: Vector,
    dst_sampler: Sampler,
    dst_point: Vector,
};

pub fn draw(in: Input, _: []const Num) Color {
    return in.src_sampler.sample(in.src_point);
}

pub fn roundedBlackOutline(in: Input, args: []const Num) Color {
    return roundedBox(in, args, .black);
}

pub fn roundedWhiteOutline(in: Input, args: []const Num) Color {
    return roundedBox(in, args, .white);
}

fn roundedBox(in: Input, args: []const Num, outline_color: Color) Color {
    const corner_radius: f32 = (args[0]);
    const outline: f32 = (args[1]);
    const b: Vector = vec.scaled(in.src_sampler.size() - vec.splat(1), 0.5);
    const p: Vector = in.p - b;
    const d = @ceil(sdRoundedBox(p, b, corner_radius));

    const dst_color = in.dst_sampler.sample(in.dst_point);
    const src_color = in.src_sampler.sample(in.src_point);
    if (d > 0) return dst_color;
    return if (d <= 0 and d > -outline) outline_color else src_color;
}

// b.x = half width
// b.y = half height
fn sdRoundedBox(p: Vector, b: Vector, r: f32) f32 {
    // r.xy = (p.x>0.0)?r.xy : r.zw;
    // r.x  = (p.y>0.0)?r.x  : r.y;
    const rv = vec.splat(r);
    const q = vec.abs(p) - b + rv;
    return @min(@max(q[0], q[1]), 0.0) + vec.length(vec.max(q, vec.splat(0.0))) - r;
}
