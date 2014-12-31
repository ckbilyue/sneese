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

#ifndef SNEeSe_snes_h
#define SNEeSe_snes_h

#include "misc.h"

#ifdef DEBUG
#ifdef CPUTRACKER
EXTERN unsigned char *InsAddress;
EXTERN unsigned LastIns;
#endif
#ifdef SPCTRACKER
EXTERN unsigned char *SPC_InsAddress;
EXTERN unsigned SPC_LastIns;
#endif
#endif

/* video emulation needs this */
#define MAX_LINES_IN_SET 16

typedef struct
{
 unsigned char count;
 unsigned char bands[3][2];
} LAYER_WIN_DATA;

typedef struct
{
 unsigned char Count_Out;
 unsigned char Bands_Out[2][2];
 unsigned char Count_In;
 unsigned char Bands_In[1][2];
} WIN_DATA;

extern WIN_DATA TableWin1, TableWin2;

#define Win_Count_Out(n) (CONCAT_NAME(TableWin, n).Count_Out)
#define Win_Bands_Out(n) (CONCAT_NAME(TableWin, n).Bands_Out)
#define Win_Count_In(n) (CONCAT_NAME(TableWin, n).Count_In)
#define Win_Bands_In(n) (CONCAT_NAME(TableWin, n).Bands_In)

#define Redo_Win_Layer(x) BIT((x) - 1)
#define Redo_Win_BG(x) Redo_Win_Layer(x)
#define Redo_Win_OBJ Redo_Win_Layer(5)
#define Redo_Win_Color Redo_Win_Layer(6)
#define Redo_Win(x) BIT(6 + (x) - 1)

enum
{
 /* main screen area */ 
 OFFSET_BG_WIN_MAIN,
 /* sub screen area in color window */
 OFFSET_BG_WIN_SUB,

 /* main screen area, no arithmetic */ 
 OFFSET_BG_WIN_MAIN_NO_COL,
 /* main screen area not on sub screen, arithmetic */
 OFFSET_BG_WIN_EX_MAIN,
 /* sub screen area not on main screen */
 OFFSET_BG_WIN_EX_SUB,
 /* screen area on both screens, arithmetic */
 OFFSET_BG_WIN_BOTH,
 /* screen area on both screens, no arithmetic */
 OFFSET_BG_WIN_BOTH_NO_COL,
 /* number of transformed window areas */
 COUNT_BG_WIN
};

enum
{
 /* main screen color on */
 OFFSET_COL_WIN_MAIN,
 /* color arithmetic on */
 OFFSET_COL_WIN_SUB,

 /* main screen color off */
 OFFSET_COL_WIN_NO_MAIN,
 /* color arithmetic off */
 OFFSET_COL_WIN_NO_SUB,

 /* first window area used for color output processing */
 OFFSET_COL_WIN_OUTPUT_FIRST,

 /* main screen color off, no arithmetic */
 OFFSET_COL_WIN_MAIN_OFF_NO_COL = OFFSET_COL_WIN_OUTPUT_FIRST,
 /* main screen color on, no arithmetic */
 OFFSET_COL_WIN_MAIN_ON_NO_COL,
 /* main screen color off, arithmetic */
 OFFSET_COL_WIN_MAIN_OFF,
 /* main screen color on, arithmetic */
 OFFSET_COL_WIN_MAIN_ON,

 /* last window area used for color output processing */
 OFFSET_COL_WIN_OUTPUT_LAST = OFFSET_COL_WIN_MAIN_ON,
 
 /* number of transformed color window areas */
 COUNT_COL_WIN
};


#define Z_PALETTE_SHIFT  (0)
#define Z_POSITION_SHIFT (5)

/* draw-order inclusive Z position list */
/* Z-buffer also used to store certain data needed for color translation */
enum
{
 Z_PALETTE_BITS = BITMASK(0,2) << Z_PALETTE_SHIFT,

 /* main screen only: specifies if pixel needs color arithmetic */
 Z_ARITHMETIC_USED = BIT(3),

 /* specifies pixel is from BG1 and uses direct color translation */
 /* not needed for OBJ */
 Z_DIRECT_COLOR_USED = BIT(4),
 /* specifies that OBJ can no longer use this pixel */
 /* only used in OBJ intermediary Z-buffer */
 Z_OBJ_USED = BIT(4),

