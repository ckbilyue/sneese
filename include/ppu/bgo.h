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

#ifndef BGO_SELF_INCLUDE

#define BGO_SELF_INCLUDE

#define SCREEN_HIRES 0
#include "ppu/bgo.h"
#undef SCREEN_HIRES

#define SCREEN_HIRES 1
#include "ppu/bgo.h"
#undef SCREEN_HIRES

#undef BGO_SELF_INCLUDE

#else   /* defined(BGO_SELF_INCLUDE) */

#ifndef BGO_SELF_INCLUDE_SIZES

#define BGO_SELF_INCLUDE_SIZES

#define OFFSET_BG_SIZE 0
#define SCREEN_BG_SIZE 0
#include "ppu/bgo.h"
#undef SCREEN_BG_SIZE

#define SCREEN_BG_SIZE 1
#include "ppu/bgo.h"
#undef SCREEN_BG_SIZE
#undef OFFSET_BG_SIZE


#define OFFSET_BG_SIZE 1
#define SCREEN_BG_SIZE 0
#include "ppu/bgo.h"
#undef SCREEN_BG_SIZE

#define SCREEN_BG_SIZE 1
#include "ppu/bgo.h"
#undef SCREEN_BG_SIZE
#undef OFFSET_BG_SIZE

#undef BGO_SELF_INCLUDE_SIZES

#else   /* defined(BGO_SELF_INCLUDE_SIZES) */

#if SCREEN_HIRES == 0

#if (OFFSET_BG_SIZE) == 0
#define OFFSET_TYPE 8x8
#define OFFSET_TILE_H_SHIFT 3
#define OFFSET_TILE_V_SHIFT 3
#else
#define OFFSET_TYPE 16x16
#define OFFSET_TILE_H_SHIFT 4
#define OFFSET_TILE_V_SHIFT 4
#endif

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

#define OFFSET_TILE_H_SHIFT 4
#define SCREEN_TILE_H_SHIFT 4

#if (OFFSET_BG_SIZE) == 0
#define OFFSET_TYPE 16x8
#define OFFSET_TILE_V_SHIFT 3
#else
#define OFFSET_TYPE 16x16
#define OFFSET_TILE_V_SHIFT 4
#endif

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


#define OFFSET_TILE_WIDTH  (1 << OFFSET_TILE_H_SHIFT)
#define OFFSET_TILE_HEIGHT (1 << OFFSET_TILE_V_SHIFT)
#define OFFSET_SC_WIDTH  (32 * OFFSET_TILE_WIDTH)
#define OFFSET_SC_HEIGHT (32 * OFFSET_TILE_HEIGHT)

#define SCREEN_TILE_WIDTH  (1 << SCREEN_TILE_H_SHIFT)
#define SCREEN_TILE_HEIGHT (1 << SCREEN_TILE_V_SHIFT)
#define SCREEN_WIDTH  (32 * SCREEN_TILE_WIDTH)
#define SCREEN_HEIGHT (32 * SCREEN_TILE_HEIGHT)


#define DISPATCHER_SCREEN_TYPE SCREEN_TYPE
#define DISPATCHER_OFFSET_TYPE OFFSET_TYPE

#define DISPATCH_PROTOTYPES_ONLY
#include "ppu/dispatch.h"
#undef DISPATCH_PROTOTYPES_ONLY


