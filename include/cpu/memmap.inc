%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2003 Charles Bilyue'.
Portions Copyright (c) 2003 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

%endif

%ifndef SNEeSe_cpu_memmap_inc
%define SNEeSe_cpu_memmap_inc

%include "misc.inc"

; Non-mapped/unsupported read
%macro NON_MAPPED_READ 0
    mov al,0xFF
    ret
%endmacro

; Non-mapped/unsupported write
%macro NON_MAPPED_WRITE 0
    ret
%endmacro

%endif ; !defined(SNEeSe_cpu_memmap_inc)
