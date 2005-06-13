/*

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2005, Charles Bilyue'.
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

/*#define CPUTRACKER 1048576*/
/*#define SPCTRACKER 1048576*/
#include <stdio.h>
#include <string.h>

/*#define DEINTERLEAVED_VRAM*/

#include "timers.h"
#include "helper.h"
#include "platform.h"
#include "apu/sound.h"
#include "cpu/cpu.h"
#include "apu/spc.h"
#include "apu/apuskip.h"

#ifdef DEBUG
#ifdef CPUTRACKER
unsigned char *InsAddress=0;
unsigned LastIns;
#endif
#ifdef SPCTRACKER
unsigned char *SPC_InsAddress=0;
unsigned SPC_LastIns;
#endif
#endif

extern void reset_bus_timings(void);

signed char snes_rom_loaded = 0;

#define SPC_CPU_CYCLE_MULTIPLICAND_PAL 102400
#define SPC_CPU_CYCLE_DIVISOR_PAL 2128137
#define SPC_CPU_CYCLE_MULTIPLICAND_NTSC 5632
#define SPC_CPU_CYCLE_DIVISOR_NTSC 118125

unsigned SPC_CPU_cycle_divisor, SPC_CPU_cycle_multiplicand;

/* Used to determine if APU emulation option change demands reset */
static signed char SPC_SAFE = TRUE;


static int Setup_Memory(void)
{
#ifdef DEBUG
#ifdef CPUTRACKER
#if CPUTRACKER >= 16
 InsAddress=(unsigned char *)malloc(CPUTRACKER);
#else
 InsAddress=(unsigned char *)malloc(5120);
#endif
#endif
#ifdef SPCTRACKER
 SPC_InsAddress=(unsigned char *)malloc(SPCTRACKER);
#endif
#endif

 return 0;
}


int snes_init(void)
{
 int memoryneeded;

 timers_init();

 memoryneeded = Setup_Memory();
 if (memoryneeded)
 {
  printf("Out of memory. Need up to %d more bytes free!\n", memoryneeded);
  return 1;
 }

 memset(&gbSNES_Screen8, 0, sizeof(gbSNES_Screen8));
 memset(&gbSNES_Screen16, 0, sizeof(gbSNES_Screen16));

 SNES_Screen8 =
  platform_get_gfx_buffer(8, 256, 239, 8, 0, &gbSNES_Screen8);
 if (SNES_Screen8 == 0) return 1;

 SNES_Screen16 =
  platform_get_gfx_buffer(16, 256, 239, 0, 0, &gbSNES_Screen16);
 if (SNES_Screen16 == 0) return 1;

 SetupTables();

 switch (sound_enabled)
 {
  case 2:
   if (Install_Sound(1)) break;
  case 1:
   Install_Sound(0);
 }

 return 0;
}

void snes_reset(void)
{
 reset_bus_timings();

 Reset_CPU();

 Reset_SPC();
 Reset_APU_Skipper();
 Reset_Sound_DSP();

 /* APU reset, no need to check this in next call to snes_exec() */
 SPC_SAFE = TRUE;
}

extern unsigned FPSMaxTicks;

#define PAL_TICKS (TIMERS_PER_SECOND / (21281370.0 / 312 / 4 / 341))
#define NTSC_TICKS (TIMERS_PER_SECOND / (1.89e9 / 88 / 262 / 4 / 341))

void set_snes_pal(void)
{
 SNES_COUNTRY = 0x10;
 set_timer_throttle_ticks(PAL_TICKS);
 FPSMaxTicks = 50;
 LastVBLLine = 311;

 SPC_CPU_cycle_multiplicand = SPC_CPU_CYCLE_MULTIPLICAND_PAL;
 SPC_CPU_cycle_divisor = SPC_CPU_CYCLE_DIVISOR_PAL;
}

void set_snes_ntsc(void)
{
 SNES_COUNTRY = 0x00;
 set_timer_throttle_ticks(NTSC_TICKS);
 FPSMaxTicks = 60;
 LastVBLLine = 261;

 SPC_CPU_cycle_multiplicand = SPC_CPU_CYCLE_MULTIPLICAND_NTSC;
 SPC_CPU_cycle_divisor = SPC_CPU_CYCLE_DIVISOR_NTSC;
}

void snes_exec(void)
{
 if (SPC_ENABLED) Make_SPC(); else Make_APU_Skipper();

 /* Reset the SNES if the SPC has been enabled, and it wasn't before */
 if (SPC_ENABLED && !SPC_SAFE) snes_reset();
 SPC_SAFE = SPC_ENABLED;

 if (sound_enabled) sound_resume();

 timers_enable(Frametime);

 Do_CPU();    /* This is the emulation core. */

 timers_disable();

 if (sound_enabled) sound_pause();    /* Ensures silent GUI */
}

/* Resets memory heaps */
void Reset_Memory(void)
{
 int i;
#ifdef DEBUG
#ifdef CPUTRACKER
 /* Reset CPU instruction tracking buffer */
#if CPUTRACKER >= 16
 memset(InsAddress,0xFF,CPUTRACKER); LastIns=0;
#else
 memset(InsAddress,0,5120); LastIns=0;
#endif
#endif
#ifdef SPCTRACKER
 /* Reset SPC instruction tracking buffer */
 memset(SPC_InsAddress,0xFF,SPCTRACKER); SPC_LastIns=0;
#endif
#endif

 /* Reset blank ROM space to 0xFF */
 memset(Blank,0xFF,(64 << 10));

 /* Reset SPC address space to the value of pin A5 */
 for (i = 0; i < (64 << 10); i += (1 << 5))
 {
  memset(SPCRAM, i & (1 << 5) ? (0 - 1) : 0, (1 << 5));
 }

 /* Reset WRAM to 0x55 */
 memset(WRAM,0x55,(128 << 10));

 /* Reset VRAM to 0 */
 memset(VRAM,0,(64 << 10));

#if 0
 /* Clear CGRAM */
 Reset_CGRAM();
 /* Clear OAM */
 memset(OAM,0,512+32);
#endif
}

/* Resets Save RAM */
void Reset_SRAM(void)
{
 if (!SaveRamLength) return;

 /* Reset SRAM to 0xAA */
 memset(SRAM, 0xAA, SaveRamLength > (8 << 10) ? SaveRamLength : (8 << 10));
}

extern unsigned char OAM_Count[239][2];
extern unsigned OAM_Lines[239][34];
extern unsigned char TileCache2[4 * 64 << 10];
extern unsigned char TileCache4[2 * 64 << 10];
extern unsigned char TileCache8[1 * 64 << 10];
void save_debug_dumps(void)
{
#ifndef RELEASE
 if (snes_rom_loaded)
 {
  FILE *fp;

#ifdef DEBUG
#ifdef SPCTRACKER
  /* This saves the SPC-tracker dump! */
  fp = fopen("SPC.DMP", "wb");
  if (fp)
  {
   fwrite(SPC_InsAddress + SPC_LastIns, 1, (SPCTRACKER) - SPC_LastIns, fp);
   fwrite(SPC_InsAddress, 1, SPC_LastIns, fp);
   fclose(fp);
  }
#endif

#ifdef CPUTRACKER
  /* This saves the CPU-tracker dump! */
  fp = fopen("C:\\INS.DMP", "wb");
  if (fp)
  {
#if CPUTRACKER >= 16
   fwrite(InsAddress + LastIns, 1, (CPUTRACKER) - LastIns, fp);
   fwrite(InsAddress, 1, LastIns, fp);
#else
   fwrite(InsAddress, 1, 5120, fp);
#endif
   fclose(fp);
  }
#endif

  fp = fopen("SPCRAM.DMP", "wb");
  if (fp)
  {
   fwrite(SPCRAM, 1, 65536, fp);
   fwrite(&_SPC_PC, 1, sizeof(unsigned), fp);
   fclose(fp);
  }

  fp = fopen("WRAM.DMP", "wb");
  if (fp)
  {
   fwrite(WRAM, 1, 131072, fp);
   fclose(fp);
  }

  fp = fopen("VRAM.DMP", "wb");
  if (fp)
  {
   fwrite(VRAM, 1, 65536, fp);
   fclose(fp);
  }

  fp = fopen("OAM.DMP", "wb");
  if (fp)
  {
   fwrite(OAM, 1, 512+32, fp);
   fclose(fp);
  }

  fp = fopen("OBJ.DMP", "wb");
  if (fp)
  {
   fwrite(OAM_Lines, sizeof(OAM_Lines), 1, fp);
   fwrite(OAM_Count, sizeof(OAM_Count), 1, fp);
   fclose(fp);
  }

  fp = fopen("PAL.DMP", "wb");
  if (fp)
  {
   fwrite(Real_SNES_Palette, sizeof(Real_SNES_Palette), 1, fp);
   fwrite(SNES_Palette, sizeof(SNES_Palette), 1, fp);
   fclose(fp);
  }

  fp = fopen("CACHE.DMP", "wb");
  if (fp)
  {
   fwrite(TileCache2, sizeof(TileCache2), 1, fp);
   fwrite(TileCache4, sizeof(TileCache4), 1, fp);
   fwrite(TileCache8, sizeof(TileCache8), 1, fp);
   fclose(fp);
  }

#endif

 }
#endif
}
