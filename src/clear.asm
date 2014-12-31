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

%define SNEeSe_clear_asm

%include "misc.inc"

section .text
EXPORT clear_text_start
section .data
EXPORT clear_data_start
section .bss
EXPORT clear_bss_start

section .text
ALIGNC
EXPORT Do_Clear
.clear_loop:
 mov bl,[edi]
 lea esi,[edi+16]
 mov [edi],eax
 mov [edi+4],eax
 mov [edi+8],eax
 mov [edi+12],eax
 mov [esi],eax
 lea edi,[esi+16]
 mov [esi+4],eax
 mov [esi+8],eax
 mov [esi+12],eax
 dec ecx
 jnz .clear_loop
 ret

section .text
ALIGNC
section .data
ALIGND
section .bss
ALIGNB
