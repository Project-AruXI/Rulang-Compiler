module main;

@import a as imported;
// or @import a, forced to use `a` instead of `imported`
// or @import a::{EXPORT_VAR}, can use `EXPORT_VAR` only

fxn main() int {
	// do something with SOME_CONST

	// do something with imported.EXPORT_VAR

	imported.exportedFunction() catch |err| {
		return -1;
	}

	return 0;
}