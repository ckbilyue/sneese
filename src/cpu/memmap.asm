%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2006, Charles Bilyue'.
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
%include "cpu/regs.inc"
%include "cpu/dma.inc"
%include "cycles.inc"

section .text
EXPORT memmap_text_start
section .data
EXPORT memmap_data_start
section .bss
EXPORT memmap_bss_start

EXTERN SRAM_Mask
EXTERN Map_Address
EXTERN Map_Byte

section .bss
ALIGNB
EXPORT Read_Bank8Mapping    ,skipl 256*8
EXPORT Write_Bank8Mapping   ,skipl 256*8
EXPORT Read_Bank8Offset     ,skipl 256*8
EXPORT Write_Bank8Offset    ,skipl 256*8
EXPORT Dummy                ,skipk 64

EXPORT Access_Speed_Mask    ,skipl
EXPORT Last_Bus_Value_A     ,skipb

section .text
ALIGNC
EXPORT SNES_GET_BYTE
 GET_BYTE_CODE
 ret

ALIGNC
EXPORT SNES_GET_BYTE_FIXED
 GET_BYTE_CODE 1
 ret

ALIGNC
EXPORT SNES_GET_WORD_FAST
 GET_WORD_CODE
 ret

ALIGNC
EXPORT SNES_GET_WORD
 GET_BYTE
 mov ah,al
 inc ebx
 and ebx,BITMASK(0,23)
 GET_BYTE
 ror ax,8
 ret

ALIGNC
EXPORT SNES_GET_LONG_FAST
 GET_LONG_CODE
 ret

ALIGNC
EXPORT SNES_GET_LONG
 xor eax,eax
 GET_BYTE
 inc ebx
 mov ah,al
 and ebx,BITMASK(0,23)
 GET_BYTE
 inc ebx
 bswap eax
 and ebx,BITMASK(0,23)
 GET_BYTE
 ror eax,16
 ret

ALIGNC
EXPORT SNES_GET_WORD_FAST_WRAP
 GET_WORD_CODE wrap
 ret

ALIGNC
EXPORT SNES_GET_WORD_WRAP
 GET_BYTE
 mov ah,al
 inc bx
 GET_BYTE
 ror ax,8
 ret

ALIGNC
EXPORT SNES_GET_LONG_FAST_WRAP
 GET_LONG_CODE wrap
 ret

ALIGNC
EXPORT SNES_GET_LONG_WRAP
 xor eax,eax
 GET_BYTE
 inc bx
 mov ah,al
 GET_BYTE
 inc bx
 bswap eax
 GET_BYTE
 ror eax,16
 ret


ALIGNC
EXPORT CPU_OPEN_BUS_READ
    mov al,[Last_Bus_Value_A]
    ret

ALIGNC
EXPORT CPU_OPEN_BUS_READ_LEGACY
    mov al,[Last_Bus_Value_A]
    mov edx,[Access_Speed_Mask]
    and edx,_5A22_LEGACY_CYCLE - _5A22_FAST_CYCLE
    add R_65c816_Cycles,edx
    ret


ALIGNC
EXPORT IGNORE_WRITE
%ifdef DEBUG
%ifdef TRAP_IGNORED_WRITES
extern _InvalidHWWrite
    mov [Map_Address],ebx  ; Set up Map Address so message works!
    mov [Map_Byte],al      ; Set up Map Byte so message works
    pusha
    call InvalidHWWrite   ; Unmapped hardware address!
    popa
%endif
%endif
    mov [Last_Bus_Value_A],al
    ret


ALIGNC
EXPORT UNSUPPORTED_READ
    mov al,0
%ifdef DEBUG
%ifdef TRAP_BAD_READS
extern _InvalidHWRead
    mov [Map_Address],ebx  ; Set up Map Address so message works!
    mov [Map_Byte],al      ; Set up Map Byte so message works
    pusha
    call InvalidHWRead     ; Unmapped hardware address!
    popa
%endif
%endif
    mov [Last_Bus_Value_A],al
    ret

ALIGNC
EXPORT UNSUPPORTED_WRITE
%ifdef DEBUG
%ifdef TRAP_BAD_WRITES
extern _InvalidHWWrite
    mov [Map_Address],ebx  ; Set up Map Address so message works!
    mov [Map_Byte],al      ; Set up Map Byte so message works
    pusha
    call InvalidHWWrite    ; Unmapped hardware address!
    popa
%endif
%endif
    mov [Last_Bus_Value_A],al
    ret


ALIGNC
EXPORT Read_Direct_Safeguard
 mov edx,ebx
 shr edx,13
 mov edx,[Read_Bank8Offset+edx*4]
 mov al,[edx+ebx]
 mov [Last_Bus_Value_A],al
 ret

