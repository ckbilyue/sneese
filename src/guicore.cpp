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

/*

 GUIcore.cc
  Contains most (eventually all) GUI core code - emulator specific GUI code
   plugs into this!
  Some stuff from helper.c will be moved here!

  This GUI has been mostly rewritten to have two parts:
   GUI core code
   Emulator specific GUI code

  The core has been written in C++, taking advantage of OOP to a
   great extent - however, in its current state, it is far from
   portable.

  The core primarily consists of a few basic classes:
   CTL
    a generic GUI 'control', which relies on four basic methods:
     attach() - init code when control is attached to a WINDOW
     detach() - deinit code when control is detached from its WINDOW
     refresh() - refresh the visual appearance of the control
     process() - periodic maintenance routine, which will eventually
      be able to respond to messages passed in from the core
    all four methods are defined virtual with no bodies in the CTL
     class definition
   WINDOW - associates an object with an area of the screen, and allows
    CTLs to link to that object and screen area
*/

#include <stdio.h>
#include <stdlib.h>

#include "wrapaleg.h"
#include "guicore.h"

/* ------------------------- DIRECTORY STUFF ------------------------- */

#include <unistd.h>
#include <string.h>

EXTERN char start_dir[MAXPATH]; /* defined in dos.c */

unsigned char GUI_ENABLED;
const char *GUI_error_table[] =
{
 "Continue",
 "Normal exit",
 "Screen setup failure",
 "Memory allocation failure"
};

int max_listed_files = 1024;

FILELIST *DirList;

int fncmp(const FILELIST *f1, const FILELIST *f2){
 if (f2->Directory && !f1->Directory) return -1;
 if (f1->Directory && !f2->Directory) return 1;
 return stricmp(f1->Name, f2->Name);
}

// This fills an array of FILELIST with file information
// from the path given, starting at file number Offset
// and with a maximum number of files of max_listed_files

int GetDirList(char *Path, FILELIST *&Files, int Offset){
 al_ffblk FileInfo;
 int FilesRead;

 int done = al_findfirst(Path, &FileInfo, FA_ARCH | FA_DIREC | FA_RDONLY);
 if (done)
 {
  al_findclose(&FileInfo);
  return 0;    // empty dir returns 0
 }

 strcpy(Files[0].Name, "..");
 // Small dirs are 4096 bytes in size on GNU/Linux, haven't tried other OS'es.
 //  Is file size for dirs important?
 Files[0].Size = 4096;
 Files[0].Directory = FA_DIREC;
 FilesRead = 1;

 do {
  if (FilesRead == max_listed_files - 26)
  {
   FILELIST *tempFiles;

   tempFiles = (FILELIST *) realloc(Files, sizeof(FILELIST[max_listed_files += 128]));
   if (!tempFiles)
   {
    set_gfx_mode(GFX_TEXT, 0, 0, 0, 0);
    printf("Fatal error: Failure allocating memory for directory\n");
    exit(EXIT_FAILURE);
   }
   else
   {
    Files = tempFiles;
   }
  }

  if (strcmp(".", FileInfo.name) != 0 && strcmp("..", FileInfo.name) != 0){
   strcpy(Files[FilesRead].Name, FileInfo.name);
   Files[FilesRead].Size = FileInfo.size;
   Files[FilesRead].Directory = FileInfo.attrib & FA_DIREC;
   FilesRead++;
  }
  done = al_findnext(&FileInfo);
 } while (!done);   // while more files and more wanted

 al_findclose(&FileInfo);

 // Sort starting one entry after the entry for ".."
 qsort(&Files[1], FilesRead - 1, sizeof(FILELIST),
  (int (*)(const void *,const void *))fncmp);

#if defined(ALLEGRO_DOS) || defined(ALLEGRO_WINDOWS)
 for (int a = 0; a < 26; a++){
  sprintf(Files[FilesRead].Name, "%c:", a + 'A');
  Files[FilesRead].Size = 0;
  Files[FilesRead].Directory = FA_DIREC;
  FilesRead++;
 }
#endif

 return FilesRead;
}

/* ------------------------- GUI STUFF ------------------------- */

#include "romload.h"
#include "types.h"
#include "font.h"
#include "helper.h"

