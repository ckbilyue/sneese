/*

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2015, Charles Bilyue.
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

#ifndef PASS2_SELF_INCLUDE

#include <stdio.h>
#include <string.h>
#include "helper.h"
#include "misc.h"
#include "snes.h"


extern unsigned char CGWSEL, CGADSUB;
extern union { colorBGR555 color; unsigned u; } COLDATA; /* TODO: eliminate this union */

static unsigned cg_translate_pixel_blank(const unsigned char (*pixel)[2])
/* forced-blank or off-screen area */
{
 return 0;
}

extern unsigned char INIDISP;

static unsigned cg_translate_pixel_pal(const unsigned char (*pixel)[2])
/* single-color translation */
{
 unsigned i;
 unsigned c;

 i = pixel[0][0];

 c = ((unsigned short *) Real_SNES_Palette)[i];

 return c;
}


#define GENERATE_DIRECT_COLOR_PALETTE(x) \
 ( (( (x)       & BIT(0)) << 1) | \
  (((((x) >> 1) & BIT(0)) << 1) <<  5) | \
  (((((x) >> 2) & BIT(0)) << 2) << 10))

static unsigned short direct_color_palette[8] =
{
 GENERATE_DIRECT_COLOR_PALETTE(0),
 GENERATE_DIRECT_COLOR_PALETTE(1),
 GENERATE_DIRECT_COLOR_PALETTE(2),
 GENERATE_DIRECT_COLOR_PALETTE(3),
 GENERATE_DIRECT_COLOR_PALETTE(4),
 GENERATE_DIRECT_COLOR_PALETTE(5),
 GENERATE_DIRECT_COLOR_PALETTE(6),
 GENERATE_DIRECT_COLOR_PALETTE(7)
};

static unsigned cg_translate_pixel_direct(const unsigned char (*pixel)[2])
/* single-color translation */
{
 unsigned i, p;
 unsigned r, g, b;
 unsigned c;

 i = pixel[0][0];
 p = pixel[0][1];

 r =  ((i & BITMASK(0,2)) << 1) << 1;

 g = (((i & BITMASK(3,5)) >> 3) << 1) << 1;

 b = (((i & BITMASK(6,7)) >> 6) << 1) << 2;

 c = r | (g << 5) | (b << 10) |
  direct_color_palette[(p & Z_PALETTE_BITS) >> Z_PALETTE_SHIFT];

 return c;
}


#define PASS2_SELF_INCLUDE

#define PASS2_TRANSLATION_MODE direct
#include "pass2.c"
#undef PASS2_TRANSLATION_MODE

#define PASS2_TRANSLATION_MODE pal
#include "pass2.c"
#undef PASS2_TRANSLATION_MODE

#define PASS2_TRANSLATION_MODE blank
#include "pass2.c"
#undef PASS2_TRANSLATION_MODE

#undef PASS2_SELF_INCLUDE

extern unsigned char Base_BGMODE;
extern unsigned char Layers_In_Use;
extern unsigned char Used_TM, Used_TS;

static unsigned short output_main[MAX_LINES_IN_SET * 256];
static unsigned short output_sub[MAX_LINES_IN_SET * 256];

enum
{
 CG_HALF_RESULT = BIT(6),
 CG_SUBTRACT    = BIT(7),
};

static void cg_clear(unsigned lines,
 unsigned first_pixel, unsigned last_pixel_plus_1)
{
 int y;

 for (y = 0; y < lines; y++)
 {
  memset(main_screen + y * 256 + first_pixel, 0,
   (last_pixel_plus_1 - first_pixel) * 2);
 }
}

