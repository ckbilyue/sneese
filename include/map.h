/*

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2005, Charles Bilyue'.
Portions copyright (c) 1998-2003, Brad Martin.
Portions copyright (c) 2003-2004, Daniel Horchner.
Portions copyright (c) 2004-2005, Nach. ( http://nsrt.edgeemu.com/ )
Unzip Technology, copyright (c) 1998 Gilles Vollant.
zlib Technology ( www.gzip.org/zlib/ ), Copyright (c) 1995-2003,
 Jean-loup Gailly ( jloup* *at* *gzip.org ) and Mark Adler
 ( madler* *at* *alumni.caltech.edu ).
JMA Technology, copyright (c) 2004-2005 NSRT Team. ( http://nsrt.edgeemu.com/ )
LZMA Technology, copyright (c) 2001-4 Igor Pavlov. ( http://www.7-zip.org )
Portions copyright (c) 2002 Andrea Mazzoleni. ( http://advancemame.sf.net )

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

map.h - a map (associative array) implementation

*/

#ifndef SNEeSe_map_h
#define SNEeSe_map_h

#include "misc.h"

/*
  map_create()  create a new map (associative array)
  map_copy()    copy map src to map dest
                dest must be a larger map than src
                Note that this function also copies the member cmp_key.
  map_put()     put object in map under key
                Callers should always reset the passed map pointer with the one
                this function returns. This is necessary in case the map had to
                be resized.
  map_get()     get object from map stored under key
                returns NULL if there is no object with key in map
  map_del()     remove the object stored under key from map
  map_dump()    display the current contents of map

  The value MAP_FREE_KEY is reserved as a special key value. Don't use that
  value.
*/

#define MAP_FREE_KEY 0

typedef struct st_map_element
{
 void *key;
 void *object;
} st_map_element_t;

typedef struct st_map
{
 st_map_element_t *data;
 int size;
 int (*cmp_key)(void *key1, void *key2);
} st_map_t;

EXTERN st_map_t *map_create(int n_elements);
EXTERN void map_copy(st_map_t *dest, st_map_t *src);
EXTERN st_map_t *map_put(st_map_t *map, void *key, void *object);
EXTERN int map_cmp_key_def(void *key1, void *key2);
EXTERN void *map_get(st_map_t *map, void *key);
EXTERN void map_del(st_map_t *map, void *key);
EXTERN void map_dump(st_map_t *map);

#endif /* !defined(SNEeSe_map_h) */
