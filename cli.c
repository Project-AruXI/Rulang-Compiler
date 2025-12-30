#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <string.h>

#include "argparse.h"
#include "config.h"
#include "diagnostics.h"
#include "compiler.h"

#define MAJOR_VERSION 0
#define MINOR_VERSION 1
#define PATCH_VERSION 0

#define BUILD_MAJOR_VERSION 0
#define BUILD_MINOR_VERSION 0
#define BUILD_PATCH_VERSION 0

Config config;


static void appendArgs(char** argv, int* arglen, int* argcap, const char* newarg) {
  if (*arglen >= *argcap) {
    *argcap *= 2;
    argv = (char**) realloc(argv, sizeof(char*) * (*argcap));
    if (!argv) emitError(ERR_MEM, NULL, "Failed to realloc memory for argument list.");
  }
  argv[*arglen] = strdup(newarg);
  (*arglen)++;
}

static void parseBuildArgs(int argc, const char** argv) {
  printf("Build system is not yet implemented.\n");
  // return;

  bool showVersion = false;

  struct argparse_option options[] = {
    OPT_HELP(),
    OPT_BOOLEAN('v', "version", &showVersion, "show version and exit", NULL, 0, 0),
    OPT_END(),
  };

  const char* const usages[] = {
    "arxc build [options]",
    NULL,
  };

  struct argparse argparse;
  argparse_init(&argparse, options, usages, 0);
  argparse_describe(&argparse, "Rulang Compiler Build Command", NULL);
  argc = argparse_parse(&argparse, argc, argv);

  if (showVersion) {
    printf("Rulang Build version %d.%d.%d\n", BUILD_MAJOR_VERSION, BUILD_MINOR_VERSION, BUILD_PATCH_VERSION);
    exit(0);
  }

  printf("After parsing build args, %d arguments remain.\n", argc);
  for (int i = 0; i < argc; i++) {
    printf("argv[%d]: %s\n", i, argv[i]);
  }
}

static void validateAssemblerArg(const char* arg) {
  if (strcmp(arg, "g") == 0) return;

  char* validAssemblerArgs[] = {
    "W",
    "F",
    "f",
    "t",
    "m",
    "p",
    "f"
  };

  for (size_t i = 0; i < sizeof(validAssemblerArgs) / sizeof(validAssemblerArgs[0]); i++) {
    if (strcmp(arg, validAssemblerArgs[i]) == 0) return;
  }

  emitError(ERR_BLANK, NULL, "Invalid assembler argument: %s", arg);
}

static int assemblerArgsCallback(struct argparse* self, const struct argparse_option* option) {
  // Arguments can be in the form of -At,m,p,f or -At -Am -Ap -Af
  // In the case that it is -At,m,p,f we need to split by commas
  // Otherwise, just append the single argument
  rlog("Assembler args callback called with value: %s", self->optvalue);

  if (!self->optvalue) {
    emitError(ERR_BLANK, NULL, "No assembler arguments provided.");
  }

  if (strchr(self->optvalue, ',')) {
    rlog("Splitting assembler args by commas.");
    char* argcopy = strdup(self->optvalue);
    char* token = strtok(argcopy, ",");
    while (token) {
      // Make sure the passed argument is valid
      // This technically could be let of for the assembler to handle it but still)
      validateAssemblerArg(token);

      // Append to assemblerArgs
      appendArgs(config.assemblerArgs.argv, &config.assemblerArgs.arglen, &config.assemblerArgs.argcap, token);
      rlog("Added assembler arg: %s", token);
      token = strtok(NULL, ",");
    }
    free(argcopy);
  } else {
    validateAssemblerArg(self->optvalue);

    rlog("Adding single assembler arg.");
    appendArgs(config.assemblerArgs.argv, &config.assemblerArgs.arglen, &config.assemblerArgs.argcap, self->optvalue);
    rlog("Added assembler arg: %s", self->optvalue);
  }

  return -1;
}

static void validateLinkerArg(const char* arg) {
  switch (arg[0]) {
    case 'l': case 'L': return;
    default: break;
  }

  emitError(ERR_BLANK, NULL, "Invalid linker argument: %s", arg);
}

