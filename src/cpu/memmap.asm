%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2003 Charles Bilyue'.
Portions Copyright (c) 2003 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

%endif

;%define TRAP_BAD_READS
;%define TRAP_BAD_WRITES
;%define TRAP_IGNORED_WRITES
;
;
; SNEeSe SNES memory mapper v2.0 - NASM rewrite
;
; There are two native pointer tables in this code, and two call tables.
;  Each table has 2k entries (1 per 8k - 8 per bank).
;  Native pointer table is consulted first, if nonzero, pointer is added
;   to SNES address, result being native address for read/write.
;  If native pointer is zero, call table is used to process read.
;
;  Files are split up as follows:
;
;    memmap.asm   Memory map handlers and table declarations.
;    memmap.inc   Memory mapping macros.
;    PPU.asm      Hardware port (21xx/40xx/42xx/43xx) handlers.
;    DMA.asm      DMA emulation code.
;
;

%define SNEeSe_memmap_asm

%include "misc.inc"
%include "cpu/memmap.inc"
%include "cpu/cpumem.inc"
%include "ppu/ppu.inc"

section .text
EXPORT_C memmap_text_start
section .data
EXPORT_C memmap_data_start
section .bss
EXPORT_C memmap_bss_start

EXTERN_C SRAM_Mask
EXTERN_C Map_Address
EXTERN_C Map_Byte

section .bss
ALIGNB
EXPORT_C Read_Bank8Mapping  ,skipl 256*8
EXPORT_C Write_Bank8Mapping ,skipl 256*8
EXPORT_C Read_Bank8Offset   ,skipl 256*8
EXPORT_C Write_Bank8Offset  ,skipl 256*8
EXPORT_C Dummy              ,skipk 64

section .text
ALIGNC
EXPORT_C SNES_GET_WORD
 GET_BYTE
 mov ah,al
 inc ebx
 and ebx,0x00FFFFFF
 GET_BYTE
 ror ax,8
 ret

ALIGNC
EXPORT_C SNES_GET_WORD_00
 GET_BYTE_00
 mov ah,al
 inc bx
 GET_BYTE_00
 ror ax,8
 ret

ALIGNC
EXPORT_C UNSUPPORTED_READ
    mov al,0
%ifdef DEBUG
%ifdef TRAP_BAD_READS
extern _InvalidHWRead
    mov [C_LABEL(Map_Address)],ebx  ; Set up Map Address so message works!
    mov [C_LABEL(Map_Byte)],al      ; Set up Map Byte so message works
    pusha
    call C_LABEL(InvalidHWRead)     ; Unmapped hardware address!
    popa
%endif
%endif
    ret

ALIGNC
EXPORT_C UNSUPPORTED_WRITE
%ifdef DEBUG
%ifdef TRAP_BAD_WRITES
extern _InvalidHWWrite
    mov [C_LABEL(Map_Address)],ebx  ; Set up Map Address so message works!
    mov [C_LABEL(Map_Byte)],al      ; Set up Map Byte so message works
    pusha
    call C_LABEL(InvalidHWWrite)    ; Unmapped hardware address!
    popa
%endif
%endif
    ret

ALIGNC
EXPORT_C IGNORE_WRITE
%ifdef DEBUG
%ifdef TRAP_IGNORED_WRITES
extern _InvalidHWWrite
    mov [C_LABEL(Map_Address)],ebx  ; Set up Map Address so message works!
    mov [C_LABEL(Map_Byte)],al      ; Set up Map Byte so message works
    pusha
    call C_LABEL(InvalidHWWrite)   ; Unmapped hardware address!
    popa
%endif
%endif
    ret

ALIGNC
EXPORT_C Read_Direct_Safeguard
 mov edx,ebx
 shr edx,13
 mov edx,[C_LABEL(Read_Bank8Offset)+edx*4]
 mov al,[edx+ebx]
 ret

ALIGNC
EXPORT_C Write_Direct_Safeguard
 mov edx,ebx
 shr edx,13
 mov edx,[C_LABEL(Write_Bank8Offset)+edx*4]
 mov [edx+ebx],al
 ret

ALIGNC
; Read hardware - 2000-5FFF in 00-3F/80-BF
EXPORT_C PPU_READ
    mov edx,0xFFFF
    and edx,ebx
    jmp [(C_LABEL(Read_Map_20_5F)-0x2000*4)+edx*4]

ALIGNC
; Write hardware - 2000-5FFF in 00-3F/80-BF
EXPORT_C PPU_WRITE
    mov edx,0xFFFF
    and edx,ebx
    jmp [(C_LABEL(Write_Map_20_5F)-0x2000*4)+edx*4]

ALIGNC
EXPORT_C SRAM_READ
    mov edx,[C_LABEL(SRAM_Mask)]
    and edx,ebx
    add edx,[C_LABEL(SRAM)]
    mov al,[edx]
    ret

ALIGNC
EXPORT_C SRAM_WRITE
    mov edx,[C_LABEL(SRAM_Mask)]
    and edx,ebx
    add edx,[C_LABEL(SRAM)]
    mov [edx],al
    ret

ALIGNC
EXPORT_C SRAM_WRITE_ALT
    push ecx
    mov ecx,ebx
    push edi
    mov edi,ebx
    shr ecx,byte 1
    and edi,0x7FFF
    and ecx,~0x7FFF
    add edi,ecx
    mov edx,[C_LABEL(SRAM_Mask)]
    and edx,edi
    add edx,[C_LABEL(SRAM)]
    mov [edx],al
    pop edi
    pop ecx
    ret

ALIGNC
EXPORT_C SRAM_WRITE_HIROM
    push ecx
    mov ecx,0x0F0000
    mov edx,0x1FFF
    and ecx,ebx
    shr ecx,3
    and edx,ebx
    add edx,ecx
    mov ecx,[C_LABEL(SRAM_Mask)]
    and edx,ecx
    mov ecx,[C_LABEL(SRAM)]
    mov [edx+ecx],al
    pop ecx
    ret

ALIGNC
EXPORT_C SRAM_WRITE_2k
    mov edx,2048 - 1
    and edx,ebx
    add edx,[C_LABEL(SRAM)]
    mov [edx],al
    mov [edx+2048],al
    mov [edx+4096],al
    mov [edx+6144],al
    ret

ALIGNC
EXPORT_C SRAM_WRITE_4k
    mov edx,4096 - 1
    and edx,ebx
    add edx,[C_LABEL(SRAM)]
    mov [edx],al
    mov [edx+4096],al
    ret

section .text
ALIGNC
section .data
ALIGND
section .bss
ALIGNB
