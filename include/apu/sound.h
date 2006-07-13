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

#ifndef SNEeSe_apu_sound_h
#define SNEeSe_apu_sound_h

#include "../misc.h"
#include "spc.h"

/*
EXTERN unsigned TotalCycles,CycleLatch0,CycleLatch1,CycleLatch2;

EXTERN unsigned SPC_T0_cycle_latch;
EXTERN unsigned SPC_T0_position, SPC_T0_target;

EXTERN unsigned SPC_T1_cycle_latch;
EXTERN unsigned SPC_T1_position, SPC_T1_target;

EXTERN unsigned SPC_T2_cycle_latch;
EXTERN unsigned SPC_T2_position, SPC_T2_target;

EXTERN unsigned char SPC_T0_counter, SPC_T1_counter, SPC_T2_counter;
*/

EXTERN unsigned char SPC_MASK;
EXTERN unsigned SPC_DSP_DATA;
EXTERN signed char ENVX_ENABLED, sound_enabled;
EXTERN int sound_bits;
EXTERN signed char sound_echo_enabled, sound_gauss_enabled;

EXTERN unsigned sound_cycle_latch;
EXTERN unsigned sound_output_position;

EXTERN int voice_handle;

EXTERN unsigned char SPC_DSP[256];
EXTERN unsigned char SNDkeys;

EXTERN void Wrap_SDSP_Cyclecounter();

EXTERN void Remove_Sound();
EXTERN int Install_Sound(int stereo);
EXTERN void Reset_Sound_DSP();

EXTERN void update_sound(void);

EXTERN void SPC_READ_DSP();
EXTERN void SPC_WRITE_DSP();

EXTERN void Update_SPC_Timer_0();
EXTERN void Update_SPC_Timer_1();
EXTERN void Update_SPC_Timer_2();

EXTERN void sound_pause(void);
EXTERN void sound_resume(void);

#endif /* !defined(SNEeSe_apu_sound_h) */
