/*

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2003 Charles Bilyue'.
Portions Copyright (c) 2003 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

*/

/*

 This contains variable and function defintions used by both ASM and C++

 Many of these will be moved to other files as soon as I figure out where
  they belong...

*/

/*#define DEBUG_KEYS*/

#include <stdio.h>
#include <unistd.h>

/* includes for own implementations of fnmerge() and fnsplit() */
#if defined(UNIX) || defined(__BEOS__)
#include <sys/types.h>
#include <sys/stat.h>
#include <string.h>
#endif

#include "wrapaleg.h"

#include "helper.h"
#include "apu/sound.h"
#include "cpu/cpu.h"
#include "platform.h"

unsigned short ScreenX,ScreenY;

RGB SNES_Palette[256];                  /* So I can access from cc modules! */
colorBGR555 Real_SNES_Palette[256];     /* Updated by palette write */
colorRGB565 HICOLOUR_Palette[256];      /* values in here are plotted direct to PC! */

unsigned char BrightnessAdjust_64[16][32];  /* Used for brightness effect */
unsigned char BrightnessAdjust_256[16][32];

unsigned char MosaicLine[16][256];      /* Used for mosaic effect */
unsigned char MosaicCount[16][256];

/*
 This sets up BrightnessAdjust to be 16 tables each with 32 elements;
  table t, element e contains (t+1)e/2, except in table 0 where all
  elements are 0.
 This table is used for SNES brightness effects.

 This sets up MosaicLine to be 16 tables each with 256 elements;
  table t, element e contains (e/(t+1))(t+1).
 This table is used for the mosaic effect.

 This sets up MosaicCount to be 16 tables each with 256 elements;
  table t, element e contains (e/(t+1))(t+1)+t+1-e, except when
  that result added to e is > 256, in which case element e is
  256 - e.
 This table is used for the mosaic effect.

 This sets up BrightnessAdjust_64 and BrightnessAdjust_256 to be 16
  tables each with 32 elements; table t, element e contains (t+1)e/8
  in BrightnessAdjust_64, and (t+1)e/2 in BrightnessAdjust_256, except
  in table 0 where all elements are 0.
 This table is used for SNES brightness effects.

 This function may eventually be expanded to set up other tables.
*/
int BGR_unpack_64[32768];
int BGR_unpack_256[32768];

void SetupTables(void)
{
 int t;
 int r, g, b;
 for (b = 0; b < 32; b++)
 {
  for (g = 0; g < 32; g++)
  {
   for (r = 0; r < 32; r++)
   {
    BGR_unpack_64[(b << 10) + (g << 5) + r] = (b << 17) + (g << 9) + (r << 1);
    BGR_unpack_256[(b << 10) + (g << 5) + r] = (b << 19) + (g << 11) + (r << 3);
   }
  }
 }

 for (t = 0; t < 32; t++)
 {
  BrightnessAdjust_64[0][t] = 0;
  BrightnessAdjust_256[0][t] = 0;
 }

 for (t = 1; t < 16; t++)
 {
  int e;

  for (e = 0; e < 32; e++)
  {
   BrightnessAdjust_64[t][e] = (t + 1) * e / 8;
   BrightnessAdjust_256[t][e] = (t + 1) * e / 2;
  }

  for (e = 0; e < 256; e++)
  {
   int count_check;

   MosaicLine[t][e] = e / (t + 1) * (t + 1);

   count_check = e / (t + 1) * (t + 1) + t + 1 - e;
   if ((e + count_check) > 256) count_check = 256 - e;
   MosaicCount[t][e] = count_check;
  }
 }
}

void Reset_CGRAM(void)
{
 int i;
 for (i = 0; i < 256; i++)
 {
  Real_SNES_Palette[i].red = 0;
  Real_SNES_Palette[i].green = 0;
  Real_SNES_Palette[i].blue = 0;
 }
}

#ifdef DEBUG
unsigned Frames;
#endif

/* Mode 0 = 320x200x256 VGA     : Mode 1 = 320x200x256 VGA  FIT */
/* Mode 2 = 320x240x256 MODE-X  : Mode 3 = 256x256x256 MODE-X   */
/* Mode 4 = 320x200x16b SVGA    : Mode 5 = 320x240x16b SVGA     */
/* Mode 6 = 640x480x16b SVGA    : Mode 7 = 640x480x16b SVGA FIT */
unsigned char SCREEN_MODE;

DISPLAY_PROCESS display_process;

signed char stretch_x, stretch_y;

/* This flag is set when palette recomputation is necessary */
signed char PaletteChanged;

SNEESE_GFX_BUFFER gbSNES_Screen8;
SNEESE_GFX_BUFFER gbSNES_Screen16;

