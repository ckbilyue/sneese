%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2003 Charles Bilyue'.
Portions Copyright (c) 2003 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

%endif

%ifndef SNEeSe_cycles_inc
%define SNEeSe_cycles_inc

%define CYCLES_PER_DOT 4
%define DOTS_PER_SCANLINE 342
%define DOTS_IN_REFRESH 10
%define DOTS_BEFORE_DISPLAY 0
%define DOTS_BEFORE_REFRESH 128
%define DOTS_IN_DISPLAY 256
%define DOTS_HBLANK_START (DOTS_BEFORE_DISPLAY + DOTS_IN_DISPLAY)

%define CYCLES_NEW_SCANLINE ((DOTS_PER_SCANLINE - DOTS_IN_REFRESH) * CYCLES_PER_DOT)
%define CYCLES_DISPLAY_START (DOTS_BEFORE_DISPLAY * CYCLES_PER_DOT)
%define CYCLES_HBLANK_START ((DOTS_HBLANK_START - DOTS_IN_REFRESH) * CYCLES_PER_DOT)

%define CYCLES_NMI_DELAY 19
%define CYCLES_REFRESH_START (DOTS_BEFORE_REFRESH * CYCLES_PER_DOT)
%define CYCLES_IN_REFRESH (DOTS_IN_REFRESH * CYCLES_PER_DOT)
%define CYCLES_REFRESH_END ((DOTS_BEFORE_REFRESH + DOTS_IN_REFRESH) * CYCLES_PER_DOT)

%endif ; !defined(SNEeSe_cycles_inc)
