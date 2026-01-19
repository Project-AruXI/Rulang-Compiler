// zig fmt: off

const std = @import("std");
const buildopts = @import("build_options");
const args = @import("args");
const App = args.App;
const Arg = args.Arg;
const Command = args.Command;
const Chameleon = @import("chameleon");

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

var clr:Chameleon.RuntimeChameleon = undefined;

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


const DbgLvl = enum {
  DBG_BASIC,
  DBG_DETAIL,
  DBG_TRACE
};


fn debug(lvl: DbgLvl, comptime fmt: []const u8, fmtargs: anytype) void {
  if (buildopts.dprint) {
    var colorstr: []const u8 = undefined;
    switch (lvl) {
      DbgLvl.DBG_BASIC => { 
        colorstr = clr.cyan().fmt(fmt, fmtargs) catch "";
      },
      DbgLvl.DBG_DETAIL => { 
        colorstr = clr.blue().fmt(fmt, fmtargs) catch "";
      },
      DbgLvl.DBG_TRACE => { 
        colorstr = clr.magenta().fmt(fmt, fmtargs) catch "";
      },
    }
    std.debug.print("{s}", .{colorstr});
  }
}


fn buildLinkerArgs(matches: args.ArgMatches) !void {
  // Build the linker args into config.linkerArgs
  // Linker args come from the following sources:
  //   getSingleValue("linker") - a single string being the argument (ie "--linker=d")
  //   getMultiValues("linker") - multiple strings being the arguments (ie "--linker=d,k")
  //   getSingleValue("libpath") - a single string being the library path (ie "--libpath=path")
  //   getMultiValues("libpath") - multiple strings being the library paths (ie "--libpath=path1,path2")
  //   getSingleValue("libs") - a single string being the library name (ie "--libs=math")
  //   getMultiValues("libs") - multiple strings being the library names (ie "--libs=math,util")
  // Resulting string array should be in the form of:
  // ["d", "k", "Lpath1,path2", "lmath,util"]
  // and placed into config.linkerArgs

  var linkerArgsList = try std.ArrayList([]const u8).initCapacity(allocator, 10);
  defer linkerArgsList.deinit(allocator);

  if (matches.getMultiValues("linker")) | linkerArgs | {
    for (linkerArgs) |arg| {
      debug(.DBG_BASIC, "Linker arg specified: {s}\n", .{arg});
      try linkerArgsList.append(allocator, try allocator.dupe(u8, arg));
    }
  }
  if (matches.getSingleValue("linker")) | linkerArg | {
    debug(.DBG_BASIC, "Single linker arg specified: {s}\n", .{linkerArg});
    try linkerArgsList.append(allocator, try allocator.dupe(u8, linkerArg));
  }

  // Handle libpaths
  if (matches.getMultiValues("libpath")) |libpaths| {
    for (libpaths) |lp| {
      debug(.DBG_BASIC, "Library path specified: {s}\n", .{lp});
      const arg = try std.fmt.allocPrint(allocator, "libpath={s}", .{lp});
      try linkerArgsList.append(allocator, arg);
    }
  }
  if (matches.getSingleValue("libpath")) |libpath| {
    debug(.DBG_BASIC, "Single library path specified: {s}\n", .{libpath});
    const arg = try std.fmt.allocPrint(allocator, "libpath={s}", .{libpath});
    try linkerArgsList.append(allocator, arg);
  }

  // Handle libs
  if (matches.getMultiValues("libs")) |libs| {
    for (libs) |lib| {
      debug(.DBG_BASIC, "Library specified: {s}\n", .{lib});
      const arg = try std.fmt.allocPrint(allocator, "library={s}", .{lib});
      try linkerArgsList.append(allocator, arg);
    }
  }
  if (matches.getSingleValue("libs")) |lib| {
    debug(.DBG_BASIC, "Single library specified: {s}\n", .{lib});
    const arg = try std.fmt.allocPrint(allocator, "library={s}", .{lib});
    try linkerArgsList.append(allocator, arg);
  }
  cfg.linkerArgs = try linkerArgsList.toOwnedSlice(allocator);

  // debug output of final linker args
  debug(.DBG_DETAIL, "Final linker args ({d}):\n", .{cfg.linkerArgs.len});
  for (cfg.linkerArgs) |arg| {
    debug(.DBG_DETAIL, "  {s}\n", .{arg});
  }
}


