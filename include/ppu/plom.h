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

#if !SCREEN_HIRES
static void CONCAT_6_NAME(Plot_Lines_, SCREEN_TYPE, M_Offset_, OFFSET_TYPE, _C2_, PLOTTER_TYPE) (
 const void *offset_map_address_base, unsigned tileset_address,
 unsigned tile_line_address_current, unsigned tile_line_address_y_current,
 unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2],
 unsigned output_surface_offset, int line_count,
 int pixel_in_tile, int pixel_count,
 unsigned char depth_low, unsigned char depth_high, unsigned current_line,
 unsigned char oc_flag, unsigned offset_v_map_difference,
 const void *t_map_address, const void *b_map_address,
 unsigned r_map_difference, unsigned first_tile_offset_current,
 unsigned offset_map_first_tile_offset, const void *map_address_current,
 int tile_on_line_offset)
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

  const void *map_address, *offset_map_address;
  unsigned tile_line_address;
  unsigned tile_line_address_y;
  unsigned tile_offset;


  if (pixel_in_tile >= 8 / DOT_WIDTH_DIVISOR) continue;

  /* first displayable tile on scanline, no offset map look-up */
  if (!(tile_on_line_offset / DOT_WIDTH_DIVISOR))
  {
   map_address = map_address_current;
   tile_offset = first_tile_offset_current;
   
   tile_line_address = tile_line_address_current;
   tile_line_address_y = tile_line_address_y_current;

  }
  else
  {
   offset_map_address = (const unsigned char *) offset_map_address_base +
    (((offset_map_first_tile_offset + tile_on_line_offset) *
    (2 / (OFFSET_TILE_WIDTH / 8))) & (2 * (32 - 1)));

   /* offset map look-up, check enable bit */
   if (!(* ((const unsigned char *) offset_map_address + 1) &
    oc_flag))
   {
    /* no change, use default offsets */
    map_address = map_address_current;
    tile_offset = first_tile_offset_current;
   
    tile_line_address = tile_line_address_current;
    tile_line_address_y = tile_line_address_y_current;
   }
   else
   {
    unsigned offset = ((* (const unsigned char *) offset_map_address) +
     (* ((const unsigned char *) offset_map_address + 1) << 8));

    /* check which offset we're changing */
    if (!(offset & (1 << 15)))
	{
     /* use new h-offset, default v-offset */
     tile_offset = (offset >> 3);

     map_address = map_address_current;

     tile_line_address = tile_line_address_current;
     tile_line_address_y = tile_line_address_y_current;
    }
	else
	{
     /* use default h-offset, new v-offset */
     unsigned screen_line_address;

     (!SCREEN_BG_SIZE ? sort_tiles_8_tall : sort_tiles_16_tall)(
      offset, &tile_line_address, &tile_line_address_y,
      &screen_line_address, current_line);

     map_address = !((offset + current_line) & SCREEN_HEIGHT) ?
      t_map_address : b_map_address;

     map_address = (unsigned char *) map_address + screen_line_address;

     tile_offset = first_tile_offset_current;
	}
   }
  }

  tile_offset += tile_on_line_offset;

  /* figure in h-offset */
  map_address = (const unsigned char *) map_address +
   ((tile_offset * (2 / (SCREEN_TILE_WIDTH / 8))) &
   (2 * (32 - 1)));

  /* determine horizontal screen map select */
  map_address = (const unsigned char *) map_address +
   (!((tile_offset * (2 / (SCREEN_TILE_WIDTH / 8))) &
   /* should always be (2 * 32) */
   (2 * 32)) ? 0 : r_map_difference);


  SETUP_BACKGROUND_TILE(2, 0)

  tile_address += (SCREEN_TILE_WIDTH == 16) && ((tile_offset & 1) ^
   (!(map & BGSC_FLIP_X) ? 0 : 1)) ? 8 : 0;

  do
  {
   run_pixel_count = Mosaic_Size;

   if (run_pixel_count > pixel_count) run_pixel_count = pixel_count;

   if (ignore_tile) continue;

   PLOTTER_CALL_PAL(main_buf, sub_buf, output_surface_offset, depth,
    tile_address,
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
  ++tile_on_line_offset, (pixel_count > 0));
}
#endif