static void cg_clear_for_arithmetic(unsigned lines,
 unsigned first_pixel, unsigned last_pixel_plus_1)
{
 unsigned char arithmetic_mode = CGADSUB & BIT(5) ? Z_ARITHMETIC_USED : 0;

 int y;

 for (y = 0; y < lines; y++)
 {
  int x;

  for (x = first_pixel; x < last_pixel_plus_1; x++)
  {
   main_screen[y * 256 + x][0] = 0;
   main_screen[y * 256 + x][1] = arithmetic_mode;
  }

  memset(sub_screen + y * 256 + first_pixel, 0,
   (last_pixel_plus_1 - first_pixel) * 2);
 }
}

void clear_scanlines(unsigned lines)
{
 int tmp_window;
 int windows_to_clear[2] = { OFFSET_COL_WIN_SUB, OFFSET_COL_WIN_NO_SUB };

 for (tmp_window = 0; tmp_window < 2; tmp_window++)
 {
  int window = windows_to_clear[tmp_window];
  const LAYER_WIN_DATA *col_win = &win_color[window];

  int runs_left;
  const unsigned char (*bands)[2]; /* RunListPtr */

  runs_left = col_win->count;
  bands = col_win->bands;

  for (; runs_left--; bands++)
  {
   unsigned first_pixel, last_pixel_plus_1;

   first_pixel = bands[0][0];
   last_pixel_plus_1 = (bands[0][1] ? bands[0][1] : 256);


   /* clear main screen */
   switch (window)
   {
   /* color arithmetic off */
   case OFFSET_COL_WIN_NO_SUB:
    cg_clear(lines, first_pixel, last_pixel_plus_1);
	break;

   /* color arithmetic on */
   case OFFSET_COL_WIN_SUB:
    cg_clear_for_arithmetic(lines,
     first_pixel, last_pixel_plus_1);
	break;

   }

  }

 }
}

/* Thanks to Blargg for fast 15-bit blending algorithms */
void cg_process_arithmetic(unsigned short *main_buf, unsigned short *sub_buf,
 int lines, int first_pixel, int last_pixel_plus_1,
 int do_all, int arithmetic_mode)
{
 unsigned char screen_arithmetic = CGWSEL & BIT(1);
 int y;

 for (y = 0; y < lines; y++)
 {
  int x;

  for (x = first_pixel; x < last_pixel_plus_1; x++)
  {
   if (do_all ||
    (main_screen[y * 256 + x][1] & Z_ARITHMETIC_USED))
   {
	const unsigned short color_lsb = BIT(0) | BIT(5) | BIT(10);
	const unsigned short color_msb = BIT(4) | BIT(9) | BIT(14);
    const unsigned short color_halfsub_lost_bits = color_lsb | BIT(15);
    unsigned short sum, carry;
    unsigned short diff, borrow;

    unsigned short main_color, sub_color;

    main_color = main_buf[y * 256 + x];
    sub_color = screen_arithmetic ? sub_buf[y * 256 + x] : COLDATA.u;

    /* if half-result disabled, or using screen arithmetic with back
	  area of sub-screen */
    if (!(arithmetic_mode & CG_HALF_RESULT) || (screen_arithmetic &&
     !(sub_screen[y * 256 + x][1] & Z_DEPTH_BITS)))
    /* full-result */
    {
     if (!(arithmetic_mode & CG_SUBTRACT))
     /* addition */
     {
      sum = main_color + sub_color;
      carry = (sum - ((main_color ^ sub_color) & color_lsb)) &
       (color_msb * 2);

      main_color = (sum - carry) | (carry - (carry >> 5));
     }
     else
     /* subtraction */
     {
      diff   = main_color - sub_color + color_msb * 2;
      borrow = (diff - ((main_color ^ sub_color) & (color_msb * 2))) &
       (color_msb * 2);

      main_color = (diff - borrow) & (borrow - (borrow >> 5));
	 }
	}
	else
    /* half-result */
	{
     if (!(arithmetic_mode & CG_SUBTRACT))
     /* addition */
	 {
      main_color = (main_color + sub_color - ((main_color ^ sub_color) &
       color_lsb)) >> 1;
	 }
	 else
     /* subtraction */
	 {
      diff   = main_color - sub_color + (color_msb * 2);
      borrow = (diff - ((main_color ^ sub_color) & (color_msb * 2))) &
       (color_msb * 2);

      main_color = (((diff - borrow) & (borrow - (borrow >> 5))) &
       ~color_halfsub_lost_bits) >> 1;
	 }
	}

    main_buf[y * 256 + x] = main_color;
   }

  }
 }
}


