/*

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2003 Charles Bilyue'.
Portions Copyright (c) 2003 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

*/

//#define NO_GUI
/* DOS platform-specific code */
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <ctype.h>
#include <time.h>

#include "wrapaleg.h"

#define GUI_DEFAULT 1

#ifdef ALLEGRO_DJGPP
#include <crt0.h>
void   __crt0_load_environment_file(char *_app_name){}
char **__crt0_glob_function(char *_arg){ return 0; }

#ifdef DEBUG
int _crt0_startup_flags = _CRT0_FLAG_FILL_DEADBEEF;
#endif
#endif

#ifdef ALLEGRO_DOS
BEGIN_COLOR_DEPTH_LIST
 COLOR_DEPTH_8
 COLOR_DEPTH_15
 COLOR_DEPTH_16
END_COLOR_DEPTH_LIST
#endif

#include "platform.h"
#include "helper.h"
#include "input.h"
#include "romload.h"
#include "apu/sound.h"
#include "cpu/cpu.h"
#include "guicore.h"
#include "version.h"

char home_dir[MAXPATH];
char cfg_name[MAXPATH];
char dat_name[MAXPATH];

char start_dir[MAXPATH] = "";

static float cfg_version;
static int cfg_changed;

/* Allegro internal var */
AL_VAR(int,_sound_hq);

