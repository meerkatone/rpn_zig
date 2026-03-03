const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "hp16c",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the HP-16C calculator");
    run_step.dependOn(&run_cmd.step);

    // Tests for each module
    const rom_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/rom.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const cpu_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/cpu.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const main_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_rom_tests = b.addRunArtifact(rom_tests);
    const run_cpu_tests = b.addRunArtifact(cpu_tests);
    const run_main_tests = b.addRunArtifact(main_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_rom_tests.step);
    test_step.dependOn(&run_cpu_tests.step);
    test_step.dependOn(&run_main_tests.step);
}
