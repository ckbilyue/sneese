%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2003 Charles Bilyue'.
Portions Copyright (c) 2003 Daniel Horchner.

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


;Define a global label
%macro EXPORT 1-2+      ;label
global %1
%1:
%2
%endmacro

;Define a global label using C label conventions
%macro EXPORT_C 1-2+    ;label
global C_LABEL(%1)
C_LABEL(%1):
%2
%endmacro


;Define a global equate
%macro EXPORT_EQU 2     ;label
global %1
%1 equ (%2)
%endmacro

;Define a global equate using C label conventions
%macro EXPORT_EQU_C 2   ;label
global C_LABEL(%1)
C_LABEL(%1) equ (%2)
%endmacro

;Declare a list of labels to be external
%macro EXTERN 1-*       ;label
%rep %0
extern %1
%rotate 1
%endrep
%endmacro

;Declare a list of labels to be external, using C label conventions
%macro EXTERN_C 1-*     ;label
%rep %0
extern C_LABEL(%1)
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

%endif ; !defined(SNEeSe_misc_inc)
