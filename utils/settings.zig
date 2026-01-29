// zig fmt: off

const bitset = @import("std").bit_set;

pub const WarningFlag = enum {
	UNREACHABLE_CODE,
	UNUSED_VARIABLE,
	UNUSED_FUNCTION,
	UNUSED_IMPORT,
	UNUSED_PARAMETER,
	DEPRECATED,
	ALL,
};

pub const Architecture = enum {
	ARU32, // Only valid through native backend (and maybe LLVM backend)
	X86_64, // Only valid through LLVM backend and C backend
	ARM64, // Only valid through LLVM backend and C backend
};

pub const Backend = enum {
	Native,
	LLVM,
	C,
};

pub const CompilerSettings = struct {
	optimizeLevel: u8, // unused for now
	targetArch: Architecture, // unused for now
	targetBackend: Backend, // unused for now
	verbose: bool, // unused for now

	disableWarnings: bool, // emit no warnings
	warningsAsErrors: bool, // treat warnings as errors
	enabledWarnings: bitset.IntegerBitSet(16),

	pub fn init(disableWarnings: bool, warningsAsErrors: bool) CompilerSettings {
		const enabledWarnings = bitset.IntegerBitSet(16).initFull();

		return CompilerSettings{
			.optimizeLevel = 0,
			.targetArch = .ARU32, // default target architecture
			.targetBackend = .Native, // default target backend
			.verbose = false,
			.disableWarnings = disableWarnings,
			.warningsAsErrors = warningsAsErrors,
			.enabledWarnings = enabledWarnings,
		};
	}
};