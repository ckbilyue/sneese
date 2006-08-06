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

#include <stdio.h>
#include "helper.h"
#include "misc.h"

unsigned char ClipTableStart[] =
{
 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

/*
extern unsigned char ClipTableStart[];
*/

extern unsigned char Used_TM, Used_TS;
extern unsigned char Layers_In_Use;

extern unsigned MosaicCountdown;
extern unsigned Mosaic_Size;
extern unsigned char MosaicLine[16][256];
extern unsigned char MosaicCount[16][256];

extern unsigned char CGWSEL;


#define clip_left_table (ClipTableStart + 16)
#define clip_right_table (ClipTableStart + 32)

unsigned tile_clip_1_left, tile_clip_1_right;
unsigned tile_clip_2_left, tile_clip_2_right;


/* TODO: Move this to a common header */
extern unsigned char TileCache2[4 * 64 << 10];
extern unsigned char TileCache4[2 * 64 << 10];
extern unsigned char TileCache8[1 * 64 << 10];


#include "ppu/plotbase.h"



typedef enum
{
 /* BG not present in this mode; 'simple' BGs with 2, 4, and 8-bpp tiles; */
 BBT_NONE,      BBT_2BPP,       BBT_4BPP,           BBT_8BPP,
 /* mode 7 matrix BG; 2, 4, and 8-bpp BGs using offset-per-tile map; */
 BBT_MATRIX,    BBT_2BPP_OPT,   BBT_4BPP_OPT,       BBT_8BPP_OPT,
 /* mode 7 EXTBG; mode 0 2-bpp BG with separate palette sets per BG */
 /* mode 6 hi-res 4-bpp BG with offset-per-tile map; unused type number */
 BBT_EXTBG,     BBT_2BPP_PAL,   BBT_4BPP_OPT_HI,    BBT_RESERVED1,
 /* unused type number; mode 5 hi-res BGs with 2 and 4-bpp tiles */
 BBT_RESERVED2, BBT_2BPP_HI,    BBT_4BPP_HI,        BBT_TYPE_COUNT, /* 15 */
 /* bits used for base type */
 BBT_BASE            = BITMASK(0,3),
 /* modifiers to the base types */
 /* large BG tiles (16x16), as opposed to small (8x8, 16x8) */
 BBT_TILES_LARGE     = BIT(4),
 /* large offset-change tiles (similar to preceding) */
 BBT_OPT_TILES_LARGE = BIT(5),
 /* ignore priority */
 BBT_NO_PRI          = BIT(6),
 /* multiple lines per call */
 BBT_MULTI           = BIT(7)
} BGMODE_BG_TYPE;


unsigned char bgmode_bg_type_table[8][4] =
{
 { BBT_2BPP_PAL,    BBT_2BPP_PAL, BBT_2BPP_PAL, BBT_2BPP_PAL },
 { BBT_4BPP,        BBT_4BPP,     BBT_2BPP,     BBT_NONE     },
 { BBT_4BPP_OPT,    BBT_4BPP_OPT, BBT_NONE,     BBT_NONE     },
 { BBT_8BPP,        BBT_4BPP,     BBT_NONE,     BBT_NONE     },
 { BBT_8BPP_OPT,    BBT_2BPP_OPT, BBT_NONE,     BBT_NONE     },
 { BBT_4BPP_HI,     BBT_2BPP_HI,  BBT_NONE,     BBT_NONE     },
 { BBT_4BPP_OPT_HI, BBT_NONE,     BBT_NONE,     BBT_NONE     },
 { BBT_MATRIX,      BBT_EXTBG,    BBT_NONE,     BBT_NONE     }
};


void update_bg_handlers(unsigned char BGMODE)
{
 BG_TABLE *bg[4] =
 {
  &bg_table_1, &bg_table_2, &bg_table_3, &bg_table_4
 };
 int i;
 int small_tile_width;

 small_tile_width = ((BGMODE & 7) == 5 || (BGMODE & 7) == 6) ? 2 : 1;

 for (i = 0; i < 4; i++)
 {
  int depth;
  extern unsigned *Depth_NBA_Table[4];
  
  depth = bgmode_bg_type_table[BGMODE & 7][i];

  /* set flag on large BG tiles */
  if (BGMODE & BIT(i + 4))
  {
   depth |= BBT_TILES_LARGE;
   bg[i]->tile_height = 2;
   bg[i]->tile_width = 2;
  }
  else
  {
   bg[i]->tile_height = 1;
   bg[i]->tile_width = small_tile_width;
  }

  /* set flag on large BG3 tiles */
  if (BGMODE & BIT((3 - 1) + 4))
  {
   depth |= BBT_OPT_TILES_LARGE;
  }

  bg[i]->depth = depth;
  bg[i]->nba_table = Depth_NBA_Table[depth & 3];
  if (bg[i]->nba_table)
   bg[i]->set_address = bg[i]->nba_table[bg[i]->nba];
 }
}



#define BGSC_FLIP_Y_BIT 15
#define BGSC_FLIP_Y BIT(BGSC_FLIP_Y_BIT)

#define BGSC_FLIP_X_BIT 14
#define BGSC_FLIP_X BIT(BGSC_FLIP_X_BIT)

#define BGSC_PRIORITY_BIT 13
#define BGSC_PRIORITY BIT(BGSC_PRIORITY_BIT)

#define BGSC_PALETTE_SHIFT 10
#define BGSC_PALETTE BITMASK(BGSC_PALETTE_SHIFT, BGSC_PALETTE_SHIFT + 3 - 1)

#define BGSC_TILE_SHIFT 0
#define BGSC_TILE BITMASK(BGSC_TILE_SHIFT, BGSC_TILE_SHIFT + 10 - 1)


#define GENERATE_2BPL_PALETTE(x) (0x04040404 * (x) + 0x03030303)
#define GENERATE_4BPL_PALETTE(x) (0x10101010 * (x) + 0x0F0F0F0F)

static unsigned palette_2bpl[8] =
{
 GENERATE_2BPL_PALETTE(0), GENERATE_2BPL_PALETTE(1),
 GENERATE_2BPL_PALETTE(2), GENERATE_2BPL_PALETTE(3),
 GENERATE_2BPL_PALETTE(4), GENERATE_2BPL_PALETTE(5),
 GENERATE_2BPL_PALETTE(6), GENERATE_2BPL_PALETTE(7)
};

static unsigned palette_4bpl[8] =
{
 GENERATE_4BPL_PALETTE(0), GENERATE_4BPL_PALETTE(1),
 GENERATE_4BPL_PALETTE(2), GENERATE_4BPL_PALETTE(3),
 GENERATE_4BPL_PALETTE(4), GENERATE_4BPL_PALETTE(5),
 GENERATE_4BPL_PALETTE(6), GENERATE_4BPL_PALETTE(7)
};


unsigned char priority_used, priority_unused;


#define GENERATE_TILE_OFFSET_TABLE(vtile) \
 16*8*(vtile),      16*8*(vtile)+1,     16*8*(vtile)+2,     16*8*(vtile)+3, \
 16*8*(vtile)+4,    16*8*(vtile)+5,     16*8*(vtile)+6,     16*8*(vtile)+7

unsigned tile_offset_table_16_8[16] =
{
 GENERATE_TILE_OFFSET_TABLE(0),
 GENERATE_TILE_OFFSET_TABLE(1)
};


typedef enum
{
 PRI_SEL_NONE, PRI_SEL_LO, PRI_SEL_HI, PRI_SEL_VAR
} PRIORITY_SELECT;



static void sort_screen_height(BG_TABLE *bg_table, unsigned current_line)
{
 int first_in_left_map, line_in_top_map;

 /* first tile in left screen map? */
 first_in_left_map = !((bg_table->hscroll >> 8) & bg_table->tile_width);
 /* line in top screen map? */
 line_in_top_map = !(((bg_table->vscroll + current_line) >> 8) &
  bg_table->tile_height);

 if (line_in_top_map)
 {
  bg_table->vl_map_address =
   first_in_left_map ? bg_table->tl_map_address : bg_table->tr_map_address;
  bg_table->vr_map_address =
   first_in_left_map ? bg_table->tr_map_address : bg_table->tl_map_address;
 }
 else
 {
  bg_table->vl_map_address =
   first_in_left_map ? bg_table->bl_map_address : bg_table->br_map_address;
  bg_table->vr_map_address =
   first_in_left_map ? bg_table->br_map_address : bg_table->bl_map_address;
 }
}

static void sort_tiles_8_tall(unsigned vscroll,
 unsigned *tile_line_address, unsigned *tile_line_address_y,
 unsigned *screen_line_address, unsigned line_to_render)
{
 unsigned line_in_screen = vscroll + line_to_render;

 /* unflipped and vertically-flipped indices into tiles for selected lines */
 *tile_line_address = line_in_screen & 7;
 *tile_line_address_y = 7 - (line_in_screen & 7);

 /* screen map row # * 32 words */
 *screen_line_address = (line_in_screen & (0x1F << 3)) << 3;
}

static void sort_tiles_16_tall(unsigned vscroll,
 unsigned *tile_line_address, unsigned *tile_line_address_y,
 unsigned *screen_line_address, unsigned line_to_render)
{
 unsigned line_in_screen = vscroll + line_to_render;

 /* unflipped and vertically-flipped indices into tiles for selected lines */
 *tile_line_address = tile_offset_table_16_8[line_in_screen & 15];
 *tile_line_address_y = (16 * 8 + 7) - *tile_line_address;

 /* screen map row # * 32 words */
 *screen_line_address = (line_in_screen & (0x1F << 4)) << 2;
}


#define FETCH_TILE_NAME \
 { \
  map_hi = * (((const unsigned char *) map_address) + 1); \
 \
  CHECK_PRIORITY \
 \
  map_lo = * (const unsigned char *) map_address; \
 \
  map = (map_lo + (map_hi << 8)); \
 }


#define GENERATE_TILE_ADDRESS \
 { \
  /* no, we're not masking it here.  it gets done later, though. */ \
  tile_address = map * 8; \
 \
  if (!(map & BGSC_FLIP_Y)) \
  { \
   tile_address += tile_line_address; \
   line_increment = 1; \
  } \
  else \
  { \
   tile_address += tile_line_address_y; \
   line_increment = (0 - 1); \
  } \
 }

#define GENERATE_PALETTE(DEPTH,BASE) \
 (palette_mask = (BASE) | ((DEPTH) == 8 ? \
  (map & BGSC_PALETTE) >> BGSC_PALETTE_SHIFT : ((DEPTH) == 4 ? \
  palette_4bpl[((map & BGSC_PALETTE) >> BGSC_PALETTE_SHIFT)] : ((DEPTH) == 2 ? \
  palette_2bpl[((map & BGSC_PALETTE) >> BGSC_PALETTE_SHIFT)] : \
  0 )))); \
 (depth |= (DEPTH) == 8 ? (palette_mask << Z_PALETTE_SHIFT) : 0);

#define SETUP_BACKGROUND_TILE(DEPTH,BASE) \
 { \
  FETCH_TILE_NAME \
  GENERATE_TILE_ADDRESS \
  GENERATE_PALETTE(DEPTH,BASE) \
 }

#define LAYER_PRESENT(layer,n) ((layer) & BIT((n) - 1))
extern unsigned char Layering_Mode;

int setup_windows_for_layer(int *first_window)
{
 switch (Layering_Mode)
 {
 case 1:
  *first_window = OFFSET_BG_WIN_MAIN;
  return 1;
 case 2:
  *first_window = OFFSET_BG_WIN_SUB;
  return 1;
 case 0:
 default:
  *first_window = OFFSET_BG_WIN_MAIN_NO_COL;
  return 5;
 }
}

unsigned char setup_screens_for_layer(
 unsigned char (**screen1)[2], unsigned char (**screen2)[2],
 int window, unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2])
{
 switch (window)
 {
 /* layering mode 0: main screen only, arithmetic */
 case 1:
  *screen1 = main_buf;
  *screen2 = 0;
  return Z_ARITHMETIC_USED;
 /* layering mode 0: sub screen only */
 case 2:
  *screen1 = (CGWSEL & 2) ? sub_buf : 0;
  *screen2 = 0;
  return 0;
 /* layering mode 0: both screens, arithmetic */
 case 3:
  *screen1 = main_buf;
  *screen2 = (CGWSEL & 2) ? sub_buf : 0;
  return Z_ARITHMETIC_USED;
 /* layering mode 0: both screens, no arithmetic */
 case 4:
  *screen1 = main_buf;
  *screen2 = (CGWSEL & 2) ? sub_buf : 0;
  return 0;
 case 0:
 /* layering mode 0: main screen only, no arithmetic */
 /* layering mode 1: main screen, no arithmetic */
 /* layering mode 2: sub screen to main, no arithmetic */
 default:
  *screen1 = (Layering_Mode != 2 || CGWSEL & 2) ? main_buf : 0;
  *screen2 = 0;
  return 0;
 }
}

