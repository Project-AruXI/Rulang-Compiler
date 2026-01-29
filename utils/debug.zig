// zig fmt: off

const std = @import("std");
const buildopts = @import("build_options");

const Chameleon = @import("chameleon");

pub const DbgLvl = enum {
  DBG_BASIC,
  DBG_DETAIL,
  DBG_TRACE
};

pub const Debug = struct {
  clr:Chameleon.RuntimeChameleon = undefined,

  pub fn init(allocator: std.mem.Allocator) Debug {
    return Debug{
      .clr = Chameleon.initRuntime(.{ .allocator = allocator })
    };
  }

  pub fn debug(this: *Debug, lvl: DbgLvl, comptime fmt: []const u8, fmtargs: anytype) void {
    if (buildopts.dprint) {
      var colorstr: []const u8 = undefined;
      switch (lvl) {
        DbgLvl.DBG_BASIC => {
          colorstr = this.clr.cyan().fmt(fmt, fmtargs) catch "";
        },
        DbgLvl.DBG_DETAIL => {
          colorstr = this.clr.blue().fmt(fmt, fmtargs) catch "";
        },
        DbgLvl.DBG_TRACE => {
          colorstr = this.clr.magenta().fmt(fmt, fmtargs) catch "";
        },
      }
      std.debug.print("{s}", .{colorstr});
    }
  }
};