static void CONCAT_6_NAME(Render_, RES_SUFFIX_U, SCREEN_TYPE, _Offset_, OFFSET_TYPE, _Run)(
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
 unsigned current_line,
 unsigned char oc_flag,

 unsigned offset_v_map_difference,

 const void *t_map_address,
 const void *b_map_address,
 
 unsigned r_map_difference,
 unsigned first_tile_offset,

 const void *map_address_current
)
{
 const void *offset_map_address;
 unsigned offset_map_first_tile_offset;

 int tile_on_line_offset = ((next_pixel + (bg_table->hscroll &
  ((8 / DOT_WIDTH_DIVISOR) - 1))) / (8 / DOT_WIDTH_DIVISOR));


 /* add in offset to our destination pointer */
 output_surface_offset += next_pixel;

 /* add in H-offset */
 next_pixel += (bg_table_3.hscroll & ((OFFSET_SC_WIDTH - 8) /
  DOT_WIDTH_DIVISOR)) + (bg_table->hscroll & ((8 / DOT_WIDTH_DIVISOR) - 1));

 /* check which horizontal section of the screen map we're starting in */
 if (next_pixel < (OFFSET_SC_WIDTH + 8) / DOT_WIDTH_DIVISOR)
 {
  offset_map_address = bg_table_3.vl_map_address;
 }
 else
 {
  offset_map_address = bg_table_3.vr_map_address;
  next_pixel -= OFFSET_SC_WIDTH / DOT_WIDTH_DIVISOR;
 }

 offset_map_address = (const unsigned char *) offset_map_address +
   (((bg_table_3.vscroll >> OFFSET_TILE_V_SHIFT) & 31) * (2 * 32));

 offset_map_first_tile_offset = ((((bg_table_3.hscroll &
  ((OFFSET_SC_WIDTH - 8) / DOT_WIDTH_DIVISOR)) + (bg_table->hscroll &
  ((8 / DOT_WIDTH_DIVISOR) - 1))) / (8 / DOT_WIDTH_DIVISOR)) - 1);


 if (next_pixel & ((8 / DOT_WIDTH_DIVISOR) - 1))
 /* left-edge clipped tile before screen map wrap */
 {
  /* set up left edge clipping */
  tile_clip_1_left  = * (const unsigned *)
   (clip_left_table +   - (next_pixel & ((8 / DOT_WIDTH_DIVISOR) - 1)));
#if !SCREEN_HIRES
  tile_clip_1_right = * (const unsigned *)
   (clip_left_table + 4 - (next_pixel & ((8 / DOT_WIDTH_DIVISOR) - 1)));
#endif  /* !SCREEN_HIRES */

  if ((((8 / DOT_WIDTH_DIVISOR) - 1) ^ ((next_pixel & ((8 / DOT_WIDTH_DIVISOR) - 1)) - (8 / DOT_WIDTH_DIVISOR))) - pixel_count < 0)
  /* right-edge clip */
  {
   /* set up right edge clipping */
   tile_clip_1_left  &= * (const unsigned *) (clip_right_table + 0 -
    (next_pixel & ((8 / DOT_WIDTH_DIVISOR) - 1)) - pixel_count);
   tile_clip_1_right &= * (const unsigned *) (clip_right_table + 4 -
    (next_pixel & ((8 / DOT_WIDTH_DIVISOR) - 1)) - pixel_count);
  }

  /* fixup pixel counters */
  output_surface_offset -= (next_pixel & ((8 / DOT_WIDTH_DIVISOR) - 1));
  /* -= (8 / DOT_WIDTH_DIVISOR) - (next_pixel & ((8 / DOT_WIDTH_DIVISOR) - 1)) */
  pixel_count += (next_pixel & ((8 / DOT_WIDTH_DIVISOR) - 1)) -
   (8 / DOT_WIDTH_DIVISOR);
  /* += (8 / DOT_WIDTH_DIVISOR) - (next_pixel & ((8 / DOT_WIDTH_DIVISOR) - 1)) */
  next_pixel -= (next_pixel & ((8 / DOT_WIDTH_DIVISOR) - 1)) -
   (8 / DOT_WIDTH_DIVISOR);

  CONCAT_5_NAME(dispatch_plotter_, RES_SUFFIX_L, SCREEN_TYPE, _offset_, OFFSET_TYPE)(plotter, offset_map_address, tileset_address,
   tile_line_address, tile_line_address_y,
   main_buf, sub_buf, output_surface_offset, line_count, 1,
   depth_low, depth_high, current_line, oc_flag,
   offset_v_map_difference, t_map_address, b_map_address, r_map_difference,
   first_tile_offset, offset_map_first_tile_offset, map_address_current,
   tile_on_line_offset);

  if (pixel_count <= 0) return;

  output_surface_offset += (8 / DOT_WIDTH_DIVISOR);
  tile_on_line_offset++;
 }

 tile_clip_1_left = tile_clip_1_right = (0 - 1);

 if (next_pixel != (OFFSET_SC_WIDTH + 8) / DOT_WIDTH_DIVISOR)
 /* handle remainder before screen map wrap */
 {
  int dots_before_wrap, whole_tiles_before_wrap;

  dots_before_wrap = ((OFFSET_SC_WIDTH + 8) / DOT_WIDTH_DIVISOR) -
   next_pixel;

  if (dots_before_wrap >= pixel_count) dots_before_wrap = pixel_count;

  whole_tiles_before_wrap = dots_before_wrap / (8 / DOT_WIDTH_DIVISOR);
  dots_before_wrap %= (8 / DOT_WIDTH_DIVISOR);

  if (whole_tiles_before_wrap)
  /* unclipped tiles before screen map wrap */
  {
   CONCAT_5_NAME(dispatch_plotter_, RES_SUFFIX_L, SCREEN_TYPE, _offset_, OFFSET_TYPE)(plotter, offset_map_address, tileset_address,
    tile_line_address, tile_line_address_y,
    main_buf, sub_buf, output_surface_offset, line_count,
    whole_tiles_before_wrap, depth_low, depth_high, current_line,
    oc_flag, offset_v_map_difference, t_map_address, b_map_address,
    r_map_difference, first_tile_offset, offset_map_first_tile_offset,
    map_address_current, tile_on_line_offset);

   pixel_count -= whole_tiles_before_wrap * (8 / DOT_WIDTH_DIVISOR);

   if (pixel_count <= 0) return;
   next_pixel += whole_tiles_before_wrap * (8 / DOT_WIDTH_DIVISOR);

   output_surface_offset += whole_tiles_before_wrap * (8 / DOT_WIDTH_DIVISOR);
   tile_on_line_offset += whole_tiles_before_wrap;
  }

  if (dots_before_wrap)
  /* right-edge clipped tile before screen map wrap */
  {
   /* set up right edge clipping */
   tile_clip_1_left  = * (const unsigned *) (clip_right_table +   - pixel_count);
   tile_clip_1_right = * (const unsigned *) (clip_right_table + 4 - pixel_count);

   CONCAT_5_NAME(dispatch_plotter_, RES_SUFFIX_L, SCREEN_TYPE, _offset_, OFFSET_TYPE)(plotter, offset_map_address, tileset_address,
    tile_line_address, tile_line_address_y,
    main_buf, sub_buf, output_surface_offset, line_count, 1,
    depth_low, depth_high, current_line, oc_flag,
    offset_v_map_difference, t_map_address, b_map_address, r_map_difference,
    first_tile_offset, offset_map_first_tile_offset, map_address_current,
    tile_on_line_offset);

   return;
  }

 }

 offset_map_address = bg_table_3.vr_map_address;

 offset_map_address = (const unsigned char *) offset_map_address +
   (((bg_table_3.vscroll >> OFFSET_TILE_V_SHIFT) & 31) * (2 * 32));

 /* handle remainder after screen map wrap */
 {
  int dots_after_wrap, whole_tiles_after_wrap;

  dots_after_wrap = pixel_count;

  whole_tiles_after_wrap = dots_after_wrap / (8 / DOT_WIDTH_DIVISOR);
  dots_after_wrap %= (8 / DOT_WIDTH_DIVISOR);

  if (whole_tiles_after_wrap)
  /* unclipped tiles after screen map wrap */
  {
   CONCAT_5_NAME(dispatch_plotter_, RES_SUFFIX_L, SCREEN_TYPE, _offset_, OFFSET_TYPE)(plotter, offset_map_address, tileset_address,
    tile_line_address, tile_line_address_y,
    main_buf, sub_buf, output_surface_offset, line_count,
    whole_tiles_after_wrap, depth_low, depth_high, current_line, oc_flag,
    offset_v_map_difference, t_map_address, b_map_address, r_map_difference,
    first_tile_offset, offset_map_first_tile_offset, map_address_current,
    tile_on_line_offset);

   pixel_count -= whole_tiles_after_wrap * (8 / DOT_WIDTH_DIVISOR);

   if (pixel_count <= 0) return;
   next_pixel += whole_tiles_after_wrap * (8 / DOT_WIDTH_DIVISOR);

   output_surface_offset += whole_tiles_after_wrap * (8 / DOT_WIDTH_DIVISOR);
   tile_on_line_offset += whole_tiles_after_wrap;
  }

  if (dots_after_wrap)
  /* right-edge clipped tile after screen map wrap */
  {
   /* set up right edge clipping */
   tile_clip_1_left  = * (const unsigned *) (clip_right_table +   - pixel_count);
   tile_clip_1_right = * (const unsigned *) (clip_right_table + 4 - pixel_count);

   CONCAT_5_NAME(dispatch_plotter_, RES_SUFFIX_L, SCREEN_TYPE, _offset_, OFFSET_TYPE)(plotter, offset_map_address, tileset_address,
    tile_line_address, tile_line_address_y,
    main_buf, sub_buf, output_surface_offset, line_count, 1,
    depth_low, depth_high, current_line, oc_flag,
    offset_v_map_difference, t_map_address, b_map_address, r_map_difference,
    first_tile_offset, offset_map_first_tile_offset, map_address_current,
    tile_on_line_offset);

   return;
  }
 }
}