unsigned char *SNES_Screen;
unsigned char *SNES_Screen8;
unsigned short *SNES_Screen16;

BITMAP *Allegro_Bitmap=0;   /* Renamed (I'm using mostly allegro now so what the hell!) */

unsigned FRAME_SKIP_MIN;    /* Min frames waited until refresh */
unsigned FRAME_SKIP_MAX;    /* Max frames waited until refresh */
unsigned char SNES_COUNTRY; /* Used for PAL/NTSC protection checks */
unsigned char SPC_ENABLED=0;
unsigned char use_mmx;
unsigned char use_fpu_copies;
unsigned char preload_cache, preload_cache_2;

void OutputScreen()
{
 static int ScreenCount = 0;    /* Used to determine screen filename */
 char filename[13];

 while (ScreenCount <= 999)
 {
  sprintf(filename, "IMAGE%03u.PCX", ScreenCount++);
  if (access(filename, F_OK)) break;
 }
 if (ScreenCount > 999){ ScreenCount = 0; return; }

 if (SCREEN_MODE < 4)
 {
  save_pcx(filename, (BITMAP *) gbSNES_Screen8.subbitmap, SNES_Palette);
 } else {
  save_pcx(filename, Allegro_Bitmap, SNES_Palette);
 }
}

int qsort_int(const void *i1, const void *i2)
{
 return *(int *)i1 - *(int *)i2;
}

int xor_bands(const unsigned char *win1, const unsigned char *win2,
 unsigned char count1, unsigned char count2, unsigned char *out_point_set)
{
 int i;
 int points = 0, out_count = 0;
 int point_set[12];

 for (i = 0; i < count1; i++, points += 2)
 {
  point_set[points] = win1[i * 2];
  point_set[points + 1] = win1[i * 2 + 1] ? win1[i * 2 + 1] : 256;
 }

 for (i = 0; i < count2; i++, points += 2)
 {
  point_set[points] = win2[i * 2];
  point_set[points + 1] = win2[i * 2 + 1] ? win2[i * 2 + 1] : 256;
 }

 
 /* sort points */
 qsort(point_set, points, sizeof(int), qsort_int);

 /* remove duplicates and output bands */
 for (i = 0; i < points - 1; i += 2)
 {
  /* skip duplicates */
  if (point_set[i] == point_set[i + 1]) continue;

  out_point_set[out_count * 2] = point_set[i];

  /* check for duplicates while they may still exist */
  while (i + 2 < points)
  {
   /* skip duplicates */
   if (point_set[i + 1] != point_set[i + 2]) break;
   i += 2;
  }
  out_point_set[out_count * 2 + 1] = point_set[i + 1];
  out_count++;
 }

 return out_count;
}

unsigned char BrightnessLevel;  /* SNES Brightness level, set up in PPU.asm */

char fixedpalettecheck=0;

/* v0.15, we do palette conversion here */
/* v0.20, support for brightness effects in 16-bit modes */
void SetPalette()
{
 /* NB - CGRamAddress[256*2] contains 256 palette entries as follows:
         CGRamAddress[0*2+0] contains GGGRRRRR  R = Red component
         CGRamAddress[0*2+1] contains 0BBBBBGG  G = Green component
                                                B = Blue component

    So each 2 addresses contains 1 palette entry.
 */
 
 colorBGR555 color;
 colorRGB565 Hi;
 unsigned char Red,Green,Blue;
 int Count;

 if (SCREEN_MODE >= 4 && SCREEN_MODE <= 7)
 /* Hi colour mode so do different palette set up */
 {
  for (Count = 0; Count < 256; Count++)
  {
   color = Real_SNES_Palette[Count];

   Red = BrightnessAdjust_256[BrightnessLevel][color.red];
   Green = BrightnessAdjust_256[BrightnessLevel][color.green];
   Blue = BrightnessAdjust_256[BrightnessLevel][color.blue];

   Hi.red = Red >> 3;
   Hi.green = Green >> 2;
   Hi.blue = Blue >> 3;
   HICOLOUR_Palette[Count] = Hi;

   /* We still have to do this or screenshot will fail */
   SNES_Palette[Count].r = Red >> 2;
   SNES_Palette[Count].g = Green >> 2;
   SNES_Palette[Count].b = Blue >> 2;
  }
  set_palette_range((RGB *)SNES_Palette, 0, 255, FALSE);
 } else {
  for(Count = 0; Count < 256; Count++)
  {
   color = Real_SNES_Palette[Count];

   Red = BrightnessAdjust_64[BrightnessLevel][color.red];
   Green = BrightnessAdjust_64[BrightnessLevel][color.green];
   Blue = BrightnessAdjust_64[BrightnessLevel][color.blue];

   SNES_Palette[Count].r = Red;
   SNES_Palette[Count].g = Green;
   SNES_Palette[Count].b = Blue;

  }
  set_palette_range((RGB *)SNES_Palette, 0, 255, FALSE);
 }
}

