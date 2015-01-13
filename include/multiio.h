/*

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2015, Charles Bilyue.
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

multiio.h - transparent support for gzipped and zipped files.

*/

#ifndef SNEeSe_multiio_h
#define SNEeSe_multiio_h

#include "misc.h"

#ifdef ZLIB
#include <zlib.h>
#include "unzip.h"
#endif

typedef union tagMULTIIO_FILE_PTR {
	void *mvPtr;
	FILE *mFile;
#ifdef ZLIB
	gzFile mgzFile;
	unzFile munzFile;
#endif
} MULTIIO_FILE_PTR;

EXTERN MULTIIO_FILE_PTR fopen2(const char *filename, const char *mode);
EXTERN int fclose2(MULTIIO_FILE_PTR mfp);
EXTERN int fseek2(MULTIIO_FILE_PTR mfp, long offset, int mode);
EXTERN size_t fread2(void *buffer, size_t size, size_t number, MULTIIO_FILE_PTR mfp);
EXTERN int fgetc2(MULTIIO_FILE_PTR mfp);
EXTERN char *fgets2(char *buffer, int maxlength, MULTIIO_FILE_PTR mfp);
EXTERN int feof2(MULTIIO_FILE_PTR mfp);
EXTERN size_t fwrite2(const void *buffer, size_t size, size_t number, MULTIIO_FILE_PTR mfp);
EXTERN int fputc2(int character, MULTIIO_FILE_PTR mfp);
EXTERN long ftell2(MULTIIO_FILE_PTR mfp);
EXTERN void rewind2(MULTIIO_FILE_PTR mfp);

// Returns the number of files in the "central dir of this disk" or -1 if
//  filename is not a ZIP file or an error occured.
#ifdef ZLIB
EXTERN int unzip_get_number_entries(const char *filename);
EXTERN int unzip_goto_file(unzFile file, int file_index);
EXTERN int unzip_current_file_nr;
#endif

#endif /* !defined(SNEeSe_multiio_h) */
