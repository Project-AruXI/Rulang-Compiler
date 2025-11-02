#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <stdbool.h>

#include "diagnostics.h"
#include "config.h"

static char FN_SCOPE[64];
static char buffer[164];
static Config config;


// Treating warnings as error preceeds doWarn
// Ie if `arxc -W -F`, `-W` is ignored

static char* errnames[ERR_NOT_ALLOWED + 1] = {
	"INTERNAL ERROR",
	"MEMORY ERROR",
	"I/O ERROR",
	"REDEFINITION ERROR",
	"UNDEFINED ERROR",
	"INVALID SYNTAX",
	"INVALID EXPRESSION",
	"NOT ALLOWED",
};

static char* warnnames[WARN_UNIMPLEMENTED + 1] = {
	"UNREACHABLE CODE",
	"UNEXPECTED BEHAVIOR",
	"UNIMPLEMENTED FEATURE"
};

static void formatMessage(const char* fmsg, va_list args) {
	vsnprintf(buffer, sizeof(buffer), fmsg, args);
}

void emitError(errType err, linedata_ctx* linedata, const char* fmsg, ...) {
	va_list args;
	va_start(args, fmsg);

	formatMessage(fmsg, args);

	if (linedata) fprintf(stderr, RED "[%s] at `%s` (%d): %s%s\n", errnames[err], linedata->source, linedata->linenum, buffer, RESET);
	else if (err == ERR_BLANK) fprintf(stderr, RED "%s%s\n", buffer, RESET);
	else fprintf(stderr, RED "[%s]: %s%s\n", errnames[err], buffer, RESET);
	exit(-1);
}


void emitWarning(warnType warn, linedata_ctx* linedata, const char* fmsg, ...) {
	if (config.warningAsFatal) {
		emitError((errType)warn, linedata, fmsg);
		return;
	}

	if (config.warnings == WARN_FLAG_NONE) return;

	// Allow filtering of warning types
	if (!WARNING_ENABLED(config, WARN_FLAG_UNREACHABLE) && warn == WARN_UNREACHABLE) return;

	va_list args;
	va_start(args, fmsg);

	formatMessage(fmsg, args);

	if (linedata) fprintf(stderr, YELLOW "[%s] at `%s` (%d): %s%s\n", warnnames[warn], linedata->source, linedata->linenum, buffer, RESET);
	else fprintf(stderr, YELLOW "[%s]: %s%s\n", warnnames[warn], buffer, RESET);
}

void initScope(const char* fxnName) {
	snprintf(FN_SCOPE, sizeof(FN_SCOPE), "%s", fxnName);
}

void debug(debugLvl lvl, const char* fmsg, ...) {
#ifdef DEBUG
	va_list args;
	va_start(args, fmsg);

	formatMessage(fmsg, args);

	char* color;
	switch (lvl) {
		case DEBUG_BASIC: color = CYAN; break;
		case DEBUG_DETAIL: color = BLUE; break;
		case DEBUG_TRACE: color = MAGENTA; break;
		default: color = CYAN; break;
	}

	fprintf(stderr, "%s@%s::%s%s\n", color, FN_SCOPE, buffer, RESET);
#endif
}

void rdebug(debugLvl lvl, const char *fmsg, ...) {
#ifdef DEBUG
	va_list args;
	va_start(args, fmsg);

	formatMessage(fmsg, args);

	char* color;
	switch (lvl) {
		case DEBUG_BASIC: color = CYAN; break;
		case DEBUG_DETAIL: color = BLUE; break;
		case DEBUG_TRACE: color = MAGENTA; break;
		default: color = CYAN; break;
	}

	fprintf(stderr, "%s%s%s\n", color, buffer, RESET);
#endif
}