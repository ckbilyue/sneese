%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2005, Charles Bilyue'.
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