void LoadConfigCurrent(void)
{
 char default_keymap[] = "45 39 41 43  5  4 23 19 17  1 65 66";
 char keymapbuf[81];

 SCREEN_MODE = get_config_int("display", "screenmode", 1);
#if defined(ALLEGRO_DOS)
 if (cfg_version >= 0.72 && SCREEN_MODE > 6) SCREEN_MODE = 0;
#elif defined(ALLEGRO_WINDOWS) || defined(ALLEGRO_UNIX) || defined(ALLEGRO_BEOS)
 if (cfg_version >= 0.72 && SCREEN_MODE > 7) SCREEN_MODE = 0;
#else
#error Unable to determine platform for limiting screen mode.
#endif

 display_process = (DISPLAY_PROCESS) get_config_int("display", "process", SDP_NONE);
 if ((unsigned) display_process >= NUM_DISPLAY_PROCESSES)
  display_process = SDP_NONE;

 stretch_x = get_config_int("display", "stretch_x", 0);
 if (stretch_x < 0) stretch_x = 0;
 else if (stretch_x > 16) stretch_x = 16;

 stretch_y = get_config_int("display", "stretch_y", 0);
 if (stretch_y < 0) stretch_y = 0;
 else if (stretch_y > 16) stretch_y = 16;

 /* 1-10,15,20,30,60 */
 FRAME_SKIP_MAX = get_config_int("display", "maxframeskip", 60);
 if (FRAME_SKIP_MAX > 60) FRAME_SKIP_MAX = 60;
 else if (FRAME_SKIP_MAX > 30 && FRAME_SKIP_MAX < 60) FRAME_SKIP_MAX = 30;
 else if (FRAME_SKIP_MAX > 20 && FRAME_SKIP_MAX < 30) FRAME_SKIP_MAX = 20;
 else if (FRAME_SKIP_MAX > 15 && FRAME_SKIP_MAX < 20) FRAME_SKIP_MAX = 15;
 else if (FRAME_SKIP_MAX > 10 && FRAME_SKIP_MAX < 15) FRAME_SKIP_MAX = 10;
 else if (FRAME_SKIP_MAX < 1) FRAME_SKIP_MAX = 1;

 /* 0-10,15,20,30,60 */
 FRAME_SKIP_MIN = get_config_int("display", "minframeskip", 0);
 if (FRAME_SKIP_MIN > 60) FRAME_SKIP_MIN = 60;
 else if (FRAME_SKIP_MIN > 30 && FRAME_SKIP_MIN < 60) FRAME_SKIP_MIN = 30;
 else if (FRAME_SKIP_MIN > 20 && FRAME_SKIP_MIN < 30) FRAME_SKIP_MIN = 20;
 else if (FRAME_SKIP_MIN > 15 && FRAME_SKIP_MIN < 20) FRAME_SKIP_MIN = 15;
 else if (FRAME_SKIP_MIN > 10 && FRAME_SKIP_MIN < 15) FRAME_SKIP_MIN = 10;
 if (FRAME_SKIP_MIN > FRAME_SKIP_MAX) FRAME_SKIP_MIN = FRAME_SKIP_MAX;

 memset(save_extension, 0, MAXEXT);
 strncpy(save_extension, get_config_string("paths", "saveextension", "SRM"), MAXEXT - 1);

 memset(save_dir, 0, MAXPATH);
 strncpy(save_dir, get_config_string("paths", "savedirectory", ""), MAXPATH - 1);

 SPC_ENABLED = get_config_int("hardware", "emulatespc", 1);

 sound_enabled = get_config_int("hardware", "outputsound", 2);
 if (sound_enabled > 2) sound_enabled = 0;

 sound_bits = get_config_int("audio", "sound_bits", 16);
 if (sound_bits != 8) sound_bits = 16;

 _sound_hq = get_config_int("audio", "sound_hq", 1);
 if (_sound_hq < 0 || _sound_hq > 2) _sound_hq = 1;

 sound_echo_enabled = get_config_int("audio", "enable_echo", 1);
 sound_gauss_enabled = get_config_int("audio", "enable_gauss", 1);

 use_mmx = (cpu_capabilities & CPU_MMX) ?
  get_config_int("extras", "use_mmx", TRUE) : 0;

 /* Enable FPU copies by default on non-MMX Pentium CPUs, except */
 /*  Pentium Overdrive CPUs for 486 systems */
 use_fpu_copies = (cpu_capabilities & CPU_FPU) ?
  get_config_int("extras", "use_fpu_copies",
  (cpu_family == 5 && cpu_model != 5 && !use_mmx &&
   !strcmp(cpu_vendor, "GenuineIntel"))) : 0;

 /* Enable cache preloading by default on Pentium class CPUs, except */
 /*  Pentium Overdrive CPUs for 486 systems */
 preload_cache = get_config_int("extras", "preload_cache",
  /* Pentium class CPU, except Pentium Overdrive CPUs for 486 systems */
  (cpu_family == 5 && cpu_model != 5));

 /* Enable partial cache preloading by default on Pentium class CPUs, */
 /*  and on 486DX2WBE and 486DX4 CPUs */
 preload_cache_2 = preload_cache ? preload_cache :
  get_config_int("extras", "preload_cache_2",
   ((cpu_family == 4 &&
   /* 486DX2WBE or 486DX4 */
    (cpu_model == 7 || cpu_model == 8 ||
   /* am5x86 */
    (cpu_model == 15 && !strcmp(cpu_vendor, "AuthenticAMD")))) ||
   /* Pentium class CPU */
   (cpu_family == 5)));

 CONTROLLER_1_TYPE = get_config_int("input", "controller_1_type", 0);
 if (CONTROLLER_1_TYPE > 2 || (CONTROLLER_1_TYPE == 2 && !mouse_available))
  CONTROLLER_1_TYPE = 0;

 CONTROLLER_2_TYPE = get_config_int("input", "controller_2_type", 0);
 if (CONTROLLER_2_TYPE > 2 || (CONTROLLER_2_TYPE == 2 && !mouse_available))
  CONTROLLER_2_TYPE = 0;

 memset(keymapbuf, 0, 81);
 strncpy(keymapbuf, get_config_string("input", "snes_pad_1_keys", default_keymap), 80);
 if (
  sscanf(keymapbuf, "%d%d%d%d%d%d%d%d%d%d%d%d",
   &input_player1.up, &input_player1.down, &input_player1.left, &input_player1.right,
   &input_player1.a, &input_player1.b, &input_player1.x, &input_player1.y, &input_player1.l, &input_player1.r,
   &input_player1.select, &input_player1.start) < 12)
 {
  sscanf(default_keymap, "%d%d%d%d%d%d%d%d%d%d%d%d",
   &input_player1.up, &input_player1.down, &input_player1.left, &input_player1.right,
   &input_player1.a, &input_player1.b, &input_player1.x, &input_player1.y, &input_player1.l, &input_player1.r,
   &input_player1.select, &input_player1.start);
 }

 strncpy(keymapbuf, get_config_string("input", "snes_pad_2_keys", default_keymap), 80);
 if (
  sscanf(keymapbuf, "%d%d%d%d%d%d%d%d%d%d%d%d",
   &input_player2.up, &input_player2.down, &input_player2.left, &input_player2.right,
   &input_player2.a, &input_player2.b, &input_player2.x, &input_player2.y, &input_player2.l, &input_player2.r,
   &input_player2.select, &input_player2.start) < 12)
 {
  sscanf(default_keymap, "%d%d%d%d%d%d%d%d%d%d%d%d",
   &input_player2.up, &input_player2.down, &input_player2.left, &input_player2.right,
   &input_player2.a, &input_player2.b, &input_player2.x, &input_player2.y, &input_player2.l, &input_player2.r,
   &input_player2.select, &input_player2.start);
 }
}