RGB GUIPal[16]={{ 0, 0, 0, 0},{ 0, 0,31, 0},{ 0,31, 0, 0},{ 0,31,31, 0},
                {31, 0, 0, 0},{31, 0,31, 0},{39,23, 0, 0},{47,47,47, 0},
                {31,31,31, 0},{ 0, 0,63, 0},{ 0,63, 0, 0},{ 0,63,63, 0},
                {63, 0, 0, 0},{63, 0,63, 0},{63,63, 0, 0},{63,63,63, 0}};

GUI_FONT ZSNES_Font(
 Xlat_ZSNES_6x6,Font_ZSNES_6x6,
 Font_Width_ZSNES,Font_Height_ZSNES,
 Font_WidthSpace_ZSNES,Font_HeightSpace_ZSNES);

GUI_FONT Modified_Font(
 Xlat_ZSNES_6x6,Font_Modified_6x6,
 Font_Width_ZSNES,Font_Height_ZSNES,
 Font_WidthSpace_ZSNES,Font_HeightSpace_ZSNES);

GUI_FONT Old_Font(
 Xlat_6x8,Font_6x8,
 Font_Width_Old,Font_Height_Old,
 Font_WidthSpace_Old,Font_HeightSpace_Old);

GUI_FONT *default_font=&Modified_Font;

int GUI_ScreenWidth=320,GUI_ScreenHeight=240;
BITMAP *GUI_Bitmap=0;
unsigned char *GUI_Screen;

static char err_create_scrn_buf[]="Error creating GUI screen buffer.\n";

char *GUI_core_init(){
 DirList = (FILELIST *) malloc(sizeof(FILELIST[max_listed_files]));
 GUI_Bitmap=create_bitmap_ex(8,GUI_ScreenWidth,GUI_ScreenHeight);
 if(!GUI_Bitmap) return err_create_scrn_buf;
 clear(GUI_Bitmap);
 GUI_Screen=(unsigned char *)GUI_Bitmap->dat;
 return 0;
}

void CopyGUIScreen(){
 acquire_screen();

 blit(Allegro_Bitmap,screen,0,0,0,0,ScreenX,ScreenY);

 release_screen();
}

int WINDOW::add(CTL *control){
 if ((numctls + 1) == 0) return control->handle = 0;
 CTL *temp = 0, *last = 0;
 unsigned handle = 1;

 if (!first){
  first = control;
 } else {
  for (temp = first; temp; temp = (last = temp)->next){
   if (temp->handle == handle){
    handle++; if (!handle) return control->handle = 0; temp = first;
   }
  }
  last->next=control;
 }

 numctls++; control->next = 0; control->attach(this);
 return control->handle = handle;
}

int WINDOW::sub(unsigned handle){
 int found = 0;
 CTL *temp, *last;

 if (first){
  while (first->handle == handle){
    found = -1;
    numctls--;
    first = first->next;
    first->detach(this);
  }

  last = first;
  for (temp = first->next; temp; temp = (last = temp)->next){
   while (temp->handle == handle){
    found = -1;
    numctls--;
    last->next = temp->next;
    temp->detach(this);
   }
  }
 }

 return found;
}

void WINDOW::refresh(){ refresh((WINDOW *)0); };
void WINDOW::refresh(WINDOW *parent){
 CTL::refresh(parent);
 rewind();
 CTL *control;
 while((control = next()) != 0){
  control->refresh(this);
 }
}

void CTL_CLEAR::refresh(WINDOW *parent){
 CTL::refresh(parent);
 int x = parent->get_visible_x(), width = parent->get_width();
 int y = parent->get_visible_y(), height = parent->get_height();

 if (parent->get_visible_x() < 0){ width += x; x = 0; }
 if (x + width > GUI_ScreenWidth) width = GUI_ScreenWidth - x;
 if (parent->get_visible_y() < 0){ height += y; y = 0; }
 if (y + height > GUI_ScreenHeight) height = GUI_ScreenHeight - y;

 if (height > 0) for (int v = y; v < y + height; v++){
  if (width > 0) memset(GUI_Screen + x + GUI_ScreenWidth * v, color, width);
 }
}

