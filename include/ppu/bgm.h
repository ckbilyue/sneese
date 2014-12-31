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

#ifndef BGM_SELF_INCLUDE

#define BGM_SELF_INCLUDE

#define SCREEN_HIRES 0
#include "ppu/bgm.h"
#undef SCREEN_HIRES

#define SCREEN_HIRES 1
#include "ppu/bgm.h"
#undef SCREEN_HIRES

#undef BGM_SELF_INCLUDE

#else   /* defined(BGM_SELF_INCLUDE) */

#ifndef BGM_SELF_INCLUDE_SIZES

#define BGM_SELF_INCLUDE_SIZES

#define SCREEN_BG_SIZE 0
#include "ppu/bgm.h"
#undef SCREEN_BG_SIZE

#define SCREEN_BG_SIZE 1
#include "ppu/bgm.h"
#undef SCREEN_BG_SIZE

#undef BGM_SELF_INCLUDE_SIZES

#else   /* defined(BGM_SELF_INCLUDE_SIZES) */

#if SCREEN_HIRES == 0

#if (SCREEN_BG_SIZE) == 0
#define SCREEN_TYPE 8x8
#define SCREEN_TILE_H_SHIFT 3
#define SCREEN_TILE_V_SHIFT 3
#else
#define SCREEN_TYPE 16x16
#define SCREEN_TILE_H_SHIFT 4
#define SCREEN_TILE_V_SHIFT 4
#endif

#define DOT_WIDTH_DIVISOR 1
#define RES_SUFFIX_L
#define RES_SUFFIX_U

#else   /* SCREEN_HIRES != 0 */

#define SCREEN_TILE_H_SHIFT 4

#if (SCREEN_BG_SIZE) == 0
#define SCREEN_TYPE 16x8
#define SCREEN_TILE_V_SHIFT 3
#else
#define SCREEN_TYPE 16x16
#define SCREEN_TILE_V_SHIFT 4
#endif

#define DOT_WIDTH_DIVISOR 2
#define RES_SUFFIX_L even_
#define RES_SUFFIX_U Even_

#define DISPATCH_EVEN_PLOTTER

#endif  /* SCREEN_HIRES != 0 */


#define SCREEN_TILE_WIDTH  (1 << SCREEN_TILE_H_SHIFT)
#define SCREEN_TILE_HEIGHT (1 << SCREEN_TILE_V_SHIFT)
#define SCREEN_WIDTH  (32 * SCREEN_TILE_WIDTH)
#define SCREEN_HEIGHT (32 * SCREEN_TILE_HEIGHT)


#define DISPATCH_MOSAIC_PLOTTER
#define DISPATCHER_SCREEN_TYPE SCREEN_TYPE

#define DISPATCH_PROTOTYPES_ONLY
#include "ppu/dispatch.h"
#undef DISPATCH_PROTOTYPES_ONLY


