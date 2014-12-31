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
