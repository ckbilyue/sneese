/*

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2004 Charles Bilyue'.
Portions Copyright (c) 2003-2004 Daniel Horchner.

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

#include "scrmode.h"
#include "types.h"
#include "version.h"

void no_adjust(void){}

SCREEN screenmodes[]={
#if defined(ALLEGRO_DOS)
 { 8,320,200,320,200,GFX_VGA   ,no_adjust  },  // 320x200x256 VGA
 { 8,320,240,320,240,GFX_VESA2L,no_adjust  },  // 320x240x256 VESA2L
 { 8,320,240,320,240,GFX_MODEX ,no_adjust  },  // 320x240x256 MODE-X
 { 8,256,256,256,239,GFX_VGA   ,Set256x239 },  // 256x239x256 VGA
 {16,320,200,320,200,GFX_VESA2L,no_adjust  },  // 320x200x16b SVGA
 {16,320,240,320,240,GFX_VESA2L,no_adjust  },  // 320x240x16b SVGA
 {16,640,480,640,480,GFX_VESA2L,no_adjust  }   // 640x480x16b SVGA
#elif defined(ALLEGRO_WINDOWS) || defined(ALLEGRO_UNIX) || defined(ALLEGRO_BEOS)
 { 8,320,200,320,200,GFX_AUTODETECT_WINDOWED  ,no_adjust  },  // 320x200x256 WIN
 { 8,320,240,320,240,GFX_AUTODETECT_WINDOWED  ,no_adjust  },  // 320x240x256 WIN
 { 8,320,240,320,240,GFX_AUTODETECT_FULLSCREEN,no_adjust  },  // 320x240x256 FS
 { 8,256,256,256,239,GFX_AUTODETECT_WINDOWED  ,no_adjust  },  // 256x239x256 WIN
 {16,320,200,320,200,GFX_AUTODETECT_WINDOWED  ,no_adjust  },  // 320x200x16b WIN
 {16,320,240,320,240,GFX_AUTODETECT_WINDOWED  ,no_adjust  },  // 320x240x16b WIN
 {16,640,480,640,480,GFX_AUTODETECT_WINDOWED  ,no_adjust  },  // 640x480x16b WIN
 {16,640,480,640,480,GFX_AUTODETECT_FULLSCREEN,no_adjust  }   // 640x480x16b FS
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

 // Load saved configuration, using defaults for missing settings
 if (LoadConfig()) return 1;

 char *name = NULL;
 if (parse_args(argc, argv, &name, 1)) return 1;

 snes_init();

 if (name != NULL)
 {
  char filename[MAXPATH];

  cout << "Attempting to load " << name << endl;

  fix_filename_path(filename, name, MAXPATH);

  if (!open_rom(filename))
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

 if (!SetGUIScreen(SCREEN_MODE)) return 1;

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
