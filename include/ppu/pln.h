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

static void CONCAT_5_NAME(Plot_Lines_, RES_SUFFIX_U, SCREEN_TYPE, _C2_, PLOTTER_TYPE) (
 const void *map_address, unsigned tileset_address,
 unsigned tile_line_address, unsigned tile_line_address_y,
 unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2],
 unsigned output_surface_offset, int line_count, int tile_count,
 unsigned char depth_low, unsigned char depth_high, unsigned palette_base)
{
 do
 {
  int line_increment;
  unsigned tile_address;
  unsigned map;
  unsigned palette_mask;
  unsigned char map_lo, map_hi;
  unsigned char depth = 0;

  SETUP_BACKGROUND_TILE(2, palette_base)

  PLOTTER_CALL_PAL(main_buf, sub_buf, output_surface_offset, depth,
   tile_address +
   (!((SCREEN_TILE_WIDTH == 16) && (map & BGSC_FLIP_X)) ? 0 : 8),
  /* limit of tileset is 1024 tiles * 8 lines, we mask to that here */
   (1024 * 8) - 1,
  /* after that mask, figure in the tileset address */
   tileset_address,
  /* then mask for VRAM, generate a cache address, maximum number of */
  /*  tile-lines for 2-bit tiles is 32k (64k / 16 * 8) */
   (64 * 1024 / 16 * 8) - 1,
   map & BGSC_FLIP_X, line_count, line_increment, palette_mask,
   tile_clip_1_left, !SCREEN_HIRES ? tile_clip_1_right : 0, TileCache2);

#if SCREEN_TILE_WIDTH == 16
  if (tile_count >= 2)
  {
   PLOTTER_CALL_PAL(main_buf, sub_buf,
    output_surface_offset + 8 / DOT_WIDTH_DIVISOR, depth,
    tile_address + (!(map & BGSC_FLIP_X) ? 8 : 0),
    (1024 * 8) - 1, tileset_address, (64 * 1024 / 16 * 8) - 1,
    map & BGSC_FLIP_X, line_count, line_increment, palette_mask,
    !SCREEN_HIRES ? tile_clip_2_left : tile_clip_1_right,
    !SCREEN_HIRES ? tile_clip_2_right : 0, TileCache2);
  }
#endif

 } while (output_surface_offset += SCREEN_TILE_WIDTH / DOT_WIDTH_DIVISOR,
  map_address = (const unsigned char *) map_address + 2,
  (tile_count -= (SCREEN_TILE_WIDTH / 8)) > 0);
}


static void CONCAT_5_NAME(Plot_Lines_, RES_SUFFIX_U, SCREEN_TYPE, _C4_, PLOTTER_TYPE) (
 const void *map_address, unsigned tileset_address,
 unsigned tile_line_address, unsigned tile_line_address_y,
 unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2],
 unsigned output_surface_offset, int line_count, int tile_count,
 unsigned char depth_low, unsigned char depth_high, unsigned palette_base)
{
 do
 {
  int line_increment;
  unsigned tile_address;
  unsigned map;
  unsigned palette_mask;
  unsigned char map_lo, map_hi;
  unsigned char depth = 0;

  SETUP_BACKGROUND_TILE(4, 0)

  PLOTTER_CALL_PAL(main_buf, sub_buf, output_surface_offset, depth,
   tile_address +
   (!((SCREEN_TILE_WIDTH == 16) && (map & BGSC_FLIP_X)) ? 0 : 8),
  /* limit of tileset is 1024 tiles * 8 lines, we mask to that here */
   (1024 * 8) - 1,
  /* after that mask, figure in the tileset address */
   tileset_address,
  /* then mask for VRAM, generate a cache address, maximum number of */
  /*  tile-lines for 4-bit tiles is 16k (64k / 32 * 8) */
   (64 * 1024 / 32 * 8) - 1,
   map & BGSC_FLIP_X, line_count, line_increment, palette_mask,
   tile_clip_1_left, !SCREEN_HIRES ? tile_clip_1_right : 0, TileCache4);

#if SCREEN_TILE_WIDTH == 16
  if (tile_count >= 2)
  {
   PLOTTER_CALL_PAL(main_buf, sub_buf,
    output_surface_offset + 8 / DOT_WIDTH_DIVISOR, depth,
    tile_address + (!(map & BGSC_FLIP_X) ? 8 : 0),
    (1024 * 8) - 1, tileset_address, (64 * 1024 / 16 * 8) - 1,
    map & BGSC_FLIP_X, line_count, line_increment, palette_mask,
    !SCREEN_HIRES ? tile_clip_2_left : tile_clip_1_right,
    !SCREEN_HIRES ? tile_clip_2_right : 0, TileCache4);
  }
#endif

 } while (output_surface_offset += SCREEN_TILE_WIDTH / DOT_WIDTH_DIVISOR,
  map_address = (const unsigned char *) map_address + 2,
  (tile_count -= (SCREEN_TILE_WIDTH / 8)) > 0);
}


#if SCREEN_HIRES == 0
static void CONCAT_4_NAME(Plot_Lines_, SCREEN_TYPE, _C8_, PLOTTER_TYPE) (
 const void *map_address, unsigned tileset_address,
 unsigned tile_line_address, unsigned tile_line_address_y,
 unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2],
 unsigned output_surface_offset, int line_count, int tile_count,
 unsigned char depth_low, unsigned char depth_high, unsigned palette_base)
{
 do
 {
  int line_increment;
  unsigned tile_address;
  unsigned map;
  unsigned palette_mask;
  unsigned char map_lo, map_hi;
  unsigned char depth = 0;

  SETUP_BACKGROUND_TILE(8, 0)

  PLOTTER_CALL(main_buf, sub_buf, output_surface_offset, depth,
   tile_address +
   (!((SCREEN_TILE_WIDTH == 16) && (map & BGSC_FLIP_X)) ? 0 : 8),
  /* limit of tileset is 1024 tiles * 8 lines, we mask to that here */
   (1024 * 8) - 1,
  /* after that mask, figure in the tileset address */
   tileset_address,
  /* then mask for VRAM, generate a cache address, maximum number of */
  /*  tile-lines for 8-bit tiles is 8k (64k / 64 * 8) */
   (64 * 1024 / 64 * 8) - 1,
   map & BGSC_FLIP_X, line_count, line_increment, palette_mask,
   tile_clip_1_left, tile_clip_1_right, TileCache8);

#if SCREEN_TILE_WIDTH == 16
  if (tile_count >= 2)
  {
   PLOTTER_CALL_PAL(main_buf, sub_buf, output_surface_offset + 8, depth,
    tile_address + (!(map & BGSC_FLIP_X) ? 8 : 0),
    (1024 * 8) - 1, tileset_address, (64 * 1024 / 16 * 8) - 1,
    map & BGSC_FLIP_X, line_count, line_increment, palette_mask,
    tile_clip_2_left, tile_clip_2_right, TileCache8);
  }
#endif

 } while (output_surface_offset += SCREEN_TILE_WIDTH,
  map_address = (const unsigned char *) map_address + 2,
  (tile_count -= (SCREEN_TILE_WIDTH / 8)) > 0);
}
#endif