fn parseArgs() ![][]const u8 {
  var cliargs = App.init(std.heap.page_allocator, "arxc", "Desc");
  defer cliargs.deinit();

  var cli = cliargs.rootCommand();
  cli.setProperty(.help_on_empty_args);

  try cli.addArgs(&[_]Arg{
    Arg.singleValueOption("output", 'o', "Output file"),
    Arg.booleanOption("version", 'V', "Show version and exit"),
    Arg.booleanOption("debug", 'g', "Include debug symbols in output"),
    Arg.booleanOption("assemble", 's', "Assemble files but do not link."),
    Arg.booleanOption("compile", 'c', "Generate assembly files but do not assemble."),
    Arg.multiValuesOption("assembler", null, "Pass arguments to assembler", 5), // for now assume assembler can take in 5
    Arg.multiValuesOption("linker", null, "Pass arguments to linker", 5), // for now assume linker can take in 5
    Arg.multiValuesOption("libpath", 'L', "Library path", 10),
    Arg.multiValuesOption("libs", 'l', "Libraries", 10),
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

  if (matches.containsArg("debug")) {
    cfg.useDebugSymbols = true;
  }

  // Add the values from assembler and linker args
  if (matches.getMultiValues("assembler")) | assemblerArgs | {
    const len = assemblerArgs.len;
    const ptrs = try allocator.alloc([]const u8, len);
    var i: usize = 0;
    while (i < assemblerArgs.len) : (i += 1) {
      const a = assemblerArgs[i];
      ptrs[i] = try allocator.dupe(u8, a);
    }
    cfg.assemblerArgs = ptrs[0..len];
  }
  if (matches.getSingleValue("assembler")) | assemblerArg | {
    debug(.DBG_BASIC, "Single assembler arg specified: {s}\n", .{assemblerArg});
    const ptr = try allocator.dupe(u8, assemblerArg);
    cfg.assemblerArgs = &[_][]const u8{ptr};
  }

  buildLinkerArgs(matches) catch |err| {
    try stdout.print("Error building linker args: {}\n", .{err});
    return err;
  };

  if (matches.containsArg("output")) {
    if (matches.getSingleValue("output")) |val| {
      cfg.outbin = try allocator.dupe(u8, val);
    }
  }

  if (matches.containsArg("assemble")) {
    cfg.assembleOnly = true;
  }
  if (matches.containsArg("compile")) {
    cfg.compileOnly = true;
  }

  const files = matches.getMultiValues("files").?;

  // Duplicate the file names so they outlive `cliargs`
  var fileList = try std.ArrayList([]const u8).initCapacity(allocator, files.len);
  defer fileList.deinit(allocator);
  for (files) |f| {
    const dup = try allocator.dupe(u8, f);
    try fileList.append(allocator, dup);
  }

  // Return an owned slice allocated from `allocator` containing the file name slices.
  return try fileList.toOwnedSlice(allocator);
}

fn callAssembler(filename: []const u8) !std.process.Child.Term {
  var cmdList = try std.ArrayList([]const u8).initCapacity(allocator, 8);
  defer cmdList.deinit(allocator);

  var allocated = try std.ArrayList([]u8).initCapacity(allocator, 8);
  defer {
    for (allocated.items) |b| allocator.free(b);
    allocated.deinit(allocator);
  }

  // program name
  try cmdList.append(allocator, "arxsm");

  // -o <filename>.ao
  try cmdList.append(allocator, "-o");
  const outname = try std.fmt.allocPrint(allocator, "{s}.ao", .{filename});
  try allocated.append(allocator, outname);
  try cmdList.append(allocator, outname);

  // <filename>.s
  const asmname = try std.fmt.allocPrint(allocator, "{s}.s", .{filename});
  try allocated.append(allocator, asmname);
  try cmdList.append(allocator, asmname);

  // assembler args: each prefixed with '-'
  for (cfg.assemblerArgs) |a| {
    const pref = try std.fmt.allocPrint(allocator, "-{s}", .{a});
    try allocated.append(allocator, pref);
    try cmdList.append(allocator, pref);
  }

  if (cfg.useDebugSymbols) {
    try cmdList.append(allocator, "-g");
  }

  // Execute the process and wait for it to finish
  const argv = cmdList.items;

  debug(.DBG_TRACE, "Assembler command:\n", .{});
  for (argv) |arg| {
    debug(.DBG_TRACE, " {s}", .{arg});
  }
  debug(.DBG_TRACE, "\n", .{});

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
  debug(.DBG_BASIC, "Linking {d} object files...\n", .{files.items.len});

  var cmdList = try std.ArrayList([]const u8).initCapacity(allocator, 8 + files.items.len);
  defer cmdList.deinit(allocator);

  // program name
  try cmdList.append(allocator, "arxlnk");

  // -o <output file>
  try cmdList.append(allocator, "-o");
  try cmdList.append(allocator, cfg.outbin);

  // <filename>.ao for each file
  for (files.items) |filename| {
    const objname = try std.fmt.allocPrint(allocator, "{s}.ao", .{filename});
    debug(.DBG_BASIC, "Linking object file: {s}\n", .{objname});
    // defer allocator.free(objname);
    try cmdList.append(allocator, objname);
  }

  // linker args: each prefixed with '-'
  for (cfg.linkerArgs) |a| {
    debug(.DBG_BASIC, "Linker arg before prefix: {s}\n", .{a});
    const pref = try std.fmt.allocPrint(
      allocator, "-{s}{s}", .{
        if (a.len == 1) "" else "-",
        a
      }
    );
    debug(.DBG_BASIC, "Linker arg: {s} from {s}\n", .{pref, a});
    // defer allocator.free(pref);
    try cmdList.append(allocator, pref);
  }

  // Execute the process and wait for it to finish
  const argv = cmdList.items;

  var cmdBuf: [2048]u8 = undefined;
  var cmdPos: usize = 0;
  for (cmdList.items) |arg| {
    const p = try std.fmt.bufPrint(cmdBuf[cmdPos..], "{s} ", .{arg});
    cmdPos += p.len;
  }
  const p1 = try std.fmt.bufPrint(cmdBuf[cmdPos..], "\n", .{});
  cmdPos += p1.len;
  debug(.DBG_BASIC, "Running linker command: {s}", .{cmdBuf[0..cmdPos]});

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
  clr = Chameleon.initRuntime(.{ .allocator = allocator });

  const infiles = parseArgs() catch |err| {
    try stdout.print("Error parsing arguments: {}\n", .{err});
    return err;
  };

  debug(.DBG_BASIC, "Infiles count: {d}\n", .{infiles.len});

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
    debug(.DBG_BASIC, "Input file {d}: '{s}' ", .{idx, infile});

    const ext = std.fs.path.extension(infile);
    debug(.DBG_BASIC, "with extension: {s}\n", .{ext});
    if (ext.len != 0) {
      if (std.mem.eql(u8, ext, ".ru")) {
        // Remove .ru extension
        const base = infile[0..infile.len - 3];
        try files.append(allocator, base);

        debug(.DBG_BASIC, "Compiling Rulang source file: {s}\n", .{infile});
        if (!compiler.compile(cfg, infile)) {
          _ = files.pop();
          idx += 1;
          continue;
        }
        debug(.DBG_BASIC, "Compilation of {s} succeeded.\n", .{infile});

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
          debug(.DBG_BASIC, "Compile-only option is set; skipping assembly file: {s}\n", .{infile});
          _ = files.pop();
          idx += 1;
          continue;
        }

        // Remove .s extension
        const base = infile[0..infile.len - 2];
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
        try stdout.flush();
      }
    } else {
      try stdout.print("Input file {s} has no extension, cannot determine type.\n", .{infile});
      try stdout.flush();
    }

    idx += 1;
  }

  if (cfg.assembleOnly) {
    try stdout.print("Assemble-only option is set; skipping linking step.\n", .{});
    try stdout.flush();
    return;
  }

  if (files.items.len == 0) {
    try stdout.print("No files to link after compilation/assembly steps.\n", .{});
    try stdout.flush();
    return;
  }

  // All files assembled to .ao files
  // Now link them
  std.debug.print("Will call linker\n", .{});
  callLinker(files) catch |err| {
    try stdout.print("Linking failed: {}\n", .{err});
    try stdout.flush();
    return err;
  };
}