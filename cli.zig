// zig fmt: off

const std = @import("std");
const args = @import("args");
const App = args.App;
const Arg = args.Arg;

const config = @import("config.zig");
const compiler = @import("compiler.zig");

const MAJOR_VERSION = 0;
const MINOR_VERSION = 1;
const PATCH_VERSION = 0;

const BUILD_MAJOR_VERSION = 0;
const BUILD_MINOR_VERSION = 0;
const BUILD_PATCH_VERSION = 0;

var buffer: [1024]u8 = undefined;
var w = std.fs.File.stdout().writer(&buffer);
const stdout = &w.interface;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

var cfg = config.Config{
  .useDebugSymbols = false,
  .warningAsFatal = false,
  .outbin = "out.aru",
  .warnings = config.WarningFlags.NONE,
  .compileOnly = false,
  .assembleOnly = false,
  .assemblerArgs = &[_][]const u8{},
  .linkerArgs = &[_][]const u8{},
};


fn parseArgs() ![][]const u8 {
  var cliargs = App.init(std.heap.page_allocator, "arxc", "Desc");
  defer cliargs.deinit();

  var cli = cliargs.rootCommand();
  cli.setProperty(.help_on_empty_args);

  try cli.addArgs(&[_]Arg{
    Arg.singleValueOption("output", 'o', "Output file"),
    Arg.booleanOption("version", 'V', "Show version and exit"),
    Arg.booleanOption("assemble", 's', "Assemble files but do not link."),
    Arg.booleanOption("compile", 'c', "Generate assembly files but do not assemble."),
    Arg.multiValuesOption("assembler", null, "Pass arguments to assembler", 5), // for now assume assembler can take in 5
    Arg.multiValuesOption("linker", null, "Pass arguments to linker", 5), // for now assume linker can take in 5
  });

  try cli.addArg(Arg.multiValuesPositional("files", null, null));

  const matches = try cliargs.parseProcess();

  if (matches.containsArg("version")) {
    try stdout.print("Rulang Compiler version {}.{}.{}\n", .{ MAJOR_VERSION, MINOR_VERSION, PATCH_VERSION });
    try stdout.flush();
    std.process.exit(0);
  }

  if (!matches.containsArg("files")) {
    try stdout.print("No input files specified.\n", .{});
    try cliargs.displayHelp();
    std.process.exit(1);
  }

  // Add the values from assembler and linker args
  if (matches.getMultiValues("assembler")) | assemblerArgs | {
    cfg.assemblerArgs = assemblerArgs;
  }
  if (matches.getMultiValues("linker")) | linkerArgs | {
    cfg.linkerArgs = linkerArgs;
  }

  if (matches.containsArg("output")) {
    cfg.outbin = matches.getSingleValue("output");
  }

  if (matches.containsArg("assemble")) {
    cfg.assembleOnly = true;
  }
  if (matches.containsArg("compile")) {
    cfg.compileOnly = true;
  }

  const raw_files = matches.getMultiValues("files").?;

  // Duplicate the file names into our allocator so they outlive `cliargs`
  var files_list = try std.ArrayList([]const u8).initCapacity(allocator, raw_files.len);
  defer files_list.deinit(allocator);
  for (raw_files) |f| {
    const dup = try allocator.dupe(u8, f);
    try files_list.append(allocator, dup);
  }

  // Return an owned slice allocated from `allocator` containing the file name slices.
  return try files_list.toOwnedSlice(allocator);
}

fn callAssembler(filename: []const u8) !std.process.Child.Term {
  var args_list = try std.ArrayList([]const u8).initCapacity(allocator, 8);
  defer args_list.deinit(allocator);

  // program name
  try args_list.append(allocator, "arxsm");

  // -o <filename>.ao
  try args_list.append(allocator, "-o");
  const outname = try std.fmt.allocPrint(allocator, "{s}.ao", .{filename});
  defer allocator.free(outname);
  try args_list.append(allocator, outname);

  // <filename>.s
  const asmname = try std.fmt.allocPrint(allocator, "{s}.s", .{filename});
  defer allocator.free(asmname);
  try args_list.append(allocator, asmname);

  // assembler args: each prefixed with '-'
  for (cfg.assemblerArgs) |a| {
    const pref = try std.fmt.allocPrint(allocator, "-{s}", .{a});
    defer allocator.free(pref);
    try args_list.append(allocator, pref);
  }

  if (cfg.useDebugSymbols) {
    try args_list.append(allocator, "-g");
  }

  // Execute the process and wait for it to finish
  const argv = args_list.items;

  var proc = std.process.Child.init(argv, allocator);
  proc.spawn() catch |err| {
    try stdout.print("Failed to spawn assembler process: {}\n", .{err});
    return err;
  };
  const status = proc.wait() catch |err| {
    try stdout.print("Failed to wait for assembler process: {}\n", .{err});
    return err;
  };

  return status;
}

