/*

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2003 Charles Bilyue'.
Portions Copyright (c) 2003 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

*/

/*

 EmuGUI.cc
  Contains emulator specific GUI code
  Some stuff from helper.c will be moved here!

*/

#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include "wrapaleg.h"
#include "guicore.h"

/* ------------------------- GUI STUFF ------------------------- */

#include "types.h"
#include "font.h"
#include "input.h"
#include "cpu/cpu.h"
#include "apu/spc.h"
#include "apu/sound.h"
#include "romload.h"
#include "debug.h"
#include "snes.h"

extern PALETTE sneesepal;

extern SCREEN screenmodes[];

// Used to configure the screen and set internal variables for rendering!
BITMAP *SetGUIScreen(int ScreenMode)
{
 if (Allegro_Bitmap)    // If bitmap exists destroy it
 {
  destroy_bitmap(Allegro_Bitmap);
  Allegro_Bitmap = NULL;
 }

 if (screenmodes[SCREEN_MODE = ScreenMode].set())
 {
  switch(ScreenMode)
  {
   case 0:
   case 1:
   case 3:
    return (BITMAP *) 0;
    break;
   default:
    if (screenmodes[SCREEN_MODE = 0].set()) return (BITMAP *) 0;
  }
 }

 ScreenX = screenmodes[SCREEN_MODE].w;
 ScreenY = screenmodes[SCREEN_MODE].h;

 Allegro_Bitmap = create_bitmap(ScreenX, ScreenY);
 if (!Allegro_Bitmap) return (BITMAP *) 0;
 clear(Allegro_Bitmap);
 SNES_Screen = (unsigned char *) Allegro_Bitmap->line[0];
 Reload_Bitmaps();  // We reload to convert to correct bit depth

 return Allegro_Bitmap;
}

extern BITMAP *sneese;
extern BITMAP *joypad;

const char *GUI_init()
{
 char *errormsg;

 errormsg = GUI_core_init();

 if (errormsg) return errormsg;

 if (joypad) destroy_bitmap(joypad);
 #ifdef DEBUG
  joypad = load_pcx("sneese.dat#joypad", sneesepal);
 #else
  joypad = load_pcx("#joypad", sneesepal);
 #endif

 return 0;
}

WINDOW *GUI_window=0;

WINDOW *Main_window=0;

enum {
 MAIN_RESUME_EMULATION,
 MAIN_RESET_EMULATION,
 MAIN_LOAD_ROM,
 MAIN_CONFIGURE,
 MAIN_ROM_INFO,
 MAIN_HW_STATUS,
 MAIN_DMA_STATUS,
 MAIN_APU_STATUS,
 MAIN_BGWIN_STATUS,
 MAIN_EXIT,
 MAIN_NUM_OPTIONS
};

char *Main_Options[MAIN_NUM_OPTIONS]={
 "Resume emulation",
 "Reset emulation",
 "Load ROM",
 "Configure",
 "ROM information",
 "HW status",
 "(H)DMA status",
 "Voice status",
 "BG window status",
 "Exit SNEeSe :("};

void UpdateGUI(int Selected)
{
 clear(GUI_Bitmap);
 Main_window->refresh();
 for(int a=0;a<MAIN_NUM_OPTIONS;a++)
  if(a!=Selected) PlotMenuItem(Main_window,default_font,Main_Options[a],0,default_font->get_heightspace()*a,16);
  else PlotSelectedMenuItem(Main_window,default_font,Main_Options[a],0,default_font->get_heightspace()*a,16);

#ifndef NO_LOGO
 if(sneese)
  stretch_blit(sneese,Allegro_Bitmap,0,0,GUI_ScreenWidth,GUI_ScreenHeight,0,0,SCREEN_W,SCREEN_H);
#endif
 draw_sprite(Allegro_Bitmap, GUI_Bitmap, 0, 0);
 vsync();
}

WINDOW *Screen_window=0;
#if defined(ALLEGRO_DOS)
#define NUM_SCREEN_OPTIONS 7
char *Screen_Options[NUM_SCREEN_OPTIONS]={
 "320x200x256 VGA",
 "320x240x256 VESA2",
 "320x240x256 MODE-X",
 "256x239x256 VGA",
 "320x200x16b VESA2",
 "320x240x16b VESA2",
 "640x480x16b VESA2"
};
#elif defined(ALLEGRO_WINDOWS) || defined(ALLEGRO_UNIX) || defined(ALLEGRO_BEOS)
#define NUM_SCREEN_OPTIONS 8
char *Screen_Options[NUM_SCREEN_OPTIONS]={
 "320x200x256 WIN",
 "320x240x256 WIN",
 "320x240x256 FS",
 "256x239x256 WIN",
 "320x200x16b WIN",
 "320x240x16b WIN",
 "640x480x16b WIN",
 "640x480x16b FS"
};
#else
#error Unsupported platform.
#endif

void UpdateScreenWindow(int Selected)
{
 Screen_window->refresh();
 for(int a=0;a<NUM_SCREEN_OPTIONS;a++)
  if(a!=Selected) PlotMenuItem(Screen_window,default_font,Screen_Options[a],0,default_font->get_heightspace()*a,20);
  else PlotSelectedMenuItem(Screen_window,default_font,Screen_Options[a],0,default_font->get_heightspace()*a,20);
#ifndef NO_LOGO
 if(sneese)
  stretch_blit(sneese,Allegro_Bitmap,0,0,GUI_ScreenWidth,GUI_ScreenHeight,0,0,SCREEN_W,SCREEN_H);
#endif
 draw_sprite(Allegro_Bitmap, GUI_Bitmap, 0, 0);
 vsync();
 CopyGUIScreen();
}

int ScreenWindow()
{
 int CursorAt = SCREEN_MODE;
 int keypress, key_asc, key_scan;
 clear_keybuf();

 for(;;)
 {
  UpdateScreenWindow(CursorAt);
  while (!keypressed());
  keypress = readkey();
  key_asc = keypress & 0xFF;
  key_scan = keypress >> 8;

  switch (key_scan)
  {
   case KEY_UP:
    if(CursorAt) CursorAt--; else CursorAt=NUM_SCREEN_OPTIONS-1;
    break;
   case KEY_DOWN:
    if(CursorAt < NUM_SCREEN_OPTIONS-1) CursorAt++; else CursorAt=0;
    break;
   case KEY_ESC:
    return -1;
   case KEY_ENTER:
   case KEY_ENTER_PAD:
    return CursorAt;
  }
 }
 return -1; // Signify normal exit
}


char *on_off[2]={ "off", "on" };
char *en_dis[2]={ "enabled", "disabled" };

char sample_size_str[] = "Sample size: xx-bit";

WINDOW *Sound_window=0;

enum {
 SOUND_ENABLE_SOUND,
 SOUND_SAMPLE_SIZE,
 SOUND_ENABLE_ECHO,
 SOUND_ENABLE_GAUSS,
 SOUND_ENABLE_ENVX,
 SOUND_NUM_OPTIONS
};

const char *Sound_Options[SOUND_NUM_OPTIONS]={
 0,                             // Sound enable setting
 sample_size_str,               // Sound sample size
 0,                             // Sound echo/FIR filter enable
 0,                             // Sound gauss filter enable
 0                              // Sound ENVX reading enable
};

void UpdateSoundWindow(int Selected)
{
 Sound_window->refresh();
 for(int a=0;a<SOUND_NUM_OPTIONS;a++)
  if(a!=Selected) PlotMenuItem(Sound_window,default_font,Sound_Options[a],0,default_font->get_heightspace()*a,24);
  else PlotSelectedMenuItem(Sound_window,default_font,Sound_Options[a],0,default_font->get_heightspace()*a,24);
#ifndef NO_LOGO
 if(sneese)
  stretch_blit(sneese,Allegro_Bitmap,0,0,GUI_ScreenWidth,GUI_ScreenHeight,0,0,SCREEN_W,SCREEN_H);
#endif
 draw_sprite(Allegro_Bitmap, GUI_Bitmap, 0, 0);
 vsync();
 CopyGUIScreen();
}

int SoundWindow()
{
 switch (sound_enabled)
 {
  case 0:
   Sound_Options[SOUND_ENABLE_SOUND] = "Sound Disabled";
   break;
  case 1:
   Sound_Options[SOUND_ENABLE_SOUND] = "Sound Enabled (mono)";
   break;
  default:
   Sound_Options[SOUND_ENABLE_SOUND] = "Sound Enabled (stereo)";
 }


 sprintf(sample_size_str, "Sample size: %2d-bit", sound_bits);


 Sound_Options[SOUND_ENABLE_ECHO] = sound_echo_enabled ?
  "Echo/FIR filter: on" : "Echo/FIR filter: off";


 Sound_Options[SOUND_ENABLE_GAUSS] = sound_gauss_enabled ?
  "Gaussian filter: on" : "Gaussian filter: off";


 Sound_Options[SOUND_ENABLE_ENVX] = ENVX_ENABLED ?
  "ENVX reading: on" : "ENVX reading: off";



 int CursorAt=0;
 int keypress, key_asc, key_scan;
 clear_keybuf();

 for(;;)
 {
  UpdateSoundWindow(CursorAt);
  while (!keypressed());
  keypress = readkey();
  key_asc = keypress & 0xFF;
  key_scan = keypress >> 8;

  switch (key_scan)
  {
   case KEY_UP:
    CursorAt--;
    if(CursorAt == -1) // so it wraps
     CursorAt = SOUND_NUM_OPTIONS-1;
    break;
   case KEY_DOWN:
    CursorAt++;
    if(CursorAt == SOUND_NUM_OPTIONS) // so it wraps
    CursorAt=0;
    break;

   case KEY_ESC:
    return -1;

   case KEY_ENTER:
   case KEY_ENTER_PAD:
    if (CursorAt == SOUND_ENABLE_SOUND)
    {
     switch(sound_enabled)
     {
      case 0:
       if (Install_Sound(0))
       {
        Sound_Options[SOUND_ENABLE_SOUND] = "Sound Enabled (mono)";
       }
       break;
      case 1:
       Remove_Sound();
       if (Install_Sound(1))
       {
        Sound_Options[SOUND_ENABLE_SOUND] = "Sound Enabled (stereo)";
       }
       else
       {
        Sound_Options[SOUND_ENABLE_SOUND] = "Sound Disabled";
       }
       break;
      case 2:
       Remove_Sound();
       Sound_Options[SOUND_ENABLE_SOUND] = "Sound Disabled";
     }
    }

    if (CursorAt == SOUND_SAMPLE_SIZE)
    {
     sound_bits = sound_bits == 16 ? 8 : 16;
     sprintf(sample_size_str, "Sample size: %2d-bit", sound_bits);

     switch(sound_enabled)
     {
      case 0:
       Sound_Options[SOUND_ENABLE_SOUND] = "Sound Disabled";
       break;

      case 1:
       Remove_Sound();
       if (Install_Sound(0))
       {
        Sound_Options[SOUND_ENABLE_SOUND] = "Sound Enabled (mono)";
       }
       else
       {
        Sound_Options[SOUND_ENABLE_SOUND] = "Sound Disabled";
       }
       break;

      case 2:
       Remove_Sound();
       if (Install_Sound(1))
       {
        Sound_Options[SOUND_ENABLE_SOUND] = "Sound Enabled (stereo)";
       }
       else
       {
        Sound_Options[SOUND_ENABLE_SOUND] = "Sound Disabled";
       }
     }

    }


    if (CursorAt == SOUND_ENABLE_ECHO)
    {
     Sound_Options[SOUND_ENABLE_ECHO] =
      (sound_echo_enabled = !sound_echo_enabled) ?
      "Echo/FIR filter: on" : "Echo/FIR filter: off";
    }


    if (CursorAt == SOUND_ENABLE_GAUSS)
    {
     Sound_Options[SOUND_ENABLE_GAUSS] =
      (sound_gauss_enabled = !sound_gauss_enabled) ?
      "Gaussian filter: on" : "Gaussian filter: off";
    }


    if (CursorAt == SOUND_ENABLE_ENVX)
    {
     Sound_Options[SOUND_ENABLE_ENVX] = (ENVX_ENABLED = !ENVX_ENABLED) ?
      "ENVX reading: on" : "ENVX reading: off";
    }

  }
 }
 return 1;          // Signify normal exit
}

WINDOW *Controls_window=0;

enum {
#if 0
#ifdef ALLEGRO_DOS
 CONTROLS_JOYSTICK_DRIVER,
#endif
#endif
 CONTROLS_CONTROLLER_1,
 CONTROLS_CONTROLLER_2,
 CONTROLS_MAP_1,
 CONTROLS_MAP_2,
 CONTROLS_NUM_OPTIONS
};

const char *Controls_Options[CONTROLS_NUM_OPTIONS]=
{
#if 0
#ifdef ALLEGRO_DOS
 "Joystick: **************",    // joystick driver
#endif
#endif
 "-------- on player 1",        // controls: first player
 "-------- on player 2",        // controls: second player
 "Define keys for player 1",
 "Define keys for player 2"
};

#if 0
const int joydriver_id[] =
{
 JOY_TYPE_NONE,
 JOY_TYPE_STANDARD,
 JOY_TYPE_2PADS,
 JOY_TYPE_4BUTTON,
 JOY_TYPE_6BUTTON,
 JOY_TYPE_8BUTTON,
 JOY_TYPE_FSPRO,
 JOY_TYPE_WINGEX,
 JOY_TYPE_SIDEWINDER,
 JOY_TYPE_SIDEWINDER_AG,
 JOY_TYPE_GAMEPAD_PRO,
 JOY_TYPE_GRIP,
 JOY_TYPE_SNESPAD_LPT1,
 JOY_TYPE_SNESPAD_LPT2,
 JOY_TYPE_SNESPAD_LPT3,
 JOY_TYPE_PSXPAD_LPT1,
 JOY_TYPE_PSXPAD_LPT2,
 JOY_TYPE_PSXPAD_LPT3,
 JOY_TYPE_N64PAD_LPT1,
 JOY_TYPE_N64PAD_LPT2,
 JOY_TYPE_N64PAD_LPT3,
 JOY_TYPE_DB9_LPT1,
 JOY_TYPE_DB9_LPT2,
 JOY_TYPE_DB9_LPT3,
 JOY_TYPE_TURBOGRAFIX_LPT1,
 JOY_TYPE_TURBOGRAFIX_LPT2,
 JOY_TYPE_TURBOGRAFIX_LPT3,
 JOY_TYPE_WINGWARRIOR,
 JOY_TYPE_IFSEGA_ISA,
 JOY_TYPE_IFSEGA_PCI,
 JOY_TYPE_IFSEGA_PCI_FAST,
 JOY_TYPE_AUTODETECT
};


const int joydriver_count = sizeof(joydriver_id) / sizeof(int);

const char *get_joydriver_str(int driver)
{
 switch (driver)
 {
 case JOY_TYPE_NONE: return "None";
 case JOY_TYPE_STANDARD: return "2-button";
 case JOY_TYPE_2PADS: return "two 2-button";
 case JOY_TYPE_4BUTTON: return "4-button";
 case JOY_TYPE_6BUTTON: return "6-button";
 case JOY_TYPE_8BUTTON: return "8-button";
 case JOY_TYPE_FSPRO: return "Flightstick";
 case JOY_TYPE_WINGEX: return "WM Extreme";
 case JOY_TYPE_SIDEWINDER: return "Sidewinder";
 case JOY_TYPE_SIDEWINDER_AG: return "Sidewinder Alt";
 case JOY_TYPE_GAMEPAD_PRO: return "Gravis Pro";
 case JOY_TYPE_GRIP: return "Gravis GrIP";
 case JOY_TYPE_SNESPAD_LPT1: return "SNES pad, LPT1";
 case JOY_TYPE_SNESPAD_LPT2: return "SNES pad, LPT2";
 case JOY_TYPE_SNESPAD_LPT3: return "SNES pad, LPT3";
 case JOY_TYPE_PSXPAD_LPT1: return "PSX pad, LPT1";
 case JOY_TYPE_PSXPAD_LPT2: return "PSX pad, LPT2";
 case JOY_TYPE_PSXPAD_LPT3: return "PSX pad, LPT3";
 case JOY_TYPE_N64PAD_LPT1: return "N64 pad, LPT1";
 case JOY_TYPE_N64PAD_LPT2: return "N64 pad, LPT2";
 case JOY_TYPE_N64PAD_LPT3: return "N64 pad, LPT3";
 case JOY_TYPE_DB9_LPT1: return "DB9stick, LPT1";
 case JOY_TYPE_DB9_LPT2: return "DB9stick, LPT2";
 case JOY_TYPE_DB9_LPT3: return "DB9stick, LPT3";
 case JOY_TYPE_TURBOGRAFIX_LPT1: return "TG16 pad, LPT1";
 case JOY_TYPE_TURBOGRAFIX_LPT2: return "TG16 pad, LPT2";
 case JOY_TYPE_TURBOGRAFIX_LPT3: return "TG16 pad, LPT3";
 case JOY_TYPE_WINGWARRIOR: return "WM Warrior";
 case JOY_TYPE_IFSEGA_ISA: return "IF-SEGA ISA";
 case JOY_TYPE_IFSEGA_PCI: return "IF-SEGA PCI";
 case JOY_TYPE_IFSEGA_PCI_FAST: return "IF-SEGA PCI2";
 case JOY_TYPE_AUTODETECT: return "Autodetect";
 }

 return "";
}
#endif

void UpdateControlsWindow(int Selected)
{
 Controls_window->refresh();
 for(int a=0;a<CONTROLS_NUM_OPTIONS;a++)
  if(a!=Selected) PlotMenuItem(Controls_window,default_font,Controls_Options[a],0,default_font->get_heightspace()*a,24);
  else PlotSelectedMenuItem(Controls_window,default_font,Controls_Options[a],0,default_font->get_heightspace()*a,24);
#ifndef NO_LOGO
 if(sneese)
  stretch_blit(sneese,Allegro_Bitmap,0,0,GUI_ScreenWidth,GUI_ScreenHeight,0,0,SCREEN_W,SCREEN_H);
#endif
 draw_sprite(Allegro_Bitmap, GUI_Bitmap, 0, 0);
 vsync();
 CopyGUIScreen();
}

WINDOW *ControlSetup_window=0;



void UpdateControllerScreen(const SNES_CONTROLLER_INPUTS *input)
{
 char tempch[9];

 ControlSetup_window->refresh();

 scantotext(input->up,tempch);
 PlotStringShadow(ControlSetup_window,default_font,tempch,38,31,15,8);
 scantotext(input->down,tempch);
 PlotStringShadow(ControlSetup_window,default_font,tempch,38,65,15,8);
 scantotext(input->left,tempch);
 PlotStringShadow(ControlSetup_window,default_font,tempch,24,44,15,8);
 scantotext(input->right,tempch);
 PlotStringShadow(ControlSetup_window,default_font,tempch,55,52,15,8);
 scantotext(input->a,tempch);
 PlotStringShadow(ControlSetup_window,default_font,tempch,151,46,15,8);
 scantotext(input->b,tempch);
 PlotStringShadow(ControlSetup_window,default_font,tempch,130,69,15,8);
 scantotext(input->x,tempch);
 PlotStringShadow(ControlSetup_window,default_font,tempch,127,25,15,8);
 scantotext(input->y,tempch);
 PlotStringShadow(ControlSetup_window,default_font,tempch,104,49,15,8);
 scantotext(input->l,tempch);
 PlotStringShadow(ControlSetup_window,default_font,tempch,40,1,15,8);
 scantotext(input->r,tempch);
 PlotStringShadow(ControlSetup_window,default_font,tempch,127,1,15,8);
 scantotext(input->select,tempch);
 PlotStringShadow(ControlSetup_window,default_font,tempch,68,40,15,8);
 scantotext(input->start,tempch);
 PlotStringShadow(ControlSetup_window,default_font,tempch,91,73,15,8);
}

signed char lastkeypress_locked = 0;
void (*lastkeypress_chain)(int scancode);
volatile int last_scancode;
volatile signed char last_scancode_valid;

static void lastkeypress_callback(int scancode)
{
 if (!(scancode & 0x80))
 {
  last_scancode = scancode;
  last_scancode_valid = -1;
 }
 if (lastkeypress_chain) lastkeypress_chain(scancode);
}
END_OF_STATIC_FUNCTION(lastkeypress_callback);

int lastkeypressed()
{
 if (!last_scancode_valid) return update_joystick_vkeys();
 last_scancode_valid = 0;
 return last_scancode;
}

int AskKey(const char *msg, int *whatkey, SNES_CONTROLLER_INPUTS *input)
{
 int tmp;

 if (!lastkeypress_locked)
 {
  LOCK_VARIABLE(lastkeypress_chain);
  LOCK_VARIABLE(last_scancode);
  LOCK_VARIABLE(last_scancode_valid);
  LOCK_FUNCTION((void *)lastkeypress_callback);
  lastkeypress_locked = -1;
 }

 lastkeypress_chain = keyboard_lowlevel_callback;
 keyboard_lowlevel_callback = lastkeypress_callback;

 PlotStringShadow(ControlSetup_window, default_font,
  msg, 84, 96, 15, 8);

#ifndef NO_LOGO
 if(sneese)
  stretch_blit(sneese, Allegro_Bitmap, 0, 0,
   GUI_ScreenWidth, GUI_ScreenHeight, 0, 0, SCREEN_W, SCREEN_H);
#endif
 draw_sprite(Allegro_Bitmap, GUI_Bitmap, 0, 0);
 CopyGUIScreen();

 do tmp = lastkeypressed(); while (!tmp);
 if (keypressed()) readkey(); /* throw away the key */

 keyboard_lowlevel_callback = lastkeypress_chain;

 if(tmp==KEY_ESC) return FALSE;

 *whatkey=tmp;

 UpdateControllerScreen(input);

 return TRUE;
}

void AskControllerInputs(SNES_CONTROLLER_INPUTS *input)
{
 clear_keybuf();
 UpdateControllerScreen(input);

 if (AskKey("Press key for UP", &input->up, input))
  if (AskKey("Press key for DOWN", &input->down, input))
  if (AskKey("Press key for LEFT", &input->left, input))
  if (AskKey("Press key for RIGHT", &input->right, input))
  if (AskKey("Press key for A", &input->a, input))
  if (AskKey("Press key for B", &input->b, input))
  if (AskKey("Press key for X", &input->x, input))
  if (AskKey("Press key for Y", &input->y, input))
  if (AskKey("Press key for L", &input->l, input))
  if (AskKey("Press key for R", &input->r, input))
  if (AskKey("Press key for SELECT", &input->select, input))
  if (AskKey("Press key for START", &input->start, input))
 {
  PlotStringShadow(ControlSetup_window,default_font,"Press ESC to exit",84,96,15,8);
#ifndef NO_LOGO
  if(sneese)
   stretch_blit(sneese,Allegro_Bitmap,0,0,GUI_ScreenWidth,GUI_ScreenHeight,0,0,SCREEN_W,SCREEN_H);
#endif
  draw_sprite(Allegro_Bitmap, GUI_Bitmap, 0, 0);
  CopyGUIScreen();

  for (;;)
  {
   while (!keypressed());
   if ((readkey() >> 8) == KEY_ESC) break;
  }
 }

 UpdateGUI(MAIN_CONFIGURE);
}

int ControlsWindow()
{
//int temp;

 switch(CONTROLLER_1_TYPE)
 {
  case 1:
   if (mouse_available)
   {
    Controls_Options[CONTROLS_CONTROLLER_1] = "Mouse on player 1";
    break;
   }
  default:
   Controls_Options[CONTROLS_CONTROLLER_1] = "Joypad on player 1";
   CONTROLLER_1_TYPE=0;
 }

 switch(CONTROLLER_2_TYPE)
 {
  case 1:
   if (mouse_available)
   {
    Controls_Options[CONTROLS_CONTROLLER_2] = "Mouse on player 2";
    break;
   }
  default:
   Controls_Options[CONTROLS_CONTROLLER_2] = "Joypad on player 2";
   CONTROLLER_2_TYPE=0;
 }

 int CursorAt=0;
 int keypress, key_asc, key_scan;
 clear_keybuf();

 for(;;)
 {
  UpdateControlsWindow(CursorAt);
  while (!keypressed());
  keypress = readkey();
  key_asc = keypress & 0xFF;
  key_scan = keypress >> 8;

  switch (key_scan)
  {
   case KEY_UP:
    CursorAt--;
    if(CursorAt == -1) // so it wraps
     CursorAt = CONTROLS_NUM_OPTIONS-1;
    break;
   case KEY_DOWN:
    CursorAt++;
    if(CursorAt == CONTROLS_NUM_OPTIONS) // so it wraps
    CursorAt=0;
    break;

   case KEY_ESC:
    return -1;

   case KEY_ENTER:
   case KEY_ENTER_PAD:

    if (CursorAt == CONTROLS_CONTROLLER_1)
    {
     switch(++CONTROLLER_1_TYPE)
     {
      case 1:
       if (mouse_available)
       {
        Controls_Options[CONTROLS_CONTROLLER_1] = "Mouse on player 1";
        break;
       }
      default:
       Controls_Options[CONTROLS_CONTROLLER_1] = "Joypad on player 1";
       CONTROLLER_1_TYPE=0;
     }
    break;
    }

    if (CursorAt == CONTROLS_CONTROLLER_2)
    {
     switch(++CONTROLLER_2_TYPE)
     {
      case 1:
       if (mouse_available)
       {
        Controls_Options[CONTROLS_CONTROLLER_2] = "Mouse on player 2";
        break;
       }
      default:
       Controls_Options[CONTROLS_CONTROLLER_2] = "Joypad on player 2";
       CONTROLLER_2_TYPE=0;
     }
     break;
    }

    if (CursorAt == CONTROLS_MAP_1)
    {
     AskControllerInputs(&input_player1);
     break;
    }

    if (CursorAt == CONTROLS_MAP_2)
    {
     AskControllerInputs(&input_player2);
     break;
    }

  }
 }
 return 1;          // Signify normal exit
}


char min_frameskip_str[] = "Min Frameskip: ???????";
char max_frameskip_str[] = "Max Frameskip: ???????";

WINDOW *Config_window=0;

char fps_counter_str[] = "FPS counter: off";
char stretch_h_str[] = "H stretch: full";
char stretch_v_str[] = "V stretch: full";

enum {
 CONFIG_SCREEN_MODE,
 CONFIG_CONTROLLERS,
 CONFIG_SOUND,
 CONFIG_ENABLE_SPC,
 CONFIG_STRETCH_H,
 CONFIG_STRETCH_V,
 CONFIG_FRAMESKIP_MIN,
 CONFIG_FRAMESKIP_MAX,
 CONFIG_ENABLE_FPS_COUNTER,
 CONFIG_NUM_OPTIONS
};

const char *Config_Options[CONFIG_NUM_OPTIONS]={
 0,                             // screen mode
 "Configure controllers",       // controller configuration menu
 "Configure sound",
 0,                             // SPC enable setting
 stretch_h_str,                 // screen stretch settings
 stretch_v_str,
 min_frameskip_str,
 max_frameskip_str,
 fps_counter_str
};


void UpdateConfigWindow(int Selected)
{
 Config_window->refresh();
 for(int a=0;a<CONFIG_NUM_OPTIONS;a++)
  if(a!=Selected) PlotMenuItem(Config_window,default_font,Config_Options[a],0,default_font->get_heightspace()*a,24);
  else PlotSelectedMenuItem(Config_window,default_font,Config_Options[a],0,default_font->get_heightspace()*a,24);
#ifndef NO_LOGO
 if(sneese)
  stretch_blit(sneese,Allegro_Bitmap,0,0,GUI_ScreenWidth,GUI_ScreenHeight,0,0,SCREEN_W,SCREEN_H);
#endif
 draw_sprite(Allegro_Bitmap, GUI_Bitmap, 0, 0);
 vsync();
 CopyGUIScreen();
}

int ConfigWindow()
{
 int temp;

 Config_Options[CONFIG_SCREEN_MODE] = Screen_Options[SCREEN_MODE];

 if(SPC_ENABLED) Config_Options[CONFIG_ENABLE_SPC] = "Emulate SPC";
 else Config_Options[CONFIG_ENABLE_SPC] = "Skip SPC";

 switch (stretch_x)
 {
  case 0:
   strcpy(stretch_h_str, "H stretch: off");
   break;
  case 1:
   strcpy(stretch_h_str, "H stretch: full");
   break;
  default:
   sprintf(stretch_h_str, "H stretch: %d", stretch_x);
   break;
 }

 switch (stretch_y)
 {
  case 0:
   strcpy(stretch_v_str, "V stretch: off");
   break;
  case 1:
   strcpy(stretch_v_str, "V stretch: full");
   break;
  default:
   sprintf(stretch_v_str, "V stretch: %d", stretch_y);
   break;
 }

 if (FPS_ENABLED) sprintf(fps_counter_str, "FPS counter: on");
 else sprintf(fps_counter_str, "FPS counter: off");

 sprintf(min_frameskip_str, "Min Frameskip: %-2d", FRAME_SKIP_MIN);
 sprintf(max_frameskip_str, "Max Frameskip: %-2d", FRAME_SKIP_MAX);

 int CursorAt=0;
 int keypress, key_asc, key_scan;
 clear_keybuf();

 for(;;)
 {
  UpdateConfigWindow(CursorAt);
  while (!keypressed());
  keypress = readkey();
  key_asc = keypress & 0xFF;
  key_scan = keypress >> 8;

  switch (key_scan)
  {
   case KEY_UP:
    CursorAt--;
    if(CursorAt == -1) // so it wraps
     CursorAt = CONFIG_NUM_OPTIONS-1;
    break;
   case KEY_DOWN:
    CursorAt++;
    if(CursorAt == CONFIG_NUM_OPTIONS) // so it wraps
    CursorAt=0;
    break;

  // For frameskip!
   case KEY_LEFT:
    if (CursorAt == CONFIG_STRETCH_H && stretch_x > 0)
    {
     stretch_x--;

     switch (stretch_x)
     {
      case 0:
       strcpy(stretch_h_str, "H stretch: off");
       break;
      case 1:
       strcpy(stretch_h_str, "H stretch: full");
       break;
      default:
       sprintf(stretch_h_str, "H stretch: %d", stretch_x);
       break;
     }
    }

    if (CursorAt == CONFIG_STRETCH_V && stretch_y > 0)
    {
     stretch_y--;

     switch (stretch_y)
     {
      case 0:
       strcpy(stretch_v_str, "V stretch: off");
       break;
      case 1:
       strcpy(stretch_v_str, "V stretch: full");
       break;
      default:
       sprintf(stretch_v_str, "V stretch: %d", stretch_y);
       break;
     }
    }

    if (CursorAt == CONFIG_FRAMESKIP_MIN && FRAME_SKIP_MIN > 0)
    {
     // 60,30,20,15,10-0
     if(FRAME_SKIP_MIN>30) FRAME_SKIP_MIN-=30;
     else if(FRAME_SKIP_MIN>20) FRAME_SKIP_MIN-=10;
     else if(FRAME_SKIP_MIN>10) FRAME_SKIP_MIN-=5;
     else FRAME_SKIP_MIN--;

     if(FRAME_SKIP_MIN>FRAME_SKIP_MAX)
     {
      FRAME_SKIP_MAX=FRAME_SKIP_MIN;
      sprintf(max_frameskip_str, "Max Frameskip: %-2d", FRAME_SKIP_MAX);
     }
     sprintf(min_frameskip_str, "Min Frameskip: %-2d", FRAME_SKIP_MIN);
     break;
    }

    if (CursorAt == CONFIG_FRAMESKIP_MAX && FRAME_SKIP_MAX > 1)
    {
     // 60,30,20,15,10-0
     if(FRAME_SKIP_MAX>30) FRAME_SKIP_MAX-=30;
     else if(FRAME_SKIP_MAX>20) FRAME_SKIP_MAX-=10;
     else if(FRAME_SKIP_MAX>10) FRAME_SKIP_MAX-=5;
     else FRAME_SKIP_MAX--;

     if(FRAME_SKIP_MAX<FRAME_SKIP_MIN)
     {
      FRAME_SKIP_MIN=FRAME_SKIP_MAX;
      sprintf(min_frameskip_str, "Min Frameskip: %-2d", FRAME_SKIP_MIN);
     }
     sprintf(max_frameskip_str, "Max Frameskip: %-2d", FRAME_SKIP_MAX);
     break;
    }

    break;

   case KEY_RIGHT:
    if (CursorAt == CONFIG_STRETCH_H && stretch_x < 16)
    {
     stretch_x++;

     switch (stretch_x)
     {
      case 0:
       strcpy(stretch_h_str, "H stretch: off");
       break;
      case 1:
       strcpy(stretch_h_str, "H stretch: full");
       break;
      default:
       sprintf(stretch_h_str, "H stretch: %d", stretch_x);
       break;
     }
    }

    if (CursorAt == CONFIG_STRETCH_V && stretch_y < 16)
    {
     stretch_y++;

     switch (stretch_y)
     {
      case 0:
       strcpy(stretch_v_str, "V stretch: off");
       break;
      case 1:
       strcpy(stretch_v_str, "V stretch: full");
       break;
      default:
       sprintf(stretch_v_str, "V stretch: %d", stretch_y);
       break;
     }
    }

    if (CursorAt == CONFIG_FRAMESKIP_MIN && FRAME_SKIP_MIN < 60)
    {
     // 0-10,15,20,30,60
     if(FRAME_SKIP_MIN<10) FRAME_SKIP_MIN++;
     else if(FRAME_SKIP_MIN<20) FRAME_SKIP_MIN+=5;
     else if(FRAME_SKIP_MIN<30) FRAME_SKIP_MIN+=10;
     else FRAME_SKIP_MIN+=30;

     if(FRAME_SKIP_MIN>FRAME_SKIP_MAX)
     {
      FRAME_SKIP_MAX=FRAME_SKIP_MIN;
      sprintf(max_frameskip_str, "Max Frameskip: %-2d", FRAME_SKIP_MAX);
     }
     sprintf(min_frameskip_str, "Min Frameskip: %-2d", FRAME_SKIP_MIN);
     break;
    }

    if (CursorAt == CONFIG_FRAMESKIP_MAX && FRAME_SKIP_MAX < 60)
    {
     // 0-10,15,20,30,60
     if(FRAME_SKIP_MAX<10) FRAME_SKIP_MAX++;
     else if(FRAME_SKIP_MAX<20) FRAME_SKIP_MAX+=5;
     else if(FRAME_SKIP_MAX<30) FRAME_SKIP_MAX+=10;
     else FRAME_SKIP_MAX+=30;

     if(FRAME_SKIP_MAX<FRAME_SKIP_MIN)
     {
      FRAME_SKIP_MIN=FRAME_SKIP_MAX;
      sprintf(min_frameskip_str, "Min Frameskip: %-2d", FRAME_SKIP_MIN);
     }
     sprintf(max_frameskip_str, "Max Frameskip: %-2d", FRAME_SKIP_MAX);
     break;
    }

    break;

   case KEY_ESC:
    return -1;

   case KEY_ENTER:
   case KEY_ENTER_PAD:
    if (CursorAt == CONFIG_SCREEN_MODE)
    {
     while((temp = ScreenWindow()) != -1)
     {
      // Setup screen mode (SCREEN_MODE is set here so following works)
      SetGUIScreen(temp);

      Config_Options[CONFIG_SCREEN_MODE] = Screen_Options[SCREEN_MODE];
#ifndef NO_LOGO
      if(sneese)   // Prevent a crash if file not found!
      {
       set_palette(sneesepal);
       stretch_blit(sneese,Allegro_Bitmap,0,0,GUI_ScreenWidth,GUI_ScreenHeight,0,0,SCREEN_W,SCREEN_H);
      }
#endif
      set_palette_range(&GUIPal[-240],240,255,1);    // Set the GUI palette up.
     }
     UpdateGUI(MAIN_CONFIGURE);
     break;
    }

    if (CursorAt == CONFIG_CONTROLLERS)
    {
     while((temp = ControlsWindow()) != -1)
     {
#ifndef NO_LOGO
      if(sneese)   // Prevent a crash if file not found!
      {
       set_palette(sneesepal);
       stretch_blit(sneese,Allegro_Bitmap,0,0,GUI_ScreenWidth,GUI_ScreenHeight,0,0,SCREEN_W,SCREEN_H);
      }
#endif
      set_palette_range(&GUIPal[-240],240,255,1);    // Set the GUI palette up.
     }
     UpdateGUI(MAIN_CONFIGURE);
     break;
    }

    if (CursorAt == CONFIG_ENABLE_SPC)
    {
     if (SPC_ENABLED)
     {
      Config_Options[CONFIG_ENABLE_SPC] = "Skip SPC";
      SPC_ENABLED = 0;
     } else {
      Config_Options[CONFIG_ENABLE_SPC] = "Emulate SPC";
      SPC_ENABLED = 1;
     }
    }

    if (CursorAt == CONFIG_SOUND)
    {
     while((temp = SoundWindow()) != -1)
     {
#ifndef NO_LOGO
      if(sneese)   // Prevent a crash if file not found!
      {
       set_palette(sneesepal);
       stretch_blit(sneese,Allegro_Bitmap,0,0,GUI_ScreenWidth,GUI_ScreenHeight,0,0,SCREEN_W,SCREEN_H);
      }
#endif
      set_palette_range(&GUIPal[-240],240,255,1);    // Set the GUI palette up.
     }
     UpdateGUI(MAIN_CONFIGURE);
     break;
    }

    if (CursorAt == CONFIG_ENABLE_FPS_COUNTER)
    {
     sprintf(fps_counter_str, (FPS_ENABLED = !FPS_ENABLED) ?
      "FPS counter: on" : "FPS counter: off");
    }

  }
 }
 return 1;          // Signify normal exit
}

WINDOW *ROMInfo_window=0;

void RomInfo(void)
{
 char drive[MAXDRIVE], dir[MAXDIR], file[MAXFILE], ext[MAXEXT];

 ROMInfo_window->refresh();

 // Don't display the full path to the file, it might not fit in the (small) window
 fnsplit(rom_romfile,drive,dir,file,ext);
 if (strlen(ext))
  strcat(file,ext);

 PlotString(ROMInfo_window,default_font,"File name: ",0,0);
 PlotString(ROMInfo_window,default_font,file,default_font->get_widthspace()*11,0);

 PlotString(ROMInfo_window,default_font,"ROM title: ",0,default_font->get_heightspace());
 PlotString(ROMInfo_window,default_font,rom_romname,default_font->get_widthspace()*11,default_font->get_heightspace());

 PlotString(ROMInfo_window,default_font,"ROM type: ",0,default_font->get_heightspace()*2);
 PlotString(ROMInfo_window,default_font,rom_romtype,default_font->get_widthspace()*10,default_font->get_heightspace()*2);

 PlotString(ROMInfo_window,default_font,rom_romhilo,0,default_font->get_heightspace()*3);

 PlotString(ROMInfo_window,default_font,"ROM size: ",0,default_font->get_heightspace()*4);
 PlotString(ROMInfo_window,default_font,rom_romsize,default_font->get_widthspace()*10,default_font->get_heightspace()*4);

 PlotString(ROMInfo_window,default_font,"SRAM size: ",0,default_font->get_heightspace()*5);
 PlotString(ROMInfo_window,default_font,rom_sram,default_font->get_widthspace()*11,default_font->get_heightspace()*5);

 PlotString(ROMInfo_window,default_font,"Country: ",0,default_font->get_heightspace()*6);
 PlotString(ROMInfo_window,default_font,rom_country,default_font->get_widthspace()*9,default_font->get_heightspace()*6);

#ifndef NO_LOGO
 if(sneese)
  stretch_blit(sneese,Allegro_Bitmap,0,0,GUI_ScreenWidth,GUI_ScreenHeight,0,0,SCREEN_W,SCREEN_H);
#endif
 draw_sprite(Allegro_Bitmap, GUI_Bitmap, 0, 0);
 vsync();
 CopyGUIScreen();

 for (;;)
 {
  while (!keypressed());
  if ((readkey() >> 8) == KEY_ESC) break;
 }
}

extern "C" unsigned char BGMODE,VMAIN,OBSEL,HiSprite;
extern "C" unsigned char W12SEL,W34SEL,WOBJSEL,WH0,WH1,WH2,WH3;
extern "C" unsigned char TM,TS,TMW,TSW,WBGLOG,WOBJLOG,CGWSEL,CGADSUB;

WINDOW *HWStatus_window=0;

EXTERN unsigned char Win1_Count_In, Win1_Count_Out;
EXTERN unsigned char Win2_Count_In, Win2_Count_Out;
EXTERN unsigned char Win1_Bands_In[2], Win1_Bands_Out[4];
EXTERN unsigned char Win2_Bands_In[2], Win2_Bands_Out[4];

void HWStatus(void)
{
 char Number[5];

 HWStatus_window->refresh();
 PlotString(HWStatus_window,default_font,"65c816 A:#### X:#### Y:#### DB:##",0,0);
 sprintf(Number, "%04X", cpu_65c816_A);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*9,0);
 sprintf(Number, "%04X", cpu_65c816_X);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*16,0);
 sprintf(Number, "%04X", cpu_65c816_Y);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*23,0);
 sprintf(Number, "%02X", (unsigned) cpu_65c816_DB);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*31,0);
 PlotString(HWStatus_window,default_font,"PB:## PC:#### S:#### D:#### P:###",0,default_font->get_heightspace());
 sprintf(Number, "%02X", (unsigned) cpu_65c816_PB);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*3,default_font->get_heightspace());
 sprintf(Number, "%04X", cpu_65c816_PC);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*9,default_font->get_heightspace());
 sprintf(Number, "%04X", cpu_65c816_S);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*16,default_font->get_heightspace());
 sprintf(Number, "%04X", cpu_65c816_D);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*23,default_font->get_heightspace());
