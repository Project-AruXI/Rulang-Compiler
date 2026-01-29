// zig fmt: off

const std = @import("std");

// const debug = @import("../utils/debug.zig");

// extern const Dbg: debug.Debug;

pub const Symbol = struct {
  name: []const u8,
  scopeLevel: usize,
  isUsed: bool,
};

pub const Scope = struct {
  allocator: std.mem.Allocator,

  symbols: std.StringHashMap(Symbol),
  parent: ?*Scope,
  children: std.ArrayList(Scope),
  level: usize,

  pub fn init(allocator: std.mem.Allocator, parent: ?*Scope) Scope {
    return Scope{
      .allocator = allocator,
      .symbols = .init(allocator),
      .parent = parent,
      .children = .empty,
      .level = if (parent) |p| p.level + 1 else 0,
    };
  }
};