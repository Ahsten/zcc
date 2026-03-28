const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "zcc",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.resolveTargetQuery(.{
                .cpu_arch = .x86_64,
                .os_tag = .linux,
            }),
        }),
    });

    b.installArtifact(exe);
    const run_artifact = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the project");
    run_step.dependOn(&run_artifact.step);

    const test_exe = b.addTest(.{
        .name = "unit_tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.graph.host,
        }),
    });

    b.installArtifact(test_exe);
    const run_test_artifact = b.addRunArtifact(test_exe);
    const run_tests = b.step("tests", "Run unit tests");
    run_tests.dependOn(&run_test_artifact.step);
}
