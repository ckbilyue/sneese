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

%ifndef SNEeSe_apu_regs_inc
%define SNEeSe_apu_regs_inc

%define R_SPC700_MemMap_Data        al
%define R_SPC700_MemMap_DataHigh    ah
%define R_SPC700_MemMap_Addx        ebx
%define R_SPC700_PSW                ch
%define R_SPC700_PSW_B              R_SPC700_PSW
%define R_SPC700_Base               edi
%define R_SPC700_Cycles             ebp
%define R_SPC700_NativePC           esi
%define R_SPC700_MemMap_Trash       edx

%endif ; !defined(SNEeSe_apu_regs_inc)
