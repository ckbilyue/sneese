/*

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2003 Charles Bilyue'.
Portions Copyright (c) 2003 Daniel Horchner.

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

EXTERN signed char snes_rom_loaded;

EXTERN int snes_init(void);
EXTERN void snes_reset(void);
EXTERN void set_snes_pal(void);
EXTERN void set_snes_ntsc(void);
EXTERN void snes_exec(void);
EXTERN void Reset_Memory(void);
EXTERN void Reset_SRAM(void);
EXTERN void save_debug_dumps(void);

#endif /* !defined(SNEeSe_snes_h) */