extern unsigned Current_Line_Render;
extern unsigned Last_Frame_Line;

/*
 to do: treat stretch=...
  1    : full stretch
  2+   : zoom in by fixed factor
  -1   : stretch to arbitrary size
  -(2+): zoom out by fixed factor
*/
void Copy_Screen()
{
 int out_position_x, out_size_x;
 int out_position_y, out_size_y;

 if (PaletteChanged)
 {
  SetPalette();
  PaletteChanged = 0;
 }

 switch (SCREEN_MODE)
 {
  case 0:   /* VGA mode 13h - linear 320x200 */
  case 1:   /* VESA2 - linear 320x240 */
  case 2:   /* VGA mode-x - planar 320x240 */
  case 3:   /* VGA - linear 256x239 */
   switch (stretch_x)
   {
    case 0:
     out_size_x = 256;
     out_position_x = (ScreenX - out_size_x) / 2;
     break;
    default:
     out_size_x = 256 * stretch_x;
     out_position_x = (ScreenX - out_size_x) / 2;
     break;
    case 1:
     out_position_x = 0;
     out_size_x = ScreenX;
     break;
   }

   switch (stretch_y)
   {
    case 0:
     out_size_y = 239;
     out_position_y = (ScreenY - out_size_y) / 2;
     break;
    default:
     out_size_y = 239 * stretch_y;
     out_position_y = (ScreenY - out_size_y) / 2;
     break;
    case 1:
     out_position_y = 0;
     out_size_y = ScreenY;
     break;
   }

   if (stretch_x || stretch_y)
   {
    if (Current_Line_Render < 239 && Current_Line_Render < Last_Frame_Line)
    {
     /* fill unrendered area with black */
     rectfill(gbSNES_Screen8.subbitmap,
      0, Current_Line_Render,
      255, Last_Frame_Line - 1,
      0);
    }

    acquire_screen();

    stretch_blit(gbSNES_Screen8.subbitmap, screen,
     0, 0, 256, 239,
     out_position_x, out_position_y, out_size_x, out_size_y);

    release_screen();
   }
   else
   {
    acquire_screen();

    blit(gbSNES_Screen8.subbitmap, screen, 0, 0,
     out_position_x, out_position_y, out_size_x, Current_Line_Render);

    if (Current_Line_Render < 239 && Current_Line_Render < Last_Frame_Line)
    {
     /* fill unrendered area with black */
     rectfill(screen,
      out_position_x, out_position_y + Current_Line_Render,
      out_position_x + out_size_x - 1, out_position_y + Last_Frame_Line - 1,
      0);
    }

    release_screen();
   }

   break;

  case 4:   /* VESA 2 16-bit - 320x200 */
  case 5:   /* VESA 2 16-bit - 320x240 */
  case 6:   /* VESA 2 16-bit - 640x480 */
  case 7:   /* Windows/X windowing system 16-bit - 640x480 */
#if 0
   {
    int ox, oy;

    out_position_x = (ScreenX > 256) ? (ScreenX - 256) / 2 : 0;
    out_size_x = (ScreenX < 256) ? ScreenX : 256;
    out_position_y = (ScreenY > 239) ? (ScreenY - 239) / 2 : 0;
    out_size_y = (ScreenY < Current_Line_Render) ? ScreenY : Current_Line_Render;

    acquire_screen();

    for (oy = 0; oy < out_size_y; oy++)
    {
     unsigned char *src_line_address = gbSNES_Screen8.subbitmap->line[oy];

     for (ox = 0; ox < out_size_x; ox++)
     {
      unsigned char color = src_line_address[ox];
      unsigned short color16 =
       ((unsigned short *)HICOLOUR_Palette)[color];

      _putpixel16(screen, out_position_x + ox, out_position_y + oy, color16);
     }
    }

    if (Current_Line_Render < 239 && Current_Line_Render < Last_Frame_Line)
    {
     /* fill unrendered area with black */
     rectfill(screen,
      out_position_x, out_position_y + Current_Line_Render,
      out_position_x + out_size_x - 1, out_position_y + Last_Frame_Line - 1,
      0);
    }

    release_screen();

    break;
   }
#else
   switch (stretch_x)
   {
    case 0:
     out_size_x = 256;
     out_position_x = (ScreenX - out_size_x) / 2;
     break;
    default:
     out_size_x = 256 * stretch_x;
     out_position_x = (ScreenX - out_size_x) / 2;
     break;
    case 1:
     out_position_x = 0;
     out_size_x = ScreenX;
     break;
   }

   switch (stretch_y)
   {
    case 0:
     out_size_y = 239;
     out_position_y = (ScreenY - out_size_y) / 2;
     break;
    default:
     out_size_y = 239 * stretch_y;
     out_position_y = (ScreenY - out_size_y) / 2;
     break;
    case 1:
     out_position_y = 0;
     out_size_y = ScreenY;
     break;
   }

   if (stretch_x || stretch_y)
   {
    if (Current_Line_Render < 239 && Current_Line_Render < Last_Frame_Line)
    {
     /* fill unrendered area with black */
     rectfill(gbSNES_Screen8.subbitmap,
      0, Current_Line_Render,
      255, Last_Frame_Line - 1,
      0);
    }

    blit(gbSNES_Screen8.subbitmap, gbSNES_Screen16.subbitmap,
     0, 0, 0, 0, 256, 239);

    acquire_screen();

    stretch_blit(gbSNES_Screen16.subbitmap, screen,
     0, 0, 256, 239,
     out_position_x, out_position_y, out_size_x, out_size_y);

    release_screen();
   }
   else
   {
    acquire_screen();

    blit(gbSNES_Screen8.subbitmap, screen, 0, 0, out_position_x, out_position_y,
     out_size_x, Current_Line_Render);

    if (Current_Line_Render < 239 && Current_Line_Render < Last_Frame_Line)
    {
     /* fill unrendered area with black */
     rectfill(screen,
      out_position_x, out_position_y + Current_Line_Render,
      out_position_x + out_size_x - 1, out_position_y + Last_Frame_Line - 1,
      0);
    }

    release_screen();
   }

   break;

#endif

  default:
   acquire_screen();

   blit(gbSNES_Screen8.subbitmap, screen, 0, 0, 0, 0, ScreenX, ScreenY);

   release_screen();
 }
}

