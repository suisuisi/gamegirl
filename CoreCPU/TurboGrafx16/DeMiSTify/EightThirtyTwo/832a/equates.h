#ifndef EQUATES_H
#define EQUATES_H

struct equate
{
	struct equate *next;
	char *identifier;
	int value;
};

struct equate *equate_new(const char *identifier, int value);

#endif

