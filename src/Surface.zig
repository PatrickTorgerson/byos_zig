const std = @import("std");
const vec = @import("vector.zig");
const Vector = vec.Vector;
const Num = @import("types.zig").Num;
const Rect = @import("types.zig").Rect;
const Color = @import("types.zig").Color;
const Blend = @import("types.zig").Blend;
const shader = @import("shader.zig");
const Font = @import("Font.zig");
const Text = @import("Text.zig");
const Surface = @This();
const bmp_header_size = 14;
const dib_header_size = 40;
const color_table_size = 8;

width: Num,
height: Num,
pixels: []u8,

pub fn deinit(surface: Surface, allocator: std.mem.Allocator) void {
    if (surface.pixels.len > 0) {
        allocator.free(surface.pixels);
    }
}

/// must call deinit() on returned surface.
pub fn init(allocator: std.mem.Allocator, width: usize, height: usize, color: Color) !Surface {
    const pixels = try allocator.alloc(u8, width * height);
    for (pixels) |*p| p.* = color.value();
    return .{
        .width = @floatFromInt(width),
        .height = @floatFromInt(height),
        .pixels = pixels,
    };
}

pub fn readPixel(surface: Surface, point: Vector) Color {
    std.debug.assert(point[0] >= 0);
    std.debug.assert(point[1] >= 0);
    std.debug.assert(point[0] < surface.width);
    std.debug.assert(point[1] < surface.height);
    return @enumFromInt(surface.pixels[@as(usize, @intFromFloat(@round(point[1]) * surface.width + @round(point[0])))]);
}

pub fn writePixel(surface: *Surface, point: Vector, color: Color) void {
    std.debug.assert(point[0] >= 0);
    std.debug.assert(point[1] >= 0);
    std.debug.assert(point[0] < surface.width);
    std.debug.assert(point[1] < surface.height);
    surface.pixels[@as(usize, @intFromFloat(@round(point[1]) * surface.width + @round(point[0])))] = color.value();
}

pub const DrawOptions = struct {
    pos: Vector = vec.zero,
    src_rect: Rect = .fromScalars(0, 0, -1, -1),
    shader_opts: shader.Options = .{},
};

pub fn drawRect(surface: *Surface, rect: Rect, color: Color, shader_opts: shader.Options) void {
    var x: Num = 0;
    var y: Num = 0;
    while (y < rect.h) : (y += 1) {
        while (x < rect.w) : (x += 1) {
            const dst_point = rect.position() + Vector{ x, y };
            const draw_color = shader_opts.func(.{
                .p = .{ x, y },
                .src_sampler = switch (color) {
                    .white => .initWhite(rect.size()),
                    .black => .initBlack(rect.size()),
                },
                .src_point = .{ x, y },
                .dst_sampler = .initSurface(surface),
                .dst_point = dst_point,
            }, shader_opts.args);
            if (shader_opts.blend == .no_alpha or shader_opts.blend.color() == draw_color)
                surface.writePixel(dst_point, draw_color);
        }
        x = 0;
    }
}

pub fn drawSurface(surface: *Surface, src: Surface, options: DrawOptions) void {
    var x: Num = 0;
    var y: Num = 0;
    const width = if (options.src_rect.w == -1) src.width else options.src_rect.w;
    const height = if (options.src_rect.h == -1) src.height else options.src_rect.h;
    while (y < height) : (y += 1) {
        while (x < width) : (x += 1) {
            const dst_point = options.pos + Vector{ x, y };
            const color = options.shader_opts.func(.{
                .p = .{ x, y },
                .src_sampler = .initSurface(&src),
                .src_point = options.src_rect.position() + Vector{ x, y },
                .dst_sampler = .initSurface(surface),
                .dst_point = dst_point,
            }, options.shader_opts.args);
            if (options.shader_opts.blend == .no_alpha or options.shader_opts.blend.color() == color)
                surface.writePixel(dst_point, color);
        }
        x = 0;
    }
}

pub fn drawText(surface: *Surface, text: Text, pos: Vector) void {
    var ycur: Num = pos[1] + text.lines[0].height;
    for (&text.lines) |l| {
        if (l.isEmpty()) break;
        var xcur: Num = pos[0];
        for (l.slice) |char| {
            const g = text.font.lookup(char);
            surface.drawSurface(text.font.bitmap, .{
                .pos = .{ l.offset + xcur + g.bearing[0], ycur - g.bearing[1] },
                .src_rect = g.bounds,
                .shader_opts = .{ .blend = .white_alpha },
            });
            xcur += g.advance;
            // todo: append hyphen
            // todo: space width
        }
        ycur += l.height + text.options.line_spacing;
    }
}

pub fn size(surface: Surface) Vector {
    return .{ surface.width, surface.height };
}

