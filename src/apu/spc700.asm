%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2005, Charles Bilyue'.
Portions Copyright (c) 2003-2004, Daniel Horchner.
Portions Copyright (c) 2004-2005, Nach. ( http://nsrt.edgeemu.com/ )
JMA Technology, Copyright (c) 2004-2005 NSRT Team. ( http://nsrt.edgeemu.com/ )
LZMA Technology, Copyright (c) 2001-4 Igor Pavlov. ( http://www.7-zip.org )
Portions Copyright (c) 2002 Andrea Mazzoleni. ( http://advancemame.sf.net )

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

%endif

; SNEeSe SPC700 CPU emulation core
; Originally written by Lee Hammerton in AT&T assembly
; Maintained/rewritten/ported to NASM by Charles Bilyue'
;
; Compile under NASM
; This code assumes preservation of ebx, ebp, esi, edi in C/C++ calls

;%define TRACKERS 1048576
;%define WATCH_SPC_BREAKS
;%define LOG_SOUND_DSP_READ
;%define LOG_SOUND_DSP_WRITE
;%define TRAP_INVALID_READ
;%define TRAP_INVALID_WRITE

%define UPDATE_SOUND_ON_RAM_WRITE

; This file contains:
;  CPU core info
;  Reset
;  Execution Loop
;  Invalid Opcode Handler
;  Flag format conversion tables
;  Variable definitions (registers, interrupt vectors, etc.)
;  CPU opcode emulation handlers
;  CPU opcode handler table
;  CPU opcode timing table
;
; CPU core info:
;  Nearly all general registers are now used in SPC700 emulation:
;   EAX,EBX are used by the memory mapper;
;   EDX is used as memory mapper work register;
;   EBP is used to hold cycle counter;
;   ESI is used by the opcode fetcher;
;   EDI is used as CPU work register.
;
;    A register              - _A
;    Y register              - _Y
;    YA register pair        - _YA
;    X register              - _X
;    Stack pointer           - _SP
;    Program Counter         - _PC
;    Processor status word   - _PSW
;       True x86 layout = |V|-|-|-|S|Z|-|A|-|-|-|C|
;    True SPC700 layout =         |N|V|P|B|H|I|Z|C|
;                   Using         |N|Z|P|H|B|I|V|C|
;
; SPC timers
;  SPC700 timing is not directly related to 65c816 timing, but for
;   simplicity in emulation we act as if it is. SPC gets 11264 cycles
;   for every 118125 (21.47727..MHz) 65c816 cycles. Since the timers
;   run at ~8KHz and ~64KHz and the main chip runs at 2.048Mhz, the
;   timers are clocked as follows:
;    2.048MHz / 8KHz  = 256 cycles    (Timers 0 and 1)
;    2.048MHz / 64KHz = 32  cycles    (Timer 2)
;
;

%define SNEeSe_SPC700_asm

%include "misc.inc"
%include "apu/spc.inc"
%include "apu/regs.inc"
%include "ppu/ppu.inc"

EXTERN_C SPC_CPU_cycle_multiplicand,SPC_CPU_cycle_divisor
EXTERN SPC_CPU_cycles_mul,SPC_CPU_cycles
EXTERN_C sound_cycle_latch
EXTERN_C SPC_DSP
EXTERN_C SPC_DSP_DATA
EXTERN_C SPC_READ_DSP,SPC_WRITE_DSP
EXTERN_C Update_SPC_Timer_0,Update_SPC_Timer_1,Update_SPC_Timer_2
EXTERN_C Wrap_SPC_Cyclecounter
EXTERN_C Map_Byte,Map_Address

EXTERN_C SNES_Cycles,EventTrip
EXTERN SPC_last_cycles,In_CPU
EXTERN_C DisplaySPC

section .text
EXPORT_C SPC_text_start
section .data
EXPORT_C SPC_data_start
section .bss
EXPORT_C SPC_bss_start

%define SPC_CTRL 0xF1
%define SPC_DSP_ADDR 0xF2

; These are the bits for flag set/clr operations
SPC_FLAG_C equ 1    ; Carry
SPC_FLAG_V equ 2    ; Overflow
SPC_FLAG_I equ 4    ; Interrupt Disable
SPC_FLAG_B equ 8    ; Break
SPC_FLAG_H equ 0x10 ; Half-carry
SPC_FLAG_P equ 0x20 ; Page (direct page)
SPC_FLAG_Z equ 0x40 ; Zero result
SPC_FLAG_N equ 0x80 ; Negative result

SPC_FLAG_NZ equ (SPC_FLAG_N | SPC_FLAG_Z)
SPC_FLAG_NZC equ (SPC_FLAG_NZ | SPC_FLAG_C)
SPC_FLAG_NHZC equ (SPC_FLAG_NZC | SPC_FLAG_H)

REAL_SPC_FLAG_C equ 1       ; Carry
REAL_SPC_FLAG_Z equ 2       ; Zero result
REAL_SPC_FLAG_I equ 4       ; Interrupt Disable
REAL_SPC_FLAG_H equ 8       ; Half-carry
REAL_SPC_FLAG_B equ 0x10    ; Break
REAL_SPC_FLAG_P equ 0x20    ; Page (direct page)
REAL_SPC_FLAG_V equ 0x40    ; Overflow
REAL_SPC_FLAG_N equ 0x80    ; Negative result

%define _PSW C_LABEL(_SPC_PSW)
%define _YA C_LABEL(_SPC_YA)
%define _A  C_LABEL(_SPC_A)
%define _Y  C_LABEL(_SPC_Y)
%define _X  C_LABEL(_SPC_X)
%define _SP C_LABEL(_SPC_SP)
%define _PC C_LABEL(_SPC_PC)

%define R_Base       R_SPC700_Base
%define R_Cycles     R_SPC700_Cycles
%define R_NativePC   R_SPC700_NativePC


%define B_SPC_Code_Base     [R_Base-SPC_Register_Base+SPC_Code_Base]
%define B_PC                [R_Base-SPC_Register_Base+_PC]
%define B_YA                [R_Base-SPC_Register_Base+_YA]
%define B_A                 [R_Base-SPC_Register_Base+_A]
%define B_Y                 [R_Base-SPC_Register_Base+_Y]
%define B_SPC_PAGE          [R_Base-SPC_Register_Base+SPC_PAGE]
%define B_SPC_PAGE_H        byte [R_Base-SPC_Register_Base+SPC_PAGE_H]
%define B_SP                [R_Base-SPC_Register_Base+_SP]
%define B_SPC_Cycles        [R_Base-SPC_Register_Base+C_LABEL(SPC_Cycles)]
%define B_PSW               [R_Base-SPC_Register_Base+_PSW]
%define B_X                 [R_Base-SPC_Register_Base+_X]

%define B_N_flag            [R_Base-SPC_Register_Base+_N_flag]
%define B_V_flag            [R_Base-SPC_Register_Base+_V_flag]
%define B_P_flag            [R_Base-SPC_Register_Base+_P_flag]
%define B_H_flag            [R_Base-SPC_Register_Base+_H_flag]
%define B_Z_flag            [R_Base-SPC_Register_Base+_Z_flag]
%define B_I_flag            [R_Base-SPC_Register_Base+_I_flag]
%define B_B_flag            [R_Base-SPC_Register_Base+_B_flag]
%define B_C_flag            [R_Base-SPC_Register_Base+_C_flag]

%define B_SPC_PORT0R        [R_Base-SPC_Register_Base+C_LABEL(SPC_PORT0R)]
%define B_SPC_PORT1R        [R_Base-SPC_Register_Base+C_LABEL(SPC_PORT1R)]
%define B_SPC_PORT2R        [R_Base-SPC_Register_Base+C_LABEL(SPC_PORT2R)]
%define B_SPC_PORT3R        [R_Base-SPC_Register_Base+C_LABEL(SPC_PORT3R)]
%define B_SPC_PORT0W        [R_Base-SPC_Register_Base+C_LABEL(SPC_PORT0W)]
%define B_SPC_PORT1W        [R_Base-SPC_Register_Base+C_LABEL(SPC_PORT1W)]
%define B_SPC_PORT2W        [R_Base-SPC_Register_Base+C_LABEL(SPC_PORT2W)]
%define B_SPC_PORT3W        [R_Base-SPC_Register_Base+C_LABEL(SPC_PORT3W)]
%ifdef DEBUG
%define B_SPC_TEMP_ADD      [R_Base-SPC_Register_Base+SPC_TEMP_ADD]
%endif

; Load cycle counter to register R_Cycles
%macro LOAD_CYCLES 0
 mov eax,[C_LABEL(SPC_Cycles)]
 mov dword R_Cycles,[C_LABEL(TotalCycles)]
 sub dword R_Cycles,eax
%endmacro

; Get cycle counter to register argument
%macro GET_CYCLES 1
 mov dword %1,[C_LABEL(SPC_Cycles)]
 add dword %1,R_Cycles
%endmacro

; Save register R_Cycles to cycle counter
%macro SAVE_CYCLES 0
 GET_CYCLES R_SPC700_MemMap_Trash
 mov [C_LABEL(TotalCycles)],R_SPC700_MemMap_Trash
%endmacro

; Load base pointer to CPU register set
%macro LOAD_BASE 0
 mov dword R_Base,SPC_Register_Base
%endmacro

; Load register R_NativePC with pointer to code at PC
%macro LOAD_PC 0
 mov dword R_NativePC,[SPC_Code_Base]
 add dword R_NativePC,[_PC]
%endmacro

; Get PC from register R_NativePC
;%1 = with
%macro GET_PC 1
%ifnidn %1,R_NativePC
 mov dword %1,R_NativePC
%endif
 sub dword %1,[SPC_Code_Base]
%endmacro

; Save PC from register R_NativePC
;%1 = with
%macro SAVE_PC 1
 GET_PC %1
 mov dword [_PC],%1
%endmacro

; Set up the flags from PC flag format to SPC flag format
; Corrupts arg 2, returns value in arg 3 (default to cl, al)
;%1 = break flag, %2 = scratchpad, %3 = output
%macro SETUPFLAGS_SPC 0-3 1,cl,al
;%macro Flags_Native_to_SPC 0-3 1,cl,al
 mov byte %3,B_N_flag
 shr byte %3,7

 mov byte %2,B_V_flag
 add byte %2,-1
 adc byte %3,%3

 mov byte %2,B_P_flag
 add byte %2,-1
 adc byte %3,%3

 mov byte %2,B_H_flag
 add byte %3,%3
%if %1 != 0
 inc byte %3
%endif

 shl byte %2,4
 adc byte %3,%3

 mov byte %2,B_I_flag
 add byte %2,-1
 adc byte %3,%3

 mov byte %2,B_Z_flag
 cmp byte %2,1
 adc byte %3,%3

 mov byte %2,B_C_flag
 add byte %2,-1
 adc byte %3,%3
%endmacro

; Restore the flags from SPC flag format to PC flag format
; Corrupts arg 2, returns value in arg 3 (default to cl, al)
;%1 = break flag, %2 = scratchpad, %3 = input
%macro RESTOREFLAGS_SPC 0-3 1,cl,al
;%macro Flags_SPC_to_Native 0-3 1,cl,al
 mov byte B_N_flag,%3   ;negative
 shl byte %3,2  ;start next (overflow)

 sbb byte %2,%2
 add byte %3,%3 ;start next (direct page)
 mov byte B_V_flag,%2

 mov byte %2,0
 adc byte %2,%2
 add byte %3,%3 ;start next (break flag, ignore)
 mov byte B_P_flag,%2
 add byte %3,%3 ;start next (half-carry)
 mov byte B_SPC_PAGE_H,%2

 sbb byte %2,%2
 mov byte B_B_flag,%1

;and byte %2,0x10
 add byte %3,%3 ;start next (interrupt enable)
 mov byte B_H_flag,%2

 sbb byte %2,%2
 add byte %3,%3 ;start next (zero)
 mov byte B_I_flag,%2

 sbb byte %2,%2
 xor byte %2,0xFF
 add byte %3,%3 ;start next (carry)
 mov byte B_Z_flag,%2

 sbb byte %2,%2
 mov byte B_C_flag,%2
%endmacro


; SPC MEMORY MAPPER IS PLACED HERE (ITS SIMPLER THAN THE CPU ONE!)

; bx - contains the actual address, al is where the info should be stored, edx is free
; NB bx is not corrupted! edx is corrupted!
; NB eax is not corrupted barring returnvalue in al... e.g. ah should not be used etc!

section .text
%macro OPCODE_EPILOG 0
%if 0
 test R_Cycles,R_Cycles
 jle SPC_START_NEXT
 jmp SPC_OUT
%else
 jmp SPC_RETURN
%endif
%endmacro

ALIGNC
EXPORT_C SPC_READ_MAPPER
;and ebx,0xFFFF
 test bh,bh
 jz C_LABEL(SPC_READ_ZERO_PAGE)

 cmp ebx,0xFFC0
 jae C_LABEL(SPC_READ_RAM_ROM)
EXPORT_C SPC_READ_RAM
 mov al,[C_LABEL(SPCRAM)+ebx]
 ret

ALIGNC
EXPORT_C SPC_READ_RAM_ROM
 mov edx,[SPC_FFC0_Address]
 mov al,[ebx + edx]
 ret

ALIGNC
EXPORT_C SPC_READ_ZERO_PAGE
 cmp bl,0xF0
 jb C_LABEL(SPC_READ_RAM)

EXPORT_C SPC_READ_FUNC
%ifdef LOG_SOUND_DSP_READ
 SAVE_PC edx
%endif
 SAVE_CYCLES    ; Set cycle counter
 jmp dword [Read_Func_Map - 0xF0 * 4 + ebx * 4]

ALIGNC
EXPORT_C SPC_READ_INVALID
 mov al,0xFF    ; v0.15
%ifdef TRAP_INVALID_READ
%ifdef DEBUG
EXTERN_C InvalidSPCHWRead
;and ebx,0xFFFF
 mov [C_LABEL(Map_Address)],ebx ; Set up Map Address so message works!
 mov [C_LABEL(Map_Byte)],al ; Set up Map Byte so message works

 pusha
 call _InvalidSPCHWRead ; Display read from invalid HW warning
 popa
%endif
%endif
 ret

;   --------

EXPORT_C SPC_WRITE_MAPPER
;and ebx,0xFFFF
 test bh,bh
 jz C_LABEL(SPC_WRITE_ZERO_PAGE)

EXPORT_C SPC_WRITE_RAM
%ifdef UPDATE_SOUND_ON_RAM_WRITE
 push ecx
;push edx
 push eax
 SAVE_CYCLES    ; Set cycle counter
EXTERN_C update_sound
 call C_LABEL(update_sound)
 pop eax
;pop edx
 pop ecx
%endif
 mov [C_LABEL(SPCRAM)+ebx],al
 ret

ALIGNC
EXPORT_C SPC_WRITE_ZERO_PAGE
 cmp bl,0xF0
 jb C_LABEL(SPC_WRITE_RAM)

EXPORT_C SPC_WRITE_FUNC
%ifdef LOG_SOUND_DSP_WRITE
 SAVE_PC edx
%endif
 SAVE_CYCLES    ; Set cycle counter
 jmp dword [Write_Func_Map - 0xF0 * 4 + ebx * 4]

EXPORT_C SPC_WRITE_INVALID
%ifdef TRAP_INVALID_WRITE
%ifdef DEBUG
EXTERN_C InvalidSPCHWWrite
;and ebx,0xFFFF
 mov [C_LABEL(Map_Address)],ebx ; Set up Map Address so message works!
 mov [C_LABEL(Map_Byte)],al ; Set up Map Byte so message works

 pusha
 call _InvalidSPCHWWrite    ; Display write to invalid HW warning
 popa
%endif
%endif
 ret

; GET_BYTE & GET_WORD now assume ebx contains the read address and 
; eax the place to store value also, corrupts edx

%macro GET_BYTE_SPC 0
;call _SPC_READ_MAPPER
 cmp ebx,0xFFC0
 jnb %%read_mapper

 test bh,bh
 jnz %%read_direct

 cmp bl,0xF0
 jb %%read_direct
 call C_LABEL(SPC_READ_FUNC)
 jmp %%done
%%read_mapper:
 call C_LABEL(SPC_READ_RAM_ROM)
 jmp %%done
%%read_direct:
 mov al,[C_LABEL(SPCRAM)+ebx]
%%done:
%endmacro

%macro GET_WORD_SPC 0
 cmp ebx,0xFFC0-1
 jnb %%read_mapper

 test bh,bh
 jnz %%read_direct

 cmp bl,0xF0-1
 jb %%read_direct
 je %%read_mapper

 cmp bl,0xFF
 je %%read_mapper

 call C_LABEL(SPC_READ_FUNC)
 mov ah,al
 inc ebx
 call C_LABEL(SPC_READ_FUNC)
 ror ax,8
 jmp %%done
%%read_mapper:
 call SPC_GET_WORD
 jmp %%done
%%read_direct:
 mov ax,[C_LABEL(SPCRAM)+ebx]
 inc ebx
%%done:
%endmacro

; SET_BYTE & SET_WORD now assume ebx contains the write address and 
; eax the value to write, corrupts edx

%macro SET_BYTE_SPC 0
%ifdef UPDATE_SOUND_ON_RAM_WRITE
 call C_LABEL(SPC_WRITE_MAPPER)
%else
 test bh,bh
 jnz %%write_direct
 cmp bl,0xF0
 jb %%write_direct
 call C_LABEL(SPC_WRITE_FUNC)
 jmp %%done
%%write_direct:
 mov [C_LABEL(SPCRAM)+ebx],al
%%done:
%endif
%endmacro

%macro SET_WORD_SPC 0
 SET_BYTE_SPC
 mov al,ah
 inc bx
 SET_BYTE_SPC
%endmacro

; Push / Pop Macros assume eax contains value - corrupt ebx,edx
%macro PUSH_B 0         ; Push Byte (SP--)
 mov ebx,B_SP
 mov [C_LABEL(SPCRAM)+ebx],al   ; Store data on stack
 dec ebx
 mov B_SP,bl            ; Decrement S (Byte)
%endmacro

%macro POP_B 0          ; Pop Byte (++SP)
 mov ebx,B_SP
 inc bl
 mov B_SP,bl
 mov al,[C_LABEL(SPCRAM)+ebx]   ; Fetch data from stack
%endmacro

%macro PUSH_W 0         ; Push Word (SP--)
 mov ebx,B_SP
 mov [C_LABEL(SPCRAM)+ebx],ah   ; Store data on stack
 mov [C_LABEL(SPCRAM)+ebx-1],al ; Store data on stack
 sub bl,2
 mov B_SP,bl            ; Postdecrement SP
%endmacro

%macro POP_W 0          ; Pop Word (++SP)
 mov ebx,B_SP
 add bl,2               ; Preincrement SP
 mov B_SP,bl
 mov ah,[C_LABEL(SPCRAM)+ebx]   ; Fetch data from stack
 mov al,[C_LABEL(SPCRAM)+ebx-1] ; Fetch data from stack
%endmacro

; --- Ease up on the finger cramps ;-)

;%1 = flag
%macro SET_FLAG_SPC 1
%if %1 & SPC_FLAG_N
 mov byte [_N_flag],0x80
%endif
%if %1 & SPC_FLAG_V
 mov byte [_V_flag],1
%endif
%if %1 & SPC_FLAG_Z
 mov byte [_Z_flag],0
%endif
%if %1 & SPC_FLAG_C
 mov byte [_C_flag],1
%endif
%if %1 & SPC_FLAG_P
 mov byte [_P_flag],1
%endif
%if %1 & SPC_FLAG_I
 mov byte [_I_flag],1
%endif
%if %1 &~ (SPC_FLAG_N | SPC_FLAG_V | SPC_FLAG_Z | SPC_FLAG_C | SPC_FLAG_P | SPC_FLAG_I)
%error Unhandled flag in SET_FLAG_SPC
%endif
%endmacro

;%1 = flag
%macro CLR_FLAG_SPC 1
%if %1 == SPC_FLAG_H
 mov byte [_H_flag],0
%endif
%if %1 == SPC_FLAG_V
 mov byte [_V_flag],0
%endif
%if %1 == SPC_FLAG_Z
 mov byte [_Z_flag],1
%endif
%if %1 == SPC_FLAG_C
 mov byte [_C_flag],0
%endif
%if %1 == SPC_FLAG_P
 mov byte [_P_flag],0
%endif
%if %1 == SPC_FLAG_I
 mov byte [_I_flag],0
%endif
%if %1 &~ (SPC_FLAG_H | SPC_FLAG_V | SPC_FLAG_Z | SPC_FLAG_C | SPC_FLAG_P | SPC_FLAG_I)
%error Unhandled flag in CLR_FLAG_SPC
%endif
%endmacro

;%1 = flag
%macro CPL_FLAG_SPC 1
%if %1 == SPC_FLAG_C
 push eax
 mov al,[_C_flag]
 test al,al
 setz [_C_flag]
 pop eax
%endif
%endmacro

;%1 = flag, %2 = wheretogo
%macro JUMP_FLAG_SPC 2
%if %1 == SPC_FLAG_N
 mov ch,B_N_flag
 test ch,ch
 js %2
%elif %1 == SPC_FLAG_Z
 mov ch,B_Z_flag
 test ch,ch
 jz %2
%elif %1 == SPC_FLAG_V
 mov ch,B_V_flag
 test ch,ch
 jnz %2
%elif %1 == SPC_FLAG_C
 mov ch,B_C_flag
 test ch,ch
 jnz %2
%else
%error Unhandled flag in JUMP_FLAG_SPC
%endif
%endmacro

;%1 = flag, %2 = wheretogo
%macro JUMP_NOT_FLAG_SPC 2
%if %1 == SPC_FLAG_N
 mov ch,B_N_flag
 test ch,ch
 jns %2
%elif %1 == SPC_FLAG_Z
 mov ch,B_Z_flag
 test ch,ch
 jnz %2
%elif %1 == SPC_FLAG_V
 mov ch,B_V_flag
 test ch,ch
 jz %2
%elif %1 == SPC_FLAG_C
 mov ch,B_C_flag
 test ch,ch
 jz %2
%else
%error Unhandled flag in JUMP_NOT_FLAG_SPC
%endif
%endmacro

%macro STORE_FLAGS_P 1
 mov byte B_P_flag,%1
%endmacro

%macro STORE_FLAGS_V 1
 mov byte B_V_flag,%1
%endmacro

%macro STORE_FLAGS_H 1
 mov byte B_H_flag,%1
%endmacro

%macro STORE_FLAGS_N 1
 mov byte B_N_flag,%1
%endmacro

%macro STORE_FLAGS_Z 1
 mov byte B_Z_flag,%1
%endmacro

%macro STORE_FLAGS_I 1
 mov byte B_I_flag,%1
%endmacro

%macro STORE_FLAGS_C 1
 mov byte B_C_flag,%1
%endmacro

%macro STORE_FLAGS_NZ 1
 STORE_FLAGS_N %1
 STORE_FLAGS_Z %1
%endmacro

%macro STORE_FLAGS_NZC 2
 STORE_FLAGS_N %1
 STORE_FLAGS_Z %1
 STORE_FLAGS_C %2
%endmacro

section .data
ALIGND
EXPORT SPCOpTable
dd  C_LABEL(SPC_NOP)           ,C_LABEL(SPC_TCALL_0)    ; 00
dd  C_LABEL(SPC_SET1)          ,C_LABEL(SPC_BBS)
dd  C_LABEL(SPC_OR_A_dp)       ,C_LABEL(SPC_OR_A_abs)
dd  C_LABEL(SPC_OR_A_OXO)      ,C_LABEL(SPC_OR_A_OOdp_XOO)
dd  C_LABEL(SPC_OR_A_IM)       ,C_LABEL(SPC_OR_dp_dp)
dd  C_LABEL(SPC_OR1)           ,C_LABEL(SPC_ASL_dp)
dd  C_LABEL(SPC_ASL_abs)       ,C_LABEL(SPC_PUSH_PSW)
dd  C_LABEL(SPC_TSET1)         ,C_LABEL(SPC_INVALID)
dd  C_LABEL(SPC_BPL)           ,C_LABEL(SPC_TCALL_1)    ; 10
dd  C_LABEL(SPC_CLR1)          ,C_LABEL(SPC_BBC)
dd  C_LABEL(SPC_OR_A_Odp_XO)   ,C_LABEL(SPC_OR_A_Oabs_XO)
dd  C_LABEL(SPC_OR_A_Oabs_YO)  ,C_LABEL(SPC_OR_A_OOdpO_YO)
dd  C_LABEL(SPC_OR_dp_IM)      ,C_LABEL(SPC_OR_OXO_OYO)
dd  C_LABEL(SPC_DECW_dp)       ,C_LABEL(SPC_ASL_Odp_XO)
dd  C_LABEL(SPC_ASL_A)         ,C_LABEL(SPC_DEC_X)
dd  C_LABEL(SPC_CMP_X_abs)     ,C_LABEL(SPC_JMP_Oabs_XO)
dd  C_LABEL(SPC_CLRP)          ,C_LABEL(SPC_TCALL_2)    ; 20
dd  C_LABEL(SPC_SET1)          ,C_LABEL(SPC_BBS)
dd  C_LABEL(SPC_AND_A_dp)      ,C_LABEL(SPC_AND_A_abs)
dd  C_LABEL(SPC_AND_A_OXO)     ,C_LABEL(SPC_AND_A_OOdp_XOO)
dd  C_LABEL(SPC_AND_A_IM)      ,C_LABEL(SPC_AND_dp_dp)
dd  C_LABEL(SPC_OR1C)          ,C_LABEL(SPC_ROL_dp)
dd  C_LABEL(SPC_ROL_abs)       ,C_LABEL(SPC_PUSH_A)
dd  C_LABEL(SPC_CBNE_dp)       ,C_LABEL(SPC_BRA)
dd  C_LABEL(SPC_BMI)           ,C_LABEL(SPC_TCALL_3)    ; 30
dd  C_LABEL(SPC_CLR1)          ,C_LABEL(SPC_BBC)
dd  C_LABEL(SPC_AND_A_Odp_XO)  ,C_LABEL(SPC_AND_A_Oabs_XO)
dd  C_LABEL(SPC_AND_A_Oabs_YO) ,C_LABEL(SPC_AND_A_OOdpO_YO)
dd  C_LABEL(SPC_AND_dp_IM)     ,C_LABEL(SPC_AND_OXO_OYO)
dd  C_LABEL(SPC_INCW_dp)       ,C_LABEL(SPC_ROL_Odp_XO)
dd  C_LABEL(SPC_ROL_A)         ,C_LABEL(SPC_INC_X)
dd  C_LABEL(SPC_CMP_X_dp)      ,C_LABEL(SPC_CALL)
dd  C_LABEL(SPC_SETP)          ,C_LABEL(SPC_TCALL_4)    ; 40
dd  C_LABEL(SPC_SET1)          ,C_LABEL(SPC_BBS)
dd  C_LABEL(SPC_EOR_A_dp)      ,C_LABEL(SPC_EOR_A_abs)
dd  C_LABEL(SPC_EOR_A_OXO)     ,C_LABEL(SPC_EOR_A_OOdp_XOO)
dd  C_LABEL(SPC_EOR_A_IM)      ,C_LABEL(SPC_EOR_dp_dp)
dd  C_LABEL(SPC_AND1)          ,C_LABEL(SPC_LSR_dp)
dd  C_LABEL(SPC_LSR_abs)       ,C_LABEL(SPC_PUSH_X)
dd  C_LABEL(SPC_TCLR1)         ,C_LABEL(SPC_PCALL)
dd  C_LABEL(SPC_BVC)           ,C_LABEL(SPC_TCALL_5)    ; 50
dd  C_LABEL(SPC_CLR1)          ,C_LABEL(SPC_BBC)
dd  C_LABEL(SPC_EOR_A_Odp_XO)  ,C_LABEL(SPC_EOR_A_Oabs_XO)
dd  C_LABEL(SPC_EOR_A_Oabs_YO) ,C_LABEL(SPC_EOR_A_OOdpO_YO)
dd  C_LABEL(SPC_EOR_dp_IM)     ,C_LABEL(SPC_EOR_OXO_OYO)
dd  C_LABEL(SPC_CMPW_YA_dp)    ,C_LABEL(SPC_LSR_Odp_XO)
dd  C_LABEL(SPC_LSR_A)         ,C_LABEL(SPC_MOV_X__A)
dd  C_LABEL(SPC_CMP_Y_abs)     ,C_LABEL(SPC_JMP_abs)
dd  C_LABEL(SPC_CLRC)          ,C_LABEL(SPC_TCALL_6)    ; 60
dd  C_LABEL(SPC_SET1)          ,C_LABEL(SPC_BBS)
dd  C_LABEL(SPC_CMP_A_dp)      ,C_LABEL(SPC_CMP_A_abs)
dd  C_LABEL(SPC_CMP_A_OXO)     ,C_LABEL(SPC_CMP_A_OOdp_XOO)
dd  C_LABEL(SPC_CMP_A_IM)      ,C_LABEL(SPC_CMP_dp_dp)
dd  C_LABEL(SPC_AND1C)         ,C_LABEL(SPC_ROR_dp)
dd  C_LABEL(SPC_ROR_abs)       ,C_LABEL(SPC_PUSH_Y)
dd  C_LABEL(SPC_DBNZ_dp)       ,C_LABEL(SPC_RET)
dd  C_LABEL(SPC_BVS)           ,C_LABEL(SPC_TCALL_7)    ; 70
dd  C_LABEL(SPC_CLR1)          ,C_LABEL(SPC_BBC)
dd  C_LABEL(SPC_CMP_A_Odp_XO)  ,C_LABEL(SPC_CMP_A_Oabs_XO)
dd  C_LABEL(SPC_CMP_A_Oabs_YO) ,C_LABEL(SPC_CMP_A_OOdpO_YO)
dd  C_LABEL(SPC_CMP_dp_IM)     ,C_LABEL(SPC_CMP_OXO_OYO)
dd  C_LABEL(SPC_ADDW_YA_dp)    ,C_LABEL(SPC_ROR_Odp_XO)
dd  C_LABEL(SPC_ROR_A)         ,C_LABEL(SPC_MOV_A__X)
dd  C_LABEL(SPC_CMP_Y_dp)      ,C_LABEL(SPC_INVALID)
dd  C_LABEL(SPC_SETC)          ,C_LABEL(SPC_TCALL_8)    ; 80
dd  C_LABEL(SPC_SET1)          ,C_LABEL(SPC_BBS)
dd  C_LABEL(SPC_ADC_A_dp)      ,C_LABEL(SPC_ADC_A_abs)
dd  C_LABEL(SPC_ADC_A_OXO)     ,C_LABEL(SPC_ADC_A_OOdp_XOO)
dd  C_LABEL(SPC_ADC_A_IM)      ,C_LABEL(SPC_ADC_dp_dp)
dd  C_LABEL(SPC_EOR1)          ,C_LABEL(SPC_DEC_dp)
dd  C_LABEL(SPC_DEC_abs)       ,C_LABEL(SPC_MOV_Y_IM)
dd  C_LABEL(SPC_POP_PSW)       ,C_LABEL(SPC_MOV_dp_IM)
dd  C_LABEL(SPC_BCC)           ,C_LABEL(SPC_TCALL_9)    ; 90
dd  C_LABEL(SPC_CLR1)          ,C_LABEL(SPC_BBC)
dd  C_LABEL(SPC_ADC_A_Odp_XO)  ,C_LABEL(SPC_ADC_A_Oabs_XO)
dd  C_LABEL(SPC_ADC_A_Oabs_YO) ,C_LABEL(SPC_ADC_A_OOdpO_YO)
dd  C_LABEL(SPC_ADC_dp_IM)     ,C_LABEL(SPC_ADC_OXO_OYO)
dd  C_LABEL(SPC_SUBW_YA_dp)    ,C_LABEL(SPC_DEC_Odp_XO)
dd  C_LABEL(SPC_DEC_A)         ,C_LABEL(SPC_MOV_X__SP)
dd  C_LABEL(SPC_DIV)           ,C_LABEL(SPC_XCN)
dd  C_LABEL(SPC_EI)            ,C_LABEL(SPC_TCALL_10)   ; A0
dd  C_LABEL(SPC_SET1)          ,C_LABEL(SPC_BBS)
dd  C_LABEL(SPC_SBC_A_dp)      ,C_LABEL(SPC_SBC_A_abs)
dd  C_LABEL(SPC_SBC_A_OXO)     ,C_LABEL(SPC_SBC_A_OOdp_XOO)
dd  C_LABEL(SPC_SBC_A_IM)      ,C_LABEL(SPC_SBC_dp_dp)
dd  C_LABEL(SPC_MOV1_C_)       ,C_LABEL(SPC_INC_dp)
dd  C_LABEL(SPC_INC_abs)       ,C_LABEL(SPC_CMP_Y_IM)
dd  C_LABEL(SPC_POP_A)         ,C_LABEL(SPC_MOV_OXOInc_A)
dd  C_LABEL(SPC_BCS)           ,C_LABEL(SPC_TCALL_11)   ; B0
dd  C_LABEL(SPC_CLR1)          ,C_LABEL(SPC_BBC)
dd  C_LABEL(SPC_SBC_A_Odp_XO)  ,C_LABEL(SPC_SBC_A_Oabs_XO)
dd  C_LABEL(SPC_SBC_A_Oabs_YO) ,C_LABEL(SPC_SBC_A_OOdpO_YO)
dd  C_LABEL(SPC_SBC_dp_IM)     ,C_LABEL(SPC_SBC_OXO_OYO)
dd  C_LABEL(SPC_MOVW_YA_dp)    ,C_LABEL(SPC_INC_Odp_XO)
dd  C_LABEL(SPC_INC_A)         ,C_LABEL(SPC_MOV_SP_X)
dd  C_LABEL(SPC_INVALID)       ,C_LABEL(SPC_MOV_A_OXOInc)
dd  C_LABEL(SPC_DI)            ,C_LABEL(SPC_TCALL_12)   ; C0
dd  C_LABEL(SPC_SET1)          ,C_LABEL(SPC_BBS)
dd  C_LABEL(SPC_MOV_dp__A)     ,C_LABEL(SPC_MOV_abs__A)
dd  C_LABEL(SPC_MOV_OXO__A)    ,C_LABEL(SPC_MOV_OOdp_XOO__A)
dd  C_LABEL(SPC_CMP_X_IM)      ,C_LABEL(SPC_MOV_abs__X)
dd  C_LABEL(SPC_MOV1__C)       ,C_LABEL(SPC_MOV_dp__Y)
dd  C_LABEL(SPC_MOV_abs__Y)    ,C_LABEL(SPC_MOV_X_IM)
dd  C_LABEL(SPC_POP_X)         ,C_LABEL(SPC_MUL)
dd  C_LABEL(SPC_BNE)           ,C_LABEL(SPC_TCALL_13)   ; D0
dd  C_LABEL(SPC_CLR1)          ,C_LABEL(SPC_BBC)
dd  C_LABEL(SPC_MOV_Odp_XO__A) ,C_LABEL(SPC_MOV_Oabs_XO__A)
dd  C_LABEL(SPC_MOV_Oabs_YO__A),C_LABEL(SPC_MOV_OOdpO_YO__A)
dd  C_LABEL(SPC_MOV_dp__X)     ,C_LABEL(SPC_MOV_Odp_YO__X)
dd  C_LABEL(SPC_MOVW_dp_YA)    ,C_LABEL(SPC_MOV_Odp_XO__Y)
dd  C_LABEL(SPC_DEC_Y)         ,C_LABEL(SPC_MOV_A__Y)
dd  C_LABEL(SPC_CBNE_Odp_XO)   ,C_LABEL(SPC_INVALID)
dd  C_LABEL(SPC_CLRV)          ,C_LABEL(SPC_TCALL_14)   ; E0
dd  C_LABEL(SPC_SET1)          ,C_LABEL(SPC_BBS)
dd  C_LABEL(SPC_MOV_A_dp)      ,C_LABEL(SPC_MOV_A_abs)
dd  C_LABEL(SPC_MOV_A_OXO)     ,C_LABEL(SPC_MOV_A_OOdp_XOO)
dd  C_LABEL(SPC_MOV_A_IM)      ,C_LABEL(SPC_MOV_X_abs)
dd  C_LABEL(SPC_NOT1)          ,C_LABEL(SPC_MOV_Y_dp)
dd  C_LABEL(SPC_MOV_Y_abs)     ,C_LABEL(SPC_NOTC)
dd  C_LABEL(SPC_POP_Y)         ,C_LABEL(SPC_INVALID) ; SPC_SLEEP
dd  C_LABEL(SPC_BEQ)           ,C_LABEL(SPC_TCALL_15)   ; F0
dd  C_LABEL(SPC_CLR1)          ,C_LABEL(SPC_BBC)
dd  C_LABEL(SPC_MOV_A_Odp_XO)  ,C_LABEL(SPC_MOV_A_Oabs_XO)
dd  C_LABEL(SPC_MOV_A_Oabs_YO) ,C_LABEL(SPC_MOV_A_OOdpO_YO)
dd  C_LABEL(SPC_MOV_X_dp)      ,C_LABEL(SPC_MOV_X_Odp_YO)
dd  C_LABEL(SPC_MOV_dp_dp)     ,C_LABEL(SPC_MOV_Y_Odp_XO)
dd  C_LABEL(SPC_INC_Y)         ,C_LABEL(SPC_MOV_Y__A)
dd  C_LABEL(SPC_DBNZ_Y)        ,C_LABEL(SPC_INVALID) ;SPC_STOP

; This holds the base instruction timings in cycles
ALIGND
SPCCycleTable:
db 2,8,4,5,3,4,3,6,2,6,5,4,5,4,6,8  ; 00
db 2,8,4,5,4,5,5,6,5,5,6,5,2,2,4,6  ; 10
db 2,8,4,5,3,4,3,6,2,6,5,4,5,4,5,2  ; 20
db 2,8,4,5,4,5,5,6,5,5,6,5,2,2,3,8  ; 30
db 2,8,4,5,3,4,3,6,2,6,4,4,5,4,6,6  ; 40
db 2,8,4,5,4,5,5,6,5,5,4,5,2,2,4,3  ; 50
db 2,8,4,5,3,4,3,6,2,6,4,4,5,4,5,5  ; 60
db 2,8,4,5,4,5,5,6,5,5,5,5,2,2,3,6  ; 70
db 2,8,4,5,3,4,3,6,2,6,5,4,5,2,4,5  ; 80
db 2,8,4,5,4,5,5,6,5,5,5,5,2,2,12,5 ; 90
db 3,8,4,5,3,4,3,6,2,6,4,4,5,2,4,4  ; A0
db 2,8,4,5,4,5,5,6,5,5,5,5,2,2,3,4  ; B0
db 3,8,4,5,4,5,4,7,2,5,6,4,5,2,4,9  ; C0
db 2,8,4,5,5,6,6,7,4,5,4,5,2,2,6,3  ; D0
db 2,8,4,5,3,4,3,6,2,4,5,3,4,3,4,3  ; E0
db 2,8,4,5,4,5,5,6,3,4,5,4,2,2,4,3  ; F0

; This code should be copied into the top of the address space
ALIGND
EXPORT_C SPC_ROM_CODE
 db 0xCD,0xEF,0xBD,0xE8,0x00,0xC6,0x1D,0xD0
 db 0xFC,0x8F,0xAA,0xF4,0x8F,0xBB,0xF5,0x78
 db 0xCC,0xF4,0xD0,0xFB,0x2F,0x19,0xEB,0xF4
 db 0xD0,0xFC,0x7E,0xF4,0xD0,0x0B,0xE4,0xF5
 db 0xCB,0xF4,0xD7,0x00,0xFC,0xD0,0xF3,0xAB
 db 0x01,0x10,0xEF,0x7E,0xF4,0x10,0xEB,0xBA
 db 0xF6,0xDA,0x00,0xBA,0xF4,0xC4,0xF4,0xDD
 db 0x5D,0xD0,0xDB,0x1F,0x00,0x00,0xC0,0xFF

ALIGND
Read_Func_Map:              ; Mappings for SPC Registers
 dd C_LABEL(SPC_READ_INVALID)
 dd C_LABEL(SPC_READ_CTRL)
 dd C_LABEL(SPC_READ_DSP_ADDR)
 dd C_LABEL(SPC_READ_DSP_DATA)
 dd C_LABEL(SPC_READ_PORT0R)
 dd C_LABEL(SPC_READ_PORT1R)
 dd C_LABEL(SPC_READ_PORT2R)
 dd C_LABEL(SPC_READ_PORT3R)
 dd C_LABEL(SPC_READ_INVALID)
 dd C_LABEL(SPC_READ_INVALID)
 dd C_LABEL(SPC_READ_INVALID)
 dd C_LABEL(SPC_READ_INVALID)
 dd C_LABEL(SPC_READ_INVALID)
 dd C_LABEL(SPC_READ_COUNTER_0)
 dd C_LABEL(SPC_READ_COUNTER_1)
 dd C_LABEL(SPC_READ_COUNTER_2)

ALIGND
Write_Func_Map:             ; Mappings for SPC Registers
 dd C_LABEL(SPC_WRITE_INVALID)
 dd C_LABEL(SPC_WRITE_CTRL)
 dd C_LABEL(SPC_WRITE_DSP_ADDR)
 dd C_LABEL(SPC_WRITE_DSP_DATA)
 dd C_LABEL(SPC_WRITE_PORT0W)
 dd C_LABEL(SPC_WRITE_PORT1W)
 dd C_LABEL(SPC_WRITE_PORT2W)
 dd C_LABEL(SPC_WRITE_PORT3W)
 dd C_LABEL(SPC_WRITE_INVALID)
 dd C_LABEL(SPC_WRITE_INVALID)
 dd C_LABEL(SPC_WRITE_TIMER_0)
 dd C_LABEL(SPC_WRITE_TIMER_1)
 dd C_LABEL(SPC_WRITE_TIMER_2)
 dd C_LABEL(SPC_WRITE_INVALID)
 dd C_LABEL(SPC_WRITE_INVALID)
 dd C_LABEL(SPC_WRITE_INVALID)

offset_to_bit:  db 0x01,0x02,0x04,0x08,0x10,0x20,0x40,0x80
offset_to_not:  db 0xFE,0xFD,0xFB,0xF7,0xEF,0xDF,0xBF,0x7F

section .bss
ALIGNB
EXPORT_C TotalCycles,skipl

EXPORT_C SPC_T0_cycle_latch,skipl
EXPORT_C SPC_T0_position,skipw
EXPORT_C SPC_T0_target,skipw

EXPORT_C SPC_T1_cycle_latch,skipl
EXPORT_C SPC_T1_position,skipw
EXPORT_C SPC_T1_target,skipw

EXPORT_C SPC_T2_cycle_latch,skipl
EXPORT_C SPC_T2_position,skipw
EXPORT_C SPC_T2_target,skipw

SPC_FFC0_Address:   skipl

EXPORT_C SPC_T0_counter,skipb
EXPORT_C SPC_T1_counter,skipb
EXPORT_C SPC_T2_counter,skipb

ALIGNB
SPC_Register_Base:

SPC_Code_Base:  skipl
EXPORT _PC ,skipl
EXPORT _YA
EXPORT _A  ,skipb
EXPORT _Y  ,skipb
            skipw
SPC_PAGE:   skipl
SPC_PAGE_H equ SPC_PAGE+1
EXPORT _N_flag,skipb
EXPORT _H_flag,skipb
EXPORT _I_flag,skipb
EXPORT _B_flag,skipb
EXPORT _SP,skipl

EXPORT C_LABEL(SPC_Cycles),skipl    ; Number of cycles to execute for SPC

EXPORT _PSW,skipb   ; Processor status word
EXPORT _X  ,skipb
EXPORT _Z_flag,skipb
EXPORT _P_flag,skipb

EXPORT _V_flag,skipb
EXPORT _C_flag,skipb

EXPORT_C SPC_PORT0R,skipb
EXPORT_C SPC_PORT1R,skipb
EXPORT_C SPC_PORT2R,skipb
EXPORT_C SPC_PORT3R,skipb

EXPORT_C SPC_PORT0W,skipb
EXPORT_C SPC_PORT1W,skipb
EXPORT_C SPC_PORT2W,skipb
EXPORT_C SPC_PORT3W,skipb

ALIGNB
%ifdef DEBUG
SPC_TEMP_ADD:   skipl
%endif

section .text
ALIGNC
SNES_R2140_SPC: ; APUI00
 Execute_SPC SaveCycles
 mov al,[C_LABEL(SPC_PORT0W)]
 ret

ALIGNC
SNES_R2141_SPC: ; APUI01
 Execute_SPC SaveCycles
 mov al,[C_LABEL(SPC_PORT1W)]
 ret

ALIGNC
SNES_R2142_SPC: ; APUI02
 Execute_SPC SaveCycles
 mov al,[C_LABEL(SPC_PORT2W)]
 ret

ALIGNC
SNES_R2143_SPC: ; APUI03
 Execute_SPC SaveCycles
 mov al,[C_LABEL(SPC_PORT3W)]
 ret

ALIGNC
SNES_W2140_SPC: ; APUI00
 cmp [C_LABEL(SPC_PORT0R)],al
 jne .change
 test al,al
 jz .no_change
.change:
 Execute_SPC SaveCycles
 mov [C_LABEL(SPC_PORT0R)],al
.no_change:
 ret

ALIGNC
SNES_W2141_SPC: ; APUI01
 cmp [C_LABEL(SPC_PORT1R)],al
 jne .change
 test al,al
 jz .no_change
.change:
 Execute_SPC SaveCycles
 mov [C_LABEL(SPC_PORT1R)],al
.no_change:
 ret

ALIGNC
SNES_W2142_SPC: ; APUI02
 cmp [C_LABEL(SPC_PORT2R)],al
 jne .change
 test al,al
 jz .no_change
.change:
 Execute_SPC SaveCycles
 mov [C_LABEL(SPC_PORT2R)],al
.no_change:
 ret

ALIGNC
SNES_W2143_SPC: ; APUI03
 cmp [C_LABEL(SPC_PORT3R)],al
 jne .change
 test al,al
 jz .no_change
.change:
 Execute_SPC SaveCycles
 mov [C_LABEL(SPC_PORT3R)],al
.no_change:
 ret

ALIGNC
EXPORT_C Make_SPC
 pusha
 mov eax,SNES_R2140_SPC
 mov edx,SNES_R2141_SPC
 mov esi,SNES_R2142_SPC
 mov edi,SNES_R2143_SPC

 mov ebx,Read_21_Address(0x40)
 mov cl,0x40 / 4

.set_read_loop:
 mov [ebx],eax
 mov [ebx+1*4],edx
 mov [ebx+2*4],esi
 mov [ebx+3*4],edi
 add ebx,byte 4*4
 dec cl
 jnz .set_read_loop

 mov eax,SNES_W2140_SPC
 mov edx,SNES_W2141_SPC
 mov esi,SNES_W2142_SPC
 mov edi,SNES_W2143_SPC

 mov ebx,Write_21_Address(0x40)
 mov cl,0x40 / 4

.set_write_loop:
 mov [ebx],eax
 mov [ebx+1*4],edx
 mov [ebx+2*4],esi
 mov [ebx+3*4],edi
 add ebx,byte 4*4
 dec cl
 jnz .set_write_loop

 popa
 ret

ALIGNC
EXPORT_C Reset_SPC
 pusha

 ; Get ROM reset vector and setup Program Counter
 movzx eax,word [C_LABEL(SPC_ROM_CODE)+(0xFFFE-0xFFC0)]
 mov [_PC],eax

 mov eax,0  ;[C_LABEL(SNES_Cycles)]
 mov [SPC_last_cycles],eax

 ; Reset the sound DSP registers
 mov [C_LABEL(SPC_Cycles)],eax  ; Clear Cycle Count
 mov [C_LABEL(TotalCycles)],eax
 mov [SPC_PAGE],eax     ; Used to save looking up P flag for Direct page stuff!
 mov dword [_SP],0x01EF ; Reset registers
 mov [_YA],eax
 mov [_X],al
 mov [_PSW],al          ; Clear Flags Register
 mov [_N_flag],al       ; Clear Flags Register
 mov byte [_Z_flag],1
 mov [_H_flag],al
 mov [_V_flag],al
 mov [_I_flag],al
 mov [_P_flag],al
 mov [_B_flag],al
 mov [_C_flag],al

 mov byte [C_LABEL(SPCRAM)+SPC_CTRL],0x80
 mov dword [SPC_FFC0_Address],C_LABEL(SPC_ROM_CODE)-0xFFC0
 mov dword [SPC_Code_Base],C_LABEL(SPC_ROM_CODE)-0xFFC0

 ; Reset timers
 mov [C_LABEL(SPC_T0_counter)],al
 mov [C_LABEL(SPC_T1_counter)],al
 mov [C_LABEL(SPC_T2_counter)],al
 mov word [C_LABEL(SPC_T0_target)],256
 mov word [C_LABEL(SPC_T1_target)],256
 mov word [C_LABEL(SPC_T2_target)],256
 mov [C_LABEL(SPC_T0_position)],ax
 mov [C_LABEL(SPC_T1_position)],ax
 mov [C_LABEL(SPC_T2_position)],ax
 mov [C_LABEL(SPC_T0_cycle_latch)],eax
 mov [C_LABEL(SPC_T1_cycle_latch)],eax
 mov [C_LABEL(SPC_T2_cycle_latch)],eax
 mov [C_LABEL(sound_cycle_latch)],eax

 ; Reset SPC700 output ports
 mov [C_LABEL(SPC_PORT0W)],al
 mov [C_LABEL(SPC_PORT1W)],al
 mov [C_LABEL(SPC_PORT2W)],al
 mov [C_LABEL(SPC_PORT3W)],al

 ; Reset SPC700 input ports
 mov [C_LABEL(SPC_PORT0R)],al
 mov [C_LABEL(SPC_PORT1R)],al
 mov [C_LABEL(SPC_PORT2R)],al
 mov [C_LABEL(SPC_PORT3R)],al

 ; Reset sound DSP port address
 mov [C_LABEL(SPC_DSP)+SPC_DSP_ADDR],al
 mov [C_LABEL(SPC_DSP_DATA)],eax

 popa
 ret

SPC_SHOW_REGISTERS:
 pusha
 call C_LABEL(DisplaySPC)
 popa
 ret

ALIGNC
EXPORT_C get_SPC_PSW
 push dword R_Base
 LOAD_BASE
 SETUPFLAGS_SPC
 pop dword R_Base
 ret

ALIGNC
SPC_GET_WORD:
 GET_BYTE_SPC
 mov ah,al
 inc bx
 GET_BYTE_SPC
 ror ax,8
 ret

ALIGNC
EXPORT_C SPC_START
%ifdef WATCH_SPC_BREAKS
EXTERN_C BreaksLast
 inc dword [C_LABEL(BreaksLast)]
%endif

 mov al,[In_CPU]
 push eax
 mov byte [In_CPU],0

 LOAD_CYCLES
 LOAD_PC
 LOAD_BASE
 xor eax,eax
 jmp SPC_START_NEXT

ALIGNC
SPC_RETURN:
;cmp R_Base,SPC_Register_Base
;jne 0b

%ifdef DEBUG
;mov ebx,[SPC_TEMP_ADD]
;mov [_OLD_SPC_ADDRESS],ebx
%endif
 test R_Cycles,R_Cycles
 jg SPC_OUT             ; Do another instruction if cycles left

SPC_START_NEXT:

; This code is for a SPC-tracker dump... #define TRACKERS to make a dump
; of the CPU state before each instruction - uncomment the calls to
; _Wangle__Fv and _exit to force the emulator to exit when the buffer
; fills. TRACKERS must be defined to the size of the buffer to be used -
; which must be a power of two, and the variables required by this and the
; write in Wangle() (romload.cc) exist only if DEBUG and SPCTRACKERS are
; also defined in romload.cc.
%ifdef TRACKERS
EXTERN_C SPC_LastIns
EXTERN_C SPC_InsAddress
EXTERN_C Wangle__Fv
EXTERN_C exit
 mov edx,[_SPC_LastIns]     ;
 add edx,[_SPC_InsAddress]  ;
 SAVE_PC eax                ;
 mov [edx],ah               ;
 mov [1+edx],al             ;
 mov al,[_A]                ;
 mov [2+edx],al             ;
 mov al,[_X]                ;
 mov [3+edx],al             ;
 mov al,[_Y]                ;
 mov [4+edx],al             ;
 mov al,[_SP]               ;
 mov [5+edx],al             ;
 SETUPFLAGS_SPC             ;
 mov [6+edx],al             ;

 mov al,[esi]               ;
 mov [7+edx],al             ;
 mov eax,[1+esi]            ;
 mov [8+edx],eax            ;
 mov eax,[5+esi]            ;
 mov [12+edx],eax           ;

 mov edx,[_SPC_LastIns]     ;
 add edx,byte 16            ;
 and edx,(TRACKERS-1)       ;
 mov [_SPC_LastIns],edx     ;
 test edx,edx               ;
 jnz .buffer_not_full       ;
 call _Wangle__Fv           ;
 jmp C_LABEL(exit)          ;
                            ;
.buffer_not_full:           ;
 xor eax,eax                ;
%endif

;mov ebx,[_PC]          ; PC now setup
;mov R_NativePC,[SPC_Code_Base]
;add R_NativePC,ebx
%ifdef DEBUG
;mov [SPC_TEMP_ADD],ebx
%endif

 xor eax,eax
 mov al,[R_NativePC]    ; Fetch opcode
 xor ebx,ebx
 mov bl,[SPCCycleTable+eax]
 add R_Cycles,ebx               ; Update cycle counter
 jmp dword [SPCOpTable+eax*4]   ; jmp to opcode handler

ALIGNC
SPC_OUT:
 SAVE_PC R_NativePC
 SAVE_CYCLES    ; Set cycle counter

%ifdef INDEPENDENT_SPC
 ; Update SPC timers to prevent overflow
 Update_SPC_Timer 0
 Update_SPC_Timer 1
 Update_SPC_Timer 2
%endif

 pop eax
 mov [In_CPU],al
 ret                    ; Return to CPU emulation

%include "apu/spcaddr.inc"  ; Include addressing mode macros
%include "apu/spcmacro.inc" ; Include instruction macros

EXPORT_C spc_ops_start

ALIGNC
EXPORT_C SPC_INVALID
 mov [C_LABEL(Map_Byte)],al ; al contains opcode!

 SAVE_PC R_NativePC
 SAVE_CYCLES    ; Set cycle counter

 mov eax,[_PC]          ; Adjust address to correct for pre-increment
 mov [C_LABEL(Map_Address)],eax ; this just sets the error output up correctly!

EXTERN_C InvalidSPCOpcode
 jmp C_LABEL(InvalidSPCOpcode)  ; This exits.. avoids conflict with other things!

ALIGNC
EXPORT_C SPC_SET1
 shr eax,5
 mov ebx,B_SPC_PAGE
 mov bl,[1+R_NativePC]
 add R_NativePC,byte 2
 mov ah,[offset_to_bit+eax]
 GET_BYTE_SPC     
 or al,ah
 SET_BYTE_SPC
 OPCODE_EPILOG

ALIGNC
EXPORT_C SPC_CLR1
 shr eax,5
 mov ebx,B_SPC_PAGE
 mov bl,[1+R_NativePC]
 add R_NativePC,byte 2
 mov ah,[offset_to_not+eax]
 GET_BYTE_SPC     
 and al,ah
 SET_BYTE_SPC
 OPCODE_EPILOG

ALIGNC
EXPORT_C SPC_BBS
 shr eax,5
 mov ebx,B_SPC_PAGE
 mov bl,[1+R_NativePC]
 add R_NativePC,byte 3
 mov ah,[offset_to_bit+eax]
 GET_BYTE_SPC
 test al,ah
 jz SPC_RETURN
 movsx eax,byte [-1+R_NativePC]
 short_branch
 OPCODE_EPILOG

ALIGNC
EXPORT_C SPC_BBC
 shr eax,5
 mov ebx,B_SPC_PAGE
 mov bl,[1+R_NativePC]
 add R_NativePC,byte 3
 mov ah,[offset_to_bit+eax]
 GET_BYTE_SPC         
 test al,ah
 jnz SPC_RETURN
 movsx eax,byte [-1+R_NativePC]
 short_branch
 OPCODE_EPILOG

%include "apu/spcops.inc"   ; Include opcodes

EXPORT_C SPC_READ_CTRL
EXPORT_C SPC_READ_DSP_ADDR
 mov al,[C_LABEL(SPCRAM)+ebx]
 ret

EXPORT_C SPC_READ_DSP_DATA
 push ecx
;push edx
 push eax
 call C_LABEL(SPC_READ_DSP)
 xor ecx,ecx
 mov cl,[C_LABEL(SPCRAM)+SPC_DSP_ADDR]
 pop eax
;pop edx
 mov al,[C_LABEL(SPC_DSP)+ecx]  ; read from DSP register
 pop ecx
 ret

EXPORT_C SPC_READ_PORT0R
 mov al,[C_LABEL(SPC_PORT0R)]
 ret
EXPORT_C SPC_READ_PORT1R
 mov al,[C_LABEL(SPC_PORT1R)]
 ret
EXPORT_C SPC_READ_PORT2R
 mov al,[C_LABEL(SPC_PORT2R)]
 ret
EXPORT_C SPC_READ_PORT3R
 mov al,[C_LABEL(SPC_PORT3R)]
 ret

; WOOPS... TIMER registers are write only, the actual timer clock is internal not accessible!

; COUNTERS ARE 4 BIT, upon read they reset to 0 status

EXPORT_C SPC_READ_COUNTER_0
 push ecx
;push edx
 push eax
 Update_SPC_Timer 0
;call C_LABEL(Update_SPC_Timer_0)
 pop eax
;pop edx
 pop ecx
 mov al,[C_LABEL(SPC_T0_counter)]
 mov [C_LABEL(SPC_T0_counter)],bh
 ret

EXPORT_C SPC_READ_COUNTER_1
 push ecx
;push edx
 push eax
 Update_SPC_Timer 1
;call C_LABEL(Update_SPC_Timer_1)
 pop eax
;pop edx
 pop ecx
 mov al,[C_LABEL(SPC_T1_counter)]
 mov byte [C_LABEL(SPC_T1_counter)],bh
 ret

EXPORT_C SPC_READ_COUNTER_2
 push ecx
;push edx
 push eax
 Update_SPC_Timer 2
;call C_LABEL(Update_SPC_Timer_2)
 pop eax
;pop edx
 pop ecx
 mov al,[C_LABEL(SPC_T2_counter)]
 mov byte [C_LABEL(SPC_T2_counter)],bh
 ret

; | ROMEN | TURBO | PC32  | PC10  | ----- |  ST2  |  ST1  |  ST0  |
;
; ROMEN - enable mask ROM in top 64-bytes of address space for CPU read
; TURBO - enable turbo CPU clock ???
; PC32  - clear SPC read ports 2 & 3
; PC10  - clear SPC read ports 0 & 1
; ST2   - start timer 2 (64kHz)
; ST1   - start timer 1 (8kHz)
; ST0   - start timer 0 (8kHz)

EXPORT_C SPC_WRITE_CTRL
 push eax
 mov ah,0
 test al,al     ; New for 0.25 - read hidden RAM
 mov edx,C_LABEL(SPCRAM)
 jns .rom_disabled
 mov edx,C_LABEL(SPC_ROM_CODE)-0xFFC0

.rom_disabled:
 mov [SPC_FFC0_Address],edx

 test al,0x10       ; Reset ports 0/1 to 00 if set
 jz .no_clear_01
 mov [C_LABEL(SPC_PORT0R)],ah   ; Ports read by SPC should be reset! 
 mov [C_LABEL(SPC_PORT1R)],ah   ; Thanks to Butcha for fix!

.no_clear_01:
 test al,0x20       ; Reset ports 2/3 to 00 if set
 jz .no_clear_23
 mov [C_LABEL(SPC_PORT2R)],ah
 mov [C_LABEL(SPC_PORT3R)],ah

.no_clear_23:
 mov edx,[C_LABEL(TotalCycles)]
 test byte [C_LABEL(SPCRAM)+ebx],4
 jnz .no_enable_timer_2
 test al,4
 jz  .no_enable_timer_2
 mov byte [C_LABEL(SPC_T2_counter)],0
%ifdef FAST_SPC
 and edx,~31
%else
 and edx,~15
%endif
 mov word [C_LABEL(SPC_T2_position)],0
 mov [C_LABEL(SPC_T2_cycle_latch)],edx

.no_enable_timer_2:
%ifdef FAST_SPC
 mov dl,0
%else
 and edx,~127
%endif
 test byte [C_LABEL(SPCRAM)+ebx],2
 jnz .no_enable_timer_1
 test al,2
 jz .no_enable_timer_1
 mov byte [C_LABEL(SPC_T1_counter)],0
 mov word [C_LABEL(SPC_T1_position)],0
 mov [C_LABEL(SPC_T1_cycle_latch)],edx

.no_enable_timer_1:
 test byte [C_LABEL(SPCRAM)+ebx],1
 jnz .no_enable_timer_0
 test al,1
 jz .no_enable_timer_0
 mov byte [C_LABEL(SPC_T0_counter)],0
 mov word [C_LABEL(SPC_T0_position)],0
 mov [C_LABEL(SPC_T0_cycle_latch)],edx

.no_enable_timer_0:
 pop eax
 mov [C_LABEL(SPCRAM)+ebx],al
 ret

EXPORT_C SPC_WRITE_DSP_ADDR
 mov [C_LABEL(SPCRAM)+ebx],al
 ret

EXPORT_C SPC_WRITE_DSP_DATA
 mov [C_LABEL(SPC_DSP_DATA)],al
 push ecx
;push edx
 push eax
 call C_LABEL(SPC_WRITE_DSP)
 pop eax
;pop edx
 pop ecx
 ret

EXPORT_C SPC_WRITE_PORT0W
 mov [C_LABEL(SPC_PORT0W)],al
 ret
EXPORT_C SPC_WRITE_PORT1W
 mov [C_LABEL(SPC_PORT1W)],al
 ret
EXPORT_C SPC_WRITE_PORT2W
 mov [C_LABEL(SPC_PORT2W)],al
 ret
EXPORT_C SPC_WRITE_PORT3W
 mov [C_LABEL(SPC_PORT3W)],al
 ret

EXPORT_C SPC_WRITE_TIMER_0
 cmp [C_LABEL(SPC_T0_target)],al
 je .no_change
 push ecx
;push edx
 push eax
 Update_SPC_Timer 0
;call C_LABEL(Update_SPC_Timer_0)   ; Timer must catch up before changing target
 pop eax
;pop edx
 pop ecx
 test al,al
 mov [C_LABEL(SPC_T0_target)],al    ; (0.32) Butcha - timer targets are writable
 setz [C_LABEL(SPC_T0_target)+1]    ; 0 = 256
.no_change:
 ret

EXPORT_C SPC_WRITE_TIMER_1
 cmp [C_LABEL(SPC_T1_target)],al
 je .no_change
 push ecx
;push edx
 push eax
 Update_SPC_Timer 1
;call C_LABEL(Update_SPC_Timer_1)   ; Timer must catch up before changing target
 pop eax
;pop edx
 pop ecx
 test al,al
 mov [C_LABEL(SPC_T1_target)],al    ; (0.32) Butcha - timer targets are writable
 setz [C_LABEL(SPC_T1_target)+1]    ; 0 = 256
.no_change:
 ret

EXPORT_C SPC_WRITE_TIMER_2
 cmp [C_LABEL(SPC_T2_target)],al
 je .no_change
 push ecx
;push edx
 push eax
 Update_SPC_Timer 2
;call C_LABEL(Update_SPC_Timer_2)   ; Timer must catch up before changing target
 pop eax
;pop edx
 pop ecx
 test al,al
 mov [C_LABEL(SPC_T2_target)],al    ; (0.32) Butcha - timer targets are writable
 setz [C_LABEL(SPC_T2_target)+1]    ; 0 = 256
.no_change:
 ret

section .text
ALIGNC
section .data
ALIGND
section .bss
ALIGNB
