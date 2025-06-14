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
const Surface = @import("Surface.zig");

const width_usize: usize = 800;
const height_usize: usize = 480;
const width: Num = 800;
const height: Num = 480;

const log = std.log.scoped(.image_gen);

pub fn newImage(allocator: std.mem.Allocator, path: []const u8) !void {
    log.info("generating image '{s}'", .{path});
    var surface = try Surface.init(allocator, width_usize, height_usize, .white);
    defer surface.deinit(allocator);

    try randomQuote(.{
        .allocator = allocator,
        .surface = &surface,
        .rect = .fromScalars(20, 20, width - 40, height - 40),
    });

    const dir = std.fs.path.dirname(path) orelse "";
    try std.fs.cwd().makePath(dir);
    const newfile = try std.fs.cwd().createFile(path, .{});
    _ = try surface.encode(allocator, newfile.writer().any());
}

const CardInput = struct {
    allocator: std.mem.Allocator,
    surface: *Surface,
    rect: Rect,
};

pub fn randomQuote(in: CardInput) !void {
    var prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
    var rng = prng.random();
    const quote = quotes[rng.uintLessThan(usize, quotes.len)];
    var font = try Font.init(in.allocator, "res/lucida.ttf", 50);
    defer font.deinit(in.allocator);
    const text = try Text.init(in.allocator, &font, quote, .{
        .max_width = in.rect.w - 20,
        .justify = .center,
        .line_spacing = 10,
        .flags = .init(.{ .equal_line_width = true }),
    });
    defer text.deinit(in.allocator);
    centeredText(in.surface, in.rect, text, 10);
}

pub fn centeredText(surface: *Surface, rect: Rect, text: Text, padding: Num) void {
    const t = if (text.size[0] >= rect.w) {
        log.warn("text too long; '{s}'", .{text.string});
        return;
    } else text;
    surface.drawRect(rect, .white, .{
        .func = shader.roundedBlackOutline,
        .args = &.{ 15, 3 },
    });
    // const x = (rect.w / 2) - (t.size[0] / 2) + rect.x;
    //std.debug.assert(text.options.justify == .center);
    const y = (rect.h / 2) - (t.size[1] / 2) + rect.y;
    log.info("attempting to draw text '{s}' with len {d}", .{ t.string, t.size[0] });
    surface.drawText(t, .{ rect.x + padding, y });
}

const quotes = [_][]const u8{
    "Hello Clarice", // yes i know, this is not the real line shut up
    "Luke, I am your father", // yes i know, this is not the real line shut up
    "Now this is pod racing!",
    "It's over Anikin! I have the high ground!",
    "You were meant to destroy the Sith not join them!",

    "So long and thanks for all the fish",
    "It truly was a sawshank redemption",
    "I am the milk man, my milk is delicious",
};
