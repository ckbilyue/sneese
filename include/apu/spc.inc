%if 0

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

%endif

%ifndef SNEeSe_apu_spc_inc
%define SNEeSe_apu_spc_inc

%include "cpu/regs.inc"
%include "cycles.inc"

%ifndef SNEeSe_SPC700_asm

%define SPC_CTRL 0xF1
EXTERN_C SPCRAM
EXTERN_C TotalCycles
EXTERN_C SPC_T0_cycle_latch,SPC_T0_target,SPC_T0_position
EXTERN_C SPC_T0_cycle_latch,SPC_T0_counter
EXTERN_C SPC_T1_cycle_latch,SPC_T1_target,SPC_T1_position
EXTERN_C SPC_T1_cycle_latch,SPC_T1_counter
EXTERN_C SPC_T2_cycle_latch,SPC_T2_target,SPC_T2_position
EXTERN_C SPC_T2_cycle_latch,SPC_T2_counter

%endif

;%define NO_TIMER_COUNTER_WRAP

;%1 = timer
%macro Update_SPC_Timer 1
 mov edx,[C_LABEL(SPC_T%1_cycle_latch)]
 mov ecx,[C_LABEL(TotalCycles)]
 sub ecx,edx
 mov eax,ecx

%if %1 != 2
 and ecx,byte ~127
 shr eax,7
%else
 and ecx,byte ~15
 shr eax,4
%endif
 add edx,ecx
 add eax,[C_LABEL(SPC_T%1_position)]
 mov [C_LABEL(SPC_T%1_cycle_latch)],edx

 test byte [C_LABEL(SPCRAM) + SPC_CTRL],1 << %1
 je %%done

 mov ecx,[C_LABEL(SPC_T%1_target)]
 mov [C_LABEL(SPC_T%1_position)],eax
 cmp eax,ecx
 jl %%done

 mov edx,eax
 shr edx,16
 div cx
 movzx ecx,byte [C_LABEL(SPC_T%1_counter)]
 movzx edx,dx
 movzx eax,ax
 mov [C_LABEL(SPC_T%1_position)],edx
 add eax,ecx

%ifdef NO_TIMER_COUNTER_WRAP
 mov edx,15
 sub edx,eax
 sbb ecx,ecx
 and ecx,edx
 add eax,ecx
%else
 and al,15
%endif
 mov [C_LABEL(SPC_T%1_counter)],al

%%done:
%endmacro


;%1 = SaveCycles
%macro Execute_SPC 0-1 0
 pusha
%ifidni %1,SaveCycles
;GET_CYCLES eax
 mov eax,[C_LABEL(EventTrip)]
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
 SPC runs at 2048000 clock.

 NTSC 65c816 timing.
 Masterclock: 21.477272..MHz. (189e7 / 88 Hz)
 Dotclock: 5.36931818..MHz.
 Optimal conversion factors: 118125:11264
 Line rate: 15.6997607655502~KHz.
 Frame rate: 59.92275~Hz.

 PAL 65c816 timing.
 Masterclock: 21.28137MHz.
 Dotclock: 5.3203425MHz.
 Optimal conversion factors: 2128137:204800
 Line rate: 15.55655701~KHz.
 Frame rate: 49.86075967~Hz.
%endif

%ifdef SPC_CYCLES_DIV_BEFORE_MUL
 xor edx,edx
 div dword [C_LABEL(SPC_CPU_cycle_divisor)]
 mov [SPC_CPU_cycles],edx   ; Save remainder
 mul dword [C_LABEL(SPC_CPU_cycle_multiplicand)]
%else
 mul dword [C_LABEL(SPC_CPU_cycle_multiplicand)]
 add eax,[SPC_CPU_cycles_mul]
;mov ecx,[C_LABEL(SPC_CPU_cycle_divisor)]
 adc edx,byte 0
 div dword [C_LABEL(SPC_CPU_cycle_divisor)]
 xor edi,edi
 mov [SPC_CPU_cycles_mul],edx   ; Save remainder
 mov [SPC_CPU_cycles],edi
%endif

 add eax,[C_LABEL(SPC_Cycles)]  ; Add new balance of SPC cycles
 mov [C_LABEL(SPC_Cycles)],eax
 cmp [C_LABEL(TotalCycles)],eax
 jb %%need_execute
 ; Check for and handle 35-minute wrap
 test eax,eax
 js %%no_cycles
 cmp dword [C_LABEL(TotalCycles)],byte 0
 jns %%no_cycles
 call C_LABEL(Wrap_SPC_Cyclecounter)
%%need_execute:
 call C_LABEL(SPC_START)
%%no_cycles:
 popa
%endmacro

%endif ; !defined(SNEeSe_apu_spc_inc)
