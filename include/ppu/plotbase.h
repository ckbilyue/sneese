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

#define swap4(x) \
 ((((unsigned) x & BITMASK( 0, 7)) << 24) | \
  (((unsigned) x & BITMASK( 8,15)) <<  8) | \
  (((unsigned) x & BITMASK(16,23)) >>  8) | \
  (((unsigned) x & BITMASK(24,31)) >> 24))


static void plot4_work(
 unsigned char (*screen1)[2], unsigned char (*screen2)[2],
 unsigned output_surface_offset,
 unsigned char depth, unsigned pixels)
{
 if (pixels)
 {
  int p;

  for (p = 0; p < 4; p++)
  {
   if (pixels & BITMASK(0,7))
   {
    if (screen1[output_surface_offset][1] <= (depth | Z_NON_DEPTH_BITS))
    {
     screen1[output_surface_offset][0] = pixels & BITMASK(0,7);
     screen1[output_surface_offset][1] = depth;
    }

    if (screen2)
    {
     if (screen2[output_surface_offset][1] <= (depth | Z_NON_DEPTH_BITS))
     {
      screen2[output_surface_offset][0] = pixels & BITMASK(0,7);
      screen2[output_surface_offset][1] = depth;
     }
    }
   }
   output_surface_offset++;
   pixels >>= 8;
  }
 }
}

static void plot4_palettized_clipped_work(
 unsigned char (*screen1)[2], unsigned char (*screen2)[2],
 unsigned output_surface_offset, unsigned char depth,
 unsigned pixels, unsigned palette_mask, unsigned clip_mask)
{
  pixels &= clip_mask;
  if (!pixels) return;

  pixels &= palette_mask;

  plot4_work(screen1, screen2, output_surface_offset, depth, pixels);
}

static void plot4_palettized_clipped(
 unsigned char (*screen1)[2], unsigned char (*screen2)[2],
 unsigned output_surface_offset, unsigned char depth,
 unsigned tile_address, int xflip,
 unsigned normal_offset, unsigned xflip_offset,
 unsigned palette_mask, unsigned clip_mask, const void *cache)
{
 unsigned pixels;

 if (!xflip)
 {
  pixels = * (unsigned *)
   ((unsigned char *) cache + tile_address * 8 + normal_offset);
 }
 else
 {
  pixels = * (unsigned *)
   ((unsigned char *) cache + tile_address * 8 + xflip_offset);

  pixels = swap4(pixels);
 }

 plot4_palettized_clipped_work(screen1, screen2, output_surface_offset,
  depth, pixels, palette_mask, clip_mask);
}


static void plot_palettized_line(
 unsigned char (*screen1)[2], unsigned char (*screen2)[2],
 unsigned output_surface_offset, unsigned char depth,
 unsigned tile_address, unsigned tileset_mask,
 unsigned tileset_address, unsigned vram_mask, int xflip, unsigned line_count,
 unsigned line_increment, unsigned palette_mask, unsigned clip_left,
 unsigned clip_right,
 const void *cache)
{
 /* mask for tileset range */
 tile_address &= tileset_mask;

 /* figure in the tileset address */
 tile_address += tileset_address;

 /* mask for VRAM/cache range */
 tile_address &= vram_mask;


 plot4_palettized_clipped(screen1, screen2, output_surface_offset, depth,
  tile_address, xflip, 0, 4, palette_mask, clip_left, cache);

 plot4_palettized_clipped(screen1, screen2, output_surface_offset + 4, depth,
  tile_address, xflip, 4, 0, palette_mask, clip_right, cache);
}

