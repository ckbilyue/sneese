/*

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2004 Charles Bilyue'.
Portions Copyright (c) 2003-2004 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

map.c - a map (associative array) implementation

*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "map.h"

st_map_t *map_create(int n_elements)
{
 st_map_t *map;
 int size = sizeof(st_map_t) + n_elements * sizeof(st_map_element_t);

 if ((map = (st_map_t *) malloc(size)) == NULL)
 {
  fprintf(stderr, "ERROR: Not enough memory for buffer (%d bytes)\n", size);
  exit(1);
 }
 map->data = (st_map_element_t *) (((unsigned char *) map) + sizeof(st_map_t));
 memset(map->data, MAP_FREE_KEY, n_elements * sizeof(st_map_element_t));
 map->size = n_elements;
 map->cmp_key = map_cmp_key_def;
 return map;
}

void map_copy(st_map_t *dest, st_map_t *src)
{
 memcpy(dest->data, src->data, src->size * sizeof(st_map_element_t));
 dest->cmp_key = src->cmp_key;
}

int map_cmp_key_def(void *key1, void *key2)
{
 return key1 != key2;
}

st_map_t *map_put(st_map_t *map, void *key, void *object)
{
 int n = 0;

 while (n < map->size && map->data[n].key != MAP_FREE_KEY &&
        map->cmp_key(map->data[n].key, key))
  n++;

 if (n == map->size)                            // current map is full
 {
  int new_size = map->size + 20;
  st_map_t *map2;

  map2 = map_create(new_size);
  map_copy(map2, map);
  free(map);
  map = map2;
 }

 map->data[n].key = key;
 map->data[n].object = object;

 return map;
}

void *map_get(st_map_t *map, void *key)
{
 int n = 0;

 while (n < map->size && map->cmp_key(map->data[n].key, key))
  n++;

 if (n == map->size)
  return NULL;

 return map->data[n].object;
}

void map_del(st_map_t *map, void *key)
{
 int n = 0;

 while (n < map->size && map->cmp_key(map->data[n].key, key))
  n++;

 if (n < map->size)
  map->data[n].key = MAP_FREE_KEY;
}

void map_dump(st_map_t *map)
{
 int n = 0;

 while (n < map->size)
 {
  printf("%p -> %p\n", map->data[n].key, map->data[n].object);
  n++;
 }
}
