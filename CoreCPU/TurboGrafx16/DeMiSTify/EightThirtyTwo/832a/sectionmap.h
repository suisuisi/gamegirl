#ifndef SECTIONMAP_H
#define SECTIONMAP_H

#include "executable.h"
#include "section.h"

struct sectionmap_entry
{
	struct section *sect;
	int address;
};

#define BUILTIN_CTORS_START 0
#define BUILTIN_CTORS_END 1
#define BUILTIN_DTORS_START 2
#define BUILTIN_DTORS_END 3
#define BUILTIN_BSS_START 4
#define BUILTIN_BSS_END 5


struct sectionmap
{
	int entrycount;
	struct sectionmap_entry *entries;	/* Array, for speed and ease of sorting */
	struct section *builtins;	/* start and end markers for ctor/dtor/bss */
	struct section *lastbuiltin;
};

struct executable;
struct sectionmap *sectionmap_new();
struct section *sectionmap_getbuiltin(struct sectionmap *map,int builtin);
int sectionmap_populate(struct executable *exe);

void sectionmap_delete(struct sectionmap *map);

void sectionmap_dump(struct sectionmap *map);

#endif

