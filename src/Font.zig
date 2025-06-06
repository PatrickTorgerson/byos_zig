const std = @import("std");
const vec = @import("vector.zig");
const Vector = vec.Vector;
const Surface = @import("Surface.zig");
const Num = @import("types.zig").Num;
const Rect = @import("types.zig").Rect;
const Color = @import("types.zig").Color;
const c = @import("c.zig").c;
const fterrors = @import("ft-errors.zig");
const err = fterrors.errorFromInt;
const Font = @This();

pub const Glyph = struct {
    bounds: Rect,
    bearing: Vector,
    advance: Num,
};

face: c.FT_Face,
bitmap: Surface,
glyph_data: [95]Glyph,

pub fn init(allocator: std.mem.Allocator, fontfile: [:0]const u8, pixel_size: u32) !Font {
    var font: Font = undefined;
    try err(c.FT_New_Face(
        ftlib,
        fontfile.ptr,
        0, // index
        &font.face,
    ));
    try err(c.FT_Set_Pixel_Sizes(font.face, 0, pixel_size));
    try font.generateGlyphs(allocator, 800);
    return font;
}

pub fn deinit(font: Font, allocator: std.mem.Allocator) void {
    _ = c.FT_Done_Face(font.face);
    font.bitmap.deinit(allocator);
}

pub fn lookup(font: Font, char: u8) Glyph {
    return font.glyph_data[asciiToIndex(char)];
}

pub fn generateGlyphs(
    font: *Font,
    allocator: std.mem.Allocator,
    comptime bitmap_width: usize,
) !void {
    const bitmap_height = try font.populateGlyphMetrics(bitmap_width);
    font.bitmap = try .init(allocator, bitmap_width, bitmap_height, .white);
    errdefer font.bitmap.deinit(allocator);

    for (font.glyph_data, 32..) |g, ascii| {
        const glyph_index = c.FT_Get_Char_Index(font.face, @intCast(ascii));
        try err(c.FT_Load_Glyph(font.face, glyph_index, c.FT_LOAD_DEFAULT));
        try err(c.FT_Render_Glyph(font.face.*.glyph, c.FT_RENDER_MODE_MONO));
        const bitmap = font.face.*.glyph.*.bitmap;
        std.debug.assert(bitmap.pixel_mode == c.FT_PIXEL_MODE_MONO);
        var x: c_int = 0;
        var y: c_int = 0;
        while (y < bitmap.rows) : (y += 1) {
            var row: []const u8 = undefined;
            row.ptr = bitmap.buffer + @as(usize, @intCast(bitmap.pitch * y));
            row.len = @intCast(bitmap.pitch);
            while (x < bitmap.width) : (x += 1) {
                const byte: usize = @intCast(@divTrunc(x, 8));
                const bit: u3 = @intCast(@mod(x, 8));
                const value = (row[byte] & (@as(u8, 0b10000000) >> bit)) >> (7 - bit);
                const color: Color = if (value == 0) .white else .black;
                font.bitmap.writePixel(g.bounds.position() + Vector{
                    @floatFromInt(x),
                    @floatFromInt(y),
                }, color);
            }
            x = 0;
        }
    }
}

pub fn populateGlyphMetrics(font: *Font, comptime bitmap_width: usize) !usize {
    var x: Num = 0;
    var y: Num = 0;
    var row_height: Num = 0;
    for (32..127) |ascii| {
        const glyph_index = c.FT_Get_Char_Index(font.face, @intCast(ascii));
        try err(c.FT_Load_Glyph(font.face, glyph_index, c.FT_LOAD_NO_BITMAP));
        const metrics = font.face.*.glyph.*.metrics;
        var g: *Glyph = &font.glyph_data[asciiToIndex(ascii)];
        g.bounds.w = @as(Num, @floatFromInt(metrics.width)) / 64;
        g.bounds.h = @as(Num, @floatFromInt(metrics.height)) / 64;
        g.bearing[0] = @as(Num, @floatFromInt(metrics.horiBearingX)) / 64;
        g.bearing[1] = @as(Num, @floatFromInt(metrics.horiBearingY)) / 64;
        g.advance = @as(Num, @floatFromInt(metrics.horiAdvance)) / 64;
        if (x + g.bounds.w >= @as(Num, @floatFromInt(bitmap_width))) {
            y += row_height;
            x = 0;
            row_height = 0;
        }
        g.bounds.x = x;
        g.bounds.y = y;
        x += g.bounds.w;
        row_height = @max(row_height, g.bounds.h);
    }
    return @intFromFloat(y + row_height);
}

fn asciiToIndex(char: anytype) usize {
    std.debug.assert(char >= 32);
    std.debug.assert(char < 127);
    return @intCast(char - 32);
}

fn indexToAscii(index: usize) usize {
    return @intCast(index + 32);
}

var ftlib: c.FT_Library = undefined;
pub fn initFreeType() !void {
    try err(c.FT_Init_FreeType(&ftlib));
}
pub fn deinitFreeType() void {
    _ = c.FT_Done_FreeType(ftlib);
}