void CTL_BORDER::refresh(WINDOW *parent){
 CTL::refresh(parent);
 const int
  cBorder_TL=240+15,cBorder_T=240+15,cBorder_TR=240+7,
  cBorder_L =240+15,cBorder_R=240+ 8,
  cBorder_BL=240+ 7,cBorder_B=240+ 8,cBorder_BR=240+8;

 if(parent->get_x()>=GUI_ScreenWidth ||
  parent->get_y()>=GUI_ScreenHeight) return;

 // left/middle/right, outer/inner, x position/width
 int lox,low,mox,mow,rox,row;
 int lix,liw,mix,miw,rix,riw;
 lox=parent->get_x(); low=1;
 lix=lox+low; liw=1;
 mox=lox+low; mow=parent->get_width()+parent->get_gap_x()+liw*2;
 mix=lix+liw; miw=parent->get_width()+parent->get_gap_x();
 rox=mox+mow; row=1;
 rix=mix+miw; riw=1;

 if(lox<0){ low+=lox; lox=0; }
 if((lox+low)>GUI_ScreenWidth) low=GUI_ScreenWidth-lox;
 if(mox<0){ mow+=mox; mox=0; }
 if((mox+mow)>GUI_ScreenWidth) mow=GUI_ScreenWidth-mox;
 if(rox<0){ row+=rox; rox=0; }
 if((rox+row)>GUI_ScreenWidth) row=GUI_ScreenWidth-rox;
 if(lix<0){ liw+=lix; lix=0; }
 if((lix+liw)>GUI_ScreenWidth) liw=GUI_ScreenWidth-lix;
 if(mix<0){ miw+=mix; mix=0; }
 if((mix+miw)>GUI_ScreenWidth) miw=GUI_ScreenWidth-mix;
 if(rix<0){ riw+=rix; rix=0; }
 if((rix+riw)>GUI_ScreenWidth) riw=GUI_ScreenWidth-rix;

 // top/middle/bottom, outer/inner, y position/height
 int toy,toh,moy,moh,boy,boh;
 int tiy,tih,miy,mih,biy,bih;
 toy=parent->get_y(); toh=1;
 tiy=toy+toh; tih=1;
 moy=toy+toh; moh=parent->get_height()+parent->get_gap_y()+tih*2;
 miy=tiy+tih; mih=parent->get_height()+parent->get_gap_y();
 boy=moy+moh; boh=1;
 biy=miy+mih; bih=1;

 if(toy<0){ toh+=toy; toy=0; }
 if((toy+toh)>GUI_ScreenHeight) toh=GUI_ScreenHeight-toy;
 if(moy<0){ moh+=moy; moy=0; }
 if((moy+moh)>GUI_ScreenHeight) moh=GUI_ScreenHeight-moy;
 if(boy<0){ boh+=boy; boy=0; }
 if((boy+boh)>GUI_ScreenHeight) boh=GUI_ScreenHeight-boy;
 if(tiy<0){ tih+=tiy; tiy=0; }
 if((tiy+tih)>GUI_ScreenHeight) tih=GUI_ScreenHeight-tiy;
 if(miy<0){ mih+=miy; miy=0; }
 if((miy+mih)>GUI_ScreenHeight) mih=GUI_ScreenHeight-miy;
 if(biy<0){ bih+=biy; biy=0; }
 if((biy+bih)>GUI_ScreenHeight) bih=GUI_ScreenHeight-biy;

 if(toh>0) for(int v=toy;v<toy+toh;v++){
  if(low>0) memset(GUI_Screen+lox+GUI_ScreenWidth*v,cBorder_TL,low);
  if(mow>0) memset(GUI_Screen+mox+GUI_ScreenWidth*v,cBorder_T,mow);
  if(row>0) memset(GUI_Screen+rox+GUI_ScreenWidth*v,cBorder_TR,row);
 }
 if(moh>0) for(int v=moy;v<moy+moh;v++){
  if(low>0) memset(GUI_Screen+lox+GUI_ScreenWidth*v,cBorder_L,low);
  if(row>0) memset(GUI_Screen+rox+GUI_ScreenWidth*v,cBorder_R,row);
 }
 if(boh>0) for(int v=boy;v<boy+boh;v++){
  if(low>0) memset(GUI_Screen+lox+GUI_ScreenWidth*v,cBorder_BL,low);
  if(mow>0) memset(GUI_Screen+mox+GUI_ScreenWidth*v,cBorder_B,mow);
  if(row>0) memset(GUI_Screen+rox+GUI_ScreenWidth*v,cBorder_BR,row);
 }

 if(tih>0) for(int v=tiy;v<tiy+tih;v++){
  if(liw>0) memset(GUI_Screen+lix+GUI_ScreenWidth*v,240+cWindow_Back,liw);
  if(miw>0) memset(GUI_Screen+mix+GUI_ScreenWidth*v,240+cWindow_Back,miw);
  if(riw>0) memset(GUI_Screen+rix+GUI_ScreenWidth*v,240+cWindow_Back,riw);
 }
 if(mih>0) for(int v=miy;v<miy+mih;v++){
  if(liw>0) memset(GUI_Screen+lix+GUI_ScreenWidth*v,240+cWindow_Back,liw);
  if(riw>0) memset(GUI_Screen+rix+GUI_ScreenWidth*v,240+cWindow_Back,riw);
 }
 if(bih>0) for(int v=biy;v<biy+bih;v++){
  if(liw>0) memset(GUI_Screen+lix+GUI_ScreenWidth*v,240+cWindow_Back,liw);
  if(miw>0) memset(GUI_Screen+mix+GUI_ScreenWidth*v,240+cWindow_Back,miw);
  if(riw>0) memset(GUI_Screen+rix+GUI_ScreenWidth*v,240+cWindow_Back,riw);
 }
}

void CTL_BITMAP::refresh(WINDOW *parent){
 CTL::refresh(parent);
 if(!bitmap) return;
 if(!*bitmap) return;
 int sx=0,sy=0,dx=x,dy=y,width=(*bitmap)->w,height=(*bitmap)->h;

 if(dx<0){ width+=dx; sx-=dx; dx=0; }
 if((dx+width)>parent->get_width()){
  width=parent->get_width()-dx;
 }
 if(dy<0){ height+=dy; sy-=dy; dy=0; }
 if((dy+height)>parent->get_height()){
  height=parent->get_height()-dy;
 }

 masked_blit(*bitmap,GUI_Bitmap,sx,sy,
  parent->get_x()+dx,parent->get_y()+dy,width,height);
}

inline static void PlotStringHelper(WINDOW *window, pGUI_FONT font,
                                    const char *String, int x, int y,
                                    int col, int col_back, int col_fore){
 while (*String){
  if (x >= window->get_width()) break;
  int lx  = window->get_visible_x() + x + font->get_widthspace() - 1,
      lx2 = window->get_visible_x() + x,
      ly  = window->get_visible_y() + y,
      ly2 = window->get_visible_y() + y + font->get_heightspace() - 1;
  vline(GUI_Bitmap, lx, ly, ly2, col);
  hline(GUI_Bitmap, lx2, ly2, lx, col);
//  if (x > -font->get_widthspace()) // this is always true - dbjh
   PlotChar(window, font, *String, x, y, col_back, col_fore);
  String++; x += font->get_widthspace();
 }
}

void PlotString(WINDOW *window,pGUI_FONT font,const char *String,int x,int y){
 PlotStringHelper(window, font, String, x, y, 240 + cText_Back, cText_Back, cText_Fore);
}

void PlotStringInv(WINDOW *window,pGUI_FONT font,const char *String,int x,int y){
 PlotStringHelper(window, font, String, x, y, 240 + cText_Fore, cText_Fore, cText_Back);
}

void PlotStringTransparent(WINDOW *window,pGUI_FONT font,const char *String,int x,int y,int color){
 while(*String){
  if(x>=window->get_width()) break;
  if(x>-font->get_widthspace())
   PlotCharT(window,font,*String,x,y,color);
  String++; x+=font->get_widthspace();
 }
}

void PlotStringShadow(WINDOW *window,pGUI_FONT font,const char *String,int x,int y,int tcolor,int scolor){
 x-=((strlen(String)*font->get_widthspace())>>1);
 PlotStringTransparent(window,font,String,x+1,y+1,scolor);
 PlotStringTransparent(window,font,String,x,y,tcolor);
}

void PlotMenuItem(WINDOW *window, pGUI_FONT font,
 const char *String, int x, int y, int maxlen){
 while (*String){
  if(x>=window->get_width()) break;
  if (maxlen > 0) maxlen--;
  if (x > -font->get_widthspace())
   PlotCharT(window, font, *String, x, y, cMenu_Fore);
  String++; x+=font->get_widthspace();
 }
 while (maxlen--){
  if(x>=window->get_width()) break;
  if(x>-font->get_widthspace())
   PlotCharT(window, font, ' ', x, y, cMenu_Fore);
  String++; x+=font->get_widthspace();
 }
}

void PlotSelectedMenuItem(WINDOW *window, pGUI_FONT font, const char *String, int x, int y, int maxlen){
 PlotStringHelper(window, font, String, x, y, 240 + cSelected_Back, cSelected_Back, cSelected_Fore);
 int len = strlen(String);
 maxlen -= len;
 if (maxlen <= 0)
  return;
 x += len * font->get_widthspace();
 rectfill (GUI_Bitmap,
           window->get_visible_x() + x,
           window->get_visible_y() + y,
           window->get_visible_x() + x + maxlen * font->get_widthspace() - 1,
           window->get_visible_y() + y + font->get_heightspace() - 1,
           240 + cSelected_Back);
}

PALETTE sneesepal;
BITMAP *sneese=0;
BITMAP *joypad=0;

void PlotChar(WINDOW *window,pGUI_FONT font,
 char Character,int x,int y,int bcolor,int fcolor){
 int width=font->get_width();
 unsigned c=font->xlat[(unsigned char) Character];
 unsigned char *Pointer=font->faces+c*((width+7)/8)*font->get_height();
 bcolor+=240; fcolor+=240;

 for(int v=0;v<font->get_height();v++){
  // Enforce vertical boundaries
  if((y+v)>=window->get_height() ||
   (window->get_visible_y()+y+v)>=GUI_ScreenHeight) break;
  if((y+v)<0 || (window->get_visible_y()+y+v)<0) continue;
  for (int h=0,bit=0x80>>(8-(width&7));h<width;h++,bit>>=1){
   // Enforce horizontal boundaries
   if((x+h)>=window->get_width() ||
    (window->get_visible_x()+x+h)>=GUI_ScreenWidth) break;
   if((x+h)<0 || (window->get_visible_x()+x+h)<0) continue;
   if(!bit) bit=0x80;
// GUI_Screen[window->get_visible_x()+x+h+
//  GUI_ScreenWidth*(window->get_visible_y()+y+v)]=
//  (Pointer[(h/8)+((width+7)/8)*v] & bit) ? fcolor : bcolor;
   putpixel(GUI_Bitmap, window->get_visible_x()+x+h,
    (window->get_visible_y()+y+v),
     (Pointer[(h/8)+((width+7)/8)*v] & bit) ? fcolor : bcolor);
  }
 }
}

void PlotCharTDirect(pGUI_FONT font,char Character,int x,int y,int color){
 int width=font->get_width();
 unsigned c=font->xlat[(unsigned char) Character];
 unsigned char *Pointer=font->faces+c*((width+7)/8)*font->get_height();
 color+=240;

 for(int v=0;v<font->get_height();v++){
  // Enforce vertical boundaries
/*if ((y+v)>=ScreenY) break;*/
  if ((y+v)>=224) break;
  if ((y+v)<0) continue;
  for (int h=0,bit=0x80>>(8-(width&7));h<width;h++,bit>>=1){
   // Enforce horizontal boundaries
/* if((x+h)>=ScreenX) break; */
   if((x+h)>=256) break;
   if((x+h)<0) continue;
   if(!bit) bit=0x80;
   if(Pointer[(h/8)+((width+7)/8)*v] & bit)
    putpixel((BITMAP *) gbSNES_Screen8.subbitmap, x+h, y+v, color);
//  SNES_Screen8[x+h+(256+16)*(y+v)]=color;
  }
 }
}

void PlotStringTDirect(pGUI_FONT font,const char *String,int x,int y,int color){
 while(*String){
  if(x>-font->get_widthspace())
   PlotCharTDirect(font,*String,x,y,color);
  String++; x+=font->get_widthspace();
  if(x>ScreenX) break;
 }
}

void PlotStringSDirect(pGUI_FONT font,const char *String,int x,int y,int tcolor,int scolor){
 x-=((strlen(String)*font->get_widthspace())>>1);
 PlotStringTDirect(font,String,x+1,y+1,scolor);
 PlotStringTDirect(font,String,x,y,tcolor);
}

