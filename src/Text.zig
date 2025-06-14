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
lines: []Line,
options: Options,

pub const Justify = enum { left, right, center, flush };
pub const Options = struct {
    /// a value less than one means no max width
    max_width: Num = 0,
    /// ignored if `max_width` is null
    justify: Justify = .left,
    /// ignored if `max_width` is null
    line_spacing: Num = 0,
    /// ignored if `max_width` is null
    flags: std.EnumSet(enum {
        hyphenate_on_wrap,
        equal_line_width,
    }) = .initEmpty(),
};

pub fn init(allocator: std.mem.Allocator, font: *Font, string: []const u8, options: Options) !Text {
    var t: Text = undefined;
    t.lines = &[_]Line{};
    t.options = options;
    t.string = std.mem.trim(u8, string, " ");
    t.font = font;
    try t.layout(allocator);
    return t;
}

pub fn deinit(text: Text, allocator: std.mem.Allocator) void {
    allocator.free(text.lines);
}

pub fn updateOptions(text: *Text, allocator: std.mem.Allocator, options: Options) !void {
    text.options = options;
    try text.layout(allocator);
}

pub fn updateString(text: *Text, allocator: std.mem.Allocator, string: []const u8) !void {
    text.string = std.mem.trim(u8, string, " ");
    try text.layout(allocator);
}

pub fn updateFont(text: *Text, allocator: std.mem.Allocator, font: *Font) !void {
    text.font = font;
    try text.layout(allocator);
}

fn reset(text: *Text, allocator: std.mem.Allocator) void {
    text.size[0] = 0;
    text.size[1] = 0;
    if (text.lines.len > 0) {
        allocator.free(text.lines);
        text.lines = &[_]Line{};
    }
}

const LayoutState = struct {
    pub const empty: LayoutState = .{};
    full_length: Num = 0,
    line_count: Num = 0,
    line_height: Num = 0,
    line_width: Num = 0,
    average_char_width: Num = 0,
    target_line_width: Num = 0,
    line_start: usize = 0,
    space_count: Num = 0,
    char_width_sum: Num = 0,
    length_map: []Num = &[_]Num{},

    pub fn init(allocator: std.mem.Allocator, text: *Text) !LayoutState {
        var state: LayoutState = .empty;
        var low: Num = 0;
        var high: Num = 0;
        state.length_map = try allocator.alloc(Num, text.string.len);
        errdefer allocator.free(state.length_map);
        for (text.string, 0..) |c, i| {
            if (c == ' ' and i > 0 and text.string[i - 1] != ' ') state.space_count += 1;
            const g = text.font.lookup(c);
            const char_width = if (i != text.string.len - 1)
                g.advance
            else
                g.bearing[0] + g.bounds.w;
            state.full_length += char_width;
            if (c != ' ') state.char_width_sum += char_width;
            state.length_map[i] = state.full_length;
            high = @min(high, -g.bearing[1]);
            low = @max(low, -g.bearing[1] + g.bounds.h);
        }
        state.average_char_width = state.full_length / @as(Num, @floatFromInt(text.string.len));
        state.line_height = low - high;
        state.line_count = @ceil(state.full_length / text.options.max_width);
        state.target_line_width = if (text.options.flags.contains(.equal_line_width))
            state.full_length / state.line_count
        else
            text.options.max_width;
        return state;
    }

    pub fn deinit(state: *LayoutState, allocator: std.mem.Allocator) void {
        allocator.free(state.length_map);
    }
};

pub fn layout(text: *Text, allocator: std.mem.Allocator) !void {
    text.reset(allocator);
    var state: LayoutState = try .init(allocator, text);
    defer state.deinit(allocator);
    const line_count: usize = @intFromFloat(state.line_count);
    text.lines = try allocator.alloc(Line, line_count);
    errdefer allocator.free(text.lines);
    text.size[1] = (state.line_count * state.line_height) +
        ((state.line_count - 1) * text.options.line_spacing);
    for (0..line_count) |l| {
        text.lines[l].height = state.line_height;
        text.lines[l].slice, text.lines[l].append_hyphen =
            buildLineSlice(text, &state, @floatFromInt(l));
        text.lines[l].offset, text.lines[l].space_width =
            offsetAndSpaceWidth(text, state);
        text.size[0] = @max(text.size[0], state.line_width);
    }
}

fn offsetAndSpaceWidth(text: *Text, state: LayoutState) struct { Num, Num } {
    var space_width: Num = 0;
    const offset = if (std.math.isInf(text.options.max_width)) 0 else switch (text.options.justify) {
        .left => 0,
        .right => text.options.max_width - state.line_width,
        .center => (text.options.max_width / 2) - (state.line_width / 2),
        .flush => blk: {
            if (state.space_count > 0)
                space_width = (text.options.max_width - state.char_width_sum) / state.space_count;
            std.debug.print("space_count = {d} | char_width_sum  = {d} | space_width = {d}\n", .{
                state.space_count,
                state.char_width_sum,
                space_width,
            });
            break :blk 0;
        },
    };
    return .{ offset, space_width };
}