static void plot_palettized_lines(
 unsigned char (*screen1)[2], unsigned char (*screen2)[2],
 unsigned output_surface_offset, unsigned char depth,
 unsigned tile_address, unsigned tileset_mask,
 unsigned tileset_address, unsigned vram_mask, int xflip, unsigned line_count,
 unsigned line_increment, unsigned palette_mask,
 unsigned clip_left, unsigned clip_right, const void *cache)
{
 /* mask for tileset range */
 tile_address &= tileset_mask;

 /* figure in the tileset address */
 tile_address += tileset_address;

 /* mask for VRAM/cache range */
 tile_address &= vram_mask;


 do
 {
  plot_palettized_line(screen1, screen2, output_surface_offset, depth,
   tile_address, (0 - 1), 0, (0 - 1),
   xflip, 1, line_increment, palette_mask, clip_left, clip_right, cache);
 } while (output_surface_offset += 256, tile_address += line_increment,
  --line_count);
}


static void plot4_palettized_even_clipped(
 unsigned char (*screen1)[2], unsigned char (*screen2)[2],
 unsigned output_surface_offset, unsigned char depth,
 unsigned tile_address, int xflip, unsigned palette_mask,
 unsigned clip_mask, const void *cache)
{
 unsigned pixels;

 if (!xflip)
 {
  pixels =
   (unsigned) * ((unsigned char *) cache + tile_address * 8 + 0) +
   ((unsigned) * ((unsigned char *) cache + tile_address * 8 + 2) <<  8) +
   ((unsigned) * ((unsigned char *) cache + tile_address * 8 + 4) << 16) +
   ((unsigned) * ((unsigned char *) cache + tile_address * 8 + 6) << 24);
 }
 else
 {
  pixels =
   ((unsigned) * ((unsigned char *) cache + tile_address * 8 + 0) << 24) +
   ((unsigned) * ((unsigned char *) cache + tile_address * 8 + 2) << 16) +
   ((unsigned) * ((unsigned char *) cache + tile_address * 8 + 4) <<  8) +
   (unsigned) * ((unsigned char *) cache + tile_address * 8 + 6);
 }

 plot4_palettized_clipped_work(screen1, screen2, output_surface_offset, depth,
  pixels, palette_mask, clip_mask);
}


static void plot_palettized_even_line(
 unsigned char (*screen1)[2], unsigned char (*screen2)[2],
 unsigned output_surface_offset, unsigned char depth,
 unsigned tile_address, unsigned tileset_mask,
 unsigned tileset_address, unsigned vram_mask, int xflip, unsigned line_count,
 unsigned line_increment, unsigned palette_mask, unsigned clip_mask,
 unsigned clip_dummy, const void *cache)
{
 /* mask for tileset range */
 tile_address &= tileset_mask;

 /* figure in the tileset address */
 tile_address += tileset_address;

 /* mask for VRAM/cache range */
 tile_address &= vram_mask;


 plot4_palettized_even_clipped(screen1, screen2, output_surface_offset, depth,
  tile_address, xflip, palette_mask, clip_mask, cache);
}

static void plot_palettized_even_lines(
 unsigned char (*screen1)[2], unsigned char (*screen2)[2],
 unsigned output_surface_offset, unsigned char depth,
 unsigned tile_address, unsigned tileset_mask,
 unsigned tileset_address, unsigned vram_mask, int xflip, unsigned line_count,
 unsigned line_increment, unsigned palette_mask, unsigned clip_mask,
 unsigned clip_dummy, const void *cache)
{
 /* mask for tileset range */
 tile_address &= tileset_mask;

 /* figure in the tileset address */
 tile_address += tileset_address;

 /* mask for VRAM/cache range */
 tile_address &= vram_mask;


 do
 {
  plot_palettized_even_line(screen1, screen2, output_surface_offset, depth,
   tile_address, (0 - 1), 0, (0 - 1),
   xflip, 1, line_increment, palette_mask, clip_mask, clip_dummy, cache);
 } while (output_surface_offset += 256, tile_address += line_increment,
  --line_count);
}


static void plot4_clipped_work(
 unsigned char (*screen1)[2], unsigned char (*screen2)[2],
 unsigned output_surface_offset, unsigned char depth,
 unsigned pixels, unsigned palette_mask, unsigned clip_mask)
{
  pixels &= clip_mask;
  if (!pixels) return;

  plot4_work(screen1, screen2, output_surface_offset, depth, pixels);
}

