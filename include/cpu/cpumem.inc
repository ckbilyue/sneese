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
EXTERN_C Last_Bus_Value_A
EXTERN_C SNES_GET_BYTE,SNES_GET_BYTE_FIXED
EXTERN_C SNES_GET_WORD,SNES_GET_WORD_WRAP
EXTERN_C SNES_GET_WORD_FAST,SNES_GET_WORD_FAST_WRAP
EXTERN_C SNES_GET_LONG,SNES_GET_LONG_WRAP
EXTERN_C SNES_GET_LONG_FAST,SNES_GET_LONG_FAST_WRAP
EXTERN_C CPU_OPEN_BUS_READ,CPU_OPEN_BUS_READ_LEGACY
EXTERN_C UNSUPPORTED_READ,UNSUPPORTED_WRITE,IGNORE_WRITE
EXTERN_C PPU_READ,PPU_WRITE
EXTERN_C SRAM_READ,SRAM_WRITE
EXTERN_C SRAM_WRITE_2k,SRAM_WRITE_4k
EXTERN_C Access_Speed_Mask
%endif

EXTERN_C BlockSpeed

%if 0

Macro's included in this ASM header

All macros assume ebx contains 24-bit address, al or ax (depending on size)
the location to return data (for read) or accept data (for write) at.
edx is always corrupted.

For bus reads:
GET_BYTE    Get byte from any bank
GET_WORD    Get word from any bank
GET_LONG    Get long (24-bit address) from any bank
For bus write:
SET_BYTE    Set byte in any bank
SET_WORD    Set word in any bank
SET_WORD_HL Set word in any bank for RMW operations

SET_WORD_HL is an alternate macros for when the address being passed in
is of the high byte, and the high byte will be written first.

GET_WORD, GET_LONG, SET_WORD, and SET_WORD_HL may be passed optional
'wrap' parameters to cause them to wrap within the same bank as the first
byte accessed.

%endif


;%1 = fixed cycle cost
%macro GET_BYTE 0-1
%if %0
%if %1
 add R_65c816_Cycles,%1
%endif
 call C_LABEL(SNES_GET_BYTE_FIXED)
%else
 call C_LABEL(SNES_GET_BYTE)
%endif
%endmacro

;%1 = fixed cycle cost
%macro GET_BYTE_CODE 0-1
%if %0
 mov dword [C_LABEL(Access_Speed_Mask)],0
%endif

 mov edx,ebx
 shr edx,13
 push edx
%if %0 == 0
 movzx edx,byte [C_LABEL(BlockSpeed)+edx]
 add R_65c816_Cycles,edx
 mov edx,[esp]
%endif
 mov edx,[C_LABEL(Read_Bank8Offset)+edx*4]
 test edx,edx
 jnz %%read_direct

 mov edx,[esp]
 call [C_LABEL(Read_Bank8Mapping)+edx*4]
 jmp %%read_done
%%read_direct:
 mov al,[edx+ebx]
 mov [C_LABEL(Last_Bus_Value_A)],al
%%read_done:
%if %0
 mov dword [C_LABEL(Access_Speed_Mask)],-1
%endif
 pop edx
%endmacro

%macro GET_WORD 0-1 0
%ifnidni %1,wrap
 call C_LABEL(SNES_GET_WORD_FAST)
%else
 call C_LABEL(SNES_GET_WORD_FAST_WRAP)
%endif
%endmacro

%macro GET_WORD_CODE 0-1 0
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
 jmp %%read_done

%%single_block:
 mov edx,ebx
 shr edx,13
 push edx
 mov edx,[C_LABEL(Read_Bank8Offset)+edx*4]
 test edx,edx
 jnz %%read_direct

 mov edx,[esp]
 push ecx
 movzx ecx,byte [C_LABEL(BlockSpeed)+edx]
%ifnidni %1,wrap
 dec ebx
%else
 dec bx
%endif
 add R_65c816_Cycles,ecx
 call [C_LABEL(Read_Bank8Mapping)+edx*4]
 mov edx,[esp+4]
 mov ah,al
%ifnidni %1,wrap
 inc ebx
%else
 inc bx
%endif
 add R_65c816_Cycles,ecx
 pop ecx
 call [C_LABEL(Read_Bank8Mapping)+edx*4]
 ror ax,8
 pop edx
 jmp %%read_done

%%read_direct:
 mov ax,[edx+ebx-1]
 pop edx
 mov [C_LABEL(Last_Bus_Value_A)],ah
 movzx edx,byte [C_LABEL(BlockSpeed)+edx]
 lea R_65c816_Cycles,[R_65c816_Cycles+edx*2]
%%read_done:
%endmacro

%macro GET_LONG 0-1 0
%ifnidni %1,wrap
 call C_LABEL(SNES_GET_LONG_FAST)
%else
 call C_LABEL(SNES_GET_LONG_FAST_WRAP)
%endif
%endmacro

%macro GET_LONG_CODE 0-1 0
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
 jmp %%read_done

%%single_block:
 mov edx,ebx
 xor eax,eax
 shr edx,13
 push edx
 mov edx,[C_LABEL(Read_Bank8Offset)+edx*4]
 test edx,edx
 jnz %%read_direct

 mov edx,[esp]
 push ecx
 movzx ecx,byte [C_LABEL(BlockSpeed)+edx]
%ifnidni %1,wrap
 sub ebx,2
%else
 sub bx,2
%endif
 add R_65c816_Cycles,ecx
 call [C_LABEL(Read_Bank8Mapping)+edx*4]
 mov edx,[esp+4]
 mov ah,al
%ifnidni %1,wrap
 inc ebx
%else
 inc bx
%endif
 add R_65c816_Cycles,ecx
 call [C_LABEL(Read_Bank8Mapping)+edx*4]
 mov edx,[esp+4]
%ifnidni %1,wrap
 inc ebx
%else
 inc bx
%endif
 bswap eax
 add R_65c816_Cycles,ecx
 pop ecx
 call [C_LABEL(Read_Bank8Mapping)+edx*4]
 ror eax,16
 pop edx
 jmp %%read_done

%%read_direct:
 mov al,[edx+ebx]
 mov [C_LABEL(Last_Bus_Value_A)],al
 shl eax,16
 mov ax,[edx+ebx-2]
 pop edx
 movzx edx,byte [C_LABEL(BlockSpeed)+edx]
 add R_65c816_Cycles,edx
 add edx,edx
 add R_65c816_Cycles,edx
%%read_done:
%endmacro

;%1 = fixed cycle cost
%macro SET_BYTE 0-1
 mov [C_LABEL(Last_Bus_Value_A)],al
 mov edx,ebx
 shr edx,13
 push edx
%if %0
%if %1
 add R_65c816_Cycles,%1
%endif
 mov dword [C_LABEL(Access_Speed_Mask)],0
%else
 movzx edx,byte [C_LABEL(BlockSpeed)+edx]
 add R_65c816_Cycles,edx
 mov edx,[esp]
%endif
 mov edx,[C_LABEL(Write_Bank8Offset)+edx*4]
 test edx,edx
 jnz %%write_direct
 mov edx,[esp]
 call [C_LABEL(Write_Bank8Mapping)+edx*4]
 jmp %%write_done
%%write_direct:
 mov [edx+ebx],al
%%write_done:
%if %0
 mov dword [C_LABEL(Access_Speed_Mask)],-1
%endif
 pop edx
%endmacro

;%1 = wrap
%macro SET_WORD 0-1 0
 SET_BYTE
 push eax
 mov al,ah
%ifnidni %1,wrap
 inc ebx
 and ebx,(1 << 24) - 1
%else
 inc bx
%endif
 SET_BYTE
 pop eax
%endmacro

;%1 = wrap
%macro SET_WORD_HL 0-1 0
 push eax
 mov al,ah
 SET_BYTE
 pop eax
%ifnidni %1,wrap
 dec ebx
 and ebx,(1 << 24) - 1
%else
 inc bx
%endif
 SET_BYTE
%endmacro

%endif ; !defined(SNEeSe_cpumem_inc)