extern void clear_scanlines(unsigned lines);


#include "ppu/obj.h"

#include "ppu/bgn.h"

#include "ppu/bgm.h"

#include "ppu/bgo.h"
 
#include "ppu/bgom.h"
 
#include "ppu/mode7.h"

extern unsigned Current_Line_Render;
extern unsigned char INIDISP, MOSAIC;
extern unsigned char Display_Needs_Update;
extern unsigned char Redo_Layering;
extern unsigned char Redo_Windowing;
extern unsigned char Redo_Offset_Change;
extern unsigned char Tile_Layers_Enabled;
extern unsigned char SCR_TM, SCR_TS;
extern unsigned char TM, TS;
extern unsigned char BGMODE_Tile_Layer_Mask;
extern unsigned BaseDestPtr;
extern int Tile_Recache_Set_Begin, Tile_Recache_Set_End;

extern void (*Render_Mode)(
 unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2],
 unsigned output_surface_offset,
 unsigned current_line, unsigned lines,
 unsigned layers1, unsigned layers2
);

static void _SCREEN_MODE_0_1(
 unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2],
 unsigned output_surface_offset,
 unsigned current_line, unsigned lines,
 unsigned layers1, unsigned layers2
);

static void _SCREEN_MODE_2_6(
 unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2],
 unsigned output_surface_offset,
 unsigned current_line, unsigned lines,
 unsigned layers1, unsigned layers2
);

