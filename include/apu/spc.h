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

#ifndef SNEeSe_apu_spc_h
#define SNEeSe_apu_spc_h

#include "../misc.h"

EXTERN void SPC_START(void);
EXTERN void Make_SPC(void);
EXTERN void Reset_SPC(void);
EXTERN unsigned char get_SPC_PSW(void);
EXTERN unsigned char SPC_PORT0R, SPC_PORT1R, SPC_PORT2R, SPC_PORT3R;
EXTERN unsigned char SPC_PORT0W, SPC_PORT1W, SPC_PORT2W, SPC_PORT3W;
EXTERN unsigned _SPC_PC, _SPC_SP, _SPC_YA;
EXTERN unsigned char _SPC_A, _SPC_Y, _SPC_X, _SPC_PSW;
EXTERN unsigned char SPC_ROM_CODE[64];

EXTERN unsigned TotalCycles;

EXTERN unsigned SPC_T0_cycle_latch;
EXTERN unsigned short SPC_T0_position, SPC_T0_target;

EXTERN unsigned SPC_T1_cycle_latch;
EXTERN unsigned short SPC_T1_position, SPC_T1_target;

EXTERN unsigned SPC_T2_cycle_latch;
EXTERN unsigned short SPC_T2_position, SPC_T2_target;

EXTERN unsigned char SPC_T0_counter, SPC_T1_counter, SPC_T2_counter;

EXTERN unsigned SPC_Cycles;

#endif /* !defined(SNEeSe_apu_spc_h) */
