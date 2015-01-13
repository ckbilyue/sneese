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

multiio.c - transparent support for gzipped and zipped files.

*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "multiio.h"
#include "map.h"

#ifdef ZLIB
#include <zlib.h>
#include "unzip.h"
#endif

st_map_t *fh_map = NULL;                        // associative array: file handle -> file mode

typedef enum { FM_NORMAL, FM_GZIP, FM_ZIP, FM_UNDEF } fmode2_t;

typedef struct st_finfo
{
 fmode2_t fmode;
 int compressed;
} st_finfo_t;

static st_finfo_t finfo_list[6] =
{
 {FM_NORMAL, 0},
 {FM_NORMAL, 1},                                // should never be used
 {FM_GZIP, 0},
 {FM_GZIP, 1},
 {FM_ZIP, 0},                                   // should never be used
 {FM_ZIP, 1}
};

#ifdef ZLIB
int unzip_current_file_nr = 0;
#endif

static void init_fh_map(void)
{
 fh_map = map_create(20);                       // 20 simultaneous open files
 map_put(fh_map, stdin, &finfo_list[0]);        //  should be enough to start with
 map_put(fh_map, stdout, &finfo_list[0]);
 map_put(fh_map, stderr, &finfo_list[0]);
}

static st_finfo_t *get_finfo(MULTIIO_FILE_PTR mfp)
{
 st_finfo_t *finfo;

 if (fh_map == NULL)
  init_fh_map();
 if ((finfo = (st_finfo_t *) map_get(fh_map, mfp.mvPtr)) == NULL)
 {
  fprintf(stderr, "\nINTERNAL ERROR: File pointer was not present in map (%p)\n", mfp.mvPtr);
  map_dump(fh_map);
  exit(1);
 }
 return finfo;
}

static fmode2_t get_fmode(MULTIIO_FILE_PTR mfp)
{
 return get_finfo(mfp)->fmode;
}

#ifdef ZLIB
int unzip_get_number_entries(const char *filename)
{
 MULTIIO_FILE_PTR mfp;
 unsigned char magic[4] = { 0 };

 if ((mfp.mFile = fopen(filename, "rb")) == NULL)
  return -1;
 fread(magic, 1, sizeof (magic), mfp.mFile);
 fclose(mfp.mFile);

 if (magic[0] == 'P' && magic[1] == 'K' && magic[2] == 0x03 && magic[3] == 0x04)
 {
  unz_global_info info;

  mfp.munzFile = unzOpen(filename);
  unzGetGlobalInfo(mfp.munzFile, &info);
  unzClose(mfp.munzFile);
  return info.number_entry;
 }
 else
  return -1;
}

int unzip_goto_file(unzFile file, int file_index)
{
 int retval = unzGoToFirstFile(file), n = 0;

 if (file_index > 0)
  while (n < file_index)
  {
   retval = unzGoToNextFile(file);
   n++;
  }
 return retval;
}

static int unzip_seek_helper(unzFile file, int offset)
{
#define MAXBUFSIZE 32768
 char buffer[MAXBUFSIZE];
 int n, tmp, pos = unztell(file);               // returns ftell() of the "current file"

 if (pos == offset)
  return 0;
 else if (pos > offset)
 {
  unzCloseCurrentFile(file);
  unzip_goto_file(file, unzip_current_file_nr);
  unzOpenCurrentFile(file);
  pos = 0;
 }
 n = offset - pos;
 while (n > 0 && !unzeof(file))
 {
  tmp = unzReadCurrentFile(file, buffer, n > MAXBUFSIZE ? MAXBUFSIZE : n);
  if (tmp < 0)
   return -1;
  n -= tmp;
 }
 return n > 0 ? -1 : 0;
}
#endif // ZLIB

MULTIIO_FILE_PTR fopen2(const char *filename, const char *mode)
{
 int n, len = strlen(mode), read = 0, compressed = 0;
 fmode2_t fmode = FM_UNDEF;
 st_finfo_t *finfo;
 MULTIIO_FILE_PTR mfp; mfp.mvPtr = NULL;

 if (fh_map == NULL)
  init_fh_map();

 for (n = 0; n < len; n++)
 {
  switch (mode[n])
  {
   case 'r':
    read = 1;
    break;
#ifdef ZLIB
   case 'f':
   case 'h':
   case '1':
   case '2':
   case '3':
   case '4':
   case '5':
   case '6':
   case '7':
   case '8':
   case '9':
    fmode = FM_GZIP;
    break;
#endif
   case 'w':
   case 'a':
    fmode = FM_NORMAL;
    break;
   case '+':
    if (fmode == FM_UNDEF)
     fmode = FM_NORMAL;
    break;
  }
 }

 if (read)
 {
  unsigned char magic[4] = { 0 };
  FILE *fh;

  // TODO?: check if mode is valid for fopen(), i.e., no 'f', 'h' or number
  if ((fh = fopen(filename, mode)) != NULL)
  {
   fread(magic, sizeof (magic), 1, fh);
#ifdef ZLIB
   if (magic[0] == 0x1f && magic[1] == 0x8b && magic[2] == 0x08)
   {                                    // ID1, ID2 and CM. gzip uses Compression Method 8
    fmode = FM_GZIP;
    compressed = 1;
   }
   else if (magic[0] == 'P' && magic[1] == 'K' && magic[2] == 0x03 && magic[3] == 0x04)
   {
    fmode = FM_ZIP;
    compressed = 1;
   }
   else
#endif
    /*
      Files that are opened with mode "r+" will probably be written to.
      zlib doesn't support mode "r+", so we have to use FM_NORMAL.
      Mode "r" doesn't require FM_NORMAL and FM_GZIP works, but we
      shouldn't introduce needless overhead.
    */
    fmode = FM_NORMAL;
    fclose(fh);
  }
 }

 if (fmode == FM_NORMAL)
  mfp.mFile = fopen(filename, mode);
#ifdef ZLIB
 else if (fmode == FM_GZIP)
  mfp.mgzFile = gzopen(filename, mode);
 else if (fmode == FM_ZIP)
 {
  mfp.munzFile = unzOpen(filename);
  if (mfp.munzFile != NULL)
  {
   unzip_goto_file(mfp.munzFile, unzip_current_file_nr);
   unzOpenCurrentFile(mfp.munzFile);
  }
 }
#endif

 if (mfp.mvPtr == NULL)
  return mfp; /*NULL*/

 finfo = &finfo_list[fmode * 2 + compressed];
 fh_map = map_put(fh_map, mfp.mvPtr, finfo);

 return mfp;
}

int fclose2(MULTIIO_FILE_PTR mfp)
{
 fmode2_t fmode = get_fmode(mfp);

 map_del(fh_map, mfp.mvPtr);
 if (fmode == FM_NORMAL)
  return fclose(mfp.mFile);
#ifdef ZLIB
 else if (fmode == FM_GZIP)
  return gzclose(mfp.mgzFile);	// TODO: replace with object or pointer union
 else if (fmode == FM_ZIP)
  {
   unzCloseCurrentFile(mfp.munzFile);
   return unzClose(mfp.munzFile);
  }
#endif
 else
  return EOF;
}

int fseek2(MULTIIO_FILE_PTR mfp, long offset, int mode)
{
 st_finfo_t *finfo = get_finfo(mfp);

 if (finfo->fmode == FM_NORMAL)
  return fseek(mfp.mFile, offset, mode);
#ifdef ZLIB
 else if (finfo->fmode == FM_GZIP)
 {
  if (mode == SEEK_END)                         // zlib doesn't support SEEK_END
  {
   // Note that this is _slow_...
   while (!gzeof(mfp.mgzFile))
   {
    gzgetc(mfp.mgzFile); // necessary for _uncompressed_ files in order to set EOF
    gzseek(mfp.mgzFile, 1024 * 1024, SEEK_CUR);
   }
   offset += gztell(mfp.mgzFile);
   mode = SEEK_SET;
  }
  /*
    The zlib documentation contains a major error. From the doc:
      gzrewind(file) is equivalent to (int)gzseek(file, 0L, SEEK_SET)
    That is not true for uncompressed files. gzrewind() doesn't change the
    file pointer for uncompressed files in the ports I (dbjh) tested
    (zlib 1.1.3, DJGPP, Cygwin & GNU/Linux). It clears the EOF indicator.
  */
  if (!finfo->compressed)
   gzrewind(mfp.mgzFile);
  return gzseek(mfp.mgzFile, offset, mode) == -1 ? -1 : 0;
 }
 else if (finfo->fmode == FM_ZIP)
 {
  int base;
  if (mode != SEEK_SET && mode != SEEK_CUR && mode != SEEK_END)
   return -1;
  if (mode == SEEK_SET)
   base = 0;
  else if (mode == SEEK_CUR)
   base = unztell(mfp.munzFile);
  else // mode == SEEK_END
  {
   unz_file_info info;

   unzip_goto_file(mfp.munzFile, unzip_current_file_nr);
   unzGetCurrentFileInfo(mfp.munzFile, &info, NULL, 0, NULL, 0, NULL, 0);
   base = info.uncompressed_size;
  }
  return unzip_seek_helper(mfp.munzFile, base + offset);
 }
#endif // ZLIB
 return -1;
}

size_t fread2(void *buffer, size_t size, size_t number, MULTIIO_FILE_PTR mfp)
{
 fmode2_t fmode = get_fmode(mfp);

 if (size == 0 || number == 0)
  return 0;

 if (fmode == FM_NORMAL)
  return fread(buffer, size, number, mfp.mFile);
#ifdef ZLIB
 else if (fmode == FM_GZIP)
 {
  int n = gzread(mfp.mgzFile, buffer, number * size);
  return n / size;
 }
 else if (fmode == FM_ZIP)
 {
  int n = unzReadCurrentFile(mfp.munzFile, buffer, number * size);
  return n / size;
 }
#endif
 return 0;
}

int fgetc2(MULTIIO_FILE_PTR mfp)
{
 fmode2_t fmode = get_fmode(mfp);

 if (fmode == FM_NORMAL)
  return fgetc(mfp.mFile);
#ifdef ZLIB
 else if (fmode == FM_GZIP)
  return gzgetc(mfp.mgzFile);
 else if (fmode == FM_ZIP)
 {
  char c;
  int retval = unzReadCurrentFile(mfp.munzFile, &c, 1);
  return retval <= 0 ? EOF : c & 0xff;          // avoid sign bit extension
 }
#endif
 else
  return EOF;
}

char *fgets2(char *buffer, int maxlength, MULTIIO_FILE_PTR mfp)
{
 fmode2_t fmode = get_fmode(mfp);

 if (fmode == FM_NORMAL)
  return fgets(buffer, maxlength, mfp.mFile);
#ifdef ZLIB
 else if (fmode == FM_GZIP)
 {
  char *retval = gzgets(mfp.mgzFile, buffer, maxlength);
  return retval == Z_NULL ? NULL : retval;
 }
 else if (fmode == FM_ZIP)
 {
  int n = 0, c = 0;
  while (n < maxlength - 1 && (c = fgetc2(mfp)) != EOF)
  {
   buffer[n] = c;                               // '\n' must also be stored in buffer
   n++;
   if (c == '\n')
   {
    buffer[n] = 0;
    break;
   }
  }
  if (n >= maxlength - 1 || c == EOF)
   buffer[n] = 0;
  return n > 0 ? buffer : NULL;
 }
#endif
 else
  return NULL;
}

int feof2(MULTIIO_FILE_PTR mfp)
{
 fmode2_t fmode = get_fmode(mfp);

 if (fmode == FM_NORMAL)
  return feof(mfp.mFile);
#ifdef ZLIB
 else if (fmode == FM_GZIP)
  return gzeof(mfp.mgzFile);
 else if (fmode == FM_ZIP)
  return unzeof(mfp.munzFile);                          // returns feof() of the "current file"
#endif
 else
  return -1;
}

size_t fwrite2(const void *buffer, size_t size, size_t number, MULTIIO_FILE_PTR mfp)
{
 fmode2_t fmode = get_fmode(mfp);

 if (size == 0 || number == 0)
  return 0;

 if (fmode == FM_NORMAL)
  return fwrite(buffer, size, number, mfp.mFile);
#ifdef ZLIB
 else if (fmode == FM_GZIP)
 {
  int n = gzwrite(mfp.mgzFile, (void *) buffer, number * size);
  return n / size;
 }
#endif
 else
  return 0;                                     // writing to zip files is not supported
}

int fputc2(int character, MULTIIO_FILE_PTR mfp)
{
 fmode2_t fmode = get_fmode(mfp);

 if (fmode == FM_NORMAL)
  return fputc(character, mfp.mFile);
#ifdef ZLIB
 else if (fmode == FM_GZIP)
  return gzputc(mfp.mgzFile, character);
#endif
 else
  return EOF;                                   // writing to zip files is not supported
}

long ftell2(MULTIIO_FILE_PTR mfp)
{
 fmode2_t fmode = get_fmode (mfp);

 if (fmode == FM_NORMAL)
  return ftell(mfp.mFile);
#ifdef ZLIB
 else if (fmode == FM_GZIP)
  return gztell(mfp.mgzFile);
 else if (fmode == FM_ZIP)
  return unztell(mfp.munzFile);                         // returns ftell() of the "current file"
#endif
 else
  return -1;
}

void rewind2(MULTIIO_FILE_PTR mfp)
{
  fseek2(mfp, 0, SEEK_SET);
}