static void _SCREEN_MODE_7(
 unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2],
 unsigned output_surface_offset,
 unsigned current_line, unsigned lines,
 unsigned layers1, unsigned layers2
);

void (*Screen_Mode[8])(
 unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2],
 unsigned output_surface_offset,
 unsigned current_line, unsigned lines,
 unsigned layers1, unsigned layers2
) =
{
 _SCREEN_MODE_0_1,
 _SCREEN_MODE_0_1,
 _SCREEN_MODE_2_6,
 _SCREEN_MODE_2_6,
 _SCREEN_MODE_2_6,
 _SCREEN_MODE_2_6,
 _SCREEN_MODE_2_6,
 _SCREEN_MODE_7
};


extern void (*Render_Select)(
 unsigned current_line,
 unsigned lines,
 unsigned output_surface_offset);

void _Update_Offset_Change(void)
{
/* TODO: reimplement this as C, and with 16x16 offset map support */
/* and figure out wth it's doing */
#if 0
Update_Offset_Change:
 mov byte [Redo_Offset_Change],0

 mov al,[Redo_Offset_Change_VOffsets]
 LOAD_BG_TABLE 3
 test al,al
 jz .no_recalc_voffsets

 mov byte [Redo_Offset_Change_VOffsets],0

;OffsetChangeMap_VOffset = ((BG3VOFS / 8) & 0x1F) * 64 +
; (BG3VOFS & 0x100 ? BLMapAddressBG3 - TLMapAddressBG3 : 0);
;OffsetChangeVMap_VOffset = ((BG3VOFS / 8 + 1) & 0x1F) * 64 +
; ((BG3VOFS + 8) & 0x100 ? BLMapAddressBG3 - TLMapAddressBG3 : 0) -
; OffsetChangeMap_VOffset;
 mov edi,[VScroll+edx]
 shl edi,3          ; divided by 8 (base tile size),
 mov ebx,[VScroll+edx]
 and edi,(0x1F << 6)    ; * 2 (16-bit words) * 32 (row)

 and bh,1
 jz .offset_line_in_map_top

 mov ebx,[BLMapAddress+edx]
 add edi,ebx
 mov ebx,[TLMapAddress+edx]
 sub edi,ebx
.offset_line_in_map_top:

 mov [OffsetChangeMap_VOffset],edi

 mov ebx,[VScroll+edx]
 add edi,byte 32*2      ; next row
 add ebx,byte 8
 and edi,(0x1F << 6)    ; * 2 (16-bit words) * 32 (row)

 and bh,1
 jz .vmap_offset_line_in_map_top

 mov ebx,[BLMapAddress+edx]
 add edi,ebx
 mov ebx,[TLMapAddress+edx]
 sub edi,ebx
.vmap_offset_line_in_map_top:

 mov ebx,[OffsetChangeMap_VOffset]
 sub edi,ebx
 mov [OffsetChangeVMap_VOffset],edi

.no_recalc_voffsets:

 ; Update BG3 position for offset change
 LOAD_BG_TABLE 3

 mov ecx,[HScroll+edx]

 mov esi,TLMapAddress
 mov edi,TRMapAddress
 and ch,1   ;8x8 tile size
 jz .first_tile_in_left_screen_map
 add esi,byte (TRMapAddress-TLMapAddress)
 add edi,byte (TLMapAddress-TRMapAddress)
.first_tile_in_left_screen_map:

 mov esi,[esi+edx]
 mov edi,[edi+edx]
 mov [VLMapAddress+edx],esi
 mov [VRMapAddress+edx],edi

%ifdef OFFSET_CHANGE_ELIMINATION
 xor eax,eax
 mov ebx,[OffsetChangeMap_VOffset]
 mov al,[HScroll + edx]
 mov cl,32
 shr eax,3
 add esi,ebx
 sub cl,al
 lea esi,[esi+eax*2]

 mov edx,[OffsetChangeVMap_VOffset]
 add edi,ebx

 mov ah,0
 mov bl,0

.detect_loop:
 mov ch,[esi+1]

 or ah,ch
 mov bh,[esi+1+edx]

 add esi,byte 2
 or bl,bh

 dec cl
 jnz .detect_loop

 add cl,al
 jz .detect_end

 mov al,0
 mov esi,edi
 jmp .detect_loop

.detect_end:
 mov [OffsetChangeDetect1],ah
 or ah,bl
 mov [OffsetChangeDetect2],bl
 mov [OffsetChangeDetect3],ah
%endif

 ret
#endif
}

