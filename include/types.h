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

#ifndef SNEeSe_types_h
#define SNEeSe_types_h

#include "platform.h"
#include "wrapaleg.h"
#include "font.h"

#define cBorder_Back 0
#define cBorder_Fore 7
#define cMenu_Back cWindow_Back
#define cMenu_Fore 0
#define cSelected_Back 0
#define cSelected_Fore 7
#define cText_Back cWindow_Back
#define cText_Fore 0
#define cWindow_Back 7

extern "C" unsigned char *GUI_Screen;

struct SCREEN {
 int depth,w_base,h_base,w,h,driver;
 void (*adjust)(void);
 int set(){
  int error;
  set_color_depth(depth);
  error=set_gfx_mode(driver, w_base, h_base, w_base, h_base);
  if(error) return error;
#ifdef ALLEGRO_DOS
  if(w_base != w || h_base != h){
   switch(driver){
    case GFX_MODEX:
    case GFX_VGA:
     (*adjust)();
     break;

    default:
     /* Size adjustment not supported */
     break;
   }
  }
#endif
  return 0;
 }
};

typedef SCREEN * pSCREEN;

typedef struct
{
 char drive[MAXDRIVE],dir[MAXDIR],file[MAXFILE],ext[MAXEXT];

 void merge(char *path)
 {
  fnmerge(path, drive, dir, file, ext);
 }

 void split(char *path)
 {
  fnsplit(path, drive, dir, file, ext);
 }
} fname;

#endif /* !defined(SNEeSe_types_h) */