fn callLinker(files: std.ArrayList([]const u8)) !void {
  std.debug.print("Linking {} object files...\n", .{files.items.len});

  var args_list = try std.ArrayList([]const u8).initCapacity(allocator, 8 + files.items.len);
  defer args_list.deinit(allocator);

  // program name
  try args_list.append(allocator, "arxlnk");

  // -o <output file>
  try args_list.append(allocator, "-o");
  const outname = cfg.outbin orelse "out.aru";
  try args_list.append(allocator, outname);

  // <filename>.ao for each file
  for (files.items) |filename| {
    const objname = try std.fmt.allocPrint(allocator, "{s}.ao", .{filename});
    std.debug.print("Linking object file: {s}\n", .{objname});
    defer allocator.free(objname);
    try args_list.append(allocator, objname);
  }

  // linker args: each prefixed with '-'
  for (cfg.linkerArgs) |a| {
    const pref = try std.fmt.allocPrint(allocator, "-{s}", .{a});
    defer allocator.free(pref);
    try args_list.append(allocator, pref);
  }

  // Execute the process and wait for it to finish
  const argv = args_list.items;

  var cmd_buf: [2048]u8 = undefined;
  var cmd_pos: usize = 0;
  const p0 = try std.fmt.bufPrint(cmd_buf[cmd_pos..], "Running linker command:", .{});
  cmd_pos += p0.len;
  for (args_list.items) |arg| {
    const p = try std.fmt.bufPrint(cmd_buf[cmd_pos..], " {s}", .{arg});
    cmd_pos += p.len;
  }
  const p1 = try std.fmt.bufPrint(cmd_buf[cmd_pos..], "\n", .{});
  cmd_pos += p1.len;
  std.debug.print("{s}", .{cmd_buf[0..cmd_pos]});

  var proc = std.process.Child.init(argv, allocator);
  proc.spawn() catch |err| {
    try stdout.print("Failed to spawn linker process: {}\n", .{err});
    return err;
  };
  const status = proc.wait() catch |err| {
    try stdout.print("Failed to wait for linker process: {}\n", .{err});
    return err;
  };

  if (status.Exited != 0) {
    return error.LinkingFailed;
  }

  return;
}

pub fn main() !void {
  const infiles = parseArgs() catch |err| {
    try stdout.print("Error parsing arguments: {}\n", .{err});
    return err;
  };

  std.debug.print("Infiles count: {d}\n", .{infiles.len});

  // Note that some files may be .ru files or .s files
  // .s files are to be assembled directly
  // .ru are to be compiled to .s first, then assembled
  // Todo later: handle assembly files as processes for parallelism, only if after some number of assembly files
  // Maybe if there are 3 or more assembly files, spawn processes to assemble them in parallel

  // Array to hold the names of the files, this is used to easily convert for object or assembly
  // Basically removing the extension
  var files = try std.ArrayList([]const u8).initCapacity(allocator, infiles.len);
  defer files.deinit(allocator);

  var idx: usize = 0;
  for (infiles) |infile| {
    std.log.debug("Input file {d}: {s} ", .{idx, infile});

    const ext = std.fs.path.extension(infile);
    std.debug.print("with extension: {s}\n", .{ext});
    if (ext.len != 0) {
      if (std.mem.eql(u8, ext, ".ru")) {
      // Remove .ru extension
      const bname = std.fs.path.basename(infile);
      const base = bname[0..bname.len - 3];
      try files.append(allocator, base);

      std.debug.print("Compiling Rulang source file: {s}\n", .{infile});
      if (!compiler.compile(cfg, infile)) {
        _ = files.pop();
        idx += 1;
        continue;
      }
      std.debug.print("Compilation of {s} succeeded.\n", .{infile});
      
      if (cfg.compileOnly) {
        // When compile-only is on, skip assembling
        _ = files.pop();
        idx += 1;
        continue;
      }
      const status = callAssembler(base) catch {
        _ = files.pop();
        idx += 1;
        continue;
      };
      if (status.Exited != 0) {
        _ = files.pop();
      }

      } else if (std.mem.eql(u8, ext, ".s") or std.mem.eql(u8, ext, ".asm") or std.mem.eql(u8, ext, ".as") or std.mem.eql(u8, ext, ".ars")) {
      // When the option to compile-only is on
      // It shall mean that all files are to be assembly
      // Meaning do not handle assembly files
      if (cfg.compileOnly) {
        std.debug.print("Compile-only option is set; skipping assembly file: {s}\n", .{infile});
        _ = files.pop();
        idx += 1;
        continue;
      }

      // Remove .s extension
      const bname = std.fs.path.basename(infile);
      const base = bname[0..bname.len - 2];
      try files.append(allocator, base);

      const status = callAssembler(base) catch {
        _ = files.pop();
        idx += 1;
        continue;
      };
      if (status.Exited != 0) {
        _ = files.pop();
      }
      } else {
        try stdout.print("Unsupported file extension: {s}\n", .{infile});
      }
    } else {
      try stdout.print("Input file {s} has no extension, cannot determine type.\n", .{infile});
    }

    idx += 1;
  }

  if (cfg.assembleOnly) {
    try stdout.print("Assemble-only option is set; skipping linking step.\n", .{});
    return;
  }

  if (files.items.len == 0) {
    try stdout.print("No files to link after compilation/assembly steps.\n", .{});
    return;
  }

  // All files assembled to .ao files
  // Now link them
  callLinker(files) catch |err| {
    try stdout.print("Linking failed: {}\n", .{err});
    return err;
  };
}