static void CONCAT_5_NAME(Render_, RES_SUFFIX_U, SCREEN_TYPE, _Offset_, OFFSET_TYPE)(
 unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2],
 unsigned output_surface_offset,
 unsigned char layers1, unsigned char layers2,

 BGMODE_BG_TYPE plotter_base,

 unsigned char depth_low,
 unsigned char depth_high,

 BG_TABLE *bg_table,
 unsigned current_line,
 unsigned lines
// void *output_surface //,
// int screen_select  /* main, sub, both */
)
{
 unsigned tileset_address = bg_table->set_address;
 unsigned char oc_flag = bg_table->oc_flag;

 unsigned offset_v_map_difference = (((bg_table_3.vscroll & (OFFSET_TILE_HEIGHT - 1)) + 8) <
  OFFSET_TILE_HEIGHT) ? 0 : ((bg_table_3.vscroll & (OFFSET_SC_HEIGHT - 1)) + 8) <
  OFFSET_SC_HEIGHT ? (2 * 32) : (!((bg_table_3.vscroll + 8) & OFFSET_SC_HEIGHT)) ?
  bg_table_3.bl_map_address - bg_table_3.tl_map_address :
  bg_table_3.tl_map_address - bg_table_3.bl_map_address;


 const void *t_map_address = bg_table->tl_map_address;
 const void *b_map_address = bg_table->bl_map_address;

 unsigned r_map_difference = (unsigned char *) bg_table->tr_map_address -
  (unsigned char *) bg_table->tl_map_address;

 unsigned first_tile_offset = bg_table->hscroll / (8 / DOT_WIDTH_DIVISOR);

 const void *map_address_current;


 sort_screen_height(&bg_table_3, 0);

 for (; lines > 0; current_line++, lines--)
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


  line_surface_offset = output_surface_offset;

  output_surface_offset += 256;

  (!SCREEN_BG_SIZE ? sort_tiles_8_tall : sort_tiles_16_tall)(bg_table->vscroll,
   &tile_line_address, &tile_line_address_y, &screen_line_address,
   current_line);

  /* add in offset to the first tile, in the line of the screen map we're on */
  map_address_current = (!((bg_table->vscroll + current_line) & SCREEN_HEIGHT) ?
   bg_table->tl_map_address : bg_table->tr_map_address);
  
  map_address_current = (unsigned char *) map_address_current +
   screen_line_address;


  plotter = plotter_base;

//plotter += (lines_in_set != 1) ? BBT_MULTI : 0;

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
    CONCAT_6_NAME(Render_, RES_SUFFIX_U, SCREEN_TYPE, _Offset_, OFFSET_TYPE, _Run)(
     screen1, screen2, line_surface_offset, layers1, layers2, 
     bg_table, 1, screen_line_address, tileset_address,
     tile_line_address, tile_line_address_y,
     next_pixel, pixel_count,
     depth_low | arithmetic_used, depth_high | arithmetic_used,
     plotter, current_line,
     oc_flag, offset_v_map_difference, t_map_address, b_map_address,
     r_map_difference, first_tile_offset, map_address_current);
   }

  }
 }
}