extern unsigned char BGMODE_Allowed_Offset_Change;

void Update_Mosaic_Predraw(unsigned current_line, unsigned char temp_mosaic)
{
 if (!(MOSAIC & 0xF0) && !MosaicCountdown)
 /* countdown register is 0 (signifying line counter reloads),
     and mosaic size is 1, so we turn mosaic handling off, since
     it won't be doing anything */
 {
  bg_table_1.mosaic = bg_table_2.mosaic =
   bg_table_3.mosaic = bg_table_4.mosaic = 0;
 }

 /* handle mosaic - setup linecounters for first line drawn */
 if (!(temp_mosaic & BIT(0)))
 {
  bg_table_1.line_counter = current_line;
 }
 if (!(temp_mosaic & BIT(1)))
 {
  bg_table_2.line_counter = current_line;
 }
 if (!(temp_mosaic & BIT(2)))
 {
  bg_table_3.line_counter = current_line;
 }
 if (!(temp_mosaic & BIT(3)))
 {
  bg_table_4.line_counter = current_line;
 }
}

void Update_Mosaic_Postdraw(unsigned current_line, unsigned lines)
{
 if (!(MOSAIC & BIT(0)))
 {
  bg_table_1.line_counter = current_line;
 }
 if (!(MOSAIC & BIT(1)))
 {
  bg_table_2.line_counter = current_line;
 }
 if (!(MOSAIC & BIT(2)))
 {
  bg_table_3.line_counter = current_line;
 }
 if (!(MOSAIC & BIT(3)))
 {
  bg_table_4.line_counter = current_line;
 }

 if (MosaicCountdown >= lines) MosaicCountdown -= lines;
 else
 {
  current_line += MosaicCountdown +
   MosaicLine[Mosaic_Size - 1][lines - MosaicCountdown - 1];
  MosaicCountdown = MosaicCount[Mosaic_Size - 1][lines - MosaicCountdown];
  if (MosaicCountdown == Mosaic_Size) MosaicCountdown = 0;

  if ((MOSAIC & BIT(0)))
  {
   bg_table_1.line_counter = current_line;
  }
  if ((MOSAIC & BIT(1)))
  {
   bg_table_2.line_counter = current_line;
  }
  if ((MOSAIC & BIT(2)))
  {
   bg_table_3.line_counter = current_line;
  }
  if ((MOSAIC & BIT(3)))
  {
   bg_table_4.line_counter = current_line;
  }
 }
}