void FixupConfig(void)
{
 /* Compatibility with old screen modes */
 if (cfg_version < 0.72)
 {
  if (SCREEN_MODE > 8)
  {
   SCREEN_MODE = 0;
  }
  else
  {
   /* old 320x200x256 squash = no h-stretch, full v-stretch */
   if (SCREEN_MODE == 1)
   {
    SCREEN_MODE = 0;
    stretch_x = 0;
    stretch_y = 1;
   }

   /* old 640x480x16b stretch = 2x h-stretch, 2x v-stretch */
   else if (SCREEN_MODE == 7)
   {
    SCREEN_MODE = 6;
    stretch_x = 2;
    stretch_y = 2;
   }

   /* old 320x240x256 SVGA */
   else if (SCREEN_MODE == 8)
   {
    SCREEN_MODE = 1;
    stretch_x = 0;
    stretch_y = 0;
   }
  }
 }
}

int LoadConfig(void)
{
 cfg_version = get_config_float("base", "version", 0);
 if (((int) (cfg_version * 8192)) != ((int) (SNEESE_VERSION * 8192)))
 {
  LoadConfigCurrent();

  //handle old version cfg files
  FixupConfig();

  cfg_version = SNEESE_VERSION;
  cfg_changed = (0 - 1);
 }
 else
 {
  LoadConfigCurrent();
 }

 return 0;
}

