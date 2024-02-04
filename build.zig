const std = @import("std");
const print = std.debug.print;

// FIXME: How do we retrieve this from the .zon file instead?
const version = std.SemanticVersion{ .major = 0, .minor = 1, .patch = 0 };

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    unitTests(b, target, optimize);

    benchmarks(b, target, optimize);
}

fn unitTests(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode
) void {
    const test_step = b.step("test", "Run unit tests");

    const tests = [_]*std.Build.Step.Compile{
        b.addTest(.{
            .name = "test_index_set",
            .root_source_file = .{ .path = "./src/index_set.zig" },
            .target = target,
            .optimize = optimize,
        }),
    };

    for (tests) |tst| {
        const test_artifact = b.addRunArtifact(tst);
        test_step.dependOn(&test_artifact.step);
    }
}

fn benchmarks(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode
) void {
    const bench_step = b.step("bench", "Run benchmarks");

    const opts = .{ .target = target, .optimize = optimize };
    const zbench_module = b.dependency("zbench", opts).module("zbench");

    // No clue what the proper way of doing this is..
    const index_set_module = b.createModule(.{ .root_source_file = .{.path = "./src/index_set.zig"} });

    const benches = b.addExecutable(.{
        .name = "bench_compare",
        .root_source_file = .{ .path = "bench/indexset_compare.zig" },
        .target = target,
        .optimize = optimize,
    });

    benches.root_module.addImport("zbench", zbench_module);
    benches.root_module.addImport("index_set", index_set_module);

    const bench_artifact = b.addRunArtifact(benches);
    bench_step.dependOn(&bench_artifact.step);
}
