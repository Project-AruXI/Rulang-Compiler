// zig fmt: off

const std = @import("std");
const config = @import("config.zig");


pub fn compile(cfg: config.Config, filename: []const u8) bool {
	const out = cfg.outbin;
	std.debug.print("compile {s}: output={s}, assemble={}, compile_only={}\n", .{ filename, out, cfg.assembleOnly, cfg.compileOnly });






	
	return true;
}