void SaveConfig(void)
{
 /*
   Open the file in text mode. Under DOS and Windows the compiler's runtime
    system will do the conversion from NL (\n) to CR/LF (\r\n).
 */
 FILE *cfg = fopen(cfg_name, "w");

 if (cfg == NULL) return;
 fprintf(cfg,"# SNEeSe Configuration file\n");
 fprintf(cfg,"\n");
 fprintf(cfg,"# Do not edit [base] section, or all settings may be lost!\n");
 fprintf(cfg,"\n");
 fprintf(cfg, "[base]\n");
 fprintf(cfg, "version=%s\n", SNEESE_VERSION_STR);
 fprintf(cfg, "\n");
 fprintf(cfg, "# Important paths and file-related settings\n");
 fprintf(cfg, "[paths]\n");
 fprintf(cfg, "saveextension=%s\n", save_extension);
 fprintf(cfg, "savedirectory=%s\n", save_dir);
 fprintf(cfg, "\n");
 fprintf(cfg, "# Display settings\n");
 fprintf(cfg, "[display]\n");
 fprintf(cfg, "# Available screen modes:\n");
#ifdef ALLEGRO_DOS
 fprintf(cfg, "#  0:320x200x256 VGA       1:320x240x256 VESA2     2:320x240x256 MODE-X\n");
 fprintf(cfg, "#  3:256x239x256 VGA       4:320x200x16b VESA2     5:320x240x16b VESA2\n");
 fprintf(cfg, "#  6:640x480x16b VESA2\n");
#elif defined(ALLEGRO_WINDOWS) || defined(ALLEGRO_UNIX) || defined(ALLEGRO_BEOS)
 fprintf(cfg, "#  0:320x200x256 WIN       1:320x240x256 WIN       2:320x240x256 FS\n");
 fprintf(cfg, "#  3:256x239x256 WIN       4:320x200x16b WIN       5:320x240x16b WIN\n");
 fprintf(cfg, "#  6:640x480x16b WIN       7:640x480x16b FS\n");
#endif
 fprintf(cfg, "screenmode=%d\n", SCREEN_MODE);
 fprintf(cfg, "\n");

 fprintf(cfg, "# Available screen processing methods:\n");
 fprintf(cfg, "#  0:none\n");
 fprintf(cfg, "process=%d\n", (int) display_process);
 fprintf(cfg, "\n");

 fprintf(cfg, "# Stretch in horizontal (x) or vertical (y) directions:\n");
 fprintf(cfg, "#  0:no stretch   1:stretch   2+: zoom in by that factor\n");
 fprintf(cfg, "stretch_x=%d\n", stretch_x);
 fprintf(cfg, "stretch_y=%d\n", stretch_y);
 fprintf(cfg, "\n");

 fprintf(cfg, "# These specify how many frames to skip.\n");
 fprintf(cfg, "# maxframeskip sets the maximum number of frames that will be skipped before\n");
 fprintf(cfg, "#  a frame is drawn.\n");
 fprintf(cfg, "# minframeskip sets the number of frames that will always be skipped before\n");
 fprintf(cfg, "#  a frame is drawn. a min skip of 0 tells SNEeSe to wait for at least one\n");
 fprintf(cfg, "#  timer tick (50/60Hz) to have passed before emulating a frame (to slow\n");
 fprintf(cfg, "#  down machines that are running too fast)\n");
 fprintf(cfg, "# 'minframeskip' will never be above 'maxframeskip' - when loaded,\n");
 fprintf(cfg, "#  'maxframeskip' has precedence over 'minframeskip'.\n");
 fprintf(cfg, "# Setting 'minframeskip' and 'maxframeskip' to the same number effectively\n");
 fprintf(cfg, "#  disables all speed-throttling.\n");
 fprintf(cfg, "minframeskip=%d\n", FRAME_SKIP_MIN);
 fprintf(cfg, "maxframeskip=%d\n", FRAME_SKIP_MAX);
 fprintf(cfg, "\n");

 fprintf(cfg, "# Emulated hardware options\n");
 fprintf(cfg, "[hardware]\n");
 fprintf(cfg, "# The following option selects emulation of SPC (1) or APU skip (0).\n");
 fprintf(cfg, "emulatespc=%d\n", SPC_ENABLED);
 fprintf(cfg, "# The following option selects whether to: (0) disable sound;\n");
 fprintf(cfg, "# (1) generate mono sound; (2) generate stereo sound.\n");
 fprintf(cfg, "# This option is ignored if SPC is disabled (emulatespc=0).\n");
 fprintf(cfg, "outputsound=%d\n", sound_enabled);
 fprintf(cfg, "\n");

 fprintf(cfg, "# Audio output options\n");
 fprintf(cfg, "[audio]\n");
 fprintf(cfg, "# The following option selects size of audio samples output.\n");
 fprintf(cfg, "# Valid values: 8 or 16 (default).\n");
 fprintf(cfg, "sound_bits=%d\n", sound_bits);
 fprintf(cfg, "# The following option selects Allegro mixing quality.\n");
 fprintf(cfg, "# 0 = fast 8-bit, 1 (default) = 16-bit, 2 = 16-bit interpolated.\n");
 fprintf(cfg, "sound_hq=%d\n", _sound_hq);

 fprintf(cfg, "# The following option determines if the SNES echo effect\n");
 fprintf(cfg, "# and its corresponding FIR filter and SPC RAM update are\n");
 fprintf(cfg, "# emulated.\n");
 fprintf(cfg, "# Valid values: 0 = don't emulate, 1 = emulate (default).\n");
 fprintf(cfg, "enable_echo=%d\n", sound_echo_enabled);
 fprintf(cfg, "# The following option determines if the SNES 4-point pitch-\n");
 fprintf(cfg, "# regulated gaussian interpolation of sample data is emulated.\n");
 fprintf(cfg, "# Valid values: 0 = don't emulate, 1 = emulate (default).\n");
 fprintf(cfg, "enable_gauss=%d\n", sound_gauss_enabled);
 fprintf(cfg, "\n");

 fprintf(cfg, "# Extra options that don't fit elsewhere\n");
 fprintf(cfg, "[extras]\n");
 fprintf(cfg, "# The following option determines if the FPU will be used to copy\n");
 fprintf(cfg, "# data, if available (0 = don't use).\n");
 fprintf(cfg, "use_fpu_copies=%d\n", use_fpu_copies ? 1 : 0);
 fprintf(cfg, "# The following option determines if MMX instructions will be used,\n");
 fprintf(cfg, "# if available (0 = don't use).\n");
 fprintf(cfg, "use_mmx=%d\n", use_mmx ? 1 : 0);
 fprintf(cfg, "# The following options determine if memory will be preloaded into\n");
 fprintf(cfg, "# the cache when it is expected it may help (0 = don't preload).\n");
 fprintf(cfg, "preload_cache=%d\n", preload_cache ? 1 : 0);
 fprintf(cfg, "preload_cache_2=%d\n", preload_cache_2 ? 1 : 0);
 fprintf(cfg, "\n");

 fprintf(cfg, "# Input and controller options\n");
 fprintf(cfg, "[input]\n");
 fprintf(cfg, "# You can select joypad, mouse, or none for emulation on\n");
 fprintf(cfg, "# each controller.\n");
 fprintf(cfg, "controller_1_type=%d\n", CONTROLLER_1_TYPE);
 fprintf(cfg, "controller_2_type=%d\n", CONTROLLER_2_TYPE);
 fprintf(cfg, "\n");

 fprintf(cfg, "# Here you will find the control mappings for controller 1\n");
 fprintf(cfg, "# the numbers you see are scan codes, use the \"Define Keys\"\n");
 fprintf(cfg, "# option in the GUI to alter the keys, it's far easier!\n");
 fprintf(cfg, "\n");
 fprintf(cfg, "# Up Down Left Right A B X Y L R Select Start\n");
 fprintf(cfg, "snes_pad_1_keys=%d %d %d %d %d %d %d %d %d %d %d %d\n",
  input_player1.up, input_player1.down, input_player1.left, input_player1.right,
  input_player1.a, input_player1.b, input_player1.x, input_player1.y, input_player1.l, input_player1.r,
  input_player1.select, input_player1.start);

 fprintf(cfg, "\n");
 fprintf(cfg, "# Player 2's mappings are found here, see above.\n");
 fprintf(cfg, "snes_pad_2_keys=%d %d %d %d %d %d %d %d %d %d %d %d\n",
  input_player2.up, input_player2.down, input_player2.left, input_player2.right,
  input_player2.a, input_player2.b, input_player2.x, input_player2.y, input_player2.l, input_player2.r,
  input_player2.select, input_player2.start);

 fclose(cfg);
}

