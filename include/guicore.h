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

#ifndef SNEeSe_guicore_h
#define SNEeSe_guicore_h

//#define NO_LOGO

#include "platform.h"
#include "wrapaleg.h"

extern unsigned char GUI_ENABLED;

#if (defined(__cplusplus)||defined(c_plusplus))

/* ------------------------- DIRECTORY STUFF ------------------------- */

// FILELIST struct holds file size, name, and directory flag.

struct FILELIST {
 int Size;
 char Name[MAXPATH];
 char Directory; // if 16 this is a directory
};

extern FILELIST *DirList;

// This fills an array of FILELIST with file information
// from the path given, starting at file number Offset
int GetDirList(char *Path, FILELIST *&Files, int Offset, int *real_file_count);

/* ------------------------- GUI STUFF ------------------------- */

#include "types.h"
#include "font.h"
#include "helper.h"

extern RGB GUIPal[16];

extern GUI_FONT ZSNES_Font,Modified_Font,Old_Font;
extern pGUI_FONT default_font;

extern int GUI_ScreenWidth,GUI_ScreenHeight;
extern BITMAP *GUI_Bitmap;
extern unsigned char *GUI_Screen;

char *GUI_core_init();
void CopyGUIScreen();

enum GUI_ERROR {
 GUI_CONTINUE, GUI_EXIT, GUI_SCREEN, GUI_ALLOC
};

extern const char *GUI_error_table[];

class WINDOW;

/*
 CTL - GUI ConTroL class
  used in chain of CTLs in conjunction with WINDOW
  contains pointer to next CTL and handle of CTL
  CTL() resets next pointer and handle
  refresh() is used to redisplay the control, typically called by
   parent WINDOW
  process() does any periodic message processing required by the control
  attach() does any special processing required at time of attachment to
   WINDOW - called by WINDOW::add()
  detach() does any special processing required at time of detachment
   from WINDOW - called by WINDOW::remove()
  refresh(),process(),attach(), and detach() are all declared as virtual
   functions, which should be chained to if overridden
*/
class CTL {
 friend class WINDOW;
 CTL *next;
 unsigned handle;
 WINDOW *parent;
// WINDOW *screen_parent;
public:
 CTL(){ next = 0; handle = 0; }
 CTL(WINDOW *parent);
 virtual void refresh(WINDOW *parent){}
 virtual void process(WINDOW *parent){}
 virtual void attach(WINDOW *parent){ this->parent = parent; }
 virtual void detach(WINDOW *parent){}
};

/*
 WINDOW - GUI WINDOW and ConTroL LIST class
  used to define a portion of the screen and allow a chain of CTLs to
   reference it
  contains pointer to first CTL, current CTL (for CTL-walking), and number
   of CTLs in list
  WINDOW() resets the list by calling clear()
  clear_list() resets the first and current pointers and number of controls
   to 0
  add() adds a control to the list, and notifies it to perform any
   attach-time processing
*/
class WINDOW : public CTL {
protected:
 CTL *first;
 CTL *current;
 int numctls;

 int focus;

 int x, y, width, height;
 int visible_x, visible_y, gap_x, gap_y;
 char *title;
// WINDOWFLAGS flags;
public:
 int get_x(){ return x; }
 int get_y(){ return y; }
 int get_width(){ return width; }
 int get_height(){ return height; }
 int get_visible_x(){ return visible_x; }
 int get_visible_y(){ return visible_y; }
 int get_gap_x(){ return gap_x; }
 int get_gap_y(){ return gap_y; }
 void set_x(int i){ x = i; }
 void set_y(int i){ y = i; }
 void set_width(int i){ width = i; }
 void set_height(int i){ height = i; }
 void set_visible_x(int i){ visible_x = i; }
 void set_visible_y(int i){ visible_y = i; }
 void set_gap_x(int i){ gap_x = i; }
 void set_gap_y(int i){ gap_y = i; }

 void clear_list(){ current = first = 0; numctls = 0; }

 WINDOW(int x,int y,int width,int height,char *title = 0) : CTL(){
  visible_x = this->x = x; visible_y = this->y = y;
  this->width = width; this->height = height;
  this->title = title;
  gap_x = gap_y = 0;
  clear_list();
 }

