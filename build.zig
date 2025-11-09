const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // This creates a "module", which represents a collection of source files alongside
    // some compilation options, such as optimization mode and linked system libraries.
    // Every executable or library we compile will be based on one or more modules.
    const lib_mod = b.createModule(.{
        // `root_source_file` is the Zig "entry point" of the module. If a module
        // only contains e.g. external object files, you can make this `null`.
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Now, we will create a static library based on the module we created above.
    // This creates a `std.Build.Step.Compile`, which is the build step responsible
    // for actually invoking the compiler.
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "spew",
        .root_module = lib_mod,
    });

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    b.installArtifact(lib);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.

    // Existing unit tests for the library module
    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    var root_dir = try std.fs.cwd().openDir("src/", .{ .iterate = true });
    defer root_dir.close();

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    var test_entries = root_dir.iterate();
    while (try test_entries.next()) |entry| {
        if (entry.kind != std.fs.File.Kind.file) {
            continue;
        }

        if (!std.mem.endsWith(u8, entry.name, "_tests.zig")) {
            continue;
        }

        const module = std.Build.Module.create(b, std.Build.Module.CreateOptions{
            .root_source_file = b.path(b.fmt("src/{s}", .{entry.name})),
            .target = target,
            .optimize = optimize,
        });

        // Existing unit tests for the library module
        const tests = b.addTest(.{
            .root_module = module,
        });

        const run_tests = b.addRunArtifact(tests);

        test_step.dependOn(&run_tests.step);
    }

    // Loop through the examples folder and create a run-* step for every file found in that directory.
    var examples_dir = try std.fs.cwd().openDir("examples/", .{ .iterate = true });
    defer examples_dir.close();
    var examples = examples_dir.iterate();
    while (try examples.next()) |entry| {
        if (!std.mem.endsWith(u8, entry.name, ".zig")) {
            continue;
        }

        const module = std.Build.Module.create(b, std.Build.Module.CreateOptions{
            .root_source_file = b.path(b.fmt("examples/{s}", .{entry.name})),
            .target = target,
            .optimize = optimize,
        });

        const name = entry.name[0 .. entry.name.len - ".zig".len];

        const example_exe = b.addExecutable(.{
            .name = name,
            .root_module = module,
        });
        example_exe.root_module.addImport("spew", lib_mod); // Link module
        b.installArtifact(example_exe);

        // Add run step
        const run_example = b.addRunArtifact(example_exe);
        run_example.step.dependOn(b.getInstallStep());
        if (b.args) |args| run_example.addArgs(args);
        b.step(
            b.fmt("run-{s}", .{name}),
            b.fmt("Run example: {s}", .{name}),
        ).dependOn(&run_example.step);
    }
}