void cmdhelp(void)
{
 const char syntax[] =
  "Usage: SNEeSe [switches] [romname.ext] [switches]\n"
  "switches:\n"
  " -fl  Force LoROM memory map\n"
  " -fh  Force HiROM memory map\n"
  " -fi  Force interleaved ROM (only supported for HiROM)\n"
  " -fn  Force non-interleaved ROM\n"
  " -fvn Force NTSC video standard\n"
  " -fvp Force PAL video standard\n"
  " -h   Copier header exists\n"
  " -n   No copier header\n"
  " -m#  Set screen mode\n"
  " -se  Enable sound echo/FIR filter\n"
  " -sde Disable sound echo/FIR filter\n"
  " -sg  Enable sound gaussian filter\n"
  " -sdg Disable sound gaussian filter\n"
  " -ds  Disable sound\n"
  " -s   Enable sound (stereo)\n"
  " -sm  Enable sound (mono)\n"
  " -saveext RAM     Set extension for save RAM files\n"
  " -savedir .\\saves Set save directory\n"
  " -fps Start with frames-per-second (FPS) counter enabled\n"
  " -gui Enable GUI\n"
  " -cli Disable GUI\n"
  " -pt  Disable cache preloads    -pb  Enable cache preloads\n"
  " -pm  Enable MMX support        -pf  Enable FPU copies\n"
  " -pd  Disable MMX/FPU support\n";

 printf("%s", syntax);
}