static void plot4_clipped(
 unsigned char (*screen1)[2], unsigned char (*screen2)[2],
 unsigned output_surface_offset, unsigned char depth,
 unsigned tile_address, int xflip, unsigned normal_offset,
 unsigned xflip_offset, unsigned palette_mask, unsigned clip_mask,
 const void *cache)
{
 unsigned pixels;

 if (!xflip)
 {
  pixels = * (unsigned *)
   ((unsigned char *) cache + tile_address * 8 + normal_offset);
 }
 else
 {
  pixels = * (unsigned *)
   ((unsigned char *) cache + tile_address * 8 + xflip_offset);

  pixels = swap4(pixels);
 }

 plot4_clipped_work(screen1, screen2, output_surface_offset, depth,
  pixels, palette_mask, clip_mask);
}


static void plot_line(
 unsigned char (*screen1)[2], unsigned char (*screen2)[2],
 unsigned output_surface_offset, unsigned char depth,
 unsigned tile_address, unsigned tileset_mask, unsigned tileset_address,
 unsigned vram_mask, int xflip, unsigned line_count, unsigned line_increment,
 unsigned palette_mask, unsigned clip_left, unsigned clip_right,
 const void *cache)
{
 /* mask for tileset range */
 tile_address &= tileset_mask;

 /* figure in the tileset address */
 tile_address += tileset_address;

 /* mask for VRAM/cache range */
 tile_address &= vram_mask;


 plot4_clipped(screen1, screen2, output_surface_offset, depth,
  tile_address, xflip, 0, 4, palette_mask, clip_left, cache);

 plot4_clipped(screen1, screen2, output_surface_offset + 4, depth,
  tile_address, xflip, 4, 0, palette_mask, clip_right, cache);
}

static void plot_lines(unsigned char (*screen1)[2], unsigned char (*screen2)[2],
 unsigned output_surface_offset, unsigned char depth,
 unsigned tile_address, unsigned tileset_mask,
 unsigned tileset_address, unsigned vram_mask, int xflip, unsigned line_count,
 unsigned line_increment, unsigned palette_mask,
 unsigned clip_left, unsigned clip_right, const void *cache)
{
 /* mask for tileset range */
 tile_address &= tileset_mask;

 /* figure in the tileset address */
 tile_address += tileset_address;

 /* mask for VRAM/cache range */
 tile_address &= vram_mask;


 do
 {
  plot_line(screen1, screen2, output_surface_offset, depth,
   tile_address, (0 - 1), 0, (0 - 1),
   xflip, 1, line_increment, palette_mask, clip_left, clip_right, cache);
 } while (output_surface_offset += 256, tile_address += line_increment,
  --line_count);
}


static void plot_mosaic_work(
 unsigned char (*screen1)[2], unsigned char (*screen2)[2],
 unsigned output_surface_offset, unsigned char depth,
 unsigned char pixel, int pixel_count)
{
 if (!pixel) return;
 do
 {
  if (screen1[output_surface_offset][1] <= (depth | Z_NON_DEPTH_BITS))
  {
   screen1[output_surface_offset][0] = pixel;
   screen1[output_surface_offset][1] = depth;
  }

  if (screen2)
  {
   if (screen2[output_surface_offset][1] <= (depth | Z_NON_DEPTH_BITS))
   {
    screen2[output_surface_offset][0] = pixel;
    screen2[output_surface_offset][1] = depth;
   }
  }
  output_surface_offset++;
 } while (--pixel_count);
}

static void plot_palettized_mosaic(
 unsigned char (*screen1)[2], unsigned char (*screen2)[2],
 unsigned output_surface_offset, unsigned char depth,
 unsigned tile_address, int pixel_in_tile, int pixel_count,
 unsigned palette_mask, const void *cache)
{
 unsigned char pixel;

 pixel = * ((unsigned char *) cache + tile_address * 8 + pixel_in_tile);

 pixel &= palette_mask;

 plot_mosaic_work(screen1, screen2, output_surface_offset, depth, pixel,
  pixel_count);
}

