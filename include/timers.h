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

#ifndef SNEeSe_timers_h
#define SNEeSe_timers_h

#include "misc.h"

#ifdef DEBUG
EXTERN volatile unsigned Timer_Counter_Profile,
 CPU_Profile_Last, CPU_Profile_Test,
 SPC_Profile_Last, SPC_Profile_Test,
 GFX_Profile_Last, GFX_Profile_Test;

#endif

EXTERN volatile unsigned FPSTicks;
EXTERN volatile unsigned Timer_Counter_Throttle;
EXTERN unsigned Frametime;

EXTERN void timers_init();
EXTERN void timers_enable(unsigned throttle_time);
EXTERN void timers_disable();
EXTERN void timers_shutdown();
EXTERN void set_timer_throttle_hz(int hertz);
EXTERN void set_timer_throttle_ms(int msec);
EXTERN void set_timer_throttle_ticks(int ticks);

#endif /* !defined(SNEeSe_timers_h) */
