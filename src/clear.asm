%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2003 Charles Bilyue'.
Portions Copyright (c) 2003 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

%endif

%define SNEeSe_clear_asm

%include "misc.inc"

section .text
EXPORT_C clear_text_start
section .data
EXPORT_C clear_data_start
section .bss
EXPORT_C clear_bss_start

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