/// decodes a bitmap image, asserts bitmap is monchrome.
/// ignores colors.
/// must call deinit() on returned surface.
/// bmp reference: https://en.wikipedia.org/wiki/BMP_file_format
pub fn decode(allocator: std.mem.Allocator, reader: std.io.AnyReader) !Surface {
    var decoder = BitmapDecoder.init(reader);
    const header_field = try decoder.read(u16);
    try decoder.skip(8);
    const pixel_offset = try decoder.read(u32);
    const dib_size = try decoder.read(u32);
    std.debug.assert(header_field == 19778); // BM
    std.debug.assert(dib_size == dib_header_size); // Windows BITMAPINFOHEADER
    const width: usize = @intCast(try decoder.read(i32));
    const height: usize = @intCast(try decoder.read(i32));
    try decoder.skip(2);
    const bits_per_pixel = try decoder.read(u16);
    const compression_method = try decoder.read(u32);
    try decoder.skip(20);
    std.debug.assert(compression_method == 0); // BI_RGB
    std.debug.assert(bits_per_pixel == 1);
    try decoder.skip(pixel_offset - decoder.offset);
    const pixels = try allocator.alloc(u8, width * height);
    errdefer allocator.free(pixels);
    const row_size: usize = @divFloor(width + 31, 32) * 4;
    const row = try allocator.alloc(u8, row_size);
    defer allocator.free(row);
    for (0..height) |h| {
        const y = height - h - 1;
        const r = try decoder.readBytes(row);
        std.debug.assert(r.len == row_size);
        for (0..width) |x| {
            const byte = @divTrunc(x, 8);
            const bit: u3 = @intCast(@mod(x, 8));
            pixels[y * width + x] = (r[byte] & (@as(u8, 0b10000000) >> bit)) >> (7 - bit);
        }
    }
    return .{
        .width = @floatFromInt(width),
        .height = @floatFromInt(height),
        .pixels = pixels,
    };
}

/// bmp reference: https://en.wikipedia.org/wiki/BMP_file_format
pub fn encode(surface: Surface, allocator: std.mem.Allocator, writer: std.io.AnyWriter) !usize {
    const pixel_offset = bmp_header_size +
        dib_header_size +
        color_table_size;
    const filesize = pixel_offset +
        (surface.pixels.len / 8);
    const width: usize = @intFromFloat(surface.width);
    const height: usize = @intFromFloat(surface.height);
    const row_size: usize = @divFloor(width + 31, 32) * 4;
    try writer.writeAll("BM");
    try writer.writeInt(u32, @intCast(filesize), .little);
    try writer.writeInt(u32, 0, .little);
    try writer.writeInt(u32, pixel_offset, .little);
    try writer.writeInt(u32, dib_header_size, .little);
    try writer.writeInt(i32, @intCast(width), .little);
    try writer.writeInt(i32, @intCast(height), .little);
    try writer.writeInt(u16, 1, .little); // color planes
    try writer.writeInt(u16, 1, .little); // bits per pixel
    try writer.writeInt(u32, 0, .little); // compression
    try writer.writeInt(u32, @intCast(row_size * height), .little); // image size
    try writer.writeInt(i32, 0, .little); // h res
    try writer.writeInt(i32, 0, .little); // v res
    try writer.writeInt(u32, 2, .little); // color count
    try writer.writeInt(u32, 2, .little); // important colors
    try writer.writeInt(u32, 0, .little); // black
    try writer.writeInt(u32, 0xFFFFFF00, .big); // white
    const row = try allocator.alloc(u8, row_size);
    defer allocator.free(row);
    for (0..height) |h| {
        const y: usize = height - h - 1;
        for (row) |*r| r.* = 0;
        for (0..width) |x| {
            const byte = @divTrunc(x, 8);
            const bit: u3 = @intCast(@mod(x, 8));
            const pixel: u8 = surface.pixels[y * width + x] << 7;
            row[byte] |= (pixel >> bit);
        }
        try writer.writeAll(row);
    }
    return filesize;
}

const BitmapDecoder = struct {
    offset: usize = 0,
    reader: std.io.AnyReader,

    pub fn init(reader: std.io.AnyReader) BitmapDecoder {
        return .{
            .reader = reader,
        };
    }

    fn read(self: *BitmapDecoder, comptime T: type) !T {
        self.offset += @sizeOf(T);
        return self.reader.readInt(T, .little);
    }

    fn skip(self: *BitmapDecoder, bytes: u64) !void {
        self.offset += bytes;
        try self.reader.skipBytes(bytes, .{});
    }

    fn readBytes(self: *BitmapDecoder, buffer: []u8) ![]u8 {
        const n = try self.reader.readAll(buffer);
        self.offset += n;
        return buffer[0..n];
    }
};