#define DO_PRIORITY_CHECK \
 (depth = !(map_hi & (BGSC_PRIORITY >> 8)) ? depth_low : depth_high);

#define CHECK_PRIORITY DO_PRIORITY_CHECK

#if SCREEN_HIRES == 0
#define PLOTTER_CALL_PAL plot_palettized_line
#define PLOTTER_CALL plot_line
#else   /* SCREEN_HIRES != 0 */
#define PLOTTER_CALL_PAL plot_palettized_even_line
#define PLOTTER_CALL plotter_call_error /* this should never get used */
#endif  /* SCREEN_HIRES != 0 */

#define PLOTTER_TYPE V
#include "ppu/plo.h"
#undef PLOTTER_TYPE
#undef PLOTTER_CALL
#undef PLOTTER_CALL_PAL

#undef CHECK_PRIORITY


#define CHECK_PRIORITY DO_PRIORITY_CHECK

#if SCREEN_HIRES == 0
#define PLOTTER_CALL_PAL plot_palettized_line
#define PLOTTER_CALL plot_line
#else   /* SCREEN_HIRES != 0 */
#define PLOTTER_CALL_PAL plot_palettized_even_line
#define PLOTTER_CALL plotter_call_error /* this should never get used */
#endif  /* SCREEN_HIRES != 0 */

#define PLOTTER_TYPE NP
#include "ppu/plo.h"
#undef PLOTTER_TYPE
#undef PLOTTER_CALL
#undef PLOTTER_CALL_PAL

#undef CHECK_PRIORITY

#undef DO_PRIORITY_CHECK

#include "ppu/dispatch.h"
#undef DISPATCHER_OFFSET_TYPE
#undef DISPATCHER_SCREEN_TYPE

#ifdef SCREEN_HIRES
#undef DISPATCH_EVEN_PLOTTER
#endif


#undef RES_SUFFIX_U
#undef RES_SUFFIX_L
#undef DOT_WIDTH_DIVISOR

#undef OFFSET_TILE_HEIGHT
#undef OFFSET_TILE_WIDTH
#undef OFFSET_TILE_V_SHIFT
#undef OFFSET_TILE_H_SHIFT
#undef OFFSET_SC_HEIGHT
#undef OFFSET_SC_WIDTH
#undef OFFSET_TYPE
#undef SCREEN_HEIGHT
#undef SCREEN_WIDTH
#undef SCREEN_TILE_HEIGHT
#undef SCREEN_TILE_WIDTH
#undef SCREEN_TILE_V_SHIFT
#undef SCREEN_TILE_H_SHIFT
#undef SCREEN_TYPE


#endif  /* defined(BGO_SELF_INCLUDE_SIZES) */

#endif  /* defined(BGO_SELF_INCLUDE) */