/* Perform platform-specific initialization */
int platform_init(int argc, char **argv)
{
 char f_drive[MAXDRIVE], f_dir[MAXDIR], f_file[MAXFILE], f_ext[MAXEXT];

 /* Ensure stdout is not buffered */
 setvbuf(stdout, NULL, _IONBF, 0);

 allegro_init();

 if (cpu_family < 4)
 {
  printf("SNEeSe requires a 486 or better!\n");
  return 1;
 }

 set_display_switch_mode(SWITCH_BACKGROUND);

#ifdef ALLEGRO_WINDOWS
 set_window_title("SNEeSeW");
#else
 set_window_title("SNEeSe");
#endif

 /* Should hook this for exit, actually... */
 set_window_close_button(FALSE);

 /* This helps SNEeSe find it's home directory, for .cfg/.dat file,
  * when started from a different directory
  * (ie, drag-and-drop via Windows Explorer)
  */
 {
  char exe_name[MAXPATH];

  get_executable_name(exe_name, MAXPATH);
  fnsplit(exe_name, f_drive, f_dir, f_file, f_ext);
 }

 fnmerge(home_dir, f_drive, f_dir, "", "");

 if (getcwd(start_dir, MAXPATH) == NULL)
 {
  printf("Failure getting current directory!\n");
  printf("Report this immediately!\n");
  return 1;
 }

 strcpy(cfg_name, home_dir);

 strcpy(dat_name, home_dir);

#ifdef ALLEGRO_WINDOWS
 strcat(cfg_name, "sneesew.cfg");
#else
 strcat(cfg_name, "sneese.cfg");
#endif
 strcat(dat_name, "sneese.dat");

 set_config_file(cfg_name); /* Yup, config files exist */

 mouse_available = install_mouse();
 if (mouse_available == -1) mouse_available = 0;

 install_keyboard();
 install_key_release_callback();

#if 0
#ifdef ALLEGRO_DOS
 if (load_joystick_data(NULL))
 {
   install_joystick(JOY_TYPE_6BUTTON);
 }
#else
#endif
#endif
 if (load_joystick_data(NULL))
 {
   install_joystick(JOY_TYPE_AUTODETECT);
 }
#if 0
#endif

#ifndef NO_GUI
#if GUI_DEFAULT
 GUI_ENABLED = 1;
#else
 GUI_ENABLED = 0;
#endif
#endif

 return 0;
}

void platform_exit(void)
{
 if (strlen(start_dir))
 {
  chdir(start_dir);
 }
}