static void CONCAT_7_NAME(Plot_Lines_, RES_SUFFIX_U, SCREEN_TYPE, M_Offset_, OFFSET_TYPE, _C4_, PLOTTER_TYPE) (
 const void *offset_map_address_base, unsigned tileset_address,
 unsigned tile_line_address_current, unsigned tile_line_address_y_current,
 unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2],
 unsigned output_surface_offset, int line_count,
 int pixel_in_tile, int pixel_count,
 unsigned char depth_low, unsigned char depth_high, unsigned current_line,
 unsigned char oc_flag, unsigned offset_v_map_difference,
 const void *t_map_address, const void *b_map_address,
 unsigned r_map_difference, unsigned first_tile_offset_current,
 unsigned offset_map_first_tile_offset, const void *map_address_current,
 int tile_on_line_offset)
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

  const void *map_address, *offset_map_address;
  unsigned tile_line_address;
  unsigned tile_line_address_y;
  unsigned tile_offset;


  if (pixel_in_tile >= 8 / DOT_WIDTH_DIVISOR) continue;

  /* first displayable tile on scanline, no offset map look-up */
  if (!(tile_on_line_offset / DOT_WIDTH_DIVISOR))
  {
   map_address = map_address_current;
   tile_offset = first_tile_offset_current;
   
   tile_line_address = tile_line_address_current;
   tile_line_address_y = tile_line_address_y_current;

  }
  else
  {
   offset_map_address = (const unsigned char *) offset_map_address_base +
    (((offset_map_first_tile_offset + tile_on_line_offset) *
    (2 / (OFFSET_TILE_WIDTH / 8))) & (2 * (32 - 1)));


   /* v-offset map look-up, check enable bit */
   if (!(* ((const unsigned char *) offset_map_address +
    offset_v_map_difference + 1) & oc_flag))
   {
    /* no change, use default v-offset */
    map_address = map_address_current;

    tile_line_address = tile_line_address_current;
    tile_line_address_y = tile_line_address_y_current;
   }
   else
   {
/*  printf("%08X - V%04X\n", (const unsigned char *) offset_map_address + offset_v_map_difference - VRAM,
     ((* ((const unsigned char *) offset_map_address + offset_v_map_difference)) +
      (* ((const unsigned char *) offset_map_address + offset_v_map_difference + 1) << 8)));*/
    /* use new v-offset */
    unsigned screen_line_address;
    unsigned vscroll = ((* ((const unsigned char *)
     offset_map_address + offset_v_map_difference)) +
     (* ((const unsigned char *) offset_map_address +
     offset_v_map_difference + 1) << 8));

    (!SCREEN_BG_SIZE ? sort_tiles_8_tall : sort_tiles_16_tall)(
     vscroll, &tile_line_address, &tile_line_address_y,
     &screen_line_address, current_line);

    map_address = !((vscroll + current_line) & SCREEN_HEIGHT) ?
     t_map_address : b_map_address;

    map_address = (unsigned char *) map_address + screen_line_address;
   }

   /* h-offset map look-up, check enable bit */
   if (!(* ((const unsigned char *) offset_map_address + 1) &
    oc_flag))
   {
    /* no change, use default v-offset */
    tile_offset = first_tile_offset_current;
   }
   else
   {
/*  printf("%08X - H%04X\n", (const unsigned char *) offset_map_address - VRAM,
     ((* (const unsigned char *) offset_map_address) +
      (* ((const unsigned char *) offset_map_address + 1) << 8)));*/
    /* use new h-offset */
    unsigned hscroll = ((* (const unsigned char *) offset_map_address) +
     (* ((const unsigned char *) offset_map_address + 1) << 8));

    tile_offset = (hscroll >> 3);
   }
  }

/*if (oc_flag & 0x20)
  {
   printf("%3d H%04X V%04X\n", tile_on_line_offset,
    !tile_on_line_offset ? 0xFFFF : ((* (const unsigned char *) offset_map_address) + (* ((const unsigned char *) offset_map_address + 1) << 8)),
	!tile_on_line_offset ? 0 : ((* ((const unsigned char *) offset_map_address + offset_v_map_difference)) + (* ((const unsigned char *) offset_map_address + offset_v_map_difference + 1) << 8)));
  }*/
  tile_offset += tile_on_line_offset;

  /* figure in h-offset */
  map_address = (const unsigned char *) map_address +
   ((tile_offset * (2 / (SCREEN_TILE_WIDTH / 8))) &
   (2 * (32 - 1)));

  /* determine horizontal screen map select */
  map_address = (const unsigned char *) map_address +
   (!((tile_offset * (2 / (SCREEN_TILE_WIDTH / 8))) &
   (2 * 32)) ? 0 : r_map_difference);


  SETUP_BACKGROUND_TILE(4, 0)

  tile_address += (SCREEN_TILE_WIDTH == 16) && ((tile_offset & 1) ^
   (!(map & BGSC_FLIP_X) ? 0 : 1)) ? 8 : 0;

  do
  {
   run_pixel_count = Mosaic_Size;

   if (run_pixel_count > pixel_count) run_pixel_count = pixel_count;

   if (ignore_tile) continue;

   PLOTTER_CALL_PAL(main_buf, sub_buf, output_surface_offset, depth,
    tile_address,
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

 } while (pixel_in_tile -= SCREEN_TILE_WIDTH / DOT_WIDTH_DIVISOR, ++tile_on_line_offset,
  (pixel_count > 0));
}


