const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "radiance",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const exe_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tests_position.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const exe_tests_movegen = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tests_movegen.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const exe_tests_960 = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tests_960.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const exe_tests_interface = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tests_interface.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const exe_tests_evaluate = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tests_evaluate.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const exe_tests_magic = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tests_magic.zig"),
            .target = target,
            .optimize = .ReleaseSafe,
        }),
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);
    const run_exe_tests_movegen = b.addRunArtifact(exe_tests_movegen);
    const run_exe_tests_960 = b.addRunArtifact(exe_tests_960);
    const run_exe_tests_interface = b.addRunArtifact(exe_tests_interface);
    const run_exe_tests_evaluate = b.addRunArtifact(exe_tests_evaluate);
    const run_exe_tests_magic = b.addRunArtifact(exe_tests_magic);

    run_exe_tests.has_side_effects = true;
    run_exe_tests_movegen.has_side_effects = true;
    run_exe_tests_960.has_side_effects = true;
    run_exe_tests_interface.has_side_effects = true;
    run_exe_tests_evaluate.has_side_effects = true;
    run_exe_tests_magic.has_side_effects = true;

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_tests.step);
    test_step.dependOn(&run_exe_tests_movegen.step);
    test_step.dependOn(&run_exe_tests_960.step);
    test_step.dependOn(&run_exe_tests_interface.step);
    test_step.dependOn(&run_exe_tests_evaluate.step);
    test_step.dependOn(&run_exe_tests_magic.step);

    const deploy_step = b.step("deploy", "Deploy executables");

    const targets: []const struct {
        query: std.Target.Query,
        name: []const u8,
    } = &.{
        .{ .query = .{ .cpu_arch = .x86_64, .os_tag = .windows, .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64 } }, .name = "radiance_x86_64-win" },
        .{ .query = .{ .cpu_arch = .x86_64, .os_tag = .windows, .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64_v2 } }, .name = "radiance_x86_64_v2-win" },
        .{ .query = .{ .cpu_arch = .x86_64, .os_tag = .windows, .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64_v3 } }, .name = "radiance_x86_64_v3-win" },
        .{ .query = .{ .cpu_arch = .x86_64, .os_tag = .windows, .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64_v4 } }, .name = "radiance_x86_64_v4-win" },
        .{ .query = .{ .cpu_arch = .x86_64, .os_tag = .linux, .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64 } }, .name = "radiance_x86_64-linux" },
        .{ .query = .{ .cpu_arch = .x86_64, .os_tag = .linux, .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64_v2 } }, .name = "radiance_x86_64_v2-linux" },
        .{ .query = .{ .cpu_arch = .x86_64, .os_tag = .linux, .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64_v3 } }, .name = "radiance_x86_64_v3-linux" },
        .{ .query = .{ .cpu_arch = .x86_64, .os_tag = .linux, .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64_v4 } }, .name = "radiance_x86_64_v4-linux" },
        .{ .query = .{ .cpu_arch = .x86_64, .os_tag = .macos, .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64 } }, .name = "radiance_x86_64-macos" },
        .{ .query = .{ .cpu_arch = .x86_64, .os_tag = .macos, .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64_v2 } }, .name = "radiance_x86_64_v2-macos" },
        .{ .query = .{ .cpu_arch = .x86_64, .os_tag = .macos, .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64_v3 } }, .name = "radiance_x86_64_v3-macos" },
        .{ .query = .{ .cpu_arch = .x86_64, .os_tag = .macos, .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64_v4 } }, .name = "radiance_x86_64_v4-macos" },
    };

    for (targets) |t| {
        const deploy_exe = b.addExecutable(.{
            .name = t.name,
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = b.resolveTargetQuery(t.query),
                .optimize = .ReleaseFast,
                .link_libc = true,
            }),
        });

        const deploy_cmd = b.addInstallArtifact(deploy_exe, .{});
        deploy_step.dependOn(&deploy_cmd.step);
    }
}