int parse_args(int argc, char **argv, char **names, int maxnames)
{
 /* Start: command line parser */

 char *tv;
 int tc;
 int numnames;

 numnames = 0;
 for (tc = 1; tc < argc; tc++)
 {
  int i;
  tv = argv[tc];
#if defined(UNIX) || defined(__BEOS__)
  if ((*tv == '-'))
#else
  if ((*tv == '-') || (*tv == '/'))
#endif
  {
   switch (*(tv + 1))
   {
#ifndef NO_GUI
    case 'c':
    case 'C':
     if (!stricmp(tv + 1, "cli"))   /* Disable enabled GUI */
     {
      GUI_ENABLED = 0;
     }
     else
     {
      printf("Invalid switch: %s\n", tv); cmdhelp(); return 1;
     }
     break;
#endif

    case 'd':
    case 'D':
     if (!stricmp(tv + 1, "ds"))
     {
      sound_enabled = 0;
     }

     else
     {
      printf("Invalid switch: %s\n", tv); cmdhelp(); return 1;
     }
     break;

    case 'm':
    case 'M':
     if (sscanf(tv + 2, "%u", &i) != 1) cmdhelp();
     if (i > 6) cmdhelp();
     SCREEN_MODE = i;
     cfg_changed = -1;
     break;
    case 'f':
    case 'F':
     switch (strlen(tv + 1))
     {
      case 2:
       switch(*(tv + 2))
       {
        case 'l': case 'L':  /* Force LoROM */
         ROM_memory_map = LoROM; break;
        case 'h': case 'H':  /* Force HiROM */
         ROM_memory_map = HiROM; break;
        case 'n': case 'N':  /* Force non-interleaved */
         ROM_interleaved = Off; break;
        case 'i': case 'I':  /* Force interleaved */
         ROM_interleaved = On; break;
        default: printf("Invalid switch: %s\n", tv); cmdhelp(); return 1;
       }
       break;
      case 3:
       switch(*(tv + 2))
       {
        case 'v': case 'V':  /* Force video standard */
         switch(*(tv + 3))
         {
          case 'n': case 'N':    /* Force NTSC video standard */
           ROM_video_standard = NTSC_video; break;
          case 'p': case 'P':    /* Force PAL video standard */
           ROM_video_standard = PAL_video; break;
          default: printf("Invalid switch: %s\n", tv); cmdhelp(); return 1;
         }
         break;
        case 'p': case 'P':  /* FPS counter */
         switch(*(tv + 3))
         {
          case 's': case 'S':    /* FPS counter */
           FPS_ENABLED = (0 - 1); break;
          default: printf("Invalid switch: %s\n", tv); cmdhelp(); return 1;
         }
         break;
        default: printf("Invalid switch: %s\n", tv); cmdhelp(); return 1;
       }
       break;
      default: printf("Invalid switch: %s\n", tv); cmdhelp(); return 1;
     }
     break;
    case 'n': case 'N': /* Force no header */
     if (strlen(tv + 1) != 1)
     {
      printf("Invalid switch: %s\n", tv); cmdhelp(); return 1;
     }
     ROM_has_header = Off; break;
    case 'h': case 'H': /* Force header */
     if (strlen(tv + 1) != 1)
     {
      printf("Invalid switch: %s\n", tv); cmdhelp(); return 1;
     }
     ROM_has_header = On; break;
    case '?':
     if (strlen(tv + 1) != 1)
     {
      printf("Invalid switch: %s\n", tv);
     }
     cmdhelp(); return 1;

#ifndef NO_GUI
    case 'g':
    case 'G':
     if (!stricmp(tv + 1, "gui"))   /* Enable disabled GUI */
     {
      GUI_ENABLED = (0 - 1);
     }
     else
     {
      printf("Invalid switch: %s\n", tv); cmdhelp(); return 1;
     }
     break;
#endif

    case 'p':
    case 'P':
     switch (strlen(tv + 1))
     {
      case 2:
       switch(*(tv + 2))
       {
        case 'b': case 'B':  /* Enable cache preloads */
         cfg_changed = (0 - 1);
         preload_cache = TRUE; break;
        case 'm': case 'M':  /* Enable MMX support */
         cfg_changed = (0 - 1);
         use_mmx = TRUE; use_fpu_copies = FALSE; break;
        case 'f': case 'F':  /* Enable FPU copies */
         cfg_changed = (0 - 1);
         use_fpu_copies = TRUE; break;
        case 'd': case 'D':  /* Disable MMX/FPU support */
         cfg_changed = (0 - 1);
         use_mmx = use_fpu_copies = FALSE; break;
        case 't': case 'T':  /* Disable cache preloads */
         cfg_changed = (0 - 1);
         preload_cache = FALSE; break;
        default: printf("Invalid switch: %s\n", tv); cmdhelp(); return 1;
       }
       break;
      case 3:
       switch(*(tv + 2))
       {
        case 'b': case 'B':  /* Enable cache preloads (alternate) */
         if (*(tv + 3) == '2')
         {
          cfg_changed = (0 - 1);
          preload_cache_2 = TRUE; break;
         }
         else
         {
          printf("Invalid switch: %s\n", tv); cmdhelp(); return 1;
         }
         break;
        case 't': case 'T':  /* Disable cache preloads (alternate) */
         if (*(tv + 3) == '2')
         {
          cfg_changed = (0 - 1);
          preload_cache_2 = FALSE; break;
         }
         else
         {
          printf("Invalid switch: %s\n", tv); cmdhelp(); return 1;
         }
         break;
        default: printf("Invalid switch: %s\n", tv); cmdhelp(); return 1;
       }
       break;
      default: printf("Invalid switch: %s\n", tv); cmdhelp(); return 1;
     }
     break;

    case 's':
    case 'S':
     if (!stricmp(tv + 1, "savedir"))
     {
      if (tc + 1 >= argc)
      {
       printf("Invalid switch: %s\n", tv); cmdhelp(); return 1;
      }

      if (strlen(argv[tc + 1]) > MAXPATH - 1)
      {
       printf("Path too long: %s\n", argv[tc + 1]); cmdhelp(); return 1;
      }

      memset(save_dir, 0, MAXPATH);
      strcpy(save_dir, argv[++tc]);
      cfg_changed = -1;
     }

     else if (!stricmp(tv + 1, "saveext"))
     {
      if (tc + 1 >= argc)
      {
       printf("Invalid switch: %s\n", tv); cmdhelp(); return 1;
      }

      if (strlen(argv[tc + 1]) > MAXEXT - 1)
      {
       printf("Extension too long: %s\n", argv[tc + 1]); cmdhelp(); return 1;
      }

      memset(save_extension, 0, MAXEXT);
      strcpy(save_extension, argv[++tc]);
      cfg_changed = -1;
     }

     else if (!stricmp(tv + 1, "sm"))
     {
      sound_enabled = 1;
     }

     else if (!stricmp(tv + 1, "s"))
     {
      sound_enabled = 2;
     }

     else if (!stricmp(tv + 1, "se"))
     {
      sound_echo_enabled = 1;
     }

     else if (!stricmp(tv + 1, "sde"))
     {
      sound_echo_enabled = 0;
     }

     else if (!stricmp(tv + 1, "sg"))
     {
      sound_gauss_enabled = 1;
     }

     else if (!stricmp(tv + 1, "sdg"))
     {
      sound_gauss_enabled = 0;
     }

     else
     {
      printf("Invalid switch: %s\n", tv); cmdhelp(); return 1;
     }
     break;

    default:
     printf("Invalid switch: %s\n", tv); cmdhelp(); return 1;
   }
  } else {
   if (numnames < maxnames) names[numnames++] = tv;
   else { cmdhelp(); return 1; }
  }
 }
#ifndef NO_GUI
 if (!GUI_ENABLED)
 {
  if (numnames == 0)
  {
   if (cfg_changed == 0) cmdhelp();
   if (cfg_changed != 0)
   {
    printf("Configuration updated\n");
    SaveConfig();
   }
   return 1;
  }
 }
#endif

 if (numnames < maxnames) names[numnames] = NULL;

 return 0;
 /* End: command line parser */
}