static void plot_mosaic(
 unsigned char (*screen1)[2], unsigned char (*screen2)[2],
 unsigned output_surface_offset, unsigned char depth,
 unsigned tile_address, int pixel_in_tile, int pixel_count,
 unsigned palette_mask, const void *cache)
{
 unsigned char pixel;

 pixel = * ((unsigned char *) cache + tile_address * 8 + pixel_in_tile);

 plot_mosaic_work(screen1, screen2, output_surface_offset, depth, pixel,
  pixel_count);
}


static void plot_palettized_run_mosaic(
 unsigned char (*screen1)[2], unsigned char (*screen2)[2],
 unsigned output_surface_offset, unsigned char depth,
 unsigned tile_address, unsigned tileset_mask,
 unsigned tileset_address, unsigned vram_mask, unsigned line_count,
 int pixel_in_tile, int pixel_count, unsigned palette_mask, const void *cache)
{
 /* mask for tileset range */
 tile_address &= tileset_mask;

 /* figure in the tileset address */
 tile_address += tileset_address;

 /* mask for VRAM/cache range */
 tile_address &= vram_mask;


 plot_palettized_mosaic(screen1, screen2, output_surface_offset, depth,
  tile_address, pixel_in_tile, pixel_count, palette_mask, cache);
}

static void plot_palettized_runs_mosaic(
 unsigned char (*screen1)[2], unsigned char (*screen2)[2],
 unsigned output_surface_offset, unsigned char depth,
 unsigned tile_address, unsigned tileset_mask,
 unsigned tileset_address, unsigned vram_mask, unsigned line_count,
 int pixel_in_tile, int pixel_count, unsigned palette_mask, const void *cache)
{
 /* mask for tileset range */
 tile_address &= tileset_mask;

 /* figure in the tileset address */
 tile_address += tileset_address;

 /* mask for VRAM/cache range */
 tile_address &= vram_mask;


 do
 {
  plot_palettized_run_mosaic(screen1, screen2, output_surface_offset, depth,
   tile_address, (0 - 1), 0, (0 - 1), 1, pixel_in_tile, pixel_count,
   palette_mask, cache);
 } while (output_surface_offset += 256, --line_count);
}


static void plot_run_mosaic(
 unsigned char (*screen1)[2], unsigned char (*screen2)[2],
 unsigned output_surface_offset, unsigned char depth, unsigned tile_address, unsigned tileset_mask,
 unsigned tileset_address, unsigned vram_mask, unsigned line_count,
 int pixel_in_tile, int pixel_count, unsigned palette_mask, const void *cache)
{
 /* mask for tileset range */
 tile_address &= tileset_mask;

 /* figure in the tileset address */
 tile_address += tileset_address;

 /* mask for VRAM/cache range */
 tile_address &= vram_mask;


 plot_mosaic(screen1, screen2, output_surface_offset, depth, tile_address,
  pixel_in_tile, pixel_count, palette_mask, cache);
}

static void plot_runs_mosaic(
 unsigned char (*screen1)[2], unsigned char (*screen2)[2],
 unsigned output_surface_offset, unsigned char depth,
 unsigned tile_address, unsigned tileset_mask,
 unsigned tileset_address, unsigned vram_mask, unsigned line_count,
 int pixel_in_tile, int pixel_count, unsigned palette_mask, const void *cache)
{
 /* mask for tileset range */
 tile_address &= tileset_mask;

 /* figure in the tileset address */
 tile_address += tileset_address;

 /* mask for VRAM/cache range */
 tile_address &= vram_mask;


 do
 {
  plot_run_mosaic(screen1, screen2, output_surface_offset, depth, tile_address,
   (0 - 1), 0, (0 - 1), 1, pixel_in_tile, pixel_count, palette_mask, cache);
 } while (output_surface_offset += 256, --line_count);
}