void cg_translate_output(unsigned current_line, unsigned lines)
{
 int y;

 for (y = 0; y < lines; y++)
 {
  int x;

  for (x = 0; x < 256; x++)
  {
   unsigned short c_in, c_out;
   unsigned brightness = INIDISP & BITMASK(0,3);
   unsigned r, g, b;

   c_in = output_main[y * 256 + x];

   r = c_in & BITMASK( 0, 4);
   g = (c_in & BITMASK( 5, 9)) >>  5;
   b = (c_in & BITMASK(10,15)) >> 10;

   /* TODO: remove platform dependant code here */
   c_out = makecol16(
    (r * (brightness + 1)) / 2,
    (g * (brightness + 1)) / 2,
    (b * (brightness + 1)) / 2);

   ((unsigned short *) ((BITMAP *) gbSNES_Screen16.subbitmap)->line
    [y + current_line])[x] = c_out;
  }
 }
}


void cg_translate(unsigned current_line, unsigned lines)
{
 int direct_color_enabled =
  /* direct color enabled */
  ((CGWSEL & BIT(0)) &&
  /* 8-bpp BG1 */
  (Base_BGMODE == 3 || Base_BGMODE == 4 || Base_BGMODE == 7)) ?
  1 : 0;

 /* compensate for blank line 0 */
 current_line--;

 if (!(INIDISP & 0x80))
 /* screen on */
 {
  int window;

  for (window = OFFSET_COL_WIN_OUTPUT_FIRST; window <= OFFSET_COL_WIN_OUTPUT_LAST;
   window++)
  {
   const LAYER_WIN_DATA *col_win = &win_color[window];

   int runs_left;
   const unsigned char (*bands)[2]; /* RunListPtr */

   int arithmetic_mode = CGADSUB & (CG_HALF_RESULT | CG_SUBTRACT);

   runs_left = col_win->count;
   bands = col_win->bands;

   for (; runs_left--; bands++)
   {
    unsigned first_pixel, last_pixel_plus_1;

    first_pixel = bands[0][0];
    last_pixel_plus_1 = (bands[0][1] ? bands[0][1] : 256);


    /* setup color for main screen */
    switch (window)
    {
    /* main screen color off w/o color arithmetic = always black */
    case OFFSET_COL_WIN_MAIN_OFF_NO_COL:
    /* main screen color off w/ color arithmetic */
    case OFFSET_COL_WIN_MAIN_OFF:
     cg_translate_blank(output_main, -1,
      (const unsigned char (*)[2]) main_screen,
      lines, first_pixel, last_pixel_plus_1, 1);
     break;

    /* main screen color on w/o color arithmetic */
    case OFFSET_COL_WIN_MAIN_ON_NO_COL:
    /* main screen color on w/ color arithmetic */
    case OFFSET_COL_WIN_MAIN_ON:
     if (direct_color_enabled &&
      /* BG1 on */
      (Used_TM & BIT(0)))
     {
      cg_translate_pal(output_main, 0,
       (const unsigned char (*)[2]) main_screen,
       lines, first_pixel, last_pixel_plus_1, 0);
      cg_translate_direct(output_main, Z_DIRECT_COLOR_USED,
       (const unsigned char (*)[2]) main_screen,
       lines, first_pixel, last_pixel_plus_1, 0);
     }
     else
     {
      cg_translate_pal(output_main, 0,
       (const unsigned char (*)[2]) main_screen,
       lines, first_pixel, last_pixel_plus_1, 1);
     }

#if 0
	 {
      int x, y;
	  for (y = 0; y < lines; y++)
	  {
       for (x = first_pixel; x < last_pixel_plus_1; x++)
	   {
        if (window == OFFSET_COL_WIN_MAIN_ON)
         output_main[y * 256 + x] |= BITMASK(10,14);
	   }
	  }
	 }
#endif
     break;

    }

    /* setup color for sub screen */
    switch (window)
    {
    /* main screen color off w/o color arithmetic = always black */
    case OFFSET_COL_WIN_MAIN_OFF_NO_COL:
    /* main screen color on w/o color arithmetic */
    case OFFSET_COL_WIN_MAIN_ON_NO_COL:
     break;

    /* main screen color off w/ color arithmetic */
    case OFFSET_COL_WIN_MAIN_OFF:
     /* subtraction mode */
     if (CGADSUB & CG_SUBTRACT)
      break;

     arithmetic_mode &= ~CG_HALF_RESULT;

    /* main screen color on w/ color arithmetic */
    case OFFSET_COL_WIN_MAIN_ON:
     /* screen arithmetic enabled */
     if (CGWSEL & BIT(1))
	 {
      colorBGR555 temp_color_0 = Real_SNES_Palette[0];

      Real_SNES_Palette[0] = COLDATA.color;

      if (direct_color_enabled &&
       /* BG1 on */
       (Used_TS & BIT(0)))
      {
       cg_translate_pal(output_sub, 0,
        (const unsigned char (*)[2]) sub_screen,
        lines, first_pixel, last_pixel_plus_1, 0);
       cg_translate_direct(output_sub, Z_DIRECT_COLOR_USED,
        (const unsigned char (*)[2]) sub_screen,
        lines, first_pixel, last_pixel_plus_1, 0);
      }
      else
      {
       cg_translate_pal(output_sub, 0,
        (const unsigned char (*)[2]) sub_screen,
        lines, first_pixel, last_pixel_plus_1, 1);
      }

	  Real_SNES_Palette[0] = temp_color_0;
	 }

     cg_process_arithmetic(output_main, output_sub, lines,
      first_pixel, last_pixel_plus_1,
	  (CGADSUB & (Used_TM | BIT(5))) == (Used_TM | BIT(5)) ? 1 : 0,
	  arithmetic_mode);

     break;

    }

   }
  }

 }
 else
 /* screen off */
 {
  /* clear applicable portion of framebuffer */
  cg_translate_blank(output_main, -1,
   (const unsigned char (*)[2]) main_screen,
   lines, 0, 256, 1);
 }

 cg_translate_output(current_line, lines);

}

