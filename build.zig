const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
        .name = "walk",
        .root_source_file = b.path("walk.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibC();
    exe.linkSystemLibrary("raylib");
    exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
    exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);

    const lib = b.addSharedLibrary(.{
        .name = "_walk",
        .root_source_file = b.path("walk.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibC();
    lib.linkSystemLibrary("raylib");
    lib.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
    lib.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
    b.installArtifact(lib);

    const wasm = b.addExecutable(.{
        .name = "terrain",
        .root_source_file = b.path("terrain.zig"),
        .target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding }),
        .optimize = .ReleaseSmall,
    });
    wasm.entry = .disabled;
    wasm.rdynamic = true;
    b.installArtifact(wasm);

    const chat_exe = b.addExecutable(.{
        .name = "chat_test",
        .root_source_file = b.path("chat.zig"),
        .target = target,
        .optimize = optimize,
    });
    chat_exe.linkLibC();
    chat_exe.linkSystemLibrary("raylib");
    chat_exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
    chat_exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
    const run_chat_cmd = b.addRunArtifact(chat_exe);
    const run_chat_step = b.step("run-chat", "Run the chat UI test");
    run_chat_step.dependOn(&run_chat_cmd.step);

    const obj_exe = b.addExecutable(.{
        .name = "object_test",
        .root_source_file = b.path("object.zig"),
        .target = target,
        .optimize = optimize,
    });
    obj_exe.linkLibC();
    obj_exe.linkSystemLibrary("raylib");
    obj_exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
    obj_exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
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
    const run_dungeon_step = b.step("run-dungeon", "Run the Dungeon generation demo");
    run_dungeon_step.dependOn(&run_dungeon_cmd.step);
}