static void plot_palettized_even_mosaic(
 unsigned char (*screen1)[2], unsigned char (*screen2)[2],
 unsigned output_surface_offset, unsigned char depth,
 unsigned tile_address, int pixel_in_tile, int pixel_count,
 unsigned palette_mask, const void *cache)
{
 unsigned char pixel;

 pixel = * ((unsigned char *) cache + tile_address * 8 + pixel_in_tile * 2);

 pixel &= palette_mask;

 plot_mosaic_work(screen1, screen2, output_surface_offset, depth, pixel,
  pixel_count);
}

static void plot_palettized_even_run_mosaic(
 unsigned char (*screen1)[2], unsigned char (*screen2)[2],
 unsigned output_surface_offset, unsigned char depth,
 unsigned tile_address, unsigned tileset_mask,
 unsigned tileset_address, unsigned vram_mask, unsigned line_count,
 int pixel_in_tile, int pixel_count, unsigned palette_mask, const void *cache)
{
 /* mask for tileset range */
 tile_address &= tileset_mask;

 /* figure in the tileset address */
 tile_address += tileset_address;

 /* mask for VRAM/cache range */
 tile_address &= vram_mask;


 plot_palettized_even_mosaic(screen1, screen2, output_surface_offset, depth,
  tile_address, pixel_in_tile, pixel_count, palette_mask, cache);
}

static void plot_palettized_even_runs_mosaic(
 unsigned char (*screen1)[2], unsigned char (*screen2)[2],
 unsigned output_surface_offset, unsigned char depth,
 unsigned tile_address, unsigned tileset_mask,
 unsigned tileset_address, unsigned vram_mask, unsigned line_count,
 int pixel_in_tile, int pixel_count, unsigned palette_mask, const void *cache)
{
 /* mask for tileset range */
 tile_address &= tileset_mask;

 /* figure in the tileset address */
 tile_address += tileset_address;

 /* mask for VRAM/cache range */
 tile_address &= vram_mask;


 do
 {
  plot_palettized_even_run_mosaic(screen1, screen2, output_surface_offset,
   depth, tile_address, (0 - 1), 0, (0 - 1), 1, pixel_in_tile, pixel_count,
   palette_mask, cache);
 } while (output_surface_offset += 256, --line_count);
}


static void plot_tag4_obj_clipped_work(unsigned char (*dest_ptr)[2],
 unsigned char depth, unsigned pixels, unsigned palette_mask,
 unsigned clip_mask)
{
 pixels &= clip_mask;
 if (!pixels) return;

 pixels &= palette_mask;

 if (pixels)
 {
  int p;

  for (p = 0; p < 4; p++)
  {
   if (pixels & BITMASK(0,7))
   {
    if (!(dest_ptr[0][1] & Z_OBJ_USED))
    {
     dest_ptr[0][0] = pixels & BITMASK(0,7);
     dest_ptr[0][1] = depth;
    }
   }
   dest_ptr++;
   pixels >>= 8;
  }
 }
}

static void plot_tag4_obj_clipped(unsigned char (*dest_ptr)[2],
 unsigned char depth, unsigned tile_address, int xflip,
 unsigned normal_offset, unsigned xflip_offset, unsigned palette_mask,
 unsigned clip_mask, const void *cache)
{
 unsigned pixels;

 if (!xflip)
 {
  pixels = * (unsigned *)
   ((unsigned char *) cache + tile_address * 8 + normal_offset);
 }
 else
 {
  pixels = * (unsigned *)
   ((unsigned char *) cache + tile_address * 8 + xflip_offset);

  pixels = swap4(pixels);
 }

 plot_tag4_obj_clipped_work(dest_ptr, depth, pixels,
  palette_mask, clip_mask);
}

static void plot_tag_obj_line(unsigned char (*dest_ptr)[2],
 unsigned char depth, unsigned tile_address, int xflip,
 unsigned palette_mask, unsigned clip_left, unsigned clip_right, const void *cache)
{
 plot_tag4_obj_clipped(dest_ptr, depth, tile_address,
  xflip, 0, 4, palette_mask, clip_left, cache);

 plot_tag4_obj_clipped(dest_ptr + 4, depth, tile_address,
  xflip, 4, 0, palette_mask, clip_right, cache);
}
