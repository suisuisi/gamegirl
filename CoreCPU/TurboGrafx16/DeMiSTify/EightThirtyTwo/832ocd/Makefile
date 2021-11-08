CC=gcc
LD=gcc
CFLAGS=-I../832a/
LIBS=-lncurses

all: 832ocd

832ocd: 832ocd.c 832ocd_connection.c frontend.c \
	../832a/832defs.c ../832a/832util.c ../832a/section.c ../832a/symbol.c ../832a/codebuffer.c
	$(CC) $(CFLAGS) -o $@ $+ $(LIBS) 

