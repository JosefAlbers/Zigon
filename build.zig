const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib_include = b.option(
        []const u8,
        "raylib-include",
        "Path to raylib include directory",
    );
    const raylib_lib = b.option(
        []const u8,
        "raylib-lib",
        "Path to raylib library directory",
    );

    const map_size = b.option(
        u32,
        "map-size",
        "Size of the terrain map (default: 128)",
    ) orelse 128;
    const dungeon_type = b.option(
        i32,
        "dungeon-type",
        "Dungeon type: -1=none, 0=rooms, 1=rogue, 2=cavern, 3=maze, 4=labyrinth, 5=arena (default: -1)",
    ) orelse -1;
    const dungeon_magnify = b.option(
        u32,
        "dungeon-magnify",
        "Dungeon magnification factor (default: 4)",
    ) orelse 4;
    const init_seed = b.option(
        u64,
        "seed",
        "Initial seed (0=use timestamp, default: 0)",
    ) orelse 0;
    const window_width = b.option(
        i32,
        "window-width",
        "Window width in pixels (default: 800)",
    ) orelse 800;
    const window_height = b.option(
        i32,
        "window-height",
        "Window height in pixels (default: 600)",
    ) orelse 600;

    const options = b.addOptions();
    options.addOption(u32, "map_size", map_size);
    options.addOption(i32, "dungeon_type", dungeon_type);
    options.addOption(u32, "dungeon_magnify", dungeon_magnify);
    options.addOption(u64, "init_seed", init_seed);
    options.addOption(i32, "window_width", window_width);
    options.addOption(i32, "window_height", window_height);

    const RaylibConfig = struct {
        fn configure(artifact: *std.Build.Step.Compile, inc: ?[]const u8, lib: ?[]const u8) void {
            artifact.linkLibC();
            artifact.linkSystemLibrary("raylib");

            if (inc) |include_path| {
                artifact.addIncludePath(.{ .cwd_relative = include_path });
            }
            if (lib) |lib_path| {
                artifact.addLibraryPath(.{ .cwd_relative = lib_path });
            }
        }
    };

    const createRaylibExe = struct {
        fn create(
            builder: *std.Build,
            name: []const u8,
            source: []const u8,
            tgt: std.Build.ResolvedTarget,
            opt: std.builtin.OptimizeMode,
            inc: ?[]const u8,
            lib: ?[]const u8,
        ) *std.Build.Step.Compile {
            const exe = builder.addExecutable(.{
                .name = name,
                .root_source_file = builder.path(source),
                .target = tgt,
                .optimize = opt,
            });
            RaylibConfig.configure(exe, inc, lib);
            return exe;
        }
    }.create;

    const exe = createRaylibExe(b, "walk", "walk.zig", target, optimize, raylib_include, raylib_lib);
    exe.root_module.addOptions("config", options);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the main application");
    run_step.dependOn(&run_cmd.step);

    const lib = b.addSharedLibrary(.{
        .name = "_walk",
        .root_source_file = b.path("walk.zig"),
        .target = target,
        .optimize = optimize,
    });
    RaylibConfig.configure(lib, raylib_include, raylib_lib);
    lib.root_module.addOptions("config", options);
    b.installArtifact(lib);

    const wasm = b.addExecutable(.{
        .name = "terrain",
        .root_source_file = b.path("terrain.zig"),
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
        }),
        .optimize = .ReleaseSmall,
    });
    wasm.entry = .disabled;
    wasm.rdynamic = true;
    b.installArtifact(wasm);

    const terrain_test_exe = b.addExecutable(.{
        .name = "terrain_test",
        .root_source_file = b.path("terrain.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_terrain_cmd = b.addRunArtifact(terrain_test_exe);

    const run_terrain_step = b.step("run-terrain", "Run the terrain generator CLI test (ASCII + PPM)");
    run_terrain_step.dependOn(&run_terrain_cmd.step);

    const chat_exe = createRaylibExe(b, "chat_test", "chat.zig", target, optimize, raylib_include, raylib_lib);
    const run_chat_cmd = b.addRunArtifact(chat_exe);
    const run_chat_step = b.step("run-chat", "Run the chat UI test");
    run_chat_step.dependOn(&run_chat_cmd.step);

    const obj_exe = createRaylibExe(b, "object_test", "object.zig", target, optimize, raylib_include, raylib_lib);
    const run_obj_cmd = b.addRunArtifact(obj_exe);
    const run_obj_step = b.step("run-object", "Run the object viewer");
    run_obj_step.dependOn(&run_obj_cmd.step);

    const dungeon_exe = b.addExecutable(.{
        .name = "dungeon_demo",
        .root_source_file = b.path("dungeon.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_dungeon_cmd = b.addRunArtifact(dungeon_exe);
    const run_dungeon_step = b.step("run-dungeon", "Run the dungeon generation demo");
    run_dungeon_step.dependOn(&run_dungeon_cmd.step);

    const web_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .emscripten,
    });
    const web_lib = b.addStaticLibrary(.{
        .name = "walk-web",
        .root_source_file = b.path("walk.zig"),
        .target = web_target,
        .optimize = optimize,
    });
    web_lib.root_module.addOptions("config", options);
    web_lib.linkLibC();
    const sysroot_path = b.option([]const u8, "sysroot", "Path to emscripten sysroot");
    if (sysroot_path) |sysroot| {
        const include_path = b.fmt("{s}/include", .{sysroot});
        web_lib.addSystemIncludePath(.{ .cwd_relative = include_path });
    }
    if (raylib_include) |inc| {
        web_lib.addIncludePath(.{ .cwd_relative = inc });
    }
    const web_step = b.step("web", "Build static library for web");
    const install_web = b.addInstallArtifact(web_lib, .{});
    web_step.dependOn(&install_web.step);

    const bench_exe = b.addExecutable(.{
        .name = "bench_terrain",
        .root_source_file = b.path("bench_terrain.zig"),
        .target = target,
        .optimize = .ReleaseFast, // Always ReleaseFast for benchmarks
    });
    b.installArtifact(bench_exe);
    const run_bench_cmd = b.addRunArtifact(bench_exe);
    const run_bench_step = b.step("run-bench", "Run terrain generation benchmarks");
    run_bench_step.dependOn(&run_bench_cmd.step);
    const bench_step = b.step("bench", "Build terrain benchmarks (ReleaseFast)");
    bench_step.dependOn(&b.addInstallArtifact(bench_exe, .{}).step);
}
