// zig fmt: off

const std = @import("std");
const allocator = std.heap.page_allocator;

const args = @import("args");


pub fn runBuild(argmatch: args.ArgMatches) !void {
	_ = argmatch;
	std.debug.print("Build runner invoked...\n", .{});
}