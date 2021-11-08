#include "uart.h"

struct teststruct
{
	int a,b;
	char *cptr;
	int (*fptr)(const char *msg);
};

struct teststruct mystruct=
{
	42,255,"Hello, world!\n",puts
};

int main(int argc,char **argv)
{
	struct teststruct localcopy=mystruct;
	localcopy.fptr(localcopy.cptr);
	return(0);
}