static int linkerArgsCallback(struct argparse* self, const struct argparse_option* option) {
  rlog("Linker args callback called with value: %s", self->optvalue);

  if (!self->optvalue) {
    emitError(ERR_BLANK, NULL, "No linker arguments provided.");
  }

  if (strchr(self->optvalue, ',')) {
    rlog("Splitting linker args by commas.");
    char* argcopy = strdup(self->optvalue);
    char* token = strtok(argcopy, ",");
    while (token) {
      rlog("Processing linker arg: %s", token);

      // Make sure the passed argument is valid
      validateLinkerArg(token);

      // Append to linkerArgs
      appendArgs(config.linkerArgs.argv, &config.linkerArgs.arglen, &config.linkerArgs.argcap, token);
      rlog("Added linker arg: %s", token);
      token = strtok(NULL, ",");
    }
    free(argcopy);
  } else {
    validateLinkerArg(self->optvalue);

    rlog("Adding single linker arg.");
    appendArgs(config.linkerArgs.argv, &config.linkerArgs.arglen, &config.linkerArgs.argcap, self->optvalue);
    rlog("Added linker arg: %s", self->optvalue);
  }


  return -1;
}

static const char** parseArgs(int argc, const char** argv, int* filecount) {
  config.outbin = "out.aru";

  bool showVersion = false;

  config.assemblerArgs.argv = (char**) calloc(8, sizeof(char*));
  config.assemblerArgs.arglen = 0;
  config.assemblerArgs.argcap = 8;

  config.linkerArgs.argv = (char**) calloc(6, sizeof(char*));
  config.linkerArgs.arglen = 0;
  config.linkerArgs.argcap = 6;

  /**
   * Disclaimer
   * The argparse library does not allow using short options with callbacks
   * So doing `-Af,p -At` will not work, only `--assembler=f,p --assembler=t` will work
   * Either keep this as the intended manner or switch libraries or modify argparse
   * For now, keep the limitation
   */

  struct argparse_option options[] = {
    OPT_STRING('o', "output", &config.outbin, "Output file", NULL, 0, 0),
    OPT_BOOLEAN('V', "version", &showVersion, "show version and exit", NULL, 0, 0),
    OPT_BOOLEAN('s', "assemble", &config.assembleOnly, "assemble files but do not link", NULL, 0, 0),
    OPT_BOOLEAN('c', "compile", &config.compileOnly, "generate assembly files but do not assemble", NULL, 0, 0),
    OPT_STRING('\0', "assembler", NULL, "pass arguments to assembler", &assemblerArgsCallback, 0, 0),
    OPT_STRING('\0', "linker", NULL, "pass arguments to linker", &linkerArgsCallback, 0, 0),
    OPT_HELP(),
    OPT_END(),
  };

  const char* const usages[] = {
    "arxc [options] ...files",
    "arxc build",
    NULL,
  };

  struct argparse argparse;
  argparse_init(&argparse, options, usages, ARGPARSE_STOP_AT_NON_OPTION);
  argparse_describe(&argparse, "Rulang Compiler", NULL);
  int nparsed = argparse_parse(&argparse, argc, argv);

  // if (nparsed < 1) {
  //   printf("nparsed: %d\n", nparsed);
  //   argparse_usage(&argparse);
  //   exit(1);
  // }

  if (argv[0] && strcmp(argv[0], "build") == 0) {
    parseBuildArgs(nparsed, argv);
    // Find way to return properly or something
    exit(1);
  }

  if (showVersion) {
    printf("Rulang Compiler version %d.%d.%d\n", MAJOR_VERSION, MINOR_VERSION, PATCH_VERSION);
    exit(0);
  }

  if (nparsed < 1) {
    fprintf(stderr, "No input files specified.\n");
    argparse_usage(&argparse);
    exit(1);
  }

  // printf("Assemble args: %s\n", assemblerArgs ? assemblerArgs : "(none)");
  rlog("Output file: %s", config.outbin);

  const char** infiles = malloc(sizeof(char*) * nparsed);
  // if (!infiles)

  for (int i = 0; i < nparsed; i++) {
    infiles[i] = argv[i];
  }
  *filecount = nparsed;

  return infiles;
}

static int callAssembler(const char* filename) {
  char command[1024];
  snprintf(command, sizeof(command), "arxsm -o %s.ao %s.s", filename, filename);

  // Make sure the assembler gets passed its proper arguments
  for (int i = 0; i < config.assemblerArgs.arglen; i++) {
    strcat(command, " -");
    strcat(command, config.assemblerArgs.argv[i]);
  }
  if (config.useDebugSymbols) strncat(command, " -g", sizeof(command) - strlen(command) - 1);
  strcat(command, "\0");

  rlog("Running assembler command: `%s`", command);

  return system(command);

  // Options on what if assembler cannot assemble:
  // 1. Stop compilation entirely
  // 2. Continue to next file
  //   In such case, the appropriate symbols will be missing
  // For now, continue
}

static void callLinker(char** files, int filecount) {
  if (filecount == 0 && files[0] == NULL) {
    rlog("No files to link, skipping linking step.");
    return;
  }

  char command[2048];
  snprintf(command, sizeof(command), "arxlnk -o %s", config.outbin);

  for (int i = 0; i < filecount; i++) {
    if (!files[i]) continue; // Skip files that failed assembly

    strncat(command, " ", sizeof(command) - strlen(command) - 1);
    strncat(command, files[i], sizeof(command) - strlen(command) - 1);
    strncat(command, ".ao", sizeof(command) - strlen(command) - 1);
  }

  // Make sure the linker gets passed its proper arguments
  for (int i = 0; i < config.linkerArgs.arglen; i++) {
    strcat(command, " -");
    strcat(command, config.linkerArgs.argv[i]);
  }
  strncat(command, "\0", sizeof(command) - strlen(command) - 1);

  rlog("Running linker command: `%s`", command);

  system(command);
}

int main(int argc, const char** argv) {
  int filecount = 0;
  const char** infiles = parseArgs(argc, argv, &filecount);
  if (!infiles) {
    // Handled in parseArgs
    return -1;
  }

  // Note that some files may be .ru files or .s files
  // .s files are to be assembled directly
  // .ru are to be compiled to .s first, then assembled
  // Todo later: handle assembly files as processes for parallelism, only if after some number of assembly files
  // Maybe if there are 3 or more assembly files, spawn processes to assemble them in parallel

  // Array to hold the names of the files, this is used to easily convert for object or assembly
  // Basically removing the extension
  char** files = (char**) malloc(sizeof(char*) * filecount);
  files[0] = NULL;

  for (int i = 0, j = 0; infiles[i]; i++) {
    rlog("Input file %d: %s", i, infiles[i]);
    // Get file extension
    const char* ext = strrchr(infiles[i], '.');
    if (!ext) {
      emitWarning(WARN_UNEXPECTED, NULL, "Input file %s has no extension, cannot determine type.\n", infiles[i]);
      // fprintf(stderr, "Input file %s has no extension, cannot determine type.\n", infiles[i]);
      continue;
    }

    if (strcmp(ext, ".s") == 0 || strcmp(ext, ".asm") == 0 || strcmp(ext, ".as") == 0 || strcmp(ext, ".ars") == 0) {
      rlog("Assembling file %s", infiles[i]);
      // Need to remove extension
      files[j] = strndup(infiles[i], ext - infiles[i]);
      j++;

      if (callAssembler(files[j-1]) != 0) {
        j--;
        free(files[j]);
        files[j] = NULL; // Remove from array
        filecount--;
        continue;
      }
    } else {
      // Take this chance to ensure all other files are .ru
      if (strcmp(ext, ".ru") != 0) {
        emitWarning(WARN_UNEXPECTED, NULL, "Input file %s has unrecognized extension %s, skipping.\n", infiles[i], ext);
        // fprintf(stderr, "Input file %s has unrecognized extension %s, skipping.\n", infiles[i], ext);
        continue;
      }
      files[j] = strndup(infiles[i], ext - infiles[i]);
      j++;

      // Also take this chance to just compile it
      if (compile(infiles[i]) != 0) {
        j--;
        free(files[j]);
        files[j] = NULL; // Remove from array
        filecount--;
        continue;
      }
      // Created file should be the assembly
      callAssembler(files[i]);
    }
  }

  for (int i = 0; i < config.assemblerArgs.arglen; i++) {
    free(config.assemblerArgs.argv[i]);
  }
  free(config.assemblerArgs.argv);


  // All files assembled to .ao files
  // Now link them
  callLinker(files, filecount);

  // Success
  free(infiles);
  free(files);
  
  for (int i = 0; i < config.linkerArgs.arglen; i++) {
    free(config.linkerArgs.argv[i]);
  }
  free(config.linkerArgs.argv);

  return 0;
}