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
const max_lines = 10;

string: []const u8,
font: *Font,
size: Vector,
lines: [max_lines]Line,
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
    hypenate_on_wrap: bool = false,
    // todo: equal line width
};

pub fn init(font: *Font, string: []const u8, options: Options) Text {
    var t: Text = undefined;
    t.options = options;
    t.string = string;
    t.font = font;
    t.layout();
    return t;
}

pub fn updateOptions(text: *Text, options: Options) void {
    text.options = options;
    text.layout();
}

pub fn updateString(text: *Text, string: []const u8) void {
    text.string = string;
    text.layout();
}

pub fn updateFont(text: *Text, font: *Font) void {
    text.font = font;
    text.layout();
}

pub fn reset(text: *Text) void {
    text.size[0] = 0;
    text.size[1] = 0;
    for (&text.lines) |*l| l.* = .empty_line;
}

const LayoutState = struct {
    low: Num = 0,
    high: Num = 0,
    white_width: Num = 0,
    line_width: Num = 0,
    /// like line_width but without whitespace
    char_width_sum: Num = 0,
    space_count: Num = 0,
    line_start: usize = 0,
    /// line index
    l: usize = 0,
    /// char index
    i: usize = 0,
    pub const initial: LayoutState = .{};
    pub fn reset(state: *LayoutState, new_i: usize, new_start: usize) void {
        const l = state.l;
        state.* = .initial;
        state.l = l + 1;
        state.i = new_i;
        state.line_start = new_start;
    }
};

fn layout(text: *Text) void {
    // todo: edge case if max_width < char width
    const max_width = if (text.options.max_width < 1) std.math.inf(Num) else text.options.max_width;
    text.reset();
    var state: LayoutState = .initial;
    while (state.i < text.string.len) : (state.i += 1) {
        const c = text.string[state.i];
        const g = text.font.lookup(c);
        state.high = @min(state.high, -g.bearing[1]);
        state.low = @max(state.low, -g.bearing[1] + g.bounds.h);
        const c_width = if (state.i < text.string.len - 1) g.advance else g.bearing[0] + g.bounds.w;
        if (c == ' ') {
            // todo: don't count consecutive spaces
            state.space_count += 1;
            state.white_width += c_width;
        } else if (state.line_width + state.white_width + c_width < max_width) {
            state.line_width += state.white_width + c_width;
            state.white_width = 0;
            state.char_width_sum += c_width;
        } else {
            text.lines[state.l].append_hyphen = backtrack(text, &state, max_width);
            text.lines[state.l].makeLine(text, state, max_width);
            while (state.i >= 0 and text.string[state.i] == ' ') state.i += 1;
            state.reset(state.i - 1, state.i);
        }
    }
    text.lines[state.l].makeLine(text, state, max_width);
    text.size[1] -= text.options.line_spacing;
}

/// sets `state.i` to end of current line, updating `state.line_width` accordingly.
/// returns is current like should end with a hyphen
pub fn backtrack(text: *Text, state: *LayoutState, max_width: Num) bool {
    state.i -= 1;
    if (text.string[state.i] == ' ') {
        state.space_count -= 1;
        return false;
    }
    if (text.options.hypenate_on_wrap) {
        const hyphen_width = text.font.lookup('-').bearing[0] + text.font.lookup('-').bounds.w;
        while (state.line_width + hyphen_width >= max_width) {
            const g = text.font.lookup(text.string[state.i]);
            state.line_width -= g.advance;
            if (text.string[state.i] != ' ') state.char_width_sum -= g.advance;
            state.i -= 1;
        }
        state.i += 1;
        if (text.string[state.i] != ' ') {
            state.line_width += hyphen_width;
            state.char_width_sum += hyphen_width;
            return true;
        }
        state.space_count -= 1;
        return false;
    } else {
        while (state.i >= 0 and text.string[state.i] != ' ') {
            const g = text.font.lookup(text.string[state.i]);
            state.line_width -= g.advance;
            if (text.string[state.i] != ' ') state.char_width_sum -= g.advance;
            state.i -= 1;
        }
        while (state.i > 0 and text.string[state.i - 1] == ' ') state.i -= 1;
        state.space_count -= 1;
        return false;
    }
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

    pub fn makeLine(line: *Line, text: *Text, state: LayoutState, max_width: Num) void {
        text.size[0] = @max(text.size[0], state.line_width);
        line.height = state.low - state.high;
        text.size[1] += line.height + text.options.line_spacing;
        line.slice = text.string[state.line_start..state.i];
        line.offset = if (std.math.isInf(max_width)) 0 else switch (text.options.justify) {
            .left => 0,
            .right => max_width - state.line_width,
            .center => (max_width / 2) - (state.line_width / 2),
            .flush => blk: {
                if (state.space_count > 0)
                    line.space_width = (max_width - state.char_width_sum) / state.space_count;
                std.debug.print("space_count = {d} | char_width_sum  = {d} | space_width = {d}\n", .{
                    state.space_count,
                    state.char_width_sum,
                    line.space_width,
                });
                break :blk 0;
            },
        };
    }
};
