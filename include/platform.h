/*

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2006, Charles Bilyue'.
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
#define FILE_CASE_SENSITIVE

EXTERN void fnmerge(char *out, const char *drive, const char *dir,
                    const char *file, const char *ext);
EXTERN void fnsplit(const char *in, char *drive, char *dir, char *file,
                    char *ext);

#endif



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


/* video abstraction */
typedef struct {
 int depth, width, height, hslack, vslack, needed_w, needed_h;
 void *bitmap, *subbitmap; /* platform-dependent pointers */
 void *buffer; /* start of actual drawing area that we'll be using */
} SNEESE_GFX_BUFFER;


#define NULL_GFX_BUFFER { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
EXTERN void *platform_get_gfx_buffer(
 int depth, int width, int height, int hslack, int vslack,
 SNEESE_GFX_BUFFER *gfx_buffer);


/* audio abstraction */
typedef struct {
 int samples, bits, stereo, freq;
 void *platform_interface;
} SNEESE_AUDIO_VOICE;
#define NULL_AUDIO_VOICE { 0, 0, 0, 0, 0 }


EXTERN signed char platform_sound_available;

EXTERN void *platform_get_audio_voice(
 int samples, int bits, int stereo, int freq,
 SNEESE_AUDIO_VOICE *audio_voice);
EXTERN void platform_free_audio_voice(SNEESE_AUDIO_VOICE *audio_voice);

EXTERN void *platform_get_audio_buffer(SNEESE_AUDIO_VOICE *audio_voice);
EXTERN void platform_free_audio_buffer(SNEESE_AUDIO_VOICE *audio_voice);

EXTERN void platform_pause_audio_voice(SNEESE_AUDIO_VOICE *audio_voice);
EXTERN void platform_resume_audio_voice(SNEESE_AUDIO_VOICE *audio_voice);


#endif /* !defined(SNEeSe_platform_h) */
