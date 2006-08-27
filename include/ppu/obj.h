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

#include <string.h>

extern unsigned char DisplayZ[8 + 256 + 8];

#define GENERATE_OBJ_PALETTE(x) (0x10101010 * (x) + 0x8F8F8F8F)

typedef struct {
 int x             : 9;
 unsigned palette  : 3;
 unsigned priority : 2;
 int x_flip        : 1;
 int y_flip        : 1;
 unsigned reserved : 2;
 unsigned address  : 14;
} obj_line_descriptor;

static unsigned palette_obj[8] =
{
 GENERATE_OBJ_PALETTE(0), GENERATE_OBJ_PALETTE(1),
 GENERATE_OBJ_PALETTE(2), GENERATE_OBJ_PALETTE(3),
 GENERATE_OBJ_PALETTE(4), GENERATE_OBJ_PALETTE(5),
 GENERATE_OBJ_PALETTE(6), GENERATE_OBJ_PALETTE(7)
};

#if 0
/* abc - a = X or Y, b = s(ize) or l(imit), c = s(mall) or l(arge)
   Xss, Xls, Xsl, Xll, Yss, Yls, Ysl, Yll
 */
static unsigned char OBJ_Size_Table[8][8] =
{
 {  1,  -7,   2, -15,   1,  -7,   2, -15 }, /*   8x8, 16x16 */
 {  1,  -7,   4, -31,   1,  -7,   4, -31 }, /*   8x8, 32x32 */
 {  1,  -7,   8, -63,   1,  -7,   8, -63 }, /*   8x8, 64x64 */
 {  2, -15,   4, -31,   2, -15,   4, -31 }, /* 16x16, 32x32 */
 {  2, -15,   8, -63,   2, -15,   8, -63 }, /* 16x16, 64x64 */
 {  4, -31,   8, -63,   4, -31,   8, -63 }, /* 32x32, 64x64 */
 {  2, -15,   4, -31,   4, -31,   8, -63 }, /* 16x32, 32x64 */
 {  2, -15,   4, -31,   4, -31,   4, -31 }  /* 16x32, 32x32 */
};
#endif

/* Line counts when last OBJ of specified priority was added */
extern unsigned char OAM_Count_Priority[240][4];

/* OBJ counts (low byte) and OBJ line counts (high byte) */
extern unsigned char OAM_Count[240][2];

#define OAM_COUNT_RANGE 0
#define OAM_COUNT_TIME  1

/* Time/range overflow flags */
extern unsigned char OAM_TimeRange[240];

/* 'Complex' priority in-use flags */
extern unsigned char OAM_Low_Before_High[240];
/* Priorities for 'complex' priority detection */
extern unsigned char OAM_Lowest_Priority[240];
/* Tail entry for ring buffers */
extern unsigned char OAM_Tail[240];

/* 239 ring buffers of 34 OBJ line descriptors (32-bit) */
extern obj_line_descriptor OAM_Lines[239][34];

/* AAAA AAAA AAAA AAxx YXPP CCCX XXXX XXXX
    A - OAM OBJ line-in-tile address
    YXPP CCC  - bits 1-7 of OAM attribute word
    X - X position
 */

/* Buffer for OAM */
extern unsigned char OAM[512 + 32];
extern unsigned SpriteCount;
extern unsigned HiSprite;
extern unsigned HiSpriteCnt1, HiSpriteCnt2;
#define obj_set_1_count ((HiSpriteCnt1 >> 8) & 0xFF)
#define obj_set_1_shift (HiSpriteCnt1 & 0xFF)
#define obj_set_2_count ((HiSpriteCnt2 >> 8) & 0xFF)
#define obj_set_2_shift (HiSpriteCnt2 & 0xFF)

/* First set size and bit offset */
//unsigned char obj_set_1_count, obj_set_1_shift;
/* Second set size and bit offset */
//unsigned char obj_set_2_count, obj_set_2_shift;

/* VRAM location of OBJ tiles 00-FF */
extern unsigned OBBASE;
/* VRAM location of OBJ tiles 100-1FF */
extern unsigned OBNAME;

extern unsigned OAMAddress;

/* Restore this at VBL */
extern unsigned OAMAddress_VBL;

extern unsigned char *HiSpriteAddr; /* OAM address of OBJ in 512b table */
extern unsigned char *HiSpriteBits; /* OAM address of OBJ in 32b table */