// sprintf(Number, "%03X", cpu_65c816_P&0x1FF);
// PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*30,default_font->get_heightspace());
 PlotString(HWStatus_window,default_font,"OLD_PB:## OLD_PC:#### OBSEL:## ##",0,default_font->get_heightspace()*2);
 sprintf(Number, "%02X", (unsigned) OLD_PB);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*7,default_font->get_heightspace()*2);
 sprintf(Number, "%04X", OLD_PC);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*17,default_font->get_heightspace()*2);
 sprintf(Number, "%02X",(unsigned) OBSEL);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*28,default_font->get_heightspace()*2);
 sprintf(Number, "%02X",(unsigned) HiSprite);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*31,default_font->get_heightspace()*2);

 PlotString(HWStatus_window,default_font,"BGMODE:## VMAIN:## TM:## TS:##",0,default_font->get_heightspace()*3);
 sprintf(Number, "%02X", (unsigned) BGMODE);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*7,default_font->get_heightspace()*3);
 sprintf(Number, "%02X", (unsigned) VMAIN);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*16,default_font->get_heightspace()*3);
 sprintf(Number, "%02X", (unsigned) TM);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*22,default_font->get_heightspace()*3);
 sprintf(Number, "%02X", (unsigned) TS);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*28,default_font->get_heightspace()*3);
 PlotString(HWStatus_window,default_font,"WH0: ## WH1: ## WH2: ## WH3: ##",0,default_font->get_heightspace()*4);
 sprintf(Number, "%02X", (unsigned) WH0);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*5,default_font->get_heightspace()*4);
 sprintf(Number, "%02X", (unsigned) WH1);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*13,default_font->get_heightspace()*4);
 sprintf(Number, "%02X", (unsigned) WH2);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*21,default_font->get_heightspace()*4);
 sprintf(Number, "%02X", (unsigned) WH3);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*29,default_font->get_heightspace()*4);
 PlotString(HWStatus_window,default_font,"TMW: ## TSW: ## WSEL: ## ## ##",0,default_font->get_heightspace()*5);
 sprintf(Number, "%02X", (unsigned) TMW);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*5,default_font->get_heightspace()*5);
 sprintf(Number, "%02X", (unsigned) TSW);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*13,default_font->get_heightspace()*5);
 sprintf(Number, "%02X", (unsigned) W12SEL);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*22,default_font->get_heightspace()*5);
 sprintf(Number, "%02X", (unsigned) W34SEL);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*25,default_font->get_heightspace()*5);
 sprintf(Number, "%02X", (unsigned) WOBJSEL);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*28,default_font->get_heightspace()*5);

 PlotString(HWStatus_window,default_font,"WLOG:## ## CGWSEL:## CGADSUB:##",0,default_font->get_heightspace()*6);
 sprintf(Number, "%02X", (unsigned) WBGLOG);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*5,default_font->get_heightspace()*6);
 sprintf(Number, "%02X", (unsigned) WOBJLOG);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*8,default_font->get_heightspace()*6);
 sprintf(Number, "%02X", (unsigned) CGWSEL);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*18,default_font->get_heightspace()*6);
 sprintf(Number, "%02X", (unsigned) CGADSUB);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*29,default_font->get_heightspace()*6);

 PlotString(HWStatus_window,default_font,"Win1:# ## ## # ## ## ## ##",0,default_font->get_heightspace()*7);
 sprintf(Number, "%1X", (unsigned) Win1_Count_In);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*5,default_font->get_heightspace()*7);
 sprintf(Number, "%02X", (unsigned) Win1_Bands_In[0]);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*7,default_font->get_heightspace()*7);
 sprintf(Number, "%02X", (unsigned) Win1_Bands_In[1]);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*10,default_font->get_heightspace()*7);
 sprintf(Number, "%1X", (unsigned) Win1_Count_Out);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*13,default_font->get_heightspace()*7);
 sprintf(Number, "%02X", (unsigned) Win1_Bands_Out[0]);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*15,default_font->get_heightspace()*7);
 sprintf(Number, "%02X", (unsigned) Win1_Bands_Out[1]);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*18,default_font->get_heightspace()*7);
 sprintf(Number, "%02X", (unsigned) Win1_Bands_Out[2]);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*21,default_font->get_heightspace()*7);
 sprintf(Number, "%02X", (unsigned) Win1_Bands_Out[3]);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*24,default_font->get_heightspace()*7);

 PlotString(HWStatus_window,default_font,"Win2:# ## ## # ## ## ## ##",0,default_font->get_heightspace()*8);
 sprintf(Number, "%1X", (unsigned) Win2_Count_In);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*5,default_font->get_heightspace()*8);
 sprintf(Number, "%02X", (unsigned) Win2_Bands_In[0]);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*7,default_font->get_heightspace()*8);
 sprintf(Number, "%02X", (unsigned) Win2_Bands_In[1]);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*10,default_font->get_heightspace()*8);
 sprintf(Number, "%1X", (unsigned) Win2_Count_Out);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*13,default_font->get_heightspace()*8);
 sprintf(Number, "%02X", (unsigned) Win2_Bands_Out[0]);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*15,default_font->get_heightspace()*8);
 sprintf(Number, "%02X", (unsigned) Win2_Bands_Out[1]);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*18,default_font->get_heightspace()*8);
 sprintf(Number, "%02X", (unsigned) Win2_Bands_Out[2]);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*21,default_font->get_heightspace()*8);
 sprintf(Number, "%02X", (unsigned) Win2_Bands_Out[3]);
 PlotString(HWStatus_window,default_font,Number,default_font->get_widthspace()*24,default_font->get_heightspace()*8);

#ifndef NO_LOGO
 if(sneese)
  stretch_blit(sneese,Allegro_Bitmap,0,0,GUI_ScreenWidth,GUI_ScreenHeight,0,0,SCREEN_W,SCREEN_H);
#endif
 draw_sprite(Allegro_Bitmap, GUI_Bitmap, 0, 0);
 vsync();
 CopyGUIScreen();

 for (;;)
 {
  while (!keypressed());
  if ((readkey() >> 8) == KEY_ESC) break;
 }
}

extern "C" unsigned char MDMAEN;
extern "C" unsigned char HDMAEN;
extern "C" unsigned char DMAP_0, DMAP_1, DMAP_2, DMAP_3;
extern "C" unsigned char DMAP_4, DMAP_5, DMAP_6, DMAP_7;
extern "C" unsigned char BBAD_0, BBAD_1, BBAD_2, BBAD_3;
extern "C" unsigned char BBAD_4, BBAD_5, BBAD_6, BBAD_7;
extern "C" unsigned char A1TL_0, A1TL_1, A1TL_2, A1TL_3;
extern "C" unsigned char A1TL_4, A1TL_5, A1TL_6, A1TL_7;
extern "C" unsigned char A1TH_0, A1TH_1, A1TH_2, A1TH_3;
extern "C" unsigned char A1TH_4, A1TH_5, A1TH_6, A1TH_7;
extern "C" unsigned char A1B_0, A1B_1, A1B_2, A1B_3;
extern "C" unsigned char A1B_4, A1B_5, A1B_6, A1B_7;
extern "C" unsigned char DASL_0, DASL_1, DASL_2, DASL_3;
extern "C" unsigned char DASL_4, DASL_5, DASL_6, DASL_7;
extern "C" unsigned char DASH_0, DASH_1, DASH_2, DASH_3;
extern "C" unsigned char DASH_4, DASH_5, DASH_6, DASH_7;
extern "C" unsigned char DASB_0, DASB_1, DASB_2, DASB_3;
extern "C" unsigned char DASB_4, DASB_5, DASB_6, DASB_7;
extern "C" unsigned char A2L_0, A2L_1, A2L_2, A2L_3;
extern "C" unsigned char A2L_4, A2L_5, A2L_6, A2L_7;
extern "C" unsigned char A2H_0, A2H_1, A2H_2, A2H_3;
extern "C" unsigned char A2H_4, A2H_5, A2H_6, A2H_7;
extern "C" unsigned char A2B_0, A2B_1, A2B_2, A2B_3;
extern "C" unsigned char A2B_4, A2B_5, A2B_6, A2B_7;

WINDOW *DMAStatus_window=0;