void _Update_Display(void)
{
 unsigned lines;
 unsigned current_line;
 unsigned lines_in_set;


 Display_Needs_Update = 0;

 if (!(INIDISP & 0x80))
 /* screen on */
 {
  if (Redo_Layering)
  {
   extern void Update_Layering(void);

   Update_Layering();
  }

  bg_table_1.priority[0][OFFSET_PRIORITY_USED] =
   bg_table_1.priority[0][OFFSET_PRIORITY_UNUSED] = 0;
  bg_table_2.priority[0][OFFSET_PRIORITY_USED] =
   bg_table_2.priority[0][OFFSET_PRIORITY_UNUSED] = 0;
  bg_table_3.priority[0][OFFSET_PRIORITY_USED] =
   bg_table_3.priority[0][OFFSET_PRIORITY_UNUSED] = 0;
  bg_table_4.priority[0][OFFSET_PRIORITY_USED] =
   bg_table_4.priority[0][OFFSET_PRIORITY_UNUSED] = 0;

#ifdef WATCH_RENDER_BREAKS
  {
   extern unsigned BreaksLast;

   BreaksLast++;
  }
#endif

  Tile_Layers_Enabled = Layers_In_Use & BGMODE_Tile_Layer_Mask;
  if (Tile_Layers_Enabled)
  {
   if ((Tile_Recache_Set_End + 1) > 0)
   /* tiles need recaching */
   {
    extern void Recache_Tile_Set(int num_tiles);

    Redo_Offset_Change = (0 - 1);

    Recache_Tile_Set((Tile_Recache_Set_End + 1) - Tile_Recache_Set_Begin);

    Tile_Recache_Set_Begin = Tile_Recache_Set_End = (0 - 2);
   }

   if (Tile_Layers_Enabled & BIT(4))
   /* may need OAM recache */
   {
    _Check_OAM_Recache();
   }

   if (BGMODE_Allowed_Offset_Change &&
    (Tile_Layers_Enabled & 3) &&    /* BG1 || BG2 */
    Redo_Offset_Change)
   {
 /* Update_Offset_Change(); */
 /* asm("pushal; call Update_Offset_Change; popal" : : :
     "eax", "ebx", "ecx", "edx", "ebp", "esi", "edi", "cc", "memory");
  */
   }
  }

  if (Redo_Windowing)
  /* need to recompute window areas */
  {
   extern void Recalc_Window_Effects(void);

   Recalc_Window_Effects();
  }
 }


 for (
  current_line = Current_Line_Render,
  lines = Ready_Line_Render - Current_Line_Render;
  lines > 0;
  lines -= lines_in_set,
  Update_Mosaic_Postdraw(current_line, lines_in_set),
  current_line += lines_in_set - 1,
  Current_Line_Render = current_line,
  BaseDestPtr += lines_in_set * 256)
 {
  extern void cg_translate(unsigned current_line, unsigned lines);

  unsigned temp_mosaic = MosaicCountdown ? MOSAIC : 0;

  lines_in_set = lines <= MAX_LINES_IN_SET ? lines : MAX_LINES_IN_SET;

  current_line++;

  /* handle mosaic - setup linecounters for first line drawn */
  Update_Mosaic_Predraw(current_line, temp_mosaic);

  if (!(INIDISP & 0x80))
  /* screen on */
  {
   Render_Mode(main_screen, sub_screen, 0, current_line, lines_in_set,
    Used_TM, Used_TS);
  }
#if 0
  else
  /* screen off */
  {
   /* clear applicable portion of framebuffer */
   clear_scanlines(lines_in_set);
  }
#endif

  cg_translate(current_line, lines_in_set);
 }
}