#define OBJ_SMALL 0
#define OBJ_LARGE 1

#define OBJ_SIZE 0
#define OBJ_LIM 1

/* objsize_small_x objlim_small_x */
/* objsize_large_x objlim_large_x */
/* objsize_small_y objlim_small_y */
/* objsize_large_y objlim_large_y */
#define objsize_small_x obj_size_current_x[OBJ_SMALL][OBJ_SIZE]
#define objsize_large_x obj_size_current_x[OBJ_LARGE][OBJ_SIZE]
#define objsize_small_y obj_size_current_y[OBJ_SMALL][OBJ_SIZE]
#define objsize_large_y obj_size_current_y[OBJ_LARGE][OBJ_SIZE]
#define objlim_small_x obj_size_current_x[OBJ_SMALL][OBJ_LIM]
#define objlim_large_x obj_size_current_x[OBJ_LARGE][OBJ_LIM]
#define objlim_small_y obj_size_current_y[OBJ_SMALL][OBJ_LIM]
#define objlim_large_y obj_size_current_y[OBJ_LARGE][OBJ_LIM]
#define obj_size_current_x Sprite_Size_Current_X
#define obj_size_current_y Sprite_Size_Current_Y
extern unsigned char Sprite_Size_Current_X[2][2];
extern unsigned char Sprite_Size_Current_Y[2][2];

//unsigned char obj_size_current_x[2][2];
//unsigned char obj_size_current_y[2][2];

/* value to XOR with OBJ current line for v-flip
   used for rectangular (undocumented) OBJ
 */
unsigned char obj_vflip_fixup;

extern unsigned char Redo_OAM;
/* OBJ Priority Rotation latch flag */
extern unsigned char SPRLatch;
/* sssnnxbb  sss=OBJ size,nn=upper 4k address,bb=offset */
extern unsigned char OBSEL;
extern unsigned char OAMHigh;
extern unsigned char OAM_Write_Low;

static unsigned char obj_buffer_base[8 + 256 + 8][2];
#define obj_buffer (obj_buffer_base + 8)

/* used to keep track of used area of OBJ buffer, for drawing and clearing */
LAYER_WIN_DATA actual_obj = { 1, { { 0, 0 }, { 0, 0 }, { 0, 0 } } };

int Build_OBJ(unsigned line, unsigned char (*band)[2])
{
 int first_pixel = 256, last_pixel = -1;

 if (!OAM_Count[line][OAM_COUNT_TIME]) return 0;

 /* clear previously used area */
 {
  int start, used;

  start = actual_obj.bands[0][0];
  used = (actual_obj.bands[0][1] ? actual_obj.bands[0][1] : 256) - start;

  memset(obj_buffer + start, 0, used * 2);
 }

 if (!OAM_Low_Before_High[line])
 /* No lower priority OBJ before higher priority OBJ */
 {
  int count1 = 0, count2;
  obj_line_descriptor *next_line;

  if (OAM_Count[line][OAM_COUNT_TIME] < 34)
   count1 = OAM_Count[line][OAM_COUNT_TIME];
  else
   count1 = OAM_Tail[line] ? OAM_Tail[line] : 34;

  next_line = &OAM_Lines[line][count1 - 1];
  count2 = OAM_Count[line][OAM_COUNT_TIME] - count1;

  for ( ;
   /* first set setup */
   /* 2 sets, max */
   count1 + count2;
   /* second set setup */
   count1 += count2,
   count2 = 0,
   next_line += 34
   ) do
  {
   unsigned tile_address;
   unsigned palette_mask;

   if (next_line[0].x < first_pixel) first_pixel = next_line[0].x;
   if (next_line[0].x + 8 > last_pixel) last_pixel = next_line[0].x + 8;

   /* get tile-line address, already masked and adjusted */
   tile_address = next_line[0].address;

   palette_mask = palette_obj[next_line[0].palette];

   plot_palettized_line(
    /* Setup output pointer, adjusted for X position of OBJ */
    obj_buffer + next_line[0].x, 0, 0,
    /* Setup priority */
    (next_line[0].priority + 1) << Z_POSITION_SHIFT, tile_address,
    /* pre-masked to tileset */
    (0 - 1),
    /* tileset address pre-added */
    0,
    /* pre-masked for VRAM / tile-line cache address */
    (0 - 1),
    next_line[0].x_flip, 1, 0, palette_mask,
    (0 - 1), (0 - 1), TileCache4);
  } while (--next_line, --count1);

 }
 else
 /* Some lower priority OBJ before higher priority OBJ */
 {
  int count1, count2;
  obj_line_descriptor *next_line;

  count2 = OAM_Tail[line];
  count1 = OAM_Count[line][OAM_COUNT_TIME] - count2;

  next_line = &OAM_Lines[line][OAM_Tail[line]];

  for ( ;
   /* first set setup */
   /* 2 sets, max */
   count1 + count2;
   /* second set setup */
   count1 += count2,
   count2 = 0,
   next_line -= 34
   ) do
  {
   unsigned tile_address;

   /* get tile-line address, already masked and adjusted */
   tile_address = next_line[0].address;

   {
    unsigned palette_mask;

    if (first_pixel > next_line[0].x) first_pixel = next_line[0].x;
    if (last_pixel < next_line[0].x + 8) last_pixel = next_line[0].x + 8;

    palette_mask = palette_obj[next_line[0].palette];

    plot_tag_obj_line(
     /* Setup output pointer, adjusted for X position of OBJ */
     obj_buffer + next_line[0].x,
     /* Setup priority */
	 ((next_line[0].priority + 1) << Z_POSITION_SHIFT) | Z_OBJ_USED,
     tile_address, next_line[0].x_flip, palette_mask, (0 - 1), (0 - 1),
     TileCache4);
   }

  } while (++next_line, --count1);

 }

 band[0][0] = first_pixel >= 0 ? first_pixel & BITMASK(0,7) : 0;
 band[0][1] = last_pixel <= 256 ? last_pixel & BITMASK(0,7) : 0;

 return 1;
}