 /* back area - everything overlaps this */
 Z_BACK_AREA = 0 << Z_POSITION_SHIFT,
 /* BG3/4 priority low  (modes 0-1) */
 /* BG2   priority low  (modes 2-7) */
 /* OBJ   priority 0 */
 Z_M01_BG34_LO = 1 << Z_POSITION_SHIFT,
 Z_M27_BG2_LO  = 1 << Z_POSITION_SHIFT,
 Z_OBJ_0       = 1 << Z_POSITION_SHIFT,
 /* BG3/4 priority high (modes 0-1) */
 /* BG1   priority low  (modes 2-7) */
 /* OBJ   priority 1 */
 Z_M01_BG34_HI = 2 << Z_POSITION_SHIFT,
 Z_M27_BG1_LO  = 2 << Z_POSITION_SHIFT,
 Z_OBJ_1       = 2 << Z_POSITION_SHIFT,
 /* BG1/2 priority low  (modes 0-1) */
 /* BG2   priority high (modes 2-7) */
 /* OBJ   priority 2 */
 Z_M01_BG12_LO = 3 << Z_POSITION_SHIFT,
 Z_M27_BG2_HI  = 3 << Z_POSITION_SHIFT,
 Z_OBJ_2       = 3 << Z_POSITION_SHIFT,
 /* BG1/2 priority high (modes 0-1) */
 /* BG1   priority high (modes 2-7) */
 /* OBJ   priority 3 */
 Z_M01_BG12_HI = 4 << Z_POSITION_SHIFT,
 Z_M27_BG1_HI  = 4 << Z_POSITION_SHIFT,
 Z_OBJ_3       = 4 << Z_POSITION_SHIFT,
 /* BG3   priority max  (mode 1 + BGMODE.d3) */
 Z_M1_BG3_MAX  = 5 << Z_POSITION_SHIFT,
 /* any bits outside this mask are used for color translation only */
 Z_DEPTH_BITS = BITMASK(0,2) << Z_POSITION_SHIFT,
 /* used for Z-checking */
 Z_NON_DEPTH_BITS = BITMASK(0,7) & ~Z_DEPTH_BITS,
 /* use for color translation mode selection */
 Z_COLOR_TYPE_BITS_MAIN = Z_ARITHMETIC_USED | Z_DIRECT_COLOR_USED,
 Z_COLOR_TYPE_BITS_SUB = Z_DIRECT_COLOR_USED

};


enum { OFFSET_PRIORITY_USED, OFFSET_PRIORITY_UNUSED };


typedef struct
{
 unsigned char WSEL;
 unsigned char WLOG;
 unsigned char BGSC;        /*  xxxxxxab  xxxxxx=base address, ab=SC Size */
 unsigned char depth;

 unsigned char tile_height;
 unsigned char tile_width;
 unsigned char mosaic;
 unsigned char nba;         /* Unused in BG3/4 (???) */

 unsigned vscroll;
 unsigned hscroll;
 void *vl_map_address;
 void *vr_map_address;

 void (*line_render)(void);
 unsigned set_address;      /* Address of BG tileset */
 void *v_map_address;       /* obsolete var */

/* map_address */           /* Screen address of BG */
 void *tl_map_address;
 void *tr_map_address;
 void *bl_map_address;
 void *br_map_address;

 unsigned *nba_table;       /* Unused in BG3/4 (???) */
 unsigned line_counter;
 unsigned mode_0_color;
 unsigned char bg_flag;
 unsigned char oc_flag;     /* Unused in BG3/4 */

 /* Unclipped display area: main screen */
 /* Unclipped display area: sub screen */
 /* Clipped main screen area not also present on sub screen */
 /* Clipped sub screen area not also present on main screen */
 /* Clipped screen area on both main and sub screens */
 LAYER_WIN_DATA bg_win[COUNT_BG_WIN];

 unsigned char priority[1+239][2];

} BG_TABLE;

extern BG_TABLE TableBG1, TableBG2, TableBG3, TableBG4;
#define bg_table_1 (TableBG1)
#define bg_table_2 (TableBG2)
#define bg_table_3 (TableBG3)
#define bg_table_4 (TableBG4)

extern LAYER_WIN_DATA win_obj[COUNT_BG_WIN], win_color[COUNT_COL_WIN];
EXTERN void merge_layer_win_with_and(LAYER_WIN_DATA *out,
 const LAYER_WIN_DATA *bgwin1, const LAYER_WIN_DATA *bgwin2, int invert2);


EXTERN signed char snes_rom_loaded;

EXTERN unsigned SPC_CPU_cycle_divisor, SPC_CPU_cycle_multiplicand;

EXTERN int snes_init(void);
EXTERN void snes_reset(void);
EXTERN void set_snes_pal(void);
EXTERN void set_snes_ntsc(void);
EXTERN void snes_exec(void);
EXTERN void Reset_Memory(void);
EXTERN void Reset_SRAM(void);
EXTERN void save_debug_dumps(void);

#endif /* !defined(SNEeSe_snes_h) */