#if !SCREEN_HIRES
static void CONCAT_6_NAME(Plot_Lines_, SCREEN_TYPE, M_Offset_, OFFSET_TYPE, _C8_, PLOTTER_TYPE) (
 const void *offset_map_address_base, unsigned tileset_address,
 unsigned tile_line_address_current, unsigned tile_line_address_y_current,
 unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2],
 unsigned output_surface_offset, int line_count,
 int pixel_in_tile, int pixel_count,
 unsigned char depth_low, unsigned char depth_high, unsigned current_line,
 unsigned char oc_flag, unsigned offset_v_map_difference,
 const void *t_map_address, const void *b_map_address,
 unsigned r_map_difference, unsigned first_tile_offset_current,
 unsigned offset_map_first_tile_offset, const void *map_address_current,
 int tile_on_line_offset)
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

  const void *map_address, *offset_map_address;
  unsigned tile_line_address;
  unsigned tile_line_address_y;
  unsigned tile_offset;


  if (pixel_in_tile >= 8 / DOT_WIDTH_DIVISOR) continue;

  /* first displayable tile on scanline, no offset map look-up */
  if (!(tile_on_line_offset / DOT_WIDTH_DIVISOR))
  {
   map_address = map_address_current;
   tile_offset = first_tile_offset_current;
   
   tile_line_address = tile_line_address_current;
   tile_line_address_y = tile_line_address_y_current;

  }
  else
  {
   offset_map_address = (const unsigned char *) offset_map_address_base +
    (((offset_map_first_tile_offset + tile_on_line_offset) *
    (2 / (OFFSET_TILE_WIDTH / 8))) & (2 * (32 - 1)));

   /* offset map look-up, check enable bit */
   if (!(* ((const unsigned char *) offset_map_address + 1) &
    oc_flag))
   {
    /* no change, use default offsets */
    map_address = map_address_current;
    tile_offset = first_tile_offset_current;
   
    tile_line_address = tile_line_address_current;
    tile_line_address_y = tile_line_address_y_current;
   }
   else
   {
    unsigned offset = ((* (const unsigned char *) offset_map_address) +
     (* ((const unsigned char *) offset_map_address + 1) << 8));

    /* check which offset we're changing */
    if (!(offset & (1 << 15)))
	{
     /* use new h-offset, default v-offset */
     tile_offset = (offset >> 3);

     map_address = map_address_current;

     tile_line_address = tile_line_address_current;
     tile_line_address_y = tile_line_address_y_current;
    }
	else
	{
     /* use default h-offset, new v-offset */
     unsigned screen_line_address;

     (!SCREEN_BG_SIZE ? sort_tiles_8_tall : sort_tiles_16_tall)(
      offset, &tile_line_address, &tile_line_address_y,
      &screen_line_address, current_line);

     map_address = !((offset + current_line) & SCREEN_HEIGHT) ?
      t_map_address : b_map_address;

     map_address = (unsigned char *) map_address + screen_line_address;

     tile_offset = first_tile_offset_current;
	}
   }
  }

  tile_offset += tile_on_line_offset;

  /* figure in h-offset */
  map_address = (const unsigned char *) map_address +
   ((tile_offset * (2 / (SCREEN_TILE_WIDTH / 8))) &
   (2 * (32 - 1)));

  /* determine horizontal screen map select */
  map_address = (const unsigned char *) map_address +
   (!((tile_offset * (2 / (SCREEN_TILE_WIDTH / 8))) &
   /* should always be (2 * 32) */
   (2 * 32)) ? 0 : r_map_difference);


  SETUP_BACKGROUND_TILE(8, 0)

  tile_address += (SCREEN_TILE_WIDTH == 16) && ((tile_offset & 1) ^
   (!(map & BGSC_FLIP_X) ? 0 : 1)) ? 8 : 0;

  do
  {
   run_pixel_count = Mosaic_Size;

   if (run_pixel_count > pixel_count) run_pixel_count = pixel_count;

   if (ignore_tile) continue;

   PLOTTER_CALL(main_buf, sub_buf, output_surface_offset, depth, tile_address,
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
    run_pixel_count, palette_mask, TileCache8);

  } while (output_surface_offset += run_pixel_count,
   pixel_in_tile += run_pixel_count, pixel_count -= run_pixel_count,
   (pixel_count > 0) && (pixel_in_tile < SCREEN_TILE_WIDTH / DOT_WIDTH_DIVISOR));

 } while (pixel_in_tile -= SCREEN_TILE_WIDTH / DOT_WIDTH_DIVISOR, ++tile_on_line_offset,
  (pixel_count > 0));
}
#endif