static void CONCAT_4_NAME(Render_, RES_SUFFIX_U, SCREEN_TYPE, M_Run)(
 unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2],
 unsigned output_surface_offset,
 unsigned char layers1, unsigned char layers2,

 BG_TABLE *bg_table,
 unsigned line_count,

 unsigned screen_line_address,
 unsigned tileset_address,
 unsigned tile_line_address, unsigned tile_line_address_y,

 unsigned next_pixel,
 int pixel_count,

 unsigned char depth_low, unsigned char depth_high,

 BGMODE_BG_TYPE plotter,
 unsigned palette_base
)
{
 const void *map_address;

 int clipped_count = MosaicCount[Mosaic_Size - 1][next_pixel];


 /* add in offset to our destination pointer */
 output_surface_offset += next_pixel;

 /* add in H-offset */
 next_pixel = MosaicLine[Mosaic_Size - 1][next_pixel] +
  (bg_table->hscroll & (SCREEN_WIDTH / DOT_WIDTH_DIVISOR - 1));

 /* check which horizontal section of the screen map we're starting in */
 if (next_pixel < SCREEN_WIDTH / DOT_WIDTH_DIVISOR)
 {
  map_address = bg_table->vl_map_address;
 }
 else
 {
  map_address = bg_table->vr_map_address;
  next_pixel -= SCREEN_WIDTH / DOT_WIDTH_DIVISOR;
 }

 /* add in offset to the first tile, in the line of the screen map we're on */
 map_address = (const unsigned char *) map_address + screen_line_address +
  (next_pixel / (SCREEN_TILE_WIDTH / DOT_WIDTH_DIVISOR)) * 2;

 if (clipped_count != Mosaic_Size)
 /* left-edge clipped run before screen map wrap */
 {
  if (clipped_count >= pixel_count) clipped_count = pixel_count;

  CONCAT_3_NAME(dispatch_mosaic_plotter_, RES_SUFFIX_L, SCREEN_TYPE)(plotter, map_address,
   tileset_address, tile_line_address, tile_line_address_y,
   main_buf, sub_buf, output_surface_offset,
   line_count, (next_pixel & (SCREEN_TILE_WIDTH / DOT_WIDTH_DIVISOR - 1)),
   clipped_count, depth_low, depth_high, palette_base);

  pixel_count -= clipped_count;
  if (pixel_count <= 0) return;

  output_surface_offset += clipped_count;
  map_address = (const unsigned char *) map_address +
   (((next_pixel + Mosaic_Size) / (SCREEN_TILE_WIDTH / DOT_WIDTH_DIVISOR)) -
   (next_pixel / (SCREEN_TILE_WIDTH / DOT_WIDTH_DIVISOR))) * 2;
  next_pixel += Mosaic_Size;

 }

 if (next_pixel < SCREEN_WIDTH / DOT_WIDTH_DIVISOR)
 /* handle remainder before screen map wrap */
 {
  int dots_before_wrap;

  if (next_pixel + pixel_count > SCREEN_WIDTH / DOT_WIDTH_DIVISOR)
  {
   dots_before_wrap = ((SCREEN_WIDTH / DOT_WIDTH_DIVISOR - 1) - next_pixel) +
    MosaicCount[Mosaic_Size - 1][(SCREEN_WIDTH / DOT_WIDTH_DIVISOR - 1) -
    next_pixel];

   if (dots_before_wrap >= pixel_count) dots_before_wrap = pixel_count;
  }
  else
  {
   dots_before_wrap = pixel_count;
  }

  CONCAT_3_NAME(dispatch_mosaic_plotter_, RES_SUFFIX_L, SCREEN_TYPE)(plotter, map_address,
   tileset_address, tile_line_address, tile_line_address_y,
   main_buf, sub_buf, output_surface_offset,
   line_count, (next_pixel & (SCREEN_TILE_WIDTH / DOT_WIDTH_DIVISOR - 1)),
   dots_before_wrap, depth_low, depth_high, palette_base);

  pixel_count -= dots_before_wrap;
  if (pixel_count <= 0) return;

  next_pixel += dots_before_wrap;
  output_surface_offset += dots_before_wrap;
 }

 next_pixel -= SCREEN_WIDTH / DOT_WIDTH_DIVISOR;

 map_address = (const unsigned char *) bg_table->vr_map_address +
  screen_line_address + (next_pixel / (SCREEN_TILE_WIDTH / DOT_WIDTH_DIVISOR)) * 2;

 /* handle remainder after screen map wrap */
 CONCAT_3_NAME(dispatch_mosaic_plotter_, RES_SUFFIX_L, SCREEN_TYPE)(plotter, map_address,
  tileset_address, tile_line_address, tile_line_address_y,
  main_buf, sub_buf, output_surface_offset,
  line_count, (next_pixel & (SCREEN_TILE_WIDTH / DOT_WIDTH_DIVISOR - 1)),
  pixel_count, depth_low, depth_high, palette_base);

}


 static void CONCAT_4_NAME(Render_, RES_SUFFIX_U, SCREEN_TYPE, M)(
 unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2],
 unsigned output_surface_offset,
 unsigned char layers1, unsigned char layers2,

 BGMODE_BG_TYPE plotter_base,

 unsigned char depth_low,
 unsigned char depth_high,

 BG_TABLE *bg_table,
 unsigned current_line,
 unsigned lines
)
{
 unsigned tileset_address = bg_table->set_address;
 unsigned lines_in_set;

 unsigned countdown = MosaicCountdown;
 unsigned current_line_mosaic = bg_table->line_counter;


 for (; lines > 0; current_line += lines_in_set, countdown -= lines_in_set,
  current_line_mosaic = !countdown ? current_line : current_line_mosaic,
  lines -= lines_in_set
 )
 {

  unsigned tile_line_address, tile_line_address_y;
  unsigned screen_line_address; /* VMapOffset */

  unsigned line_surface_offset;

  int first_window, num_windows;
  int window;

  BGMODE_BG_TYPE plotter;

  const LAYER_WIN_DATA *bg_win;

  int runs_left;
  const unsigned char (*bands)[2]; /* RunListPtr */

  if (!countdown) countdown = Mosaic_Size;
  lines_in_set = lines <= countdown ? lines : countdown;
  if (lines_in_set > 8) lines_in_set = 8;

  line_surface_offset = output_surface_offset;

  output_surface_offset += lines_in_set * 256;

  sort_screen_height(bg_table, current_line_mosaic);

  (!SCREEN_BG_SIZE ? sort_tiles_8_tall : sort_tiles_16_tall)(bg_table->vscroll,
   &tile_line_address, &tile_line_address_y, &screen_line_address,
   current_line_mosaic);

  plotter = plotter_base;

  plotter += (lines_in_set != 1) ? BBT_MULTI : 0;

  num_windows = setup_windows_for_layer(&first_window);


  for (window = 0; window < num_windows; window++)
  {
   unsigned char (*screen1)[2], (*screen2)[2];
   unsigned char arithmetic_used;

   arithmetic_used = setup_screens_for_layer(&screen1, &screen2,
    window, main_buf, sub_buf);
   if (!screen1) continue;

   bg_win = &bg_table->bg_win[first_window + window];

   runs_left = bg_win->count;
   bands = bg_win->bands;

   for (; runs_left--; bands++)
   {
    unsigned next_pixel;
    int pixel_count;

    /* (right edge + 1) - left edge */
    next_pixel = bands[0][0];
    pixel_count = (bands[0][1] ? bands[0][1] : 256) - bands[0][0];
    CONCAT_4_NAME(Render_, RES_SUFFIX_U, SCREEN_TYPE, M_Run)(
     screen1, screen2, line_surface_offset, layers1, layers2, bg_table,
     lines_in_set, screen_line_address, tileset_address,
     tile_line_address, tile_line_address_y, next_pixel, pixel_count,
     depth_low | arithmetic_used, depth_high | arithmetic_used,
     plotter, bg_table->mode_0_color);
   }

  }
 }
}



