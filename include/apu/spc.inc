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

%ifndef SNEeSe_apu_spc_inc
%define SNEeSe_apu_spc_inc

%include "cpu/regs.inc"
%include "cycles.inc"

%ifndef SNEeSe_SPC700_asm

EXTERN SPC_READ_PORT_W, SPC_WRITE_PORT_R
EXTERN SPC_READ_PORT_R, SPC_WRITE_PORT_W

%define SPC_CTRL 0xF1
EXTERN SPCRAM

%endif

;%define NO_TIMER_COUNTER_WRAP

EXTERN Update_SPC_Timer
;%1 = timer
%macro UpdateSPCTimer 1
 push dword %1
 call Update_SPC_Timer
 add esp,4
%endmacro


;%1 = SaveCycles
%macro Execute_SPC 0-1 0
 pusha
%ifidni %1,SaveCycles
;GET_CYCLES eax
 mov eax,[EventTrip]
 add dword eax,R_65c816_Cycles

 cmp eax,CYCLES_REFRESH_START
 jb %%before_refresh
 add eax,byte CYCLES_IN_REFRESH
%%before_refresh:

 ; Update CPU and SPC cycles
 mov edi,[SPC_last_cycles]
 mov [SPC_last_cycles],eax
 sub eax,edi
 add eax,[SPC_CPU_cycles]
%endif

%if 0
 SPC runs at approx. 1024000 clock (32040 x 32).

 NTSC 5A22 timing.
 Masterclock: 21.477272..MHz. (189e7 / 88 Hz)
 Dotclock: 5.36931818..MHz.
 Optimal conversion factors: 328125:15664
 Line rate: 15.6997607655502~KHz.
 Frame rate: 59.92275~Hz.

 PAL 5A22 timing.
 Masterclock: 21.28137MHz.
 Dotclock: 5.3203425MHz.
 Optimal conversion factors: 709379:34176
 Line rate: 15.55655701~KHz.
 Frame rate: 49.86075967~Hz.
%endif

 push eax
 call SPC_START
 add esp,4
 popa
%endmacro

%endif ; !defined(SNEeSe_apu_spc_inc)
