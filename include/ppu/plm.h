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

static void CONCAT_5_NAME(Plot_Lines_, RES_SUFFIX_U, SCREEN_TYPE, M_C2_, PLOTTER_TYPE) (
 const void *map_address, unsigned tileset_address,
 unsigned tile_line_address, unsigned tile_line_address_y,
 unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2],
 unsigned output_surface_offset, int line_count,
 int pixel_in_tile, int pixel_count,
 unsigned char depth_low, unsigned char depth_high, unsigned palette_base)
{
 do
 {
  int line_increment;
  unsigned tile_address;
  unsigned map;
  unsigned palette_mask;
  unsigned char map_lo, map_hi;
  int run_pixel_count;
  int ignore_tile = 0;
  unsigned char depth = 0;

  if (pixel_in_tile >= SCREEN_TILE_WIDTH / DOT_WIDTH_DIVISOR) continue;

  SETUP_BACKGROUND_TILE(2, palette_base)

  do
  {
   run_pixel_count = Mosaic_Size;

   if (run_pixel_count > pixel_count) run_pixel_count = pixel_count;

   if (ignore_tile) continue;

   PLOTTER_CALL_PAL(main_buf, sub_buf, output_surface_offset, depth,
    tile_address + ((SCREEN_TILE_WIDTH == 16) && ((pixel_in_tile &
     (8 / DOT_WIDTH_DIVISOR)) ^ (!(map & BGSC_FLIP_X) ?
	 0 : (8 / DOT_WIDTH_DIVISOR))) ? 8 : 0),
   /* limit of tileset is 1024 tiles * 8 lines, we mask to that here */
    (1024 * 8) - 1,
   /* after that mask, figure in the tileset address */
    tileset_address,
   /* then mask for VRAM, generate a cache address, maximum number of */
   /*  tile-lines for 2-bit tiles is 32k (64k / 16 * 8) */
    (64 * 1024 / 16 * 8) - 1,
    line_count,
    (!(map & BGSC_FLIP_X) ? pixel_in_tile :
     (SCREEN_TILE_WIDTH / DOT_WIDTH_DIVISOR - 1) - pixel_in_tile) &
     ((8 / DOT_WIDTH_DIVISOR) - 1),
    run_pixel_count, palette_mask, TileCache2);

  } while (output_surface_offset += run_pixel_count,
   pixel_in_tile += run_pixel_count, pixel_count -= run_pixel_count,
   (pixel_count > 0) && (pixel_in_tile < SCREEN_TILE_WIDTH / DOT_WIDTH_DIVISOR));

 } while (pixel_in_tile -= SCREEN_TILE_WIDTH / DOT_WIDTH_DIVISOR,
  map_address = (const unsigned char *) map_address + 2, (pixel_count > 0));
}


