/*

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2003 Charles Bilyue'.
Portions Copyright (c) 2003 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

*/

#ifndef SNEeSe_helper_h
#define SNEeSe_helper_h

#include "wrapaleg.h"
#include "platform.h"

#include "misc.h"

EXTERN unsigned char WRAM[131072];  /* Buffer for Work RAM */
EXTERN unsigned char VRAM[65536];   /* Buffer for Video RAM */
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

/* Display processing methods, such as interpolation/EAGLE, would go here */
typedef enum {
 SDP_NONE, NUM_DISPLAY_PROCESSES
} DISPLAY_PROCESS;

EXTERN DISPLAY_PROCESS display_process;

EXTERN signed char stretch_x, stretch_y;

/* This flag is set when palette recomputation is necessary */
EXTERN signed char PaletteChanged;

EXTERN SNEESE_GFX_BUFFER gbSNES_Screen8;
EXTERN SNEESE_GFX_BUFFER gbSNES_Screen16;

EXTERN unsigned char *SNES_Screen8;
EXTERN unsigned short *SNES_Screen16;

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

#endif /* !defined(SNEeSe_helper_h) */