void cg_translate_finish(void)
{
 static unsigned last_frame_line = 224;

 /* -1 to compensate for first blank line; +1 to start on blanked lines */
 int current_line = (Current_Line_Render - 1) + 1;
 int lines = last_frame_line - current_line;

 if (lines > 0)
 {
  cg_translate_blank(output_main, -1,
   (const unsigned char (*)[2]) main_screen,
   lines, 0, 256, 1);
  cg_translate_output(current_line, lines);
 }

 last_frame_line = Current_Line_Render - 1;
}


#else   /* defined(PASS2_SELF_INCLUDE) */

static void CONCAT_NAME(cg_translate_, PASS2_TRANSLATION_MODE)(
 unsigned short *output, int mode, const unsigned char (*screen)[2],
 int lines, int first_pixel, int last_pixel_plus_1, int do_all)
{
 int y;

 for (y = 0; y < lines; y++)
 {
  int x;

  for (x = first_pixel; x < last_pixel_plus_1; x++)
  {
   if (do_all ||
    ((screen[y * 256 + x][1] & Z_DIRECT_COLOR_USED) == mode))
   {
    output[y * 256 + x] =
     CONCAT_NAME(cg_translate_pixel_, PASS2_TRANSLATION_MODE)(
      screen + y * 256 + x);
   }
  }
 }
}

#endif  /* defined(PASS2_SELF_INCLUDE) */