static void CONCAT_5_NAME(Plot_Lines_, RES_SUFFIX_U, SCREEN_TYPE, M_C4_, PLOTTER_TYPE) (
 const void *map_address, unsigned tileset_address,
 unsigned tile_line_address, unsigned tile_line_address_y,
 unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2],
 unsigned output_surface_offset, int line_count,
 int pixel_in_tile, int pixel_count,
 unsigned char depth_low, unsigned char depth_high, unsigned palette_base)
{
 do
 {
  int line_increment;
  unsigned tile_address;
  unsigned map;
  unsigned palette_mask;
  unsigned char map_lo, map_hi;
  int run_pixel_count;
  int ignore_tile = 0;
  unsigned char depth = 0;

  if (pixel_in_tile >= SCREEN_TILE_WIDTH / DOT_WIDTH_DIVISOR) continue;

  SETUP_BACKGROUND_TILE(4, 0)

  do
  {
   run_pixel_count = Mosaic_Size;

   if (run_pixel_count > pixel_count) run_pixel_count = pixel_count;

   if (ignore_tile) continue;

   PLOTTER_CALL_PAL(main_buf, sub_buf, output_surface_offset, depth,
    tile_address + ((SCREEN_TILE_WIDTH == 16) && ((pixel_in_tile &
     (8 / DOT_WIDTH_DIVISOR)) ^ (!(map & BGSC_FLIP_X) ?
	 0 : (8 / DOT_WIDTH_DIVISOR))) ? 8 : 0),
   /* limit of tileset is 1024 tiles * 8 lines, we mask to that here */
    (1024 * 8) - 1,
   /* after that mask, figure in the tileset address */
    tileset_address,
   /* then mask for VRAM, generate a cache address, maximum number of */
   /*  tile-lines for 2-bit tiles is 32k (64k / 16 * 8) */
    (64 * 1024 / 16 * 8) - 1,
    line_count,
    (!(map & BGSC_FLIP_X) ? pixel_in_tile :
     (SCREEN_TILE_WIDTH / DOT_WIDTH_DIVISOR - 1) - pixel_in_tile) &
     ((8 / DOT_WIDTH_DIVISOR) - 1),
    run_pixel_count, palette_mask, TileCache4);

  } while (output_surface_offset += run_pixel_count,
   pixel_in_tile += run_pixel_count, pixel_count -= run_pixel_count,
   (pixel_count > 0) && (pixel_in_tile < SCREEN_TILE_WIDTH / DOT_WIDTH_DIVISOR));

 } while (pixel_in_tile -= SCREEN_TILE_WIDTH / DOT_WIDTH_DIVISOR,
  map_address = (const unsigned char *) map_address + 2, (pixel_count > 0));
}


#if !SCREEN_HIRES
static void CONCAT_4_NAME(Plot_Lines_, SCREEN_TYPE, M_C8_, PLOTTER_TYPE) (
 const void *map_address, unsigned tileset_address,
 unsigned tile_line_address, unsigned tile_line_address_y,
 unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2],
 unsigned output_surface_offset, int line_count,
 int pixel_in_tile, int pixel_count,
 unsigned char depth_low, unsigned char depth_high, unsigned palette_base)
{
 do
 {
  int line_increment;
  unsigned tile_address;
  unsigned map;
  unsigned palette_mask;
  unsigned char map_lo, map_hi;
  int run_pixel_count;
  int ignore_tile = 0;
  unsigned char depth = 0;

  if (pixel_in_tile >= SCREEN_TILE_WIDTH) continue;

  SETUP_BACKGROUND_TILE(8, 0)

  do
  {
   run_pixel_count = Mosaic_Size;

   if (run_pixel_count > pixel_count) run_pixel_count = pixel_count;

   if (ignore_tile) continue;

   PLOTTER_CALL(main_buf, sub_buf, output_surface_offset, depth,
    tile_address + ((SCREEN_TILE_WIDTH == 16) && ((pixel_in_tile & 8) ^
     (!(map & BGSC_FLIP_X) ? 0 : 8)) ? 8 : 0),
   /* limit of tileset is 1024 tiles * 8 lines, we mask to that here */
    (1024 * 8) - 1,
   /* after that mask, figure in the tileset address */
    tileset_address,
   /* then mask for VRAM, generate a cache address, maximum number of */
   /*  tile-lines for 2-bit tiles is 32k (64k / 16 * 8) */
    (64 * 1024 / 16 * 8) - 1,
    line_count,
    (!(map & BGSC_FLIP_X) ? pixel_in_tile :
     (SCREEN_TILE_WIDTH - 1) - pixel_in_tile) & 7,
    run_pixel_count, palette_mask, TileCache8);

  } while (output_surface_offset += run_pixel_count,
   pixel_in_tile += run_pixel_count, pixel_count -= run_pixel_count,
   (pixel_count > 0) && (pixel_in_tile < SCREEN_TILE_WIDTH));

 } while (pixel_in_tile -= SCREEN_TILE_WIDTH,
  map_address = (const unsigned char *) map_address + 2, (pixel_count > 0));
}
#endif
