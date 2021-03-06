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

%ifndef SNEeSe_misc_inc
%define SNEeSe_misc_inc

;For repeating a data item of a specific type and value
%macro DUPLICATE 3      ;vartype, count, data
times %2 %1 %3
%endmacro


;Reserving space in uninitialized data section for specified count of bytes
%macro skipb 0-1 1      ;count=1
resb %1
%endmacro

;Reserving space in uninitialized data section for specified count of
;(16-bit) words
%macro skipw 0-1 1      ;count=1
resw %1
%endmacro

;Reserving space in uninitialized data section for specified count of
;(32-bit) longs
%macro skipl 0-1 1      ;count=1
resd %1
%endmacro

;Reserving space in uninitialized data section for specified count of
;kilobytes
%macro skipk 0-1 1      ;count=1
resb %1*1024
%endmacro


;Platform specific prefixing and suffixing conventions for C labels
%ifndef C_LABELS_PREFIX
%define C_LABELS_PREFIX
%endif

%ifndef C_LABELS_SUFFIX
%define C_LABELS_SUFFIX
%endif

%ifnidn _ %+ C_LABELS_PREFIX %+ _,__

%ifnidn _ %+ C_LABELS_SUFFIX %+ _,__
%define C_LABEL(x) C_LABELS_PREFIX %+ x %+ C_LABELS_SUFFIX
%else
%define C_LABEL(x) C_LABELS_PREFIX %+ x
%endif

%else

%ifnidn _ %+ C_LABELS_SUFFIX %+ _,__
%define C_LABEL(x) x %+ C_LABELS_SUFFIX
%else
%define C_LABEL(x) x
%endif

%endif


;Define a global label with optional directives/values
%macro EXPORT 1-2+      ;label
global C_LABEL(%1)
C_LABEL(%1):

%ifnidn C_LABEL(%1),%1
%1:
%endif

%2
%endmacro


;Define a global equate
%macro EXPORT_EQU 2     ;label
global C_LABEL(%1)
C_LABEL(%1) equ (%2)

%ifnidn C_LABEL(%1),%1
%1 equ (%2)
%endif
%endmacro


;Declare a list of labels to be external, using C label conventions
%macro EXTERN 1-*       ;label
%rep %0
extern C_LABEL(%1)

%ifnidn C_LABEL(%1),%1
%1 equ C_LABEL(%1)
%endif

%rotate 1
%endrep
%endmacro


;Helper macro for aligning the code section
%macro ALIGNC 0
align 16
%endmacro

;Helper macro for aligning the initialized data section
%macro ALIGND 0
alignb 16,db 0
%endmacro

;Helper macro for aligning the uninitialized data section
%macro ALIGNB 0
alignb 16
%endmacro


; macros to clarify generation of literal bit masks
%define BIT(bit) (1 << (bit))
; lowest bit in mask, highest bit in mask
%define BITMASK(lsb,msb) ((BIT((msb) - (lsb) + 1) - 1) << (lsb))


%ifndef RELEASE_BUILD
extern C_LABEL(print_hexnum),C_LABEL(print_decnum),C_LABEL(print_str)
section .data
ALIGND
nl_str:db 10,0
gap_str:db " ",0
arrow_str:db " -> ",0
alert_str:db "!",0
at_str:db " @ ",0
mdmaen_str:db "MDMAEN: ",0
htime_str:db "HTIME: ",0
vtime_str:db "VTIME: ",0
nmitimen_str:db "NMITIMEN: ",0
irqfire_str:db "IRQ @ ",0
irqcnl_str:db "IRQ scheduled in IRQ_Check_Newline",10,0
irqc_str:db "IRQ scheduled in IRQ_Check",10,0
irqcl_str:db "IRQ scheduled in IRQ_Check_Late",10,0
obsel_str:db "OBSEL: ",0
hdma_init1_str:db "hdma_init1: ",0
hdma_init2_str:db "hdma_init2: ",0
hdma_xfer1_str:db "hdma_xfer1: ",0
hdma_xfer2_str:db "hdma_xfer2: ",0
dma_xfer1_str:db "dma_xfer1: ",0
dma_xfer2_str:db "dma_xfer2: ",0
dma_xfer3_str:db "dma_xfer3: ",0
dma_exit_str:db "dma_exit: ",0
comma_str:db ",",0
%endif

%endif ; !defined(SNEeSe_misc_inc)
