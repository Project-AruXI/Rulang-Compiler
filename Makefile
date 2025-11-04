CC = gcc
CFLAGS = -Wall
LDFLAGS = -L./common
OUT = ./out
COMP = ./components
COMMON = ./common
HEADERS = ./headers
STRUCTURES = ./structures

INCLUDES = -I$(HEADERS) -I$(COMMON)

SRCS = compiler.c cli.c $(COMP)/diagnostics.c 
# 			 $(COMP)/lexer.c $(COMP)/parser.c \
# 			 $(COMP)/codegen.c $(COMP)/utils.c $(STRUCTURES)/ast.c
LIBS = $(COMMON)/libargparse.a $(COMMON)/libsds.a $(COMMON)/libpcre2-8.a
DLIBS = -lutf8v
TARGET = $(OUT)/arxc

ifeq ($(MAKECMDGOALS),windows)
	TARGET = $(OUT)/arxc.exe
	SRCS := $(SRCS) $(COMP)/getline.c
endif

OBJS = $(SRCS:.c=.o)

%.o: %.c
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

all: arxc

arxc: $(OBJS)
	$(CC) $(CFLAGS) -o $(TARGET) $(OBJS) $(LIBS) $(DLIBS) $(LDFLAGS)


windows: CC = zig cc
windows: CFLAGS += --target=x86_64-windows -g -O0
windows: LIBS = $(COMMON)/libargparse-win.a $(COMMON)/libsds-win.a
windows: arxc

debug: CFLAGS += -g -DDEBUG -O0
debug: arxc

clean:
	rm -f **/*.o
	rm compiler.o