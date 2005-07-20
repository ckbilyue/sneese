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

*/



#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include "unzip.h"
#include "romload.h"

#define BUFFER_SIZE 2048

#define ROM_SPACE_MAX (ROM_SIZE_MAX + ROM_Header_Size)

bool IPSPatched = false;
bool AutoPatch =  true;

const char *patchfile = 0;

struct
{
  unsigned int file_size;
  unsigned char *data;
  unsigned char *current;
  unsigned int buffer_total;
  unsigned int proccessed;

  unzFile zipfile;
  FILE *fp;
} IPSPatch;


static bool reloadBuffer()
{
  if (IPSPatch.proccessed == IPSPatch.file_size) { return(false); }

  IPSPatch.buffer_total = IPSPatch.fp ?
  /* Regular Files */     fread(IPSPatch.data, 1, BUFFER_SIZE, IPSPatch.fp) :
  /* Zip Files     */     unzReadCurrentFile(IPSPatch.zipfile, IPSPatch.data, BUFFER_SIZE);

  IPSPatch.current = IPSPatch.data;
  if (IPSPatch.buffer_total && (IPSPatch.buffer_total <= BUFFER_SIZE))
  {
    return(true);
  }

  IPSPatch.buffer_total = 0;
  return(false);
}

static int IPSget()
{
  int retVal;
  if (IPSPatch.current == IPSPatch.data + IPSPatch.buffer_total)
  {
    if (!reloadBuffer()) { return(-1); }
  }
  IPSPatch.proccessed++;
  retVal = *IPSPatch.current;
  IPSPatch.current++;
  return(retVal);
}

static bool initPatch()
{
  struct stat stat_results;
  stat(patchfile, &stat_results);

  IPSPatch.file_size = (unsigned int)stat_results.st_size;
  IPSPatch.data = (unsigned char *)malloc(BUFFER_SIZE);
  if (!IPSPatch.data) { return(false); }

  IPSPatch.proccessed = 0;
  
  IPSPatch.zipfile = 0;

  IPSPatch.fp = 0;
  IPSPatch.fp = fopen(patchfile, "rb");
  if (!IPSPatch.fp) { return(false); }

  return(reloadBuffer());
}

static void deinitPatch()
{
  if (IPSPatch.data)
  {
    free(IPSPatch.data);
    IPSPatch.data = 0;
  }

  if (IPSPatch.fp)
  {
    fclose(IPSPatch.fp);
    IPSPatch.fp = 0;
  }

  if (IPSPatch.zipfile)
  {
    unzCloseCurrentFile(IPSPatch.zipfile);
    unzClose(IPSPatch.zipfile);
    IPSPatch.zipfile = 0;
  }
}


void PatchUsingIPS()
{
  int location = 0, length = 0;
  int sub = (ROM_has_header == On) ? ROM_Header_Size : 0;

  IPSPatched = false;

  if (!AutoPatch)
  {
    deinitPatch(); //Needed if the call to this function was done from findZipIPS()
    return;
  }

  if (patchfile) //Regular file, not Zip
  {
    if (!initPatch())
    {
      deinitPatch(); //Needed because if it didn't fully init, some things could have
      return;
    }
    printf("Patching ROM with IPS file.\n");
  }

  //Yup, it's goto! :)
  //See 'IPSDone:' for explanation
  if (IPSget() != 'P') { goto IPSDone; }
  if (IPSget() != 'A') { goto IPSDone; }
  if (IPSget() != 'T') { goto IPSDone; }
  if (IPSget() != 'C') { goto IPSDone; }
  if (IPSget() != 'H') { goto IPSDone; }

  while (IPSPatch.proccessed != IPSPatch.file_size)
  {
    //Location is a 3 byte value (max 16MB)
    int inloc = (IPSget() << 16) | (IPSget() << 8) | IPSget();

    if (inloc == 0x454f46) //EOF
    {
      break;
    }

    //Offset by size of ROM header
    location = inloc - sub;

    //Length is a 2 byte value (max 64KB)
    length = (IPSget() << 8) | IPSget();

    if (length) // Not RLE
    {
      int i;
      for (i = 0; i < length; i++, location++)
      {
        if (location >= 0)
        {
          if ((unsigned int)location >= ROM_SPACE_MAX) { goto IPSDone; }
          if (!PatchROMAddress(location, (unsigned char)IPSget())) { goto IPSDone; }
        }
        else
        {
          IPSget(); //Need to skip the bytes that write to header
        }
      }
    }
    else //RLE
    {
      int i;
      unsigned char newVal;
      length = (IPSget() << 8) | IPSget();
      newVal = (unsigned char)IPSget();
      for (i = 0; i < length; i++, location++)
      {
        if (location >= 0)
        {
          if ((unsigned int)location >= ROM_SPACE_MAX) { goto IPSDone; }
          if (!PatchROMAddress(location, newVal)) { goto IPSDone; }
        }
      }
    }
  }

  //We use gotos to break out of the nested loops,
  //as well as a simple way to check for 'PATCH' in
  //some cases like this one, goto is the way to go.
  IPSDone:

  deinitPatch();

  IPSPatched = true;

  /* //For Debugging
  //Write out patched ROM
  FILE *fp = 0;
  fp = fopen("sneese.rom", "wb");
  if (!fp) { perror(0); asm volatile("int $3"); }
  fwrite(RomAddress, 1, rom_allocated_size, fp);
  fclose(fp);
  */
}

void findZipIPS(const char *compressedfile)
{
  bool FoundIPS = false;
  unz_file_info cFileInfo; //Create variable to hold info for a compressed file
  int cFile;

  IPSPatch.zipfile = unzOpen(compressedfile); //Open zip file
  cFile = unzGoToFirstFile(IPSPatch.zipfile); //Set cFile to first compressed file

  while(cFile == UNZ_OK) //While not at end of compressed file list
  {
    //Temporary char array for file name
    char cFileName[256];

    //Gets info on current file, and places it in cFileInfo
    unzGetCurrentFileInfo(IPSPatch.zipfile, &cFileInfo, cFileName, 256, NULL, 0, NULL, 0);

    //Find IPS file
    if (strlen(cFileName) >= 5) //Char + ".IPS"
    {
      char *ext = cFileName+strlen(cFileName)-4;
      if (!strncasecmp(ext, ".IPS", 4))
      {
        FoundIPS = true;
        break;
      }
    }

    //Go to next file in zip file
    cFile = unzGoToNextFile(IPSPatch.zipfile);
  }

  if (!FoundIPS)
  {
    unzClose(IPSPatch.zipfile);
    IPSPatch.zipfile = 0;
    return;
  }

  //Open file
  unzOpenCurrentFile(IPSPatch.zipfile);

  patchfile = 0;
  IPSPatch.fp = 0;
  IPSPatch.file_size = (unsigned int)cFileInfo.uncompressed_size;
  IPSPatch.data = (unsigned char *)malloc(BUFFER_SIZE);
  if (IPSPatch.data)
  {
    IPSPatch.proccessed = 0;
    reloadBuffer();
    printf("Patching ROM with IPS that was in the ZIP file.\n");
    PatchUsingIPS();    
  }
  else
  {
    deinitPatch();
  }
}
