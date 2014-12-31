%if 0

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

%endif

%ifndef SNEeSe_cycles_inc
%define SNEeSe_cycles_inc

%define _5A22_FAST_CYCLE 6
%define _5A22_SLOW_CYCLE 8
%define _5A22_LEGACY_CYCLE 12

%define CYCLES_IRQ_DELAY 10

%define CYCLES_PER_DOT 4
%define CYCLES_HALF_DOT (CYCLES_PER_DOT / 2)
%define DOTS_PER_SCANLINE 341
%define DOTS_PER_SCANLINE_REPORTED 340
%define DOTS_IN_REFRESH 10
%define USABLE_DOTS_PER_SCANLINE (DOTS_PER_SCANLINE - DOTS_IN_REFRESH)
%define DOTS_BEFORE_DISPLAY 1
%define DOTS_BEFORE_REFRESH 0x85
%define DOTS_IN_DISPLAY 273
%define DOTS_HBLANK_START (DOTS_BEFORE_DISPLAY + DOTS_IN_DISPLAY)
%define DOTS_HDMA_START 274
%define LONG_DOT_1 (323 - DOTS_IN_REFRESH)
%define LONG_DOT_2 (327 - DOTS_IN_REFRESH)

%define CYCLES_NEW_SCANLINE ((DOTS_PER_SCANLINE - DOTS_IN_REFRESH) * CYCLES_PER_DOT)
%define CYCLES_DISPLAY_START (DOTS_BEFORE_DISPLAY * CYCLES_PER_DOT)
%define CYCLES_HBLANK_START ((DOTS_HBLANK_START - DOTS_IN_REFRESH) * CYCLES_PER_DOT)
%define CYCLES_HDMA_START ((DOTS_HDMA_START - DOTS_IN_REFRESH) * CYCLES_PER_DOT)
%define LONG_DOT_1_START (LONG_DOT_1 * CYCLES_PER_DOT)
%define LONG_DOT_2_START (LONG_DOT_2 * CYCLES_PER_DOT)

%define CYCLES_NMI_DELAY 19
%define CYCLES_REFRESH_START (DOTS_BEFORE_REFRESH * CYCLES_PER_DOT)
%define CYCLES_IN_REFRESH (DOTS_IN_REFRESH * CYCLES_PER_DOT)
%define CYCLES_REFRESH_END ((DOTS_BEFORE_REFRESH + DOTS_IN_REFRESH) * CYCLES_PER_DOT)

%endif ; !defined(SNEeSe_cycles_inc)
