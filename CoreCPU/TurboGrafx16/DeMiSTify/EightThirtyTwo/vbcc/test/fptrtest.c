#include "uart.h"

static int (*fptr)(const char *msg);
static int (**fptrptr)(const char *msg);

int call()
{
	fptr("Hello world!\n");
	(*fptrptr)("Hello world!\n");
}

int main(int argc,char **argv)
{
	int iptr;
	fptr=puts;
	fptrptr=&fptr;
	iptr=(int)fptr;
	((int (*)(const char *))iptr)("Hello world!\n");
	call();
	return(0);
}

