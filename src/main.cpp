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

//#define NO_GUI

#include "wrapaleg.h"

#include <iostream>

using namespace std;


#include <stdio.h>

#include "platform.h"
#include "romload.h"
#include "helper.h"
#include "guicore.h"
#include "emugui.h"
#include "debug.h"
#include "snes.h"
#include "timers.h"

#include "types.h"
#include "version.h"


extern const int screenmode_fallback = 2;  /* 640x480x16b */

SCREEN screenmodes[]={
#if defined(ALLEGRO_DOS)
 {16,320,200,320,200,GFX_VESA2L,},  // 320x200x16b VESA2L
 {16,320,240,320,240,GFX_VESA2L,},  // 320x240x16b VESA2L
 {16,640,480,640,480,GFX_VESA2L,},  // 640x480x16b VESA2L
 {16,800,600,800,600,GFX_VESA2L,},  // 800x600x16b VESA2L
 {16,960,720,960,720,GFX_VESA2L,},  // 960x720x16b VESA2L
 {16,1024,768,1024,768,GFX_VESA2L,} // 1024x768x16b VESA2L
#elif defined(ALLEGRO_WINDOWS) || defined(ALLEGRO_UNIX) || defined(ALLEGRO_BEOS)
 {16,320,200,320,200,               // 320x200x16b
  GFX_AUTODETECT_FULLSCREEN, GFX_AUTODETECT_WINDOWED },
 {16,320,240,320,240,               // 320x240x16b
  GFX_AUTODETECT_FULLSCREEN, GFX_AUTODETECT_WINDOWED },
 {16,640,480,640,480,               // 640x480x16b
  GFX_AUTODETECT_FULLSCREEN, GFX_AUTODETECT_WINDOWED },
 {16,800,600,800,600,               // 800x600x16b
  GFX_AUTODETECT_FULLSCREEN, GFX_AUTODETECT_WINDOWED },
 {16,960,720,960,720,               // 960x720x16b
  GFX_AUTODETECT_FULLSCREEN, GFX_AUTODETECT_WINDOWED },
 {16,1024,768,1024,768,               // 1024x768x16b
  GFX_AUTODETECT_FULLSCREEN, GFX_AUTODETECT_WINDOWED },
 {16,256,239,256,239,               // 256x239x16b
  GFX_AUTODETECT_FULLSCREEN, GFX_AUTODETECT_WINDOWED },
 {16,512,478,512,478,               // 512x478x16b
  GFX_AUTODETECT_FULLSCREEN, GFX_AUTODETECT_WINDOWED },
 {16,768,717,768,717,               // 768x717x16b
  GFX_AUTODETECT_FULLSCREEN, GFX_AUTODETECT_WINDOWED }
#else
#error No screen modes defined.
#endif
};

int main(int argc, char **argv)
{

 cout << "SNEeSe, version " << SNEESE_VERSION_STR
      << " (" << RELEASE_DATE << ")" << endl
      << allegro_id << endl << endl;
 cout.flush();

 // Perform platform-specific initialization
 if (platform_init(argc, argv)) return 1;

 atexit(platform_exit);

 debug_init();

 // Load saved configuration, using defaults for missing settings
 if (LoadConfig()) return 1;

 char *name = NULL;
 if (parse_args(argc, argv, &name, 1)) return 1;

 snes_init();

 if (name != NULL)
 {
  cout << "Attempting to load " << name << endl;

  if (!open_rom_with_default_path(name))
  {
   cout << "Failed to load cartridge ROM: " << name << endl;
   return 1;
  }

#if defined(ALLEGRO_DOS) || defined(ALLEGRO_UNIX) || defined(ALLEGRO_BEOS)
  cout << endl << "Press any key to continue...";
  cout.flush();

  // We have to create a window or else the keyboard functions won't work
  //  (i.e., the two just below)
#if defined(ALLEGRO_UNIX)
  if (set_gfx_mode(GFX_XWINDOWS, 300, 80, 0, 0) == 0)
   textout_ex(screen, font, "Press any key to continue...", 38, 36, makecol(220, 220, 220), -1);
#elif defined(ALLEGRO_BEOS)
  if (set_gfx_mode(GFX_BWINDOW, 300, 80, 0, 0) == 0)
   textout_ex(screen, font, "Press any key to continue...", 38, 36, makecol(220, 220, 220), -1);
#endif

  while (!keypressed());
  readkey();
  cout << " continuing..." << endl;
#endif
 }

#ifndef NO_GUI
 const char *errormsg = (const char *)0;
 if (GUI_ENABLED)
 {
  errormsg = GUI_init();
  if (errormsg)
  {
   cout << errormsg;
   return 1;
  }
 }
#endif

 if (!SetGUIScreen(SCREEN_MODE, screen_mode_windowed)) return 1;

#ifndef NO_GUI
 GUI_ERROR GUI_error = GUI_EXIT;
#endif
 for (;;)
 {
  if (snes_rom_loaded)
  {
   snes_exec();
  }

#ifndef NO_GUI
  if (!GUI_ENABLED) break;
  GUI_error = GUI();
  if (GUI_error != GUI_CONTINUE) break;
#else
  break;
#endif
 }

 if (snes_rom_loaded)
  SaveSRAM(SRAM_filename);  // Save the Save RAM to file

 SaveConfig();

 set_gfx_mode(GFX_TEXT, 0, 0, 0, 0);
 remove_keyboard();

#ifdef DEBUG
 if (snes_rom_loaded)
 {
  DisplayStatus();
 }

// cout << "\nThanks for testing SNEeSe - look out for future releases.\n";
 cout << "\nThanks for using SNEeSe - look out for future releases.\n";
#else
 cout << "\nThanks for using SNEeSe - look out for future releases.\n";
#endif

 cout << "Displayed frames: " << Frames << endl;

#ifndef NO_GUI
 if (GUI_ENABLED)
 {
  if (GUI_error != GUI_EXIT)
  {
   cout << "GUI: " << GUI_error_table[GUI_error] << endl;
  }
 }
#endif

 save_debug_dumps();
 cout.flush();

 return 0;
}
END_OF_MAIN()
