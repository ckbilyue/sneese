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

multiio.h - transparent support for gzipped and zipped files.

*/

#ifndef SNEeSe_multiio_h
#define SNEeSe_multiio_h

#include "misc.h"

#ifdef ZLIB
#include <zlib.h>
#include "unzip.h"
#endif

EXTERN FILE *fopen2(const char *filename, const char *mode);
EXTERN int fclose2(FILE *file);
EXTERN int fseek2(FILE *file, long offset, int mode);
EXTERN size_t fread2(void *buffer, size_t size, size_t number, FILE *file);
EXTERN int fgetc2(FILE *file);
EXTERN char *fgets2(char *buffer, int maxlength, FILE *file);
EXTERN int feof2(FILE *file);
EXTERN size_t fwrite2(const void *buffer, size_t size, size_t number, FILE *file);
EXTERN int fputc2(int character, FILE *file);
EXTERN long ftell2(FILE *file);
EXTERN void rewind2(FILE *file);

// Returns the number of files in the "central dir of this disk" or -1 if
//  filename is not a ZIP file or an error occured.
#ifdef ZLIB
EXTERN int unzip_get_number_entries(const char *filename);
EXTERN int unzip_goto_file(unzFile file, int file_index);
EXTERN int unzip_current_file_nr;
#endif

#endif /* !defined(SNEeSe_multiio_h) */
