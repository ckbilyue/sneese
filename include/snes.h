/*

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2005, Charles Bilyue'.
Portions Copyright (c) 2003-2004, Daniel Horchner.
Portions Copyright (c) 2004-2005, Nach. ( http://nsrt.edgeemu.com/ )
JMA Technology, Copyright (c) 2004-2005 NSRT Team. ( http://nsrt.edgeemu.com/ )
LZMA Technology, Copyright (c) 2001-4 Igor Pavlov. ( http://www.7-zip.org )
Portions Copyright (c) 2002 Andrea Mazzoleni. ( http://advancemame.sf.net )

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