extern "C" unsigned FPSLast;
extern "C" void ShowFPS(void);
void ShowFPS(void){
 char FPS[5];

 if (FPSLast <= 9999)
 {
  FPS[0] = '0' + (FPSLast / 1000);
  FPS[1] = '0' + (FPSLast / 100) % 10;
  FPS[2] = '0' + (FPSLast / 10) % 10;
  if (FPS[0] == '0')
  {
   FPS[0] = ' ';
   if (FPS[1] == '0')
   {
    FPS[1] = ' ';
    if (FPS[2] == '0')
    {
     FPS[2] = ' ';
    }
   }
  }
  FPS[3] = '0' + FPSLast % 10;
  FPS[4] = 0;
 }
 else
 {
  FPS[0] = 'X'; FPS[1] = 'X'; FPS[2] = 'X'; FPS[3] = 'X';
  FPS[4] = 0;
 }
 PlotStringSDirect(default_font,FPS,180,2,1,2);
}

extern "C" unsigned BreaksLast;
extern "C" void ShowBreaks(void);
void ShowBreaks(void){
 char Breaks[5];

 if (BreaksLast <= 9999)
 {
  Breaks[0] = '0' + (BreaksLast / 1000);
  Breaks[1] = '0' + (BreaksLast / 100) % 10;
  Breaks[2] = '0' + (BreaksLast / 10) % 10;
  if (Breaks[0] == '0')
  {
   Breaks[0] = ' ';
   if (Breaks[1] == '0')
   {
    Breaks[1] = ' ';
    if (Breaks[2] == '0')
    {
     Breaks[2] = ' ';
    }
   }
  }
  Breaks[3] = '0' + BreaksLast % 10;
  Breaks[4] = 0;
 }
 else
 {
  Breaks[0] = 'X'; Breaks[1] = 'X'; Breaks[2] = 'X'; Breaks[3] = 'X';
  Breaks[4] = 0;
 }
 PlotStringSDirect(default_font,Breaks,76,2,1,2);
}

void PlotCharT(WINDOW *window,pGUI_FONT font,
 char Character,int x,int y,int color){
 int width=font->get_width();
 unsigned c=font->xlat[(unsigned char) Character];
 unsigned char *Pointer=font->faces+c*((width+7)/8)*font->get_height();
 color+=240;

 for(int v=0;v<font->get_height();v++){
  // Enforce vertical boundaries
  if((y+v)>=window->get_height() ||
   (window->get_visible_y()+y+v)>=GUI_ScreenHeight) break;
  if((y+v)<0 || (window->get_visible_y()+y+v)<0) continue;
  for (int h=0,bit=0x80>>(8-(width&7));h<width;h++,bit>>=1){
   // Enforce horizontal boundaries
   if((x+h)>=window->get_width() ||
    (window->get_visible_x()+x+h)>=GUI_ScreenWidth) break;
   if((x+h)<0 || (window->get_visible_x()+x+h)<0) continue;
   if(!bit) bit=0x80;
   if(Pointer[(h/8)+((width+7)/8)*v] & bit)
//  GUI_Screen[window->get_visible_x()+x+h+
//   GUI_ScreenWidth*(window->get_visible_y()+y+v)]=color;
    putpixel(GUI_Bitmap, window->get_visible_x()+x+h,
     (window->get_visible_y()+y+v),color);
  }
 }
}

/*
void PlotCharBorder(unsigned char Character,int x,int y){
 unsigned char *Pointer=FontData+((long)Character)*FontWidth*FontHeight;

 for(int v=0;v<FontHeight;v++){
  for(int h=0;h<FontWidth;h++){
   if(v>=0 && v<=FontHeight-1 && h>=0 && h<=FontWidth-1 &&
    Pointer[h+FontWidth*v]==1)
//  GUI_Screen[x+h+GUI_ScreenWidth*(v+y)]=255;
    putpixel(GUI_Bitmap,x+h,(v+y),255;
   else if((v>0 && Pointer[h+FontWidth*(v-1)]==1) ||
    (v<FontHeight-1 && Pointer[h+FontWidth*(v+1)]==1) ||
    (h>0 && Pointer[(h-1)+FontWidth*v]==1) ||
    (h<FontWidth-1 && Pointer[(h+1)+FontWidth*v]==1))
//  GUI_Screen[x+h+GUI_ScreenWidth*(v+y)]=240;
    putpixel(GUI_Bitmap,x+h,(v+y),240;
  }
 }
}*/