#if defined(UNIX) || defined(__BEOS__)
void fnmerge(char *out, const char *drive, const char *dir, const char *file,
             const char *ext)
{
 out[0] = 0;
 if (strlen (drive))
  strcat(out, drive);
 if (strlen (dir))
 {
  strcat(out, dir);
  strcat(out, "/");
 }
 if (strlen (file))
  strcat(out, file);
 if (strlen (ext))
 {
  strcat(out, ".");
  strcat(out, ext);
 }
}

static void set_dir(char *dir, const char *in, const char *inptr)
{
 if (inptr > in + 1)
 {
  if (*(inptr - 2) == '.' && *(inptr - 1) == '.') /* check for ".." */
  {
   strcpy(dir, inptr - 2);
   return;
  }
 }
 else if (inptr > in)
 {
  if (*(inptr - 1) == '.')                        /* check for "." */
  {
   strcpy(dir, inptr - 1);
   return;
  }
 }
 /* NOT else! */
 strcpy(dir, in);
}

void fnsplit(const char *in0, char *drive, char *dir, char *file, char *ext)
/* Note: We assume "in0" points to a correct filename */
{
 struct stat fstate;
 char *p1, *p2, in[FILENAME_MAX];

 strcpy(in, in0);     /* don't modify in0 parameter */

 stat(in, &fstate);

 /* We're running on Unix or BeOS, so we don't check for a drive letter */
 *drive = 0;

 if ((p1 = strchr(in, '/')))
 {
  if (S_ISDIR(fstate.st_mode))
  {
   if (p1[1] == 0)    /* single trailing slash */
    strcpy(dir, in);
   else               /* "leading" slash */
    set_dir(dir, in, p1);
   *file = 0;
  }
  else
  {
   p2 = strrchr(in, '/');
   if (p1 == p2)      /* only one slash (must be a leading one) */
   {
    *p1 = 0;
    set_dir(dir, in, p1);
    strcpy(file, p1 + 1);
   }
   else
   {
    *p2 = 0;
    set_dir(dir, in, p1);
    strcpy(file, p2 + 1);
   }
  }
 }
 else                 /* no slash */
 {
  if (S_ISDIR(fstate.st_mode))
  {
   strcpy(dir, in);
   *file = 0;
  }
  else
  {
   *dir = 0;
   strcpy(file, in);
  }
 }

 if ((p1 = strrchr(file, '.')))
 {
  if (p1 > file)
  {
   strcpy(ext, p1);   /* save period in ext */
   *p1 = 0;
  }
  else                /* file name with leading period */
   *ext = 0;
 }
 else
  *ext = 0;
}
#endif
