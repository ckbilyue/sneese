%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2004 Charles Bilyue'.
Portions Copyright (c) 2003-2004 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

%endif

%ifndef SNEeSe_cpumem_inc
%define SNEeSe_cpumem_inc

%ifndef SNEeSe_memmap_asm

EXTERN_C memmap_text_start,memmap_data_start,memmap_bss_start
EXTERN_C Read_Bank8Mapping,Write_Bank8Mapping
EXTERN_C Read_Bank8Offset,Write_Bank8Offset
EXTERN_C Dummy
EXTERN_C SNES_GET_WORD,SNES_GET_WORD_WRAP
EXTERN_C SNES_GET_LONG,SNES_GET_LONG_WRAP
EXTERN_C UNSUPPORTED_READ,UNSUPPORTED_WRITE,IGNORE_WRITE
EXTERN_C PPU_READ,PPU_WRITE
EXTERN_C SRAM_READ,SRAM_WRITE
EXTERN_C SRAM_WRITE_2k,SRAM_WRITE_4k
%endif

%if 0

Macro's included in this ASM header

All macros assume ebx contains 24-bit address, al or ax (depending on size)
the location to return data (for read) or accept data (for write) at.
edx is always corrupted.

For bus reads:
GET_BYTE    Get byte from any bank
GET_WORD    Get word from any bank
For bus write:
SET_BYTE    Set byte in any bank
SET_WORD    Set word in any bank
SET_WORD_HL Set word in any bank for RMW operations

SET_WORD may be passed an optional 'NoSave' parameter to prevent the
push/pop used to preserve the data word.

SET_WORD may be passed an optional 'Double' parameter to force it to
use al for both high and low bytes of write data. eax is not modified.

SET_WORD_HL is an alternate macros for when the address being passed in
is of the high byte, and the high byte will be written first. This
alternate macro does not support NoSave or Double.

%endif

%macro GET_BYTE 0
 mov edx,ebx
 shr edx,13
 mov edx,[C_LABEL(Read_Bank8Offset)+edx*4]
 test edx,edx
 jnz %%read_direct
 mov edx,ebx
 shr edx,13
 call [C_LABEL(Read_Bank8Mapping)+edx*4]
 jmp short %%read_done
%%read_direct:
 mov al,[edx+ebx]
%%read_done:
%endmacro

%macro GET_WORD 0-1 0
%ifnidni %1,wrap
 inc ebx
 test ebx,(8 << 10) - 1
 jnz %%single_block
 dec ebx
 call C_LABEL(SNES_GET_WORD)
%else
 inc bx
 test bx,(8 << 10) - 1
 jnz %%single_block
 dec ebx
 call C_LABEL(SNES_GET_WORD_WRAP)
%endif
 jmp short %%read_done

%%single_block:
 mov edx,ebx
 shr edx,13
 mov edx,[C_LABEL(Read_Bank8Offset)+edx*4]
 test edx,edx
 jnz %%read_direct

 mov edx,ebx
 shr edx,13
 push edx
%ifnidni %1,wrap
 dec ebx
%else
 dec bx
%endif
 call [C_LABEL(Read_Bank8Mapping)+edx*4]
 mov ah,al
%ifnidni %1,wrap
 inc ebx
%else
 inc bx
%endif
 pop edx
 call [C_LABEL(Read_Bank8Mapping)+edx*4]
 ror ax,8
 jmp short %%read_done

%%read_direct:
 mov ax,[edx+ebx-1]
%%read_done:
%endmacro

%macro GET_LONG 0-1 0
%ifnidni %1,wrap
 add ebx,2
 test ebx,(8 << 10) - 2
 jnz %%single_block
 sub bx,2
 call C_LABEL(SNES_GET_LONG)
%else
 add bx,2
 test bx,(8 << 10) - 2
 jnz %%single_block
 sub bx,2
 call C_LABEL(SNES_GET_LONG_WRAP)
%endif
 jmp short %%read_done

%%single_block:
 mov edx,ebx
 xor eax,eax
 shr edx,13
 push edx
 mov edx,[C_LABEL(Read_Bank8Offset)+edx*4]
 test edx,edx
 jnz %%read_direct

 mov edx,[esp]
%ifnidni %1,wrap
 sub ebx,2
%else
 sub bx,2
%endif
 call [C_LABEL(Read_Bank8Mapping)+edx*4]
 mov edx,[esp]
 mov ah,al
%ifnidni %1,wrap
 inc ebx
%else
 inc bx
%endif
 call [C_LABEL(Read_Bank8Mapping)+edx*4]
 pop edx
%ifnidni %1,wrap
 inc ebx
%else
 inc bx
%endif
 bswap eax
 call [C_LABEL(Read_Bank8Mapping)+edx*4]
 ror eax,16
 jmp short %%read_done

%%read_direct:
 mov al,[edx+ebx]
 shl eax,16
 mov ax,[edx+ebx-2]
 pop edx
%%read_done:
%endmacro

%macro SET_BYTE 0
 mov edx,ebx
 shr edx,13
 mov edx,[C_LABEL(Write_Bank8Offset)+edx*4]
 test edx,edx
 jnz %%write_direct
 mov edx,ebx
 shr edx,13
 call [C_LABEL(Write_Bank8Mapping)+edx*4]
 jmp short %%write_done
%%write_direct:
 mov [edx+ebx],al
%%write_done:
%endmacro

;%1 = NoSave/Double
%macro SET_WORD 0-1 0
 SET_BYTE
%ifnidni %1,Double
%ifnidni %1,NoSave
 push eax
%endif
 mov al,ah
%endif
 inc ebx
 and ebx,(1 << 24) - 1
 SET_BYTE
%ifnidni %1,Double
%ifnidni %1,NoSave
 pop eax
%endif
%endif
%endmacro

%macro SET_WORD_HL 0
 push eax
 mov al,ah
 SET_BYTE
 pop eax
 dec ebx
 and ebx,(1 << 24) - 1
 SET_BYTE
%endmacro

%endif ; !defined(SNEeSe_cpumem_inc)
