test {
    const testing = @import("std").testing;
    testing.refAllDecls(@import("ft-errors.zig"));
    testing.refAllDecls(@import("Text.zig"));
}