#define DO_PRIORITY_CHECK \
 (depth = !(map_hi & (BGSC_PRIORITY >> 8)) ? depth_low : depth_high);

#define CHECK_PRIORITY DO_PRIORITY_CHECK

#if SCREEN_HIRES == 0
#define PLOTTER_CALL_PAL plot_palettized_runs_mosaic
#define PLOTTER_CALL plot_runs_mosaic
#else   /* SCREEN_HIRES != 0 */
#define PLOTTER_CALL_PAL plot_palettized_even_runs_mosaic
#define PLOTTER_CALL plotter_call_error /* this should never get used */
#endif  /* SCREEN_HIRES != 0 */

#define PLOTTER_TYPE V_M
#include "ppu/plm.h"
#undef PLOTTER_TYPE
#undef PLOTTER_CALL
#undef PLOTTER_CALL_PAL

#if SCREEN_HIRES == 0
#define PLOTTER_CALL_PAL plot_palettized_run_mosaic
#define PLOTTER_CALL plot_run_mosaic
#else   /* SCREEN_HIRES != 0 */
#define PLOTTER_CALL_PAL plot_palettized_even_run_mosaic
#define PLOTTER_CALL plotter_call_error /* this should never get used */
#endif  /* SCREEN_HIRES != 0 */

#define PLOTTER_TYPE V
#include "ppu/plm.h"
#undef PLOTTER_TYPE
#undef PLOTTER_CALL
#undef PLOTTER_CALL_PAL

#undef CHECK_PRIORITY


#define CHECK_PRIORITY DO_PRIORITY_CHECK

#if SCREEN_HIRES == 0
#define PLOTTER_CALL_PAL plot_palettized_runs_mosaic
#define PLOTTER_CALL plot_runs_mosaic
#else   /* SCREEN_HIRES != 0 */
#define PLOTTER_CALL_PAL plot_palettized_even_runs_mosaic
#define PLOTTER_CALL plotter_call_error /* this should never get used */
#endif  /* SCREEN_HIRES != 0 */

#define PLOTTER_TYPE NP_M
#include "ppu/plm.h"
#undef PLOTTER_TYPE
#undef PLOTTER_CALL
#undef PLOTTER_CALL_PAL

#if SCREEN_HIRES == 0
#define PLOTTER_CALL_PAL plot_palettized_run_mosaic
#define PLOTTER_CALL plot_run_mosaic
#else   /* SCREEN_HIRES != 0 */
#define PLOTTER_CALL_PAL plot_palettized_even_run_mosaic
#define PLOTTER_CALL plotter_call_error /* this should never get used */
#endif  /* SCREEN_HIRES != 0 */

#define PLOTTER_TYPE NP
#include "ppu/plm.h"
#undef PLOTTER_TYPE
#undef PLOTTER_CALL
#undef PLOTTER_CALL_PAL

#undef CHECK_PRIORITY

#undef DO_PRIORITY_CHECK


#include "ppu/dispatch.h"
#undef DISPATCHER_SCREEN_TYPE
#undef DISPATCH_MOSAIC_PLOTTER

#ifdef SCREEN_HIRES
#undef DISPATCH_EVEN_PLOTTER
#endif


#undef RES_SUFFIX_U
#undef RES_SUFFIX_L
#undef DOT_WIDTH_DIVISOR

#undef SCREEN_HEIGHT
#undef SCREEN_WIDTH
#undef SCREEN_TILE_HEIGHT
#undef SCREEN_TILE_WIDTH
#undef SCREEN_TILE_V_SHIFT
#undef SCREEN_TILE_H_SHIFT
#undef SCREEN_TYPE


#endif  /* defined(BGM_SELF_INCLUDE_SIZES) */

#endif  /* defined(BGM_SELF_INCLUDE) */