extern unsigned char Base_BGMODE, BGMODE;
#define BG3_HIGHEST ((Base_BGMODE == 1) && (BGMODE & 8))

extern unsigned char Tile_priority_bit;


typedef void (*BG_RENDER_LINE_FN_PTR)(
 unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2],
 unsigned output_surface_offset,
 unsigned char layers1, unsigned char layers2,

 BGMODE_BG_TYPE plotter_base,
/*
 PRIORITY_SELECT priority_select,
 */
 unsigned char depth_low,
 unsigned char depth_high,

 BG_TABLE *bg_table,
 unsigned current_line,
 unsigned lines
);

void Render_Line(
 unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2],
 unsigned output_surface_offset,
 unsigned char layers1, unsigned char layers2,

 unsigned char depth_low,
 unsigned char depth_high,

 BG_TABLE *bg_table,
 unsigned current_line,
 unsigned lines)
{
 BG_RENDER_LINE_FN_PTR handler_lookup[2][2][2][15] =
 {
  { /* no mosaic */
   { /* small OPT tiles */
    { /* small BG tiles */
     0,                              Render_8x8,
     Render_8x8,                     Render_8x8,
     0,                              Render_8x8_Offset_8x8,
     Render_8x8_Offset_8x8,          Render_8x8_Offset_8x8,
     0,                              Render_8x8,
     Render_Even_16x8_Offset_16x8,   0,
     0,                              Render_Even_16x8,
     Render_Even_16x8
    },
    { /* large BG tiles */
     0,                              Render_16x16,
     Render_16x16,                   Render_16x16,
     0,                              Render_16x16_Offset_8x8,
     Render_16x16_Offset_8x8,        Render_16x16_Offset_8x8,
     0,                              Render_16x16,
     Render_Even_16x16_Offset_16x8,  0,
     0,                              Render_Even_16x16,
     Render_Even_16x16
    }
   },
   { /* large OPT tiles */
    { /* small BG tiles */
     0,                              Render_8x8,
     Render_8x8,                     Render_8x8,
     0,                              Render_8x8_Offset_16x16,
     Render_8x8_Offset_16x16,        Render_8x8_Offset_16x16,
     0,                              Render_8x8,
     Render_Even_16x8_Offset_16x16,  0,
     0,                              Render_Even_16x8,
     Render_Even_16x8
    },
    { /* large BG tiles */
     0,                              Render_16x16,
     Render_16x16,                   Render_16x16,
     0,                              Render_16x16_Offset_16x16,
     Render_16x16_Offset_16x16,      Render_16x16_Offset_16x16,
     0,                              Render_16x16,
     Render_Even_16x16_Offset_16x16, 0,
     0,                              Render_Even_16x16,
     Render_Even_16x16
    }
   }
  },
  { /* mosaic */
   { /* small OPT tiles */
    { /* small BG tiles */
     0,                               Render_8x8M,
     Render_8x8M,                     Render_8x8M,
     0,                               Render_8x8M_Offset_8x8,
     Render_8x8M_Offset_8x8,          Render_8x8M_Offset_8x8,
     0,                               Render_8x8M,
     Render_Even_16x8M_Offset_16x8,   0,
     0,                               Render_Even_16x8M,
     Render_Even_16x8M
    },
    { /* large BG tiles */
     0,                               Render_16x16M,
     Render_16x16M,                   Render_16x16M,
     0,                               Render_16x16M_Offset_8x8,
     Render_16x16M_Offset_8x8,        Render_16x16M_Offset_8x8,
     0,                               Render_16x16M,
     Render_Even_16x16M_Offset_16x8,  0,
     0,                               Render_Even_16x16M,
     Render_Even_16x16M
    }
   },
   { /* large OPT tiles */
    { /* small BG tiles */
     0,                               Render_8x8M,
     Render_8x8M,                     Render_8x8M,
     0,                               Render_8x8M_Offset_16x16,
     Render_8x8M_Offset_16x16,        Render_8x8M_Offset_16x16,
     0,                               Render_8x8M,
     Render_Even_16x8M_Offset_16x16,  0,
     0,                               Render_Even_16x8M,
     Render_Even_16x8M
    },
    { /* large BG tiles */
     0,                               Render_16x16M,
     Render_16x16M,                   Render_16x16M,
     0,                               Render_16x16M_Offset_16x16,
     Render_16x16M_Offset_16x16,      Render_16x16M_Offset_16x16,
     0,                               Render_16x16M,
     Render_Even_16x16M_Offset_16x16, 0,
     0,                               Render_Even_16x16M,
     Render_Even_16x16M
    }
   }
  }
 };

 if (Base_BGMODE == 3 || Base_BGMODE == 4)
 /* Modes 3 and 4 */
 {
  if ((bg_table->bg_flag == BIT(0)) && (CGWSEL & BIT(0)))
  /* BG1, direct color enabled */
  {
   depth_low |= Z_DIRECT_COLOR_USED;
   depth_high |= Z_DIRECT_COLOR_USED;
  }
 }

 handler_lookup
  [bg_table->mosaic ? 1 : 0]
  [bg_table->depth & BBT_OPT_TILES_LARGE ? 1 : 0]
  [bg_table->depth & BBT_TILES_LARGE ? 1 : 0]
  [bg_table->depth & BBT_BASE]
 (
  main_buf, sub_buf, output_surface_offset, layers1, layers2,

  bg_table->depth & BBT_BASE,

  depth_low, depth_high,

  bg_table,
  current_line,
  lines
// void *output_surface //,
// int screen_select  // main, sub, both
 );
}