void DMAStatus(void)
{
 char Line[34];

 DMAStatus_window->refresh();
 sprintf(Line,"MDMAEN:%02X HDMAEN:%02X",
  (unsigned) MDMAEN, (unsigned) HDMAEN);
 PlotString(DMAStatus_window,default_font,Line,0,0);

 sprintf(Line,"%02X %02X %02X%02X%02X %02X%02X%02X %02X%02X%02X",
 (unsigned) DMAP_0,(unsigned) BBAD_0,
 (unsigned) A1B_0,(unsigned) A1TH_0,(unsigned) A1TL_0,
 (unsigned) A2B_0,(unsigned) A2H_0,(unsigned) A2L_0,
 (unsigned) DASB_0,(unsigned) DASH_0,(unsigned) DASL_0);
 PlotString(DMAStatus_window,default_font,Line,0,default_font->get_heightspace());

 sprintf(Line,"%02X %02X %02X%02X%02X %02X%02X%02X %02X%02X%02X",
 (unsigned) DMAP_1,(unsigned) BBAD_1,
 (unsigned) A1B_1,(unsigned) A1TH_1,(unsigned) A1TL_1,
 (unsigned) A2B_1,(unsigned) A2H_1,(unsigned) A2L_1,
 (unsigned) DASB_1,(unsigned) DASH_1,(unsigned) DASL_1);
 PlotString(DMAStatus_window,default_font,Line,0,default_font->get_heightspace()*2);

 sprintf(Line,"%02X %02X %02X%02X%02X %02X%02X%02X %02X%02X%02X",
 (unsigned) DMAP_2,(unsigned) BBAD_2,
 (unsigned) A1B_2,(unsigned) A1TH_2,(unsigned) A1TL_2,
 (unsigned) A2B_2,(unsigned) A2H_2,(unsigned) A2L_2,
 (unsigned) DASB_2,(unsigned) DASH_2,(unsigned) DASL_2);
 PlotString(DMAStatus_window,default_font,Line,0,default_font->get_heightspace()*3);

 sprintf(Line,"%02X %02X %02X%02X%02X %02X%02X%02X %02X%02X%02X",
 (unsigned) DMAP_3,(unsigned) BBAD_3,
 (unsigned) A1B_3,(unsigned) A1TH_3,(unsigned) A1TL_3,
 (unsigned) A2B_3,(unsigned) A2H_3,(unsigned) A2L_3,
 (unsigned) DASB_3,(unsigned) DASH_3,(unsigned) DASL_3);
 PlotString(DMAStatus_window,default_font,Line,0,default_font->get_heightspace()*4);

 sprintf(Line,"%02X %02X %02X%02X%02X %02X%02X%02X %02X%02X%02X",
 (unsigned) DMAP_4,(unsigned) BBAD_4,
 (unsigned) A1B_4,(unsigned) A1TH_4,(unsigned) A1TL_4,
 (unsigned) A2B_4,(unsigned) A2H_4,(unsigned) A2L_4,
 (unsigned) DASB_4,(unsigned) DASH_4,(unsigned) DASL_4);
 PlotString(DMAStatus_window,default_font,Line,0,default_font->get_heightspace()*5);

 sprintf(Line,"%02X %02X %02X%02X%02X %02X%02X%02X %02X%02X%02X",
 (unsigned) DMAP_5,(unsigned) BBAD_5,
 (unsigned) A1B_5,(unsigned) A1TH_5,(unsigned) A1TL_5,
 (unsigned) A2B_5,(unsigned) A2H_5,(unsigned) A2L_5,
 (unsigned) DASB_5,(unsigned) DASH_5,(unsigned) DASL_5);
 PlotString(DMAStatus_window,default_font,Line,0,default_font->get_heightspace()*6);

 sprintf(Line,"%02X %02X %02X%02X%02X %02X%02X%02X %02X%02X%02X",
 (unsigned) DMAP_6,(unsigned) BBAD_6,
 (unsigned) A1B_6,(unsigned) A1TH_6,(unsigned) A1TL_6,
 (unsigned) A2B_6,(unsigned) A2H_6,(unsigned) A2L_6,
 (unsigned) DASB_6,(unsigned) DASH_6,(unsigned) DASL_6);
 PlotString(DMAStatus_window,default_font,Line,0,default_font->get_heightspace()*7);

 sprintf(Line,"%02X %02X %02X%02X%02X %02X%02X%02X %02X%02X%02X",
 (unsigned) DMAP_7,(unsigned) BBAD_7,
 (unsigned) A1B_7,(unsigned) A1TH_7,(unsigned) A1TL_7,
 (unsigned) A2B_7,(unsigned) A2H_7,(unsigned) A2L_7,
 (unsigned) DASB_7,(unsigned) DASH_7,(unsigned) DASL_7);
 PlotString(DMAStatus_window,default_font,Line,0,default_font->get_heightspace()*8);

#ifndef NO_LOGO
 if(sneese)
  stretch_blit(sneese,Allegro_Bitmap,0,0,GUI_ScreenWidth,GUI_ScreenHeight,0,0,SCREEN_W,SCREEN_H);
#endif
 draw_sprite(Allegro_Bitmap, GUI_Bitmap, 0, 0);
 vsync();
 CopyGUIScreen();

 for (;;)
 {
  while (!keypressed());
  if ((readkey() >> 8) == KEY_ESC) break;
 }
}

WINDOW *APUStatus_window=0;

void APUStatus(void)
{
 char Line[34];
 int v,i;

 APUStatus_window->refresh();
 sprintf(Line,"SNDkeys:%02X", (unsigned) SNDkeys);
 PlotString(APUStatus_window,default_font,Line,0,0);

 for (v = 0; v < 8; v++)
 {
  for (i = 0; i < 16; i++)
  {
   sprintf(Line,"%02X", (unsigned) SPC_DSP[i + (v << 4)]);
   PlotString(APUStatus_window,default_font,Line,
   i * 3 * default_font->get_widthspace(),
   (v + 1) * default_font->get_heightspace());
  }
 }

#ifndef NO_LOGO
 if(sneese)
  stretch_blit(sneese,Allegro_Bitmap,0,0,GUI_ScreenWidth,GUI_ScreenHeight,0,0,SCREEN_W,SCREEN_H);
#endif
 draw_sprite(Allegro_Bitmap, GUI_Bitmap, 0, 0);
 vsync();
 CopyGUIScreen();

 for (;;)
 {
  while (!keypressed());
  if ((readkey() >> 8) == KEY_ESC) break;
 }
}

extern unsigned char WinBG1_Main_Count, WinBG1_Main_Bands[6];
extern unsigned char WinBG1_Sub_Count, WinBG1_Sub_Bands[6];
extern unsigned char WinBG2_Main_Count, WinBG2_Main_Bands[6];
extern unsigned char WinBG2_Sub_Count, WinBG2_Sub_Bands[6];
extern unsigned char WinBG3_Main_Count, WinBG3_Main_Bands[6];
extern unsigned char WinBG3_Sub_Count, WinBG3_Sub_Bands[6];
extern unsigned char WinBG4_Main_Count, WinBG4_Main_Bands[6];
extern unsigned char WinBG4_Sub_Count, WinBG4_Sub_Bands[6];

WINDOW *BGWinStatus_window=0;

void BGWinStatus(void)
{
 char Line[34];

 BGWinStatus_window->refresh();
 sprintf(Line,"BG1M: %02X: %02X %02X %02X %02X %02X %02X",
  (unsigned) WinBG1_Main_Count,
  (unsigned) WinBG1_Main_Bands[0],
  (unsigned) WinBG1_Main_Bands[1],
  (unsigned) WinBG1_Main_Bands[2],
  (unsigned) WinBG1_Main_Bands[3],
  (unsigned) WinBG1_Main_Bands[4],
  (unsigned) WinBG1_Main_Bands[5]);
 PlotString(BGWinStatus_window,default_font,Line,0,0);

 sprintf(Line,"BG1S: %02X: %02X %02X %02X %02X %02X %02X",
  (unsigned) WinBG1_Sub_Count,
  (unsigned) WinBG1_Sub_Bands[0],
  (unsigned) WinBG1_Sub_Bands[1],
  (unsigned) WinBG1_Sub_Bands[2],
  (unsigned) WinBG1_Sub_Bands[3],
  (unsigned) WinBG1_Sub_Bands[4],
  (unsigned) WinBG1_Sub_Bands[5]);
 PlotString(BGWinStatus_window,default_font,Line,
  0, default_font->get_heightspace());

 sprintf(Line,"BG2M: %02X: %02X %02X %02X %02X %02X %02X",
  (unsigned) WinBG2_Main_Count,
  (unsigned) WinBG2_Main_Bands[0],
  (unsigned) WinBG2_Main_Bands[1],
  (unsigned) WinBG2_Main_Bands[2],
  (unsigned) WinBG2_Main_Bands[3],
  (unsigned) WinBG2_Main_Bands[4],
  (unsigned) WinBG2_Main_Bands[5]);
 PlotString(BGWinStatus_window,default_font,Line,
  0, 2 * default_font->get_heightspace());

 sprintf(Line,"BG2S: %02X: %02X %02X %02X %02X %02X %02X",
  (unsigned) WinBG2_Sub_Count,
  (unsigned) WinBG2_Sub_Bands[0],
  (unsigned) WinBG2_Sub_Bands[1],
  (unsigned) WinBG2_Sub_Bands[2],
  (unsigned) WinBG2_Sub_Bands[3],
  (unsigned) WinBG2_Sub_Bands[4],
  (unsigned) WinBG2_Sub_Bands[5]);
 PlotString(BGWinStatus_window,default_font,Line,
  0, 3 * default_font->get_heightspace());

 sprintf(Line,"BG3M: %02X: %02X %02X %02X %02X %02X %02X",
  (unsigned) WinBG3_Main_Count,
  (unsigned) WinBG3_Main_Bands[0],
  (unsigned) WinBG3_Main_Bands[1],
  (unsigned) WinBG3_Main_Bands[2],
  (unsigned) WinBG3_Main_Bands[3],
  (unsigned) WinBG3_Main_Bands[4],
  (unsigned) WinBG3_Main_Bands[5]);
 PlotString(BGWinStatus_window,default_font,Line,
  0, 4 * default_font->get_heightspace());

 sprintf(Line,"BG3S: %02X: %02X %02X %02X %02X %02X %02X",
  (unsigned) WinBG3_Sub_Count,
  (unsigned) WinBG3_Sub_Bands[0],
  (unsigned) WinBG3_Sub_Bands[1],
  (unsigned) WinBG3_Sub_Bands[2],
  (unsigned) WinBG3_Sub_Bands[3],
  (unsigned) WinBG3_Sub_Bands[4],
  (unsigned) WinBG3_Sub_Bands[5]);
 PlotString(BGWinStatus_window,default_font,Line,
  0, 5 * default_font->get_heightspace());

 sprintf(Line,"BG4M: %02X: %02X %02X %02X %02X %02X %02X",
  (unsigned) WinBG4_Main_Count,
  (unsigned) WinBG4_Main_Bands[0],
  (unsigned) WinBG4_Main_Bands[1],
  (unsigned) WinBG4_Main_Bands[2],
  (unsigned) WinBG4_Main_Bands[3],
  (unsigned) WinBG4_Main_Bands[4],
  (unsigned) WinBG4_Main_Bands[5]);
 PlotString(BGWinStatus_window,default_font,Line,
  0, 6 * default_font->get_heightspace());

 sprintf(Line,"BG4S: %02X: %02X %02X %02X %02X %02X %02X",
  (unsigned) WinBG4_Sub_Count,
  (unsigned) WinBG4_Sub_Bands[0],
  (unsigned) WinBG4_Sub_Bands[1],
  (unsigned) WinBG4_Sub_Bands[2],
  (unsigned) WinBG4_Sub_Bands[3],
  (unsigned) WinBG4_Sub_Bands[4],
  (unsigned) WinBG4_Sub_Bands[5]);
 PlotString(BGWinStatus_window,default_font,Line,
  0, 7 * default_font->get_heightspace());

#ifndef NO_LOGO
 if(sneese)
  stretch_blit(sneese,Allegro_Bitmap,0,0,GUI_ScreenWidth,GUI_ScreenHeight,0,0,SCREEN_W,SCREEN_H);
#endif
 draw_sprite(Allegro_Bitmap, GUI_Bitmap, 0, 0);
 vsync();
 CopyGUIScreen();

 for (;;)
 {
  while (!keypressed());
  if ((readkey() >> 8) == KEY_ESC) break;
 }
}

