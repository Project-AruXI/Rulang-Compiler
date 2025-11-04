#ifndef _CONFIG_H_
#define _CONFIG_H_

#include <stdbool.h>
#include <stdint.h>


// Config struct to keep track of:
// Which warnings to show
// To include debug symbols or not
// Whether warnings are fatal or not
// Output filename

typedef uint8_t FLAGS8;

typedef struct Config {
	bool useDebugSymbols;
	bool warningAsFatal;
	const char* outbin;
	FLAGS8 warnings;

	bool compileOnly; // Generate assembly and stop
	bool assembleOnly; // Generate object files and stop

	struct {
		char** argv;
		int arglen;
		int argcap;
	} assemblerArgs;

	struct {
		char** argv;
		int arglen;
		int argcap;
	} linkerArgs;
} Config;

typedef enum {
	WARN_FLAG_NONE = 0x00,
	WARN_FLAG_UNUSED_SYMB = 1 << 0,
	WARN_FLAG_OVERFLOW = 1 << 1,
	WARN_FLAG_UNREACHABLE = 1 << 2,
	WARN_FLAG_ALL = 0xFF
} WarningFlags;

#define WARNING_ENABLED(config, warning) ((config).warnings & (warning))

#endif