void _Plot_Sprites(unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2],
 unsigned output_surface_offset,
 unsigned char layers1, unsigned char layers2, unsigned line, int line_count)
{

 line--;

 for (; line_count; output_surface_offset += 256,
  line++, line_count--)
 {
  int first_window, num_windows;
  int window;

  const LAYER_WIN_DATA *obj_win;

  int runs_left;
  const unsigned char (*bands)[2]; /* RunListPtr */

  LAYER_WIN_DATA clipped_obj;

  actual_obj.count = Build_OBJ(line, &actual_obj.bands[0]);

  if (!actual_obj.count) continue;

  num_windows = setup_windows_for_layer(&first_window);

  for (window = 0; window < num_windows; window++)
  {
   unsigned char (*screen1)[2], (*screen2)[2];
   unsigned char arithmetic_used;

   arithmetic_used = setup_screens_for_layer(&screen1, &screen2,
    window, main_buf, sub_buf);
   if (!screen1) continue;

   obj_win = &win_obj[first_window + window];

   merge_layer_win_with_and(&clipped_obj,
    &actual_obj,
    obj_win, 0);

   runs_left = clipped_obj.count;
   bands = (const unsigned char (*)[2]) clipped_obj.bands;

   for (; runs_left--; bands++)
   {
    unsigned next_pixel;
    int pixel_count;

    /* (right edge + 1) - left edge */
    next_pixel = bands[0][0];
    pixel_count = (bands[0][1] ? bands[0][1] : 256) - bands[0][0];

    for ( ; pixel_count; next_pixel++, pixel_count--)
    {
     unsigned char pixel;
     unsigned char depth;

     pixel = obj_buffer[next_pixel][0];
     if (!pixel) continue;

     depth = obj_buffer[next_pixel][1] & ~Z_OBJ_USED;
	 if (pixel & 0x40) depth |= arithmetic_used;

     if (screen1[output_surface_offset + next_pixel][1] <=
      (depth | Z_NON_DEPTH_BITS))
     {
      screen1[output_surface_offset + next_pixel][0] = pixel;
      screen1[output_surface_offset + next_pixel][1] = depth;
     }

     if (screen2)
     {
      if (screen2[output_surface_offset + next_pixel][1] <=
       (depth | Z_NON_DEPTH_BITS))
      {
       screen2[output_surface_offset + next_pixel][0] = pixel;
       screen2[output_surface_offset + next_pixel][1] = depth;
      }

     }

    }

   }

  }

 }

}


#define OAM_TIME_OVER BIT(7)
#define OAM_RANGE_OVER BIT(6)

/* AAAA AAAA AAAA AAxx YXPP CCCX XXXX XXXX
   A - OAM sprite line-in-tile address
   YXPP CCC  - bits 1-7 of OAM attribute word
   X - X position
*/
/* adds start_count line-descriptors to end of list,
  end_count line-descriptors to start of list */
