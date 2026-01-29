// zig fmt: off

pub const FLAGS8 = u8;
pub const WarningFlags = enum(FLAGS8) {
  NONE = 0x00,
  UNUSED_SYMB = 1 << 0,
  OVERFLOW = 1 << 1,
  UNREACHABLE = 1 << 2,
  ALL = 0xFF,
};

pub const Config = struct {
  useDebugSymbols: bool,
  warningAsFatal: bool,
  outbin: []const u8,
  warnings: WarningFlags,

  compileOnly: bool, // Generate assembly and stop
  assembleOnly: bool, // Generate object files and stop

  assemblerArgs: []const []const u8,
  linkerArgs: []const []const u8,

  pub fn init(outbin: ?[]const u8, assembleOnly: bool, compileOnly: bool) Config {
    return Config{
      .useDebugSymbols = false,
      .warningAsFatal = false,
      .outbin = outbin orelse "out.aru",
      .warnings = WarningFlags.NONE,
      .compileOnly = compileOnly,
      .assembleOnly = assembleOnly,
      .assemblerArgs = &[_][]const u8{},
      .linkerArgs = &[_][]const u8{},
    };
  }
};

pub inline fn warningEnabled(cfg: *const Config, warning: WarningFlags) bool {
  return (cfg.warnings & warning) != 0;
}