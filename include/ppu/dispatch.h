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

#ifndef DISPATCHER_OFFSET_TYPE

#ifndef DISPATCH_MOSAIC_PLOTTER

#ifndef DISPATCH_PLOTTER_EXPANSION

static void CONCAT_3_NAME(dispatch_plotter_, RES_SUFFIX_L, DISPATCHER_SCREEN_TYPE) (BGMODE_BG_TYPE plotter,
 const void *map_address, unsigned tileset_address,
 unsigned tile_line_address, unsigned tile_line_address_y,
 unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2],
 unsigned output_surface_offset, int line_count, int tile_count,
 unsigned char depth_low, unsigned char depth_high, unsigned palette_base)
#ifdef DISPATCH_PROTOTYPES_ONLY
;
#else   /* !defined(DISPATCH_PROTOTYPES_ONLY) */
{
#define DISPATCH_PLOTTER_EXPANSION
 if (!(plotter & BBT_NO_PRI))
 {
  if (plotter & BBT_MULTI)
  {
#define PLOTTER_TYPE V_M
#include "ppu/dispatch.h"
#undef PLOTTER_TYPE
  }
  else
  {
#define PLOTTER_TYPE V
#include "ppu/dispatch.h"
#undef PLOTTER_TYPE
  }
 }
 else
 {
  if (plotter & BBT_MULTI)
  {
#define PLOTTER_TYPE NP_M
#include "ppu/dispatch.h"
#undef PLOTTER_TYPE
  }
  else
  {
#define PLOTTER_TYPE NP
#include "ppu/dispatch.h"
#undef PLOTTER_TYPE
  }
 }
#undef DISPATCH_PLOTTER_EXPANSION
}
#endif  /* !defined(DISPATCH_PROTOTYPES_ONLY) */


#else   /* defined(DISPATCH_PLOTTER_EXPANSION) */

 switch (plotter & BBT_BASE)
 {
#if !SCREEN_HIRES
  case BBT_2BPP:
  case BBT_2BPP_PAL:
#else
  case BBT_2BPP_HI:
#endif
   CONCAT_5_NAME(Plot_Lines_, RES_SUFFIX_U, DISPATCHER_SCREEN_TYPE, _C2_, PLOTTER_TYPE) (
    map_address, tileset_address,
    tile_line_address, tile_line_address_y,
    main_buf, sub_buf, output_surface_offset, line_count,
    tile_count, depth_low, depth_high, palette_base);
   break;
#if !SCREEN_HIRES
  case BBT_4BPP:
#else
  case BBT_4BPP_HI:
#endif
   CONCAT_5_NAME(Plot_Lines_, RES_SUFFIX_U, DISPATCHER_SCREEN_TYPE, _C4_, PLOTTER_TYPE) (
    map_address, tileset_address,
    tile_line_address, tile_line_address_y,
    main_buf, sub_buf, output_surface_offset, line_count,
    tile_count, depth_low, depth_high, palette_base);
   break;
  case BBT_8BPP:
#if !SCREEN_HIRES
   CONCAT_5_NAME(Plot_Lines_, RES_SUFFIX_U, DISPATCHER_SCREEN_TYPE, _C8_, PLOTTER_TYPE) (
    map_address, tileset_address,
    tile_line_address, tile_line_address_y,
    main_buf, sub_buf, output_surface_offset, line_count,
    tile_count, depth_low, depth_high, palette_base);
#endif
   break;
  default:
  /* not handled here */
   break;
 }
#endif  /* defined(DISPATCH_PLOTTER_EXPANSION) */

#else   /* defined(DISPATCH_MOSAIC_PLOTTER) */

#ifndef DISPATCH_PLOTTER_EXPANSION

static void CONCAT_3_NAME(dispatch_mosaic_plotter_, RES_SUFFIX_L, DISPATCHER_SCREEN_TYPE) (BGMODE_BG_TYPE plotter,
 const void *map_address, unsigned tileset_address,
 unsigned tile_line_address, unsigned tile_line_address_y,
 unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2],
 unsigned output_surface_offset, int line_count,
 int pixel_in_tile, int pixel_count,
 unsigned char depth_low, unsigned char depth_high, unsigned palette_base)
#ifdef DISPATCH_PROTOTYPES_ONLY
;
#else   /* !defined(DISPATCH_PROTOTYPES_ONLY) */
{
#define DISPATCH_PLOTTER_EXPANSION
 if (!(plotter & BBT_NO_PRI))
 {
  if (plotter & BBT_MULTI)
  {
#define PLOTTER_TYPE V_M
#include "ppu/dispatch.h"
#undef PLOTTER_TYPE
  }
  else
  {
#define PLOTTER_TYPE V
#include "ppu/dispatch.h"
#undef PLOTTER_TYPE
  }
 }
 else
 {
  if (plotter & BBT_MULTI)
  {
#define PLOTTER_TYPE NP_M
#include "ppu/dispatch.h"
#undef PLOTTER_TYPE
  }
  else
  {
#define PLOTTER_TYPE NP
#include "ppu/dispatch.h"
#undef PLOTTER_TYPE
  }
 }
#undef DISPATCH_PLOTTER_EXPANSION
}
#endif  /* !defined(DISPATCH_PROTOTYPES_ONLY) */


#else   /* defined(DISPATCH_PLOTTER_EXPANSION) */

 switch (plotter & BBT_BASE)
 {
#if !SCREEN_HIRES
  case BBT_2BPP:
  case BBT_2BPP_PAL:
#else
  case BBT_2BPP_HI:
#endif
   CONCAT_5_NAME(Plot_Lines_, RES_SUFFIX_U, DISPATCHER_SCREEN_TYPE, M_C2_, PLOTTER_TYPE) (
    map_address, tileset_address,
    tile_line_address, tile_line_address_y,
    main_buf, sub_buf, output_surface_offset, line_count,
    pixel_in_tile, pixel_count, depth_low, depth_high, palette_base);
   break;
#if !SCREEN_HIRES
  case BBT_4BPP:
#else
  case BBT_4BPP_HI:
#endif
   CONCAT_5_NAME(Plot_Lines_, RES_SUFFIX_U, DISPATCHER_SCREEN_TYPE, M_C4_, PLOTTER_TYPE) (
    map_address, tileset_address,
    tile_line_address, tile_line_address_y,
    main_buf, sub_buf, output_surface_offset, line_count,
    pixel_in_tile, pixel_count, depth_low, depth_high, palette_base);
   break;
  case BBT_8BPP:
#if !SCREEN_HIRES
   CONCAT_5_NAME(Plot_Lines_, RES_SUFFIX_U, DISPATCHER_SCREEN_TYPE, M_C8_, PLOTTER_TYPE) (
    map_address, tileset_address,
    tile_line_address, tile_line_address_y,
    main_buf, sub_buf, output_surface_offset, line_count,
    pixel_in_tile, pixel_count, depth_low, depth_high, palette_base);
#endif
   break;
  default:
  /* not handled here */
   break;
 }
#endif  /* defined(DISPATCH_PLOTTER_EXPANSION) */

#endif  /* defined(DISPATCH_MOSAIC_PLOTTER) */

#else   /* defined(DISPATCHER_OFFSET_TYPE) */

#ifndef DISPATCH_MOSAIC_PLOTTER

#ifndef DISPATCH_PLOTTER_EXPANSION


static void CONCAT_5_NAME(dispatch_plotter_, RES_SUFFIX_L, DISPATCHER_SCREEN_TYPE, _offset_, DISPATCHER_OFFSET_TYPE)(BGMODE_BG_TYPE plotter,
 const void *offset_map_address_base, unsigned tileset_address,
 unsigned tile_line_address, unsigned tile_line_address_y,
 unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2],
 unsigned output_surface_offset, int line_count, int tile_count,
 unsigned char depth_low, unsigned char depth_high, unsigned current_line,
 unsigned char oc_flag, unsigned offset_v_map_difference,
 const void *t_map_address, const void *b_map_address,
 unsigned r_map_difference, unsigned first_tile_offset_current,
 unsigned offset_map_first_tile_offset, const void *map_address_current,
 int tile_on_line_offset)
#ifdef DISPATCH_PROTOTYPES_ONLY
;
#else   /* !defined(DISPATCH_PROTOTYPES_ONLY) */
{
#define DISPATCH_PLOTTER_EXPANSION
 if (!(plotter & BBT_NO_PRI))
 {
#define PLOTTER_TYPE V
#include "ppu/dispatch.h"
#undef PLOTTER_TYPE
 }
 else
 {
#define PLOTTER_TYPE NP
#include "ppu/dispatch.h"
#undef PLOTTER_TYPE
 }
#undef DISPATCH_PLOTTER_EXPANSION
}
#endif  /* !defined(DISPATCH_PROTOTYPES_ONLY) */


#else   /* defined(DISPATCH_PLOTTER_EXPANSION) */

 switch (plotter & BBT_BASE)
 {
#if !SCREEN_HIRES
  case BBT_4BPP_OPT:
#else
  case BBT_4BPP_OPT_HI:
#endif
   CONCAT_7_NAME(Plot_Lines_, RES_SUFFIX_U, DISPATCHER_SCREEN_TYPE, _Offset_, DISPATCHER_OFFSET_TYPE, _C4_, PLOTTER_TYPE) (
    offset_map_address_base, tileset_address,
    tile_line_address, tile_line_address_y,
    main_buf, sub_buf, output_surface_offset, line_count,
    tile_count, depth_low, depth_high, current_line, oc_flag,
    offset_v_map_difference, t_map_address, b_map_address, r_map_difference,
    first_tile_offset_current, offset_map_first_tile_offset,
	map_address_current, tile_on_line_offset);
   break;
  case BBT_2BPP_OPT:
#if !SCREEN_HIRES
   CONCAT_7_NAME(Plot_Lines_, RES_SUFFIX_U, DISPATCHER_SCREEN_TYPE, _Offset_, DISPATCHER_OFFSET_TYPE, _C2_, PLOTTER_TYPE) (
    offset_map_address_base, tileset_address,
    tile_line_address, tile_line_address_y,
    main_buf, sub_buf, output_surface_offset, line_count,
    tile_count, depth_low, depth_high, current_line, oc_flag,
    offset_v_map_difference, t_map_address, b_map_address, r_map_difference,
    first_tile_offset_current, offset_map_first_tile_offset,
	map_address_current, tile_on_line_offset);
#endif
   break;
  case BBT_8BPP_OPT:
#if !SCREEN_HIRES
   CONCAT_7_NAME(Plot_Lines_, RES_SUFFIX_U, DISPATCHER_SCREEN_TYPE, _Offset_, DISPATCHER_OFFSET_TYPE, _C8_, PLOTTER_TYPE) (
    offset_map_address_base, tileset_address,
    tile_line_address, tile_line_address_y,
    main_buf, sub_buf, output_surface_offset, line_count,
    tile_count, depth_low, depth_high, current_line, oc_flag,
    offset_v_map_difference, t_map_address, b_map_address, r_map_difference,
    first_tile_offset_current, offset_map_first_tile_offset,
	map_address_current, tile_on_line_offset);
#endif
   break;
  default:
  /* not handled here */
   break;
 }
#endif  /* defined(DISPATCH_PLOTTER_EXPANSION) */

#else   /* defined(DISPATCH_MOSAIC_PLOTTER) */

#ifndef DISPATCH_PLOTTER_EXPANSION


static void CONCAT_5_NAME(dispatch_mosaic_plotter_, RES_SUFFIX_L, DISPATCHER_SCREEN_TYPE, _offset_, DISPATCHER_OFFSET_TYPE)(BGMODE_BG_TYPE plotter,
 const void *offset_map_address_base, unsigned tileset_address,
 unsigned tile_line_address, unsigned tile_line_address_y,
 unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2],
 unsigned output_surface_offset, int line_count,
 int pixel_in_tile, int pixel_count,
 unsigned char depth_low, unsigned char depth_high, unsigned current_line,
 unsigned char oc_flag, unsigned offset_v_map_difference,
 const void *t_map_address, const void *b_map_address,
 unsigned r_map_difference, unsigned first_tile_offset_current,
 unsigned offset_map_first_tile_offset, const void *map_address_current,
 int tile_on_line_offset)
#ifdef DISPATCH_PROTOTYPES_ONLY
;
#else   /* !defined(DISPATCH_PROTOTYPES_ONLY) */
{
#define DISPATCH_PLOTTER_EXPANSION
 if (!(plotter & BBT_NO_PRI))
 {
  if (plotter & BBT_MULTI)
  {
#define PLOTTER_TYPE V_M
#include "ppu/dispatch.h"
#undef PLOTTER_TYPE
  }
  else
  {
#define PLOTTER_TYPE V
#include "ppu/dispatch.h"
#undef PLOTTER_TYPE
  }
 }
 else
 {
  if (plotter & BBT_MULTI)
  {
#define PLOTTER_TYPE NP_M
#include "ppu/dispatch.h"
#undef PLOTTER_TYPE
  }
  else
  {
#define PLOTTER_TYPE NP
#include "ppu/dispatch.h"
#undef PLOTTER_TYPE
  }
 }
#undef DISPATCH_PLOTTER_EXPANSION
}
#endif  /* !defined(DISPATCH_PROTOTYPES_ONLY) */


#else   /* defined(DISPATCH_PLOTTER_EXPANSION) */

 switch (plotter & BBT_BASE)
 {
#if !SCREEN_HIRES
  case BBT_4BPP_OPT:
#else
  case BBT_4BPP_OPT_HI:
#endif
   CONCAT_7_NAME(Plot_Lines_, RES_SUFFIX_U, DISPATCHER_SCREEN_TYPE, M_Offset_, DISPATCHER_OFFSET_TYPE, _C4_, PLOTTER_TYPE) (
    offset_map_address_base, tileset_address,
    tile_line_address, tile_line_address_y,
    main_buf, sub_buf, output_surface_offset, line_count,
    pixel_in_tile, pixel_count, depth_low, depth_high, current_line, oc_flag,
    offset_v_map_difference, t_map_address, b_map_address, r_map_difference,
    first_tile_offset_current, offset_map_first_tile_offset,
	map_address_current, tile_on_line_offset);
   break;
  case BBT_2BPP_OPT:
#if !SCREEN_HIRES
   CONCAT_7_NAME(Plot_Lines_, RES_SUFFIX_U, DISPATCHER_SCREEN_TYPE, M_Offset_, DISPATCHER_OFFSET_TYPE, _C2_, PLOTTER_TYPE) (
    offset_map_address_base, tileset_address,
    tile_line_address, tile_line_address_y,
    main_buf, sub_buf, output_surface_offset, line_count,
    pixel_in_tile, pixel_count, depth_low, depth_high, current_line, oc_flag,
    offset_v_map_difference, t_map_address, b_map_address, r_map_difference,
    first_tile_offset_current, offset_map_first_tile_offset,
	map_address_current, tile_on_line_offset);
#endif
   break;
  case BBT_8BPP_OPT:
#if !SCREEN_HIRES
   CONCAT_7_NAME(Plot_Lines_, RES_SUFFIX_U, DISPATCHER_SCREEN_TYPE, M_Offset_, DISPATCHER_OFFSET_TYPE, _C8_, PLOTTER_TYPE) (
    offset_map_address_base, tileset_address,
    tile_line_address, tile_line_address_y,
    main_buf, sub_buf, output_surface_offset, line_count,
    pixel_in_tile, pixel_count, depth_low, depth_high, current_line, oc_flag,
    offset_v_map_difference, t_map_address, b_map_address, r_map_difference,
    first_tile_offset_current, offset_map_first_tile_offset,
	map_address_current, tile_on_line_offset);
#endif
   break;
  default:
  /* not handled here */
   break;
 }
#endif  /* defined(DISPATCH_PLOTTER_EXPANSION) */

#endif  /* defined(DISPATCH_MOSAIC_PLOTTER) */

#endif  /* defined(DISPATCHER_OFFSET_TYPE) */
