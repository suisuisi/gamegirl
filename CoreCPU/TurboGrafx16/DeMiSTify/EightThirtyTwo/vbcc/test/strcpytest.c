/*
--stop-time=2ms
*/

#include <stdio.h>
// #include <string.h>
// #include <ctype.h>

struct mystruct
{
	char *str;
};

struct mystruct st;

char strbuf[20];

int main(int argc,char **argv)
{
	int i=0;
	st.str="HELLO, world!\n";

	for(i=0;i<strlen(st.str);++i)
		st.str[i]=tolower(st.str[i]);

	puts(st.str);

	strcpy(strbuf,"Testing: ");
	strncat(strbuf,st.str,5);
	strcat(strbuf,st.str);
	for(i=0;i<strlen(strbuf);++i)
		strbuf[i]=toupper(strbuf[i]);

	puts(strbuf);
	printf("strlen is %d\n",strlen(strbuf));

	strncpy(strbuf,"Hello, World\n",7);
	puts(strbuf);
	return(0);
}
