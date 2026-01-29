// zig fmt: off

const std = @import("std");

// const CompilerSettings = @import("utils").settings.CompilerSettings;
const CompilerSettings = @import("../utils/settings.zig").CompilerSettings;
const Scope = @import("scope.zig").Scope;

pub const Parser = struct {
  allocator: std.mem.Allocator,

  settings: CompilerSettings,
  scopes: Scope,
  currentScope: Scope,

  pub fn init(allocator: std.mem.Allocator, settings: CompilerSettings) Parser {
    const scope = Scope.init(allocator, null);

    return Parser{
      .allocator = allocator,
      .settings = settings,
      .scopes = scope,
      .currentScope = scope
    };
  }

  pub fn parse(this: *Parser, source: []const u8) void {
    _ = this;
    _ = source;
    // parsing logic goes here
  }

  pub fn openScope(this: *Parser) !void {
    const newScope = Scope.init(this.allocator, &this.currentScope);
    // Add newScope to the children of currentScope
    try this.currentScope.children.append(this.allocator, newScope);
    this.currentScope = newScope;
  }

  pub fn closeScope(this: *Parser) void {
    // Maybe check for unused symbols??

    this.currentScope = this.currentScope.parent orelse this.currentScope;
  }
};


