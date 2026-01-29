// zig fmt: off

const std = @import("std");
const config = @import("config.zig");

// const debug = @import("utils").debug;
// const CompilerSettings = @import("utils").settings.CompilerSettings;
// const Lexer = @import("lexer").lexer.Lexer;
// const Parser = @import("parser").parser.Parser;
const debug = @import("utils/debug.zig");
const CompilerSettings = @import("utils/settings.zig").CompilerSettings;
const Lexer = @import("lexer/mod.zig").lexer.Lexer;
const Parser = @import("parser/mod.zig").parser.Parser;


pub fn compile(cfg: config.Config, filename: []const u8, dbg: *debug.Debug) bool {
  var debugAllocator: std.heap.DebugAllocator(.{}) = .init;
  const allocator = debugAllocator.allocator();
  

  const out = cfg.outbin;
  dbg.debug(.DBG_BASIC, "Compile {s}: output={s}\n", .{ filename, out });

  const file = std.fs.cwd().openFile(filename, .{}) catch {
    // std.debug.print("Error: Could not open file {s}\n", .{ filename });
    dbg.debug(.DBG_BASIC, "Error: Could not open file {s}\n", .{ filename });
    return false;
  };
  defer file.close();
  const fileSize = file.getEndPos() catch {
    // std.debug.print("Error: Could not get file size for {s}\n", .{ filename });
    dbg.debug(.DBG_BASIC, "Error: Could not get file size for {s}\n", .{ filename });
    return false;
  };
  const fileBuffer = allocator.alloc(u8, fileSize) catch {
    // std.debug.print("Error: Could not allocate buffer for file {s}\n", .{ filename });
    dbg.debug(.DBG_BASIC, "Error: Could not allocate buffer for file {s}\n", .{ filename });
    return false;
  };
  defer allocator.free(fileBuffer);

  var fileReader = file.reader(fileBuffer);
  const data = fileReader.interface.readAlloc(allocator, fileSize) catch {
    // std.debug.print("Error: Could not read file {s}\n", .{ filename });
    dbg.debug(.DBG_BASIC, "Error: Could not read file {s}\n", .{ filename });
    return false;
  };
  defer allocator.free(data);

  const disableWarnings = cfg.warnings == config.WarningFlags.NONE;

  const compilerSettings = CompilerSettings.init(disableWarnings, cfg.warningAsFatal);

  // lex and parse
  var lexer = Lexer.init(allocator, data);
  var parser = Parser.init(allocator, compilerSettings);
  lexer = lexer;
  parser = parser;

  while (true) {
    const token = lexer.nextToken() catch |err| {
      dbg.debug(.DBG_BASIC, "Lexing error: {}\n", .{err});
      return false;
    };
    if (token.tokType == .Eof) break;
    // std.debug.print("Token: {s}\n", .{token.toString()});
    dbg.debug(.DBG_TRACE, "Token: {}\n", .{token});
  }


  // semantic analysis


  // codegen





  return true;
}