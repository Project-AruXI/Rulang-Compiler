// zig fmt: off

// const Token = @import("ast").token.Token;
const Token = @import("../ast/token.zig").Token;

pub const CompilerReporter = struct {
  filepath: []const u8,
  message: []const u8,
  token: ?Token,
  detail: []const u8,

  pub fn init(filepath: []const u8) CompilerReporter {
    return CompilerReporter{
      .filepath = filepath,
      .message = "",
      .token = null,
      .detail = "",
    };
  }
};