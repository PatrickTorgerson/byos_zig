const std = @import("std");
const buildFreetype = @import("build-freetype.zig").build;
const buildLibpng = @import("build-libpng.zig").build;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const libpng = try buildLibpng(b, target, optimize);
    const freetype = try buildFreetype(b, libpng, target, optimize);
    buildExecutable(b, "server", target, optimize, &.{freetype});
    buildExecutable(b, "client", target, optimize, &.{});
    buildExecutable(b, "testbench", target, optimize, &.{freetype});
    buildTests(b, "tests", target, optimize, &.{freetype});
}

fn buildExecutable(
    b: *std.Build,
    comptime name: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    libs: []const *std.Build.Step.Compile,
) void {
    const mod = b.createModule(.{
        .root_source_file = b.path("src/" ++ name ++ ".zig"),
        .target = target,
        .optimize = optimize,
    });
    mod.addIncludePath(std.Build.LazyPath{ .cwd_relative = b.h_dir });
    mod.addIncludePath(b.path(""));

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = mod,
    });
    for (libs) |lib| {
        std.debug.assert(lib.kind == .lib);
        exe.linkLibrary(lib);
    }
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step(name, "Run the " ++ name ++ "app");
    run_step.dependOn(&run_cmd.step);
}

fn buildTests(
    b: *std.Build,
    comptime name: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    libs: []const *std.Build.Step.Compile,
) void {
    const mod = b.createModule(.{
        .root_source_file = b.path("src/" ++ name ++ ".zig"),
        .target = target,
        .optimize = optimize,
    });
    mod.addIncludePath(std.Build.LazyPath{ .cwd_relative = b.h_dir });
    mod.addIncludePath(b.path(""));
    for (libs) |lib| {
        std.debug.assert(lib.kind == .lib);
        mod.linkLibrary(lib);
    }

    const tests = b.addTest(.{
        .root_module = mod,
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}