void add_obj_worker(obj_line_descriptor *ring, int start_count, int end_count,
 unsigned line_address, unsigned tile_offset, unsigned line_offset,
 unsigned tile_increment, obj_line_descriptor partial)
{
 do
 {
  for ( ; start_count; ring++, tile_offset += tile_increment, partial.x -= 8,
   --start_count)
  {
   /* compute tile line #'s and store line descriptors */
   unsigned temp_line_address;

   temp_line_address = ((((line_address + tile_offset) & BITMASK(0,3)) +
    (line_address & ~BITMASK(0,3))) * 8) + line_offset;

   temp_line_address &=
    (BITMASK(0,8) * 8 + /* OBJ tile range */
    BITMASK(0,2));      /* line in tile range */

   temp_line_address += !(temp_line_address & (BIT(8) * 8)) ?
    OBBASE : OBNAME;

   partial.address = temp_line_address;

   *ring = partial;
  }

 } while (ring -= 34, start_count += end_count, end_count = 0, start_count);

}

void Add_OBJ(unsigned char *obj_data, int obj_size_select,
 int obj_x_position, int tile_start_offset, int tile_count)
{
 unsigned line, total_lines, visible_lines, line_offset = 0;
 unsigned tile_offset = 0;
 unsigned tile_address;
 int tile_increment = 0;

 /* if OBJ not on any scanlines, nothing to do */
 if (obj_data[1] >= 239 && (256 - obj_data[1] >=
  (obj_size_current_y[obj_size_select][OBJ_SIZE] * 8))) return;

 total_lines = (obj_size_current_y[obj_size_select][OBJ_SIZE] * 8);

 visible_lines = (obj_data[1] >= 239) ?
  (256 - obj_data[1] >= total_lines ? 0 : total_lines - (256 - obj_data[1])) :
  (239 - obj_data[1] <= total_lines ? 239 - obj_data[1] : total_lines);

 line_offset = (obj_data[1] >= 239) ? total_lines - visible_lines : 0;

 line = (obj_data[1] + line_offset) & 0xFF;

 /* Get base tile # */
 tile_address = (obj_data[2] + (obj_data[3] << 8));

 if (!(obj_data[3] & BIT(6)))
 /* no X-flip */
 {
  tile_offset = tile_start_offset + tile_count - 1;
  tile_increment = -1;
 }
 else
 /* X flip */
 {
  tile_offset = obj_size_current_x[obj_size_select][OBJ_SIZE] - 1 -
   (tile_start_offset + tile_count - 1);
  tile_increment = 1;
 }

 for (; visible_lines; line++, line_offset++, visible_lines--)
 {
  unsigned this_line_offset, this_tile_address;
  obj_line_descriptor *next_line;
  obj_line_descriptor partial;
  int count1 = 0, count2;
  int priority;

  /* Check OBJ count for line (if 32, set range over and ignore OBJ) */
  if (OAM_Count[line][OAM_COUNT_RANGE] >= 32)
  /* skip OBJ over 'range' limit (32 OBJ) */
  {
   OAM_TimeRange[line] |= OAM_RANGE_OVER;

   continue;
  }
  /* else increment OBJ count */
  OAM_Count[line][OAM_COUNT_RANGE]++;

  /* check and handle Y-flip */
  this_line_offset = !(obj_data[3] & BIT(7)) ? line_offset :
   (total_lines - line_offset - 1) ^ obj_vflip_fixup;

  /* tile address adjusted for current line */
  this_tile_address = tile_address + ((this_line_offset & ~7) * (16 / 8));

  /* Check tile count for line (if 34, set time over and ignore tiles) */
  /* If will be over 34, set time over and adjust width */

  /* setup pointer to line descriptors to be used, update line count */
  next_line = &OAM_Lines[line][0];

  if (OAM_Count[line][OAM_COUNT_TIME] == 34)
  {
   next_line += OAM_Tail[line];

   if (OAM_Tail[line] + tile_count <= 34)
   {
    count1 = tile_count;
   }
   else
   {
    count1 = 34 - OAM_Tail[line];
   }

   if (OAM_Tail[line] + tile_count < 34)
   {
    OAM_Tail[line] = OAM_Tail[line] + tile_count;
   }
   else
   /* handle ring buffer wrapping */
   {
    OAM_Tail[line] = OAM_Tail[line] + tile_count - 34;
   }

   OAM_TimeRange[line] |= OAM_TIME_OVER;
  }
  else
  {
   next_line += OAM_Count[line][OAM_COUNT_TIME];

   /* handle ring buffer wrapping */
   if (OAM_Count[line][OAM_COUNT_TIME] + tile_count > 34)
   {
    count1 = 34 - OAM_Count[line][OAM_COUNT_TIME];
    OAM_Tail[line] = OAM_Count[line][OAM_COUNT_TIME] + tile_count - 34;

    OAM_TimeRange[line] |= OAM_TIME_OVER;

    OAM_Count[line][OAM_COUNT_TIME] = 34;
   }
   else
   {
    count1 = tile_count;
 
    OAM_Count[line][OAM_COUNT_TIME] = OAM_Count[line][OAM_COUNT_TIME] +
     tile_count;
   }
  }
  count2 = tile_count - count1;

  /* Determine if OBJ sequence on line contains higher priorities
    after lower priorities, set new last-tile-for-priority */
  priority = obj_data[3] & 0x30;

  if (OAM_Lowest_Priority[line] < priority)
  {
   OAM_Low_Before_High[line] = (0 - 1);
  }
  else
  {
   OAM_Lowest_Priority[line] = priority;
  }

  OAM_Count_Priority[line][priority >> 4] = OAM_Count[line][OAM_COUNT_TIME];
  partial.x = obj_x_position + (count1 + count2 - 1) * 8;
  partial.palette  = (obj_data[3] & BITMASK(1,3)) >> 1;
  partial.priority = (obj_data[3] & BITMASK(4,5)) >> 4;
  partial.x_flip = obj_data[3] & BIT(6) ? 1 : 0;
  partial.y_flip = obj_data[3] & BIT(7) ? 1 : 0;

  add_obj_worker(next_line, count1, count2,
   this_tile_address, tile_offset, (this_line_offset & 7), tile_increment,
   partial);
 }

}