 int add(CTL *control);
 int add(CTL &control){ return add(&control); }
 int sub(unsigned handle);
 int sub(CTL *control){ return sub(control->handle); }
 int sub(CTL &control){ return sub(control.handle); }
 virtual void refresh(WINDOW *parent);
 virtual void refresh();    //
 WINDOW &operator+=(CTL *control){ add(control); return *this; }
 WINDOW &operator+=(CTL &control){ add(control); return *this; }
 WINDOW &operator-=(CTL *control){ sub(control); return *this; }
 WINDOW &operator-=(CTL &control){ sub(control); return *this; }
 void rewind(){ current=first; }
 CTL *next(){
  CTL *temp = current;
  if(current){ current = current->next; }
  return temp;
 }
};

inline CTL::CTL(WINDOW *parent){
 next = 0; handle = 0; (this->parent = parent)->add(this);
}

class CTL_CLEAR : public CTL {
 int color;
public:
 CTL_CLEAR(int color=240+7){ this->color=color; }
 CTL_CLEAR(WINDOW *parent,int color=240){
  this->color=color; parent->add(this);
 }
 void refresh(WINDOW *parent);
};

class CTL_BORDER : public CTL {
public:
 CTL_BORDER(){}
 CTL_BORDER(WINDOW *parent){ parent->add(this); }
 void attach(WINDOW *parent){
  CTL::attach(parent);
  parent->set_visible_x(parent->get_visible_x()+2);
  parent->set_visible_y(parent->get_visible_y()+2);
 }
 void detach(WINDOW *parent){
  CTL::detach(parent);
  parent->set_visible_x(parent->get_visible_x()-2);
  parent->set_visible_y(parent->get_visible_y()-2);
 }
 void refresh(WINDOW *parent);
};

class BORDER_WINDOW : public WINDOW {
 CTL_BORDER border;
public:
 BORDER_WINDOW(int x,int y,int width,int height,char *title=0)
 : WINDOW(x,y,width,height,title){
  add(&border);
 }
};

class CTL_MENU : CTL {
 char *name;
public:
 CTL_MENU(char *name = 0){ this->name = name; }
};

class CTL_MENUITEM : public CTL {
 CTL_MENU *base;
 char *name;
 void (*activate)();
public:
 friend class CTL_MENU;
 CTL_MENUITEM(char *name = 0,void (*activate)() = 0){
  this->name = name; this->activate = activate;
 }
 void process(WINDOW *parent){ CTL::process(parent); (*activate)(); }
};

class CTL_BITMAP : public CTL {
 BITMAP **bitmap;
 int x,y;
public:
 CTL_BITMAP(BITMAP **bitmap,int x,int y){
  this->bitmap=bitmap; this->x=x; this->y=y;
 }
 CTL_BITMAP(WINDOW *parent,BITMAP **bitmap,int x,int y) : CTL(parent){
  this->bitmap=bitmap; this->x=x; this->y=y;
 }
 void refresh(WINDOW *parent);
};

void PlotChar(WINDOW *window,pGUI_FONT font,
 char Character,int x,int y,int color);
void PlotCharT(WINDOW *window,pGUI_FONT font,
 char Character,int x,int y,int color);
void PlotCharBorder(unsigned char Character,int x,int y);

void PlotString(WINDOW *window,pGUI_FONT font,
 const char *String,int x,int y);
void PlotStringInv(WINDOW *window,pGUI_FONT font,
 const char *String,int x,int y);
void PlotStringTransparent(WINDOW *window,pGUI_FONT font,
 const char *String,int x,int y,int color);
void PlotStringShadow(WINDOW *window,pGUI_FONT font,
 const char *String,int x,int y,int tcolor,int scolor);

void PlotMenuItem(WINDOW *window,pGUI_FONT font,
 const char *String,int x,int y,int maxlen=0);
void PlotSelectedMenuItem(WINDOW *window,pGUI_FONT font,
 const char *String,int x,int y,int maxlen=0);

BITMAP *SetGUIScreen(int ScreenMode, int windowed);


void gui_wait_for_input();


#endif /* defined(__cplusplus)||defined(c_plusplus) */

#endif /* !defined(SNEeSe_guicore_h) */