void _Render_SM01(unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2],
 unsigned output_surface_offset,unsigned current_line, unsigned lines,
 unsigned char layers1, unsigned char layers2)
{
 if (LAYER_PRESENT(layers1 | layers2, 4))
 {
  Render_Line(main_buf, sub_buf, output_surface_offset, layers1, layers2,
   Z_M01_BG34_LO,
   Z_M01_BG34_HI,
   &bg_table_4, current_line, lines);
 }

 if (LAYER_PRESENT(layers1 | layers2, 3))
 {
  Render_Line(main_buf, sub_buf, output_surface_offset, layers1, layers2,
   Z_M01_BG34_LO,
   !BG3_HIGHEST ? Z_M01_BG34_HI : Z_M1_BG3_MAX,
   &bg_table_3, current_line, lines);
 }

 if (LAYER_PRESENT(layers1 | layers2, 2))
 {
  Render_Line(main_buf, sub_buf, output_surface_offset, layers1, layers2,
   Z_M01_BG12_LO,
   Z_M01_BG12_HI,
   &bg_table_2, current_line, lines);
 }

 if (LAYER_PRESENT(layers1 | layers2, 1))
 {
  Render_Line(main_buf, sub_buf, output_surface_offset, layers1, layers2,
   Z_M01_BG12_LO,
   Z_M01_BG12_HI,
   &bg_table_1, current_line, lines);
 }

 if (LAYER_PRESENT(layers1 | layers2, 5))  /* OBJ */
 {
  _Plot_Sprites(main_buf, sub_buf, output_surface_offset, layers1, layers2,
   current_line, lines);
 }

}