void *platform_get_gfx_buffer(
 int depth, int width, int height, int hslack, int vslack,
 SNEESE_GFX_BUFFER *gfx_buffer)
{
 int needed_w, needed_h;

 needed_w = width + hslack;
 needed_h = height + vslack * 2 + (hslack ? 1 : 0);

 gfx_buffer->depth = depth;
 gfx_buffer->width = width;
 gfx_buffer->height = height;
 gfx_buffer->hslack = hslack;
 gfx_buffer->vslack = vslack;
 gfx_buffer->needed_w = needed_w;
 gfx_buffer->needed_h = needed_h;

 if (gfx_buffer->subbitmap)
 {
  destroy_bitmap(gfx_buffer->subbitmap);
  gfx_buffer->subbitmap = NULL;
 }

 if (gfx_buffer->bitmap)
 {
  destroy_bitmap(gfx_buffer->bitmap);
  gfx_buffer->bitmap = NULL;
 }

 gfx_buffer->bitmap = create_bitmap_ex(depth, needed_w, needed_h);
 if (!gfx_buffer->bitmap)
 {
  printf("Failure creating internal render bitmap!\n");
  return 0;
 }

 gfx_buffer->subbitmap =
  create_sub_bitmap(gfx_buffer->bitmap, hslack, vslack, width, height);
 if (!gfx_buffer->subbitmap)
 {
  printf("Failure creating internal render bitmap!\n");
  return 0;
 }

 return gfx_buffer->buffer = ((BITMAP *) gfx_buffer->subbitmap)->line[0];
}