void _Recache_OAM(void)
{
#ifdef Profile_Recache_OAM
 Calls_Recache_OAM++;
#endif

 /* Clear count and other tables */
 memset(OAM_Count_Priority, 0, sizeof(OAM_Count_Priority));
 memset(OAM_Count, 0, sizeof(OAM_Count));
 memset(OAM_Tail, 0, sizeof(OAM_Tail));
 memset(OAM_TimeRange, 0, sizeof(OAM_TimeRange));
 memset(OAM_Low_Before_High, 0, sizeof(OAM_Low_Before_High));
 memset(OAM_Lowest_Priority, 0, sizeof(OAM_Lowest_Priority));

 /* OAM 512 byte subtable address OAM+(0-511) */
 unsigned char *obj_data;
 /* edi = OAM 32 byte subtable address OAM+(512-543) */
 unsigned char *obj_bits;
 /* count of OBJ left in current decode pass (1-128) */
 int obj_count;
 /* variable shift count for OAM subtable (0, 2, 4, 6) */
 int obj_bits_shift;

 int set;

 for (
  /* first set setup */
  set = 0,
  obj_bits_shift = obj_set_1_shift,
  obj_count = obj_set_1_count,
  obj_data = HiSpriteAddr,
  obj_bits = HiSpriteBits;
  /* 2 sets, max */
  set < 2;
  /* second set setup */
  set++,
  obj_bits_shift = obj_set_2_shift,
  obj_count = obj_set_2_count,
  obj_data -= 128 * 4,
  obj_bits -= 128 * 2 / 8
  )
 {
  for (; obj_count > 0; obj_count--,
   /* go to next OBJ XYAA bytes */
   obj_data += 4,
   /* adjust variable shift count, go to next sprite X-MSB/size byte
       if needed */
   obj_bits += (obj_bits_shift -= 2) >= 0 ? 0 : 1, obj_bits_shift &= 7)
  {
  /* Tile attribute word: YXPP CCCT TTTT TTTT
      Where:
       Y, X are vertical/horizontal flip
       P is priority
       C is color palette selector
       T is tile number

     AAAA AAAA AAAA AAAA YXPP CCCX XXXX XXXX
      A - OAM OBJ line-in-tile address
      YXPP CCC  - bits 1-7 of OAM attribute word
      X - X position
   */

   /* Perform clipping & determine visible range */

   /* Get size */
   int obj_size_select = !((*obj_bits << obj_bits_shift) & 0x80) ?
    OBJ_SMALL : OBJ_LARGE;

   /* count of on-screen tiles */
   int tile_count = obj_size_current_x[obj_size_select][OBJ_SIZE];
   /* first on-screen tile from leftmost */
   int tile_start_offset = 0;

   int obj_x_position = 0;

   if (!((*obj_bits << obj_bits_shift) & 0x40))
   /* positive X */
   {
    /* width in tiles <= 32 - (X & 0xFF) / 8 for +X */
    int max_tiles;

    obj_x_position = obj_data[0];
	
	max_tiles = 32 - obj_x_position / 8;

    if (tile_count >= max_tiles) tile_count = max_tiles;

   }
   else
   /* negative X */
   {
    /* Determine if OBJ is entirely offscreen */
    if (obj_data[0] < obj_size_current_x[obj_size_select][OBJ_LIM])
     continue;

    /* tile offset to start from (left edge) */
    /* 32 - (((X & 0xFF) + 7) / 8) for -X */
    tile_start_offset = ((((unsigned) obj_data[0] + 7) / 8) ^ (0 - 1)) + 33;

    obj_x_position = obj_data[0] - 0x100 + tile_start_offset * 8;

    /* width in tiles -= tile start offset */
    tile_count -= tile_start_offset;
   }

   obj_vflip_fixup =
    (obj_size_current_x[obj_size_select][OBJ_SIZE] ==
    obj_size_current_y[obj_size_select][OBJ_SIZE]) ? 0 :
    obj_size_current_x[obj_size_select][OBJ_SIZE] * 8;

   Add_OBJ(obj_data, obj_size_select, obj_x_position, tile_start_offset,
    tile_count);

  }
 }

 Redo_OAM = 0;
}

void _Check_OAM_Recache(void)
{
 unsigned temp_oam_address;

 /* if priority rotation is off, treat OAM address as 0 */
 temp_oam_address = (SPRLatch & 0x80) ? OAMAddress : 0;

 /* convert address to OBJ # and compare */
 if (((temp_oam_address / 2) & (128 - 1)) != HiSprite
  || (HiSpriteCnt1 & 1))
 {
 unsigned xobj_set_1_shift, xobj_set_1_count;
 unsigned xobj_set_2_shift, xobj_set_2_count;
  /* priority update */
  HiSprite = (temp_oam_address / 2) & (128 - 1);
  HiSpriteAddr = OAM + (HiSprite * 4);
  HiSpriteBits = OAM + (HiSprite * 2 / 8) + (128 * 4);
  xobj_set_1_shift = (6 - HiSprite * 2) & 7;
  xobj_set_1_count = 128 - HiSprite;
  xobj_set_2_shift = 6;
  xobj_set_2_count = HiSprite;
 HiSpriteCnt1 = xobj_set_1_shift + (xobj_set_1_count << 8);
 HiSpriteCnt2 = xobj_set_2_shift + (xobj_set_2_count << 8);
 }
 else if (!Redo_OAM) return;

 _Recache_OAM();
}

void _Reset_Sprites(void)
{
 unsigned xobj_set_1_shift, xobj_set_1_count;
 unsigned xobj_set_2_shift, xobj_set_2_count;

 /* Reset OBJ renderer vars */
 HiSprite = 0;
 HiSpriteAddr = OAM;
 HiSpriteBits = OAM + (128 * 4);
 xobj_set_1_shift = (6 - HiSprite * 2) & 7;
 xobj_set_1_count = 128 - HiSprite;
 xobj_set_2_shift = 6;
 xobj_set_2_count = HiSprite;
HiSpriteCnt1 = xobj_set_1_shift + (xobj_set_1_count << 8);
HiSpriteCnt2 = xobj_set_2_shift + (xobj_set_2_count << 8);

 Redo_OAM = (0 - 1);

 /*
 mov ecx,[OBJ_Size_Table]
 mov edx,[OBJ_Size_Table+4]
 mov [OBJ_Size_Current_X],ecx
 mov [OBJ_Size_Current_Y],edx
 */

 OBBASE = 0;
 OBNAME = 0;

 /* Reset OBJ port vars */
 OAMAddress = 0;
 OAMAddress_VBL = 0;
 OAMHigh = 0;
 OAM_Write_Low = 0;
 SPRLatch = 0;
 OBSEL = 0;

}