CTL *joypad_bitmap=0;

CTL_CLEAR GUI_clear;
CTL_CLEAR Main_clear;
CTL_CLEAR Screen_clear;
CTL_CLEAR Config_clear;
CTL_CLEAR Sound_clear;
CTL_CLEAR ControlSetup_clear;
CTL_CLEAR ROMInfo_clear;
CTL_CLEAR HWStatus_clear;
CTL_CLEAR DMAStatus_clear;
CTL_CLEAR APUStatus_clear;
CTL_CLEAR BGWinStatus_clear;
CTL_CLEAR File_clear;

int allocate_windows()
{
 static int file_cleared=0;
 if(!file_cleared) File_window+=File_clear;

 GUI_window=new BORDER_WINDOW(-1,-1,320,240);
 Main_window=new BORDER_WINDOW(0,0,16*default_font->get_widthspace(),MAIN_NUM_OPTIONS*default_font->get_heightspace());
 Screen_window=new BORDER_WINDOW(100,30,21*default_font->get_widthspace(),NUM_SCREEN_OPTIONS*default_font->get_heightspace());
 Config_window=new BORDER_WINDOW(70,15,24*default_font->get_widthspace(),CONFIG_NUM_OPTIONS*default_font->get_heightspace());
 Controls_window=new BORDER_WINDOW(90,105,24*default_font->get_widthspace(),CONTROLS_NUM_OPTIONS*default_font->get_heightspace());
 Sound_window=new BORDER_WINDOW(90,105,24*default_font->get_widthspace(),SOUND_NUM_OPTIONS*default_font->get_heightspace());
 ControlSetup_window=new BORDER_WINDOW(29,34,168,104);
 ROMInfo_window=new BORDER_WINDOW(10,70,33*default_font->get_widthspace(),7*default_font->get_heightspace());
 HWStatus_window=new BORDER_WINDOW(10,70,33*default_font->get_widthspace(),9*default_font->get_heightspace());
 DMAStatus_window=new BORDER_WINDOW(10,70,33*default_font->get_widthspace(),9*default_font->get_heightspace());
 APUStatus_window=new BORDER_WINDOW(8,70,48*default_font->get_widthspace(),9*default_font->get_heightspace());
 BGWinStatus_window=new BORDER_WINDOW(8,70,48*default_font->get_widthspace(),9*default_font->get_heightspace());
 if(!(GUI_window && Main_window && Screen_window && Config_window &&
    Controls_window && Sound_window && ControlSetup_window &&
    ROMInfo_window && HWStatus_window && DMAStatus_window &&
    APUStatus_window && BGWinStatus_window)) return 1;
 *GUI_window+=GUI_clear;
 *Main_window+=Main_clear;
 *Screen_window+=Screen_clear;
 *Config_window+=Config_clear;
 *Controls_window+=Config_clear;
 *Sound_window+=Sound_clear;
 *ControlSetup_window+=ControlSetup_clear;
 if(joypad)
  joypad_bitmap=new CTL_BITMAP(ControlSetup_window,&joypad,7,12);
 *ROMInfo_window+=ROMInfo_clear;
 *HWStatus_window+=HWStatus_clear;
 *DMAStatus_window+=DMAStatus_clear;
 *APUStatus_window+=APUStatus_clear;
 *BGWinStatus_window+=BGWinStatus_clear;
 return 0;
}

void free_windows()
{
 delete GUI_window;
 delete Main_window;
 delete joypad_bitmap;
 delete Screen_window; delete Config_window; delete Sound_window;
 delete ControlSetup_window; delete ROMInfo_window;
 delete HWStatus_window; delete DMAStatus_window;
 delete APUStatus_window; delete BGWinStatus_window;

 GUI_window=0;
 Main_window=0;
 joypad_bitmap=0;
 Screen_window=0; Config_window=0; Sound_window=0;
 ControlSetup_window=0; ROMInfo_window=0; HWStatus_window=0;
 DMAStatus_window=0; APUStatus_window=0;
}

extern volatile unsigned Timer_Counter_Throttle;
extern volatile unsigned Timer_Counter_Profile;

GUI_ERROR GUI()
{
 unsigned char OLD_SPC_ENABLED=SPC_ENABLED;

 if (allocate_windows()) return GUI_EXIT;

#ifndef NO_LOGO
 if (sneese)
 { // Prevent a crash if file not found!
  set_palette(sneesepal);
  stretch_blit(sneese,Allegro_Bitmap,0,0,GUI_ScreenWidth,GUI_ScreenHeight,0,0,SCREEN_W,SCREEN_H);
 }
#endif

 set_palette_range(&GUIPal[-240],240,255,1);    // Set the GUI palette up.

 clear_keybuf();

 int CursorAt = 0;

 for(;;)
 {
  int keypress, key_asc, key_scan;

  UpdateGUI(CursorAt);
  CopyGUIScreen();
  while (!keypressed());
  keypress = readkey();
  key_asc = keypress & 0xFF;
  key_scan = keypress >> 8;

  switch (key_scan)
  {
   case KEY_UP:
    CursorAt--;
    if(CursorAt == -1) // so it wraps
     CursorAt = MAIN_NUM_OPTIONS-1;
    break;

   case KEY_DOWN:
    CursorAt++;
    if(CursorAt == MAIN_NUM_OPTIONS) // so it wraps
     CursorAt=0;
    break;

   case KEY_ESC:
    if (snes_rom_loaded)
    {
     while (key[KEY_ESC]);
     goto resume_emulation;
    }
    break;

  case KEY_ENTER:
  case KEY_ENTER_PAD:
   if(snes_rom_loaded)
   {

    if (CursorAt == MAIN_RESUME_EMULATION) goto resume_emulation;
    if (CursorAt == MAIN_RESET_EMULATION)
    {
     snes_reset();
     goto resume_emulation;
    }

    if (CursorAt == MAIN_ROM_INFO)
     RomInfo();

    if (CursorAt == MAIN_HW_STATUS)
     HWStatus();

    if (CursorAt == MAIN_DMA_STATUS)
     DMAStatus();

    if (CursorAt == MAIN_APU_STATUS)
     APUStatus();

    if (CursorAt == MAIN_BGWIN_STATUS)
     BGWinStatus();
   }

   if (CursorAt == MAIN_LOAD_ROM)
   {
    char TempBufferP[MAXPATH]; // For saving the current directory to use!

    getcwd(TempBufferP,MAXPATH);
    if (FileWindow() == 0)
    {
     chdir(TempBufferP);
     goto resume_emulation;
    }
    chdir(TempBufferP);
    break;
   }

   if (CursorAt == MAIN_CONFIGURE)
    ConfigWindow();
   if (CursorAt == MAIN_EXIT)
   {
    free_windows();
    return GUI_EXIT;
   }
  }
 }

 resume_emulation:

 // Reset the SNES if the SPC has been enabled, and it wasn't before
 if(snes_rom_loaded && SPC_ENABLED && (SPC_ENABLED!=OLD_SPC_ENABLED))
 {
  snes_reset();
 }

 acquire_screen();

 clear(screen);

 release_screen();

 clear(Allegro_Bitmap);

 free_windows();
 return GUI_CONTINUE;   // Signify normal exit
}