static void _SCREEN_MODE_0_1(
/*
 ebx,[C_LABEL(Current_Line_Render)]+1
 edi,[BaseDestPtr]
 ebp,lines
 al = screens 1, ah = screens 2
*/
 unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2],
 unsigned output_surface_offset,
 unsigned current_line,
 unsigned lines,
 unsigned layers1, unsigned layers2
)
{
 clear_scanlines(lines);

 _Render_SM01(main_buf, sub_buf, output_surface_offset,
  current_line, lines, layers1, layers2);
}


void _Render_SM26(unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2],
 unsigned output_surface_offset,
 unsigned current_line, unsigned lines, unsigned layers1, unsigned layers2)
{
/*
 window_offset = (window_offset - 0x42) / 7;
 */

 if (LAYER_PRESENT(layers1 | layers2, 2))
 {
  Render_Line(main_buf, sub_buf, output_surface_offset, layers1, layers2,
   Z_M27_BG2_LO,
   Z_M27_BG2_HI,
   &bg_table_2, current_line, lines);
 }

 if (LAYER_PRESENT(layers1 | layers2, 1))
 {
  Render_Line(main_buf, sub_buf, output_surface_offset, layers1, layers2,
   Z_M27_BG1_LO,
   Z_M27_BG1_HI,
   &bg_table_1, current_line, lines);
 }

 if (LAYER_PRESENT(layers1 | layers2, 5))  /* OBJ */
 {
  _Plot_Sprites(main_buf, sub_buf, output_surface_offset, layers1, layers2,
   current_line, lines);
 }
}

static void _SCREEN_MODE_2_6(
/*
 ebx,[C_LABEL(Current_Line_Render)]+1
 edi,[BaseDestPtr]
 ebp,lines
 al = screens 1, ah = screens 2
*/
 unsigned char (*main_buf)[2], unsigned char (*sub_buf)[2],
 unsigned output_surface_offset,
 unsigned current_line,
 unsigned lines,
 unsigned layers1, unsigned layers2
)
{
 clear_scanlines(lines);
 
 _Render_SM26(main_buf, sub_buf, output_surface_offset,
  current_line, lines, layers1, layers2);
}