fn buildLineSlice(text: *Text, state: *LayoutState, line_number: Num) struct { []const u8, bool } {
    var append_hyphen = false;
    const end_pos = (line_number + 1) * state.target_line_width;
    var end_char = findCharFromPixelPos(state.*, end_pos);
    const line_end = if (text.options.flags.contains(.hyphenate_on_wrap)) blk: {
        end_char -= 1; // todo: you know
        append_hyphen = true;
        break :blk end_char;
    } else findNearestWordBreak(text.string, end_char);
    state.line_width = determineLineWidth(text.*, state.*, state.line_start, line_end);
    const slice = text.string[state.line_start..line_end];
    var i = line_end;
    state.line_start = while (i < text.string.len and text.string[i] == ' ') {
        if (i == text.string.len - 1) break text.string.len;
        i += 1;
    } else i;
    return .{ slice, append_hyphen };
}

fn determineLineWidth(text: Text, state: LayoutState, line_start: usize, line_end: usize) Num {
    std.debug.assert(line_end > 0);
    const pixel_start = state.length_map[line_start] - text.font.lookup(text.string[line_start]).bounds.w;
    const pixel_end = state.length_map[line_end - 1];
    return pixel_end - pixel_start;
}

fn findNearestWordBreak(string: []const u8, start: usize) usize {
    std.debug.assert(start < string.len);
    var i: usize = start;
    while (string[i] == ' ' and i != 0 and string[i - 1] == ' ') i -= 1;
    if (string[i] == ' ') return i;
    const word_start = while (string[i] != ' ') {
        if (i == 0) break i;
        i -= 1;
    } else i + 1;
    i = start;
    const word_end = while (string[i] != ' ') {
        if (i == string.len - 1) break i;
        i += 1;
    } else i - 1;
    const dist_to_start = start - word_start;
    const dist_to_end = word_end - start;
    return if (dist_to_end < dist_to_start) word_end + 1 else blk: {
        if (word_start == 0) break :blk 0;
        i = word_start - 1;
        while (string[i] == ' ' and i != 0 and string[i - 1] == ' ') i -= 1;
        break :blk i;
    };
}

test findNearestWordBreak {
    const string = "word   bigword   word";
    try std.testing.expectEqual(@as(usize, 0), findNearestWordBreak(string, 1));
    try std.testing.expectEqual(@as(usize, 4), findNearestWordBreak(string, 6));
    try std.testing.expectEqual(@as(usize, 4), findNearestWordBreak(string, 10));
    try std.testing.expectEqual(@as(usize, 14), findNearestWordBreak(string, 11));
    try std.testing.expectEqual(@as(usize, 14), findNearestWordBreak(string, 18));
    try std.testing.expectEqual(@as(usize, 21), findNearestWordBreak(string, 19));
}

fn findCharFromPixelPos(state: LayoutState, pos: Num) usize {
    if (pos < 0) return 0;
    var i: usize = @intFromFloat(pos / state.average_char_width);
    if (i >= state.length_map.len) i = state.length_map.len - 1;
    while (true) {
        if (state.length_map[i] < pos) {
            if (i == state.length_map.len - 1) return i;
            i += 1;
        } else if (state.length_map[i] > pos) {
            if (i == 0 or state.length_map[i - 1] < pos) return i;
            i -= 1;
        } else return i;
    }
}

test findCharFromPixelPos {
    var length_map = [_]Num{ 10, 23, 44, 59, 70, 80, 97 };
    const average_char_width = averageCharWidth(&length_map);
    const state = LayoutState{
        .length_map = &length_map,
        .average_char_width = average_char_width,
    };
    try std.testing.expectEqual(@as(usize, 0), findCharFromPixelPos(state, -1000));
    try std.testing.expectEqual(@as(usize, length_map.len - 1), findCharFromPixelPos(state, 1000));
    try std.testing.expectEqual(@as(usize, 0), findCharFromPixelPos(state, 5));
    try std.testing.expectEqual(@as(usize, 1), findCharFromPixelPos(state, 15));
    try std.testing.expectEqual(@as(usize, 2), findCharFromPixelPos(state, 44));
    try std.testing.expectEqual(@as(usize, 3), findCharFromPixelPos(state, 50));
}

fn averageCharWidth(length_map: []const Num) Num {
    var avg: Num = 0;
    for (length_map, 0..) |l, i| {
        const prev = if (i == 0) 0 else length_map[i - 1];
        avg += l - prev;
    }
    return avg / @as(Num, @floatFromInt(length_map.len));
}

pub const Line = struct {
    slice: []const u8,
    height: Num,
    offset: Num,
    space_width: Num = 0,
    append_hyphen: bool = false,

    pub const empty_line = Line{
        .slice = "",
        .height = -1,
        .offset = -1,
    };

    pub fn isEmpty(line: Line) bool {
        return line.offset == -1;
    }
};
