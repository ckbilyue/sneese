/*

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2005, Charles Bilyue'.
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

#ifndef SNEeSe_font_h
#define SNEeSe_font_h

class WINDOW;
typedef WINDOW * pWINDOW;
struct GUI_FONT;
typedef GUI_FONT * pGUI_FONT;

class GUI_FONT {
protected:
 unsigned char *xlat;
 unsigned char *faces;
 int width,widthspace;
 int height,heightspace;
public:
 int get_width(){ return width; }
 int get_widthspace(){ return widthspace; }
 int get_height(){ return height; }
 int get_heightspace(){ return heightspace; }

 friend void PlotChar(pWINDOW window,pGUI_FONT font,
  char Character,int x,int y,int bcolor,int fcolor);
 friend void PlotCharT(pWINDOW window,pGUI_FONT font,
  char Character,int x,int y,int color);
 friend void PlotCharTDirect(pGUI_FONT font,char Character,
  int x,int y,int color);

 GUI_FONT(unsigned char *xlat,unsigned char *faces,int width,int height,
  int widthspace,int heightspace){
  this->xlat=xlat; this->faces=faces;
  this->width=width; this->height=height;
  this->widthspace=widthspace; this->heightspace=heightspace;
 }
};

typedef GUI_FONT * pGUI_FONT;

extern "C" unsigned char Xlat_ZSNES_6x6[256];
extern "C" unsigned char Font_ZSNES_6x6[25];
extern "C" unsigned char Font_Modified_6x6[25];
extern "C" unsigned char Xlat_6x8[256];
extern "C" unsigned char Font_6x8[48];

#define Font_Width_ZSNES 5
#define Font_Height_ZSNES 5
#define Font_WidthSpace_ZSNES 6
#define Font_HeightSpace_ZSNES 6
#define Font_Width_Old 6
#define Font_Height_Old 8
#define Font_WidthSpace_Old 7
#define Font_HeightSpace_Old 8

#include "misc.h"

#endif /* !defined(SNEeSe_font_h) */