ALIGNC
EXPORT Write_Direct_Safeguard
 mov edx,ebx
 shr edx,13
 mov edx,[Write_Bank8Offset+edx*4]
 mov [edx+ebx],al
 mov [Last_Bus_Value_A],al
 ret

ALIGNC
; Read hardware - 2000-5FFF in 00-3F/80-BF
EXPORT PPU_READ
    mov edx,BITMASK(0,15)
    and edx,ebx

    cmp dh,0x21
    je .b_bus_read

    cmp byte [In_DMA],0
    jz .access_ok
    cmp dh,0x40
    jb .access_ok
    cmp edx,0x437F
    jbe CPU_OPEN_BUS_READ
.access_ok:
    call [(Read_Map_20_5F-0x2000*4)+edx*4]
    mov [Last_Bus_Value_A],al
    ret

.b_bus_read:
    jmp [(Read_Map_20_5F-0x2000*4)+edx*4]

ALIGNC
; Write hardware - 2000-5FFF in 00-3F/80-BF
EXPORT PPU_WRITE
    mov edx,BITMASK(0,15)
    and edx,ebx

    cmp dh,0x21
    je .b_bus_write

    mov [Last_Bus_Value_A],al
    cmp byte [In_DMA],0
    jz .access_ok
    cmp dh,0x40
    jb .access_ok
    cmp edx,0x437F
    jbe IGNORE_WRITE
.access_ok:
    jmp [(Write_Map_20_5F-0x2000*4)+edx*4]
.b_bus_write:
%if 0
    pusha
extern print_str,print_hexnum,print_decnum
    cmp dl,0x02
    jb .log
    cmp dl,0x05
    jb .no_log
    cmp dl,0x15
    jb .log
    cmp dl,0x1A
    jb .no_log
    cmp dl,0x21
    jb .log
    cmp dl,0x23
    jb .no_log
    cmp dl,0x40
    jb .log
    jmp .no_log
.log:
    movzx eax,al
    movzx edx,dx
    push byte 4
    push edx
    push arrow_str
    push byte 2
    push eax
    call print_hexnum
    add esp,4*2
    call print_str
    add esp,4
    call print_hexnum
    push at_str
    call print_str
    push dword [Current_Line_Timing]
    call print_decnum
    push nl_str
    call print_str
    add esp,4*5
.no_log:
    popa
%endif
    jmp [(Write_Map_20_5F-0x2000*4)+edx*4]

ALIGNC
EXPORT SRAM_READ
    mov edx,[SRAM_Mask]
    and edx,ebx
    add edx,[SRAM]
    mov al,[edx]
    mov [Last_Bus_Value_A],al
    ret

ALIGNC
EXPORT SRAM_WRITE
    mov edx,[SRAM_Mask]
    and edx,ebx
    add edx,[SRAM]
    mov [edx],al
    mov [Last_Bus_Value_A],al
    ret

ALIGNC
EXPORT SRAM_WRITE_ALT
    push ecx
    mov ecx,ebx
    push edi
    mov edi,ebx
    shr ecx,byte 1
    and edi,(32 << 10) - 1
    and ecx,~((32 << 10) - 1)
    add edi,ecx
    mov edx,[SRAM_Mask]
    and edx,edi
    add edx,[SRAM]
    mov [edx],al
    mov [Last_Bus_Value_A],al
    pop edi
    pop ecx
    ret

ALIGNC
EXPORT SRAM_WRITE_HIROM
    push ecx
    mov ecx,0x0F0000
    mov edx,((8 << 10) - 1)
    and ecx,ebx
    shr ecx,3
    and edx,ebx
    add edx,ecx
    mov ecx,[SRAM_Mask]
    and edx,ecx
    mov ecx,[SRAM]
    mov [edx+ecx],al
    mov [Last_Bus_Value_A],al
    pop ecx
    ret

ALIGNC
EXPORT SRAM_WRITE_2k
    mov edx,(2 << 10) - 1
    and edx,ebx
    add edx,[SRAM]
    mov [edx],al
    mov [edx+2048],al
    mov [edx+4096],al
    mov [edx+6144],al
    mov [Last_Bus_Value_A],al
    ret

ALIGNC
EXPORT SRAM_WRITE_4k
    mov edx,(4 << 10) - 1
    and edx,ebx
    add edx,[SRAM]
    mov [edx],al
    mov [edx+4096],al
    mov [Last_Bus_Value_A],al
    ret

section .text
ALIGNC
section .data
ALIGND
section .bss
ALIGNB
