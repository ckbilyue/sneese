%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2005, Charles Bilyue'.
Portions Copyright (c) 2003-2004, Daniel Horchner.
Portions Copyright (c) 2004-2005, Nach. ( http://nsrt.edgeemu.com/ )
JMA Technology, Copyright (c) 2004-2005 NSRT Team. ( http://nsrt.edgeemu.com/ )
LZMA Technology, Copyright (c) 2001-4 Igor Pavlov. ( http://www.7-zip.org )
Portions Copyright (c) 2002 Andrea Mazzoleni. ( http://advancemame.sf.net )

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

%endif

%ifndef SNEeSe_cpu_regs_inc
%define SNEeSe_cpu_regs_inc

%define R_65c816_MemMap_Data        al
%define R_65c816_MemMap_DataHigh    ah
%define R_65c816_MemMap_Addx        ebx
%define R_65c816_P                  ecx
%define R_65c816_P_W                R_65c816_P
%define R_65c816_P_B                cl
%define R_65c816_Base               edi
%define R_65c816_Cycles             ebp
%define R_65c816_PBPC               esi
%define R_65c816_PC                 si
%define R_65c816_MemMap_Trash       edx

%endif ; !defined(SNEeSe_cpu_regs_inc)
