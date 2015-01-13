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

#ifndef SNEeSe_helper_h
#define SNEeSe_helper_h

#include "platform.h"

#include "misc.h"
#include "snes.h"

EXTERN unsigned char WRAM[131072];  /* Buffer for Work RAM */
EXTERN unsigned char VRAM[65536];   /* Buffer for Video RAM */

/* Used to determine size of file for saving/loading, and to restrict writes
 *  to non-existant SRAM
 */
EXTERN unsigned SaveRamLength;      /* Size of Save RAM */
EXTERN unsigned char *SRAM;         /* Buffer for Save RAM */
EXTERN unsigned char SPCRAM[65536]; /* Buffer for SPC RAM/ROM */
EXTERN unsigned char Blank[65536];  /* Blank ROM buffer */
EXTERN unsigned char OAM[512+32];   /* Buffer for OAM */

EXTERN unsigned short ScreenX,ScreenY;

typedef struct {
 unsigned short blue  :5;
 unsigned short green :6;
 unsigned short red   :5;
} colorRGB565;

typedef struct {
 unsigned short red   :5;
 unsigned short green :5;
 unsigned short blue  :5;
 unsigned short fill  :1;
} colorBGR555;

EXTERN unsigned char MosaicLine[16][256];      /* Used for mosaic effect */
EXTERN unsigned char MosaicCount[16][256];     /* Used for mosaic effect */
EXTERN unsigned char BrightnessAdjust[16][256];/* Used for brightness effect */
EXTERN RGB SNES_Palette[256];                  /* So I can access from cc modules! */
EXTERN colorBGR555 Real_SNES_Palette[256];     /* Updated by palette write */
EXTERN colorRGB565 HICOLOUR_Palette[256];      /* values in here are plotted direct to PC! */

EXTERN void SetupTables(void);
EXTERN void Reset_CGRAM(void);

#ifdef DEBUG
EXTERN unsigned Frames;
EXTERN unsigned FrameLimit;
#endif

EXTERN unsigned M7X,M7Y,M7A,M7B,M7C,M7D;

EXTERN unsigned char SCREEN_MODE;
EXTERN unsigned char screen_mode_windowed;

/* Display processing methods, such as interpolation/EAGLE, would go here */
typedef enum {
 SDP_NONE, NUM_DISPLAY_PROCESSES
} DISPLAY_PROCESS;

EXTERN DISPLAY_PROCESS display_process;

EXTERN signed char stretch_x, stretch_y;

/* This flag is set when palette recomputation is necessary */
EXTERN signed char PaletteChanged;

EXTERN SNEESE_GFX_BUFFER gbSNES_Screen;

EXTERN unsigned char (*Real_SNES_Screen8)[2];
EXTERN unsigned char (*main_screen)[2];
EXTERN unsigned char (*sub_screen)[2];
EXTERN void *SNES_Screen;

EXTERN BITMAP *Allegro_Bitmap;  /* Renamed (I'm using mostly allegro now so what the hell!) */
EXTERN BITMAP *Internal_Bitmap;
EXTERN BITMAP *Internal_Bitmap_blitsrc;

EXTERN unsigned FRAME_SKIP_MIN;     /* Min frames waited until refresh */
EXTERN unsigned FRAME_SKIP_MAX;     /* Max frames waited until refresh */
EXTERN unsigned char SNES_COUNTRY;  /* Used for PAL/NTSC protection checks */
EXTERN unsigned char SPC_ENABLED;
EXTERN unsigned char use_mmx;
EXTERN unsigned char use_fpu_copies;
EXTERN unsigned char preload_cache, preload_cache_2;

EXTERN void OutputScreen();

EXTERN unsigned char BrightnessLevel;   /* SNES Brightness level, set up in PPU.asm */
EXTERN char fixedpalettecheck;

EXTERN void SetPalette(void);
EXTERN void Copy_Screen(void);

EXTERN unsigned Current_Line_Render;

#endif /* !defined(SNEeSe_helper_h) */
