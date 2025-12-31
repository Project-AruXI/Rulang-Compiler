// zig fmt: off

const std = @import("std");


pub fn build(b: *std.Build) void {
  const target = b.standardTargetOptions(.{});

  const optimize = b.standardOptimizeOption(.{});

  const exe = b.addExecutable(.{
    .name = "arxc",
    .root_module = b.createModule(.{
      .root_source_file = b.path("cli.zig"),
      .target = target,
      .optimize = optimize,
    }),
  });

  const options = b.addOptions();
  options.addOption(bool, "dprint", b.option(bool, "dprint", "Enable debug printing") orelse false);
  exe.root_module.addOptions("build_options", options);

  const cliargs = b.dependency("yazap", .{});
  exe.root_module.addImport("args", cliargs.module("yazap"));

  const cham = b.dependency("chameleon", .{});
  exe.root_module.addImport("chameleon", cham.module("chameleon"));

  const install_exe = b.addInstallArtifact(exe, .{
    .dest_dir = .{
      .override = .{ .custom = "../out" },
    },
  });
  
  b.getInstallStep().dependOn(&install_exe.step);

  const run_step = b.step("run", "Run the app");

  const run_cmd = b.addRunArtifact(exe);
  run_step.dependOn(&run_cmd.step);

  run_cmd.step.dependOn(b.getInstallStep());

  if (b.args) |args| {
    run_cmd.addArgs(args);
  }

  const exe_tests = b.addTest(.{
    .root_module = exe.root_module,
  });

  const run_exe_tests = b.addRunArtifact(exe_tests);

  const test_step = b.step("test", "Run tests");
  test_step.dependOn(&run_exe_tests.step);
}