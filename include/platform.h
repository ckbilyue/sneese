/*

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2005, Charles Bilyue'.
Portions Copyright (c) 2003-2004, Daniel Horchner.
Portions Copyright (c) 2004-2005, Nach. ( http://nsrt.edgeemu.com/ )
JMA Technology, Copyright (c) 2004-2005 NSRT Team. ( http://nsrt.edgeemu.com/ )
LZMA Technology, Copyright (c) 2001-4 Igor Pavlov. ( http://www.7-zip.org )
Portions Copyright (c) 2002 Andrea Mazzoleni. ( http://advancemame.sf.net )

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

*/

#ifndef SNEeSe_platform_h
#define SNEeSe_platform_h

#include "misc.h"

/* Path separation/length abstraction */
#if     defined DJGPP

#include <dir.h>

#define FILE_SEPARATOR "\\"

#elif   defined WIN32

#include <stdlib.h>

#define fnmerge _makepath
#define fnsplit _splitpath

#include <stdio.h>

#define MAXPATH     FILENAME_MAX
#define MAXDRIVE    FILENAME_MAX
#define MAXDIR      FILENAME_MAX
#define MAXFILE     FILENAME_MAX
#define MAXEXT      FILENAME_MAX
#define FILE_SEPARATOR "\\"

#elif defined(UNIX) || defined(__BEOS__)

#include <stdio.h>

#define MAXPATH     FILENAME_MAX
#define MAXDRIVE    FILENAME_MAX
#define MAXDIR      FILENAME_MAX
#define MAXFILE     FILENAME_MAX
#define MAXEXT      FILENAME_MAX
#define FILE_SEPARATOR "/"

EXTERN void fnmerge(char *out, const char *drive, const char *dir,
                    const char *file, const char *ext);
EXTERN void fnsplit(const char *in, char *drive, char *dir, char *file,
                    char *ext);

#endif


typedef struct {
 int depth, width, height, hslack, vslack, needed_w, needed_h;
 void *bitmap, *subbitmap; /* platform-dependent pointers */
 void *buffer; /* start of actual drawing area that we'll be using */
} SNEESE_GFX_BUFFER;


EXTERN char home_dir[MAXPATH];
EXTERN char cfg_name[MAXPATH];
EXTERN char dat_name[MAXPATH];

EXTERN char start_dir[MAXPATH];

EXTERN int LoadConfig(void);
EXTERN void SaveConfig(void);
EXTERN void cmdhelp(void);
EXTERN int platform_init(int argc, char **argv);
EXTERN void platform_exit(void);
EXTERN int parse_args(int argc, char **argv, char **names, int maxnames);
EXTERN void *platform_get_gfx_buffer(
 int depth, int width, int height, int hslack, int vslack,
 SNEESE_GFX_BUFFER *gfx_buffer);

#endif /* !defined(SNEeSe_platform_h) */
