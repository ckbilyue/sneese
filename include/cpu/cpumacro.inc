%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2004 Charles Bilyue'.
Portions Copyright (c) 2003-2004 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

%endif

; SNEeSe 65c816 CPU emulation core
; Originally written by Savoury SnaX (Not quite sure if I like AT&T)
; Maintained/rewritten by Charles Bilyue'
;
; Compile under NASM
;
; This file contains:
;  CPU opcode macros
;
; Examples of usage:
;  EM_LDA Direct = 8-bit LDA using "direct" address mode
;  BFC SNES_FLAG_C = Branch if carry flag clear (BCC)

;%1 = addr
%macro _ADC 1
%if M_8bit
 READ8_%1
 JUMP_FLAG SNES_FLAG_D,%%decimal_mode
 mov cl,B_C_flag
 mov bl,B_A
 add cl,255 ;MAKE_CARRY
 adc bl,al
 seto B_V_flag
 sbb al,al
 mov B_A,bl
 STORE_FLAGS_NZC bl,al
 OPCODE_EPILOG

ALIGNC
%%decimal_mode:
 mov cl,B_C_flag
 mov bl,al
 add cl,255 ;MAKE_CARRY
 mov al,B_A
 mov ecx,ebx
 mov edx,eax
 adc al,bl
 daa
 mov B_A,al
 sbb bl,bl
 STORE_FLAGS_NZC al,bl
;al = result, cl = argument, dl = old accumulator
 xor cl,dl ;accum ^ arg
 xor al,dl ;accum ^ result
 xor cl,-1 ;~(accum ^ arg)
 and al,0x80
 and al,cl ;(~((accum ^ arg)) & ((accum ^ result)) & 0x80)
 STORE_FLAGS_V al
%else
 READ16_%1
 JUMP_FLAG SNES_FLAG_D,%%decimal_mode
 mov cl,B_C_flag
 mov ebx,B_A
 add cl,255 ;MAKE_CARRY
 adc bx,ax
 seto B_V_flag
 sbb al,al
 STORE_FLAGS_N bh
 mov B_A,bx
 or bl,bh
 STORE_FLAGS_C al
 STORE_FLAGS_Z bl
 OPCODE_EPILOG

ALIGNC
%%decimal_mode:
 mov cl,B_C_flag
 mov ebx,eax
 add cl,255 ;MAKE_CARRY
 mov eax,B_A
 mov ecx,ebx
 mov edx,eax
 adc al,bl
 daa
 mov bl,al
 mov al,ah
 adc al,bh
 daa
 mov bh,al
 sbb al,al
 STORE_FLAGS_N bh
 mov B_A,bx
 or bl,bh
 STORE_FLAGS_C al
 STORE_FLAGS_Z bl
;ax = result, cx = argument, dx = old accumulator
 xor ch,dh ;accum ^ arg
 xor ah,dh ;accum ^ result
 xor ch,-1 ;~(accum ^ arg)
 and ah,0x80
 and ah,ch ;(~((accum ^ arg)) & ((accum ^ result)) & 0x80)
 STORE_FLAGS_V ah
%endif
%endmacro

;%1 = addr
%macro _AND 1
%if M_8bit
 READ8_%1
 mov bl,B_A
 and bl,al
 mov B_A,bl
 STORE_FLAGS_NZ bl
%else
 READ16_%1
 mov ebx,B_A
 and ebx,eax
 mov B_A,bx
 or bl,bh
 STORE_FLAGS_N bh
 STORE_FLAGS_Z bl
%endif
%endmacro

%macro _ASL 0
%if M_8bit
 add al,al
 sbb cl,cl
 STORE_FLAGS_NZC al,cl
%else
 add ax,ax
 sbb cl,cl
 mov dl,ah
 STORE_FLAGS_C cl
 or dl,al
 STORE_FLAGS_N ah
 STORE_FLAGS_Z dl
%endif
%endmacro

;%1 = label, %2 = flag
%macro BFC 2
ALIGNC
EXPORT_C ALL_%1
 add R_NativePC,byte 2
 JUMP_FLAG %2,C_LABEL(CPU_RETURN),near  ; flag set
 movsx eax,byte [R_NativePC - 1]    ; sign extend for addition
 add R_Cycles,byte 6            ; branch taken
 add R_NativePC,eax
 OPCODE_EPILOG
%endmacro

;%1 = label, %2 = flag
%macro BFS 2
ALIGNC
EXPORT_C ALL_%1
 add R_NativePC,byte 2
 JUMP_NOT_FLAG %2,C_LABEL(CPU_RETURN),near  ; flag clear
 movsx eax,byte [R_NativePC - 1]    ; sign extend for addition
 add R_Cycles,byte 6            ; branch taken
 add R_NativePC,eax
 OPCODE_EPILOG
%endmacro

;%1 = addr
%macro _BIT 1
%if M_8bit
 READ8_%1
 mov cl,B_A
 STORE_FLAGS_N al
 and cl,al
 and al,0x40
 STORE_FLAGS_Z cl
 STORE_FLAGS_V al
%else
 READ16_%1
 mov ecx,B_A
 STORE_FLAGS_N ah
 and ecx,eax
 and ah,0x40
 or cl,ch
 STORE_FLAGS_V ah
 STORE_FLAGS_Z cl
%endif
%endmacro

;%1 = addr, %2 = reg, %3 = size
%macro V_CMP 3
%if %3 == 8
 READ8_%1
 mov cl,%2
 sub cl,al
 sbb al,al
 STORE_FLAGS_N cl
 xor al,0xFF
 STORE_FLAGS_Z cl
 STORE_FLAGS_C al
%else
 READ16_%1
 mov ecx,%2
 sub cx,ax
 sbb al,al
 STORE_FLAGS_N ch
 or cl,ch
 xor al,0xFF
 STORE_FLAGS_Z cl
 STORE_FLAGS_C al
%endif
%endmacro

;%1 = addr
%macro _CMP 1
 V_CMP %1,B_A,M_size
%endmacro

;%1 = addr
%macro _CPX 1
 V_CMP %1,B_X,X_size
%endmacro

;%1 = addr
%macro _CPY 1
 V_CMP %1,B_Y,X_size
%endmacro

;size
%macro _DEC 1
%if (%1) == 8
 dec al
 STORE_FLAGS_NZ al
%else
 dec eax
 mov cl,ah
 STORE_FLAGS_N ah
 or cl,al
 STORE_FLAGS_Z cl
%endif
%endmacro

%define _DEC_M _DEC M_size
%define _DEC_X _DEC X_size

;%1 = addr
%macro _EOR 1
%if M_8bit
 READ8_%1
 mov bl,B_A
 xor bl,al
 mov B_A,bl
 STORE_FLAGS_NZ bl
%else
 READ16_%1
 mov ebx,B_A
 xor ebx,eax
 mov B_A,bx
 or bl,bh
 STORE_FLAGS_N bh
 STORE_FLAGS_Z bl
%endif
%endmacro

;size
%macro _INC 1
%if (%1) == 8
 inc al
 STORE_FLAGS_NZ al
%else
 inc eax
 mov cl,ah
 STORE_FLAGS_N ah
 or cl,al
 STORE_FLAGS_Z cl
%endif
%endmacro

%define _INC_M _INC M_size
%define _INC_X _INC X_size

;%1 = addr, %2 = reg, %3 = size
%macro V_LDx 3
%if %3 == 8
 READ8_%1
 mov %2,al
 STORE_FLAGS_NZ al
%else
 READ16_%1
 mov %2,ax
 or al,ah
 STORE_FLAGS_N ah
 STORE_FLAGS_Z al
%endif
%endmacro

;%1 = addr
%macro _LDA 1
 V_LDx %1,B_A,M_size
%endmacro

;%1 = addr
%macro _LDX 1
 V_LDx %1,B_X,X_size
%endmacro

;%1 = addr
%macro _LDY 1
 V_LDx %1,B_Y,X_size
%endmacro

%macro _LSR 0
%if M_8bit
 shr al,1
 sbb cl,cl
 STORE_FLAGS_NZC al,cl
%else
 shr ax,1
 sbb cl,cl
 mov dl,ah
 STORE_FLAGS_C cl
 or dl,al
 STORE_FLAGS_N ah
 STORE_FLAGS_Z dl
%endif
%endmacro

;%1 = X flag, %2 = direction (0 = MVP, backward, 1 = MVN, forward)
%macro ALL_MVX 2
 push ebx           ; Cycles per instruction iteration
.again:
 mov al,[1+R_NativePC]  ; Dest bank
 mov bl,[2+R_NativePC]  ; Src bank
 mov B_DB,al
%if %1
 mov al,B_X         ; Source address, 8-bit
%else
 mov eax,B_X        ; Source address, 16-bit
%endif
 shl ebx,16
 add ebx,eax
%ifidni %2,MVN
 inc eax            ; MVN, Forward copy
%elifidni %2,MVP
 dec eax            ; MVP, Backward copy
%else
%error Invalid instruction ID for ALL_MVX
%endif
%if %1
 mov B_X,al
%else
 mov B_X,ax
%endif
 GET_BYTE
 mov ebx,B_DB_Shifted
%if %1
 mov bl,B_Y         ; Dest address, 8-bit
%else
 mov bx,B_Y         ; Dest address, 16-bit
%endif
 SET_BYTE
 mov eax,B_A
%ifidni %2,MVN
 inc ebx            ; MVN, Forward copy
%elifidni %2,MVP
 dec ebx            ; MVP, Backward copy
%else
%error Invalid instruction ID for ALL_MVX
%endif
 sub eax,byte 1
%if %1
 mov B_Y,bl
%else
 mov B_Y,bx
%endif
 jc  .done
 test R_Cycles,R_Cycles
 jge .event
 mov B_A,ax
 add R_Cycles,[esp]
 xor eax,eax
 xor ebx,ebx
 jmp .again
ALIGNC
.done:
 add R_NativePC,byte 3
.event:
 mov B_A,ax
 pop edx
 OPCODE_EPILOG
%endmacro

;%1 = addr
%macro _ORA 1
%if M_8bit
 READ8_%1
 mov bl,B_A
 or bl,al
 mov B_A,bl
 STORE_FLAGS_NZ bl
%else
 READ16_%1
 mov ebx,B_A
 or ebx,eax
 mov B_A,bx
 or bl,bh
 STORE_FLAGS_N bh
 STORE_FLAGS_Z bl
%endif
%endmacro

%macro _ROL 0
%if M_8bit
 mov cl,B_C_flag
 add cl,255 ;MAKE_CARRY
 adc al,al
 sbb cl,cl
 STORE_FLAGS_NZC al,cl
%else
 mov cl,B_C_flag
 add cl,255 ;MAKE_CARRY
 adc ax,ax
 sbb cl,cl
 mov dl,ah
 STORE_FLAGS_C cl
 or dl,al
 STORE_FLAGS_N ah
 STORE_FLAGS_Z dl
%endif
%endmacro

%macro _ROR 0
%if M_8bit
 mov cl,B_C_flag
 add cl,255 ;MAKE_CARRY
 rcr al,1
 sbb cl,cl
 STORE_FLAGS_NZC al,cl
%else
 mov cl,B_C_flag
 add cl,255 ;MAKE_CARRY
 rcr ax,1
 sbb cl,cl
 mov dl,ah
 STORE_FLAGS_C cl
 or dl,al
 STORE_FLAGS_N ah
 STORE_FLAGS_Z dl
%endif
%endmacro

;%1 = addr
%macro _SBC 1
%if M_8bit
 READ8_%1
 JUMP_FLAG SNES_FLAG_D,%%decimal_mode
 mov cl,B_C_flag
 mov bl,B_A
 cmp cl,1   ;MAKE_NOT_CARRY
 sbb bl,al
 seto B_V_flag
 sbb al,al
 mov B_A,bl
 xor al,0xFF
 STORE_FLAGS_NZC bl,al
 OPCODE_EPILOG

ALIGNC
%%decimal_mode:
 mov cl,B_C_flag
 mov bl,al
 cmp cl,1   ;MAKE_NOT_CARRY
 mov al,B_A
 mov ecx,ebx
 mov edx,eax
 sbb al,bl
 das
 mov B_A,al
 sbb bl,bl
 STORE_FLAGS_N al
 xor bl,0xFF
 STORE_FLAGS_Z al
 STORE_FLAGS_C bl
;al = result, cl = argument, dl = old accumulator
 xor cl,dl ;accum ^ arg
 xor al,dl ;accum ^ result
 and cl,0x80
 and al,cl ;(((accum ^ arg)) & ((accum ^ result)) & 0x80)
 STORE_FLAGS_V al
%else
 READ16_%1
 JUMP_FLAG SNES_FLAG_D,%%decimal_mode
 mov cl,B_C_flag
 mov ebx,B_A
 cmp cl,1   ;MAKE_NOT_CARRY
 sbb bx,ax
 seto B_V_flag
 sbb al,al
 mov B_A,bx
 xor al,0xFF
 STORE_FLAGS_N bh
 or bl,bh
 STORE_FLAGS_C al
 STORE_FLAGS_Z bl
 OPCODE_EPILOG

ALIGNC
%%decimal_mode:
 mov cl,B_C_flag
 mov ebx,eax
 cmp cl,1   ;MAKE_NOT_CARRY
 mov eax,B_A
 mov ecx,ebx
 mov edx,eax
 sbb al,bl
 das
 mov bl,al
 mov al,ah
 sbb al,bh
 das
 mov bh,al
 sbb al,al
 STORE_FLAGS_N bh
 xor al,0xFF
 mov B_A,bx
 or bl,bh
 STORE_FLAGS_C al
 STORE_FLAGS_Z bl
;ax = result, cx = argument, dx = old accumulator
 xor ch,dh ;accum ^ arg
 xor ah,dh ;accum ^ result
 and ch,0x80
 and ah,ch ;(((accum ^ arg)) & ((accum ^ result)) & 0x80)
 STORE_FLAGS_V ah
%endif
%endmacro

;%1 = addr, %2 = reg, %3 = size
%macro V_STx 3
%if %3 == 8
 WRITE8_%1 %2
%else
 WRITE16_%1 %2
%endif
%endmacro

;%1 = addr
%macro _STA 1
 V_STx %1,B_A,M_size
%endmacro

;%1 = addr
%macro _STX 1
 V_STx %1,B_X,X_size
%endmacro

;%1 = addr
%macro _STY 1
 V_STx %1,B_Y,X_size
%endmacro

;%1 = addr
%macro _STZ 1
 V_STx %1,0,M_size
%endmacro

; TRB set flag Z on A & Memory Operand not A & !Memory Operand!
%macro _TRB 0
%if M_8bit
 mov cl,B_A
 mov ah,cl
 xor cl,-1
 and ah,al      ; Z set for: mem & A
 STORE_FLAGS_Z ah
 and al,cl      ; mem &= ~A
%else
 mov ecx,B_A
 test ecx,eax
 setnz B_Z_flag ; Z set for: mem & A
 xor ecx,-1
 and eax,ecx    ; mem &= ~A
%endif
%endmacro

; TSB set flag Z on A & Memory Operand not A | Memory Operand!
%macro _TSB 0
%if M_8bit
 mov cl,B_A
 mov ah,cl
 and cl,al      ; Z set for: mem & A
 STORE_FLAGS_Z cl
 or al,ah       ; mem |= A
%else
 mov ecx,B_A
 test ecx,eax
 setnz B_Z_flag ; Z set for: mem & A
 or eax,ecx     ; mem |= A
%endif
%endmacro

; label, value
%macro E0_PUSH8 2
ALIGNC
EXPORT_C %2
 ADDR_Implied
 mov al,%1
 E0_PUSH_B
 OPCODE_EPILOG
%endmacro

; label, value
%macro E1_PUSH8 2
ALIGNC
EXPORT_C %2
 ADDR_Implied
 mov al,%1
 E1_PUSH_B
 OPCODE_EPILOG
%endmacro

; label, value, new
%macro E0_PUSH16 2-3 0
ALIGNC
EXPORT_C %2
 ADDR_Implied
 mov eax,%1
 E0_PUSH_W
 OPCODE_EPILOG
%endmacro

; label, value, new
%macro E1_PUSH16 2-3 0
ALIGNC
EXPORT_C %2
 ADDR_Implied
 mov eax,%1
 E1_PUSH_W %3
 OPCODE_EPILOG
%endmacro

; label, value
%macro E0_PULL8 2
ALIGNC
EXPORT_C %2
 ADDR_Implied
 E0_PULL_B
 mov %1,al
 STORE_FLAGS_NZ al
 OPCODE_EPILOG
%endmacro

; label, value
%macro E1_PULL8 2
ALIGNC
EXPORT_C %2
 ADDR_Implied
 E1_PULL_B
 mov %1,al
 STORE_FLAGS_NZ al
 OPCODE_EPILOG
%endmacro

; label, value, new
%macro E0_PULL16 2-3 0
ALIGNC
EXPORT_C %2
 ADDR_Implied
 E0_PULL_W
 STORE_FLAGS_N ah
 mov %1,eax
 or al,ah
 STORE_FLAGS_Z al
 OPCODE_EPILOG
%endmacro

; label, value, new
%macro E1_PULL16 2-3 0
ALIGNC
EXPORT_C %2
 ADDR_Implied
 E1_PULL_W %3
 STORE_FLAGS_N ah
 mov %1,eax
 or al,ah
 STORE_FLAGS_Z al
 OPCODE_EPILOG
%endmacro

;src,size,label
%macro _TxS 3
ALIGNC
EXPORT_C %3
 ADDR_Implied
 mov eax,%1
%if (%2) == 8
 mov B_S,al
%else
 mov B_S,eax
%endif
 OPCODE_EPILOG
%endmacro

;src,dest,size,label
%macro _Txx 4
ALIGNC
EXPORT_C %4
 ADDR_Implied
 mov eax,%1
%if (%3) == 8
 mov %2,al
 STORE_FLAGS_NZ al
%else
 mov %2,eax
 or al,ah
 STORE_FLAGS_N ah
 STORE_FLAGS_Z al
%endif
 OPCODE_EPILOG
%endmacro

;src,size,label
%macro _TxA 3
 _Txx %1,B_A,%2,%3
%endmacro

;src,size,label
%macro _TxX 3
 _Txx %1,B_X,%2,%3
%endmacro

;src,size,label
%macro _TxY 3
 _Txx %1,B_Y,%2,%3
%endmacro

;src,label
%macro _TxC 2
 _Txx %1,B_A,16,%2
%endmacro

;label
%macro _TCD 1
 _Txx B_A,B_D,16,%1
%endmacro

;flag,label
%macro _CLx 2
ALIGNC
EXPORT_C %2     ; Set flag
 ADDR_Implied
 STORE_FLAGS_%1 0
 OPCODE_EPILOG
%endmacro

;flag,label
%macro _SEx 2
ALIGNC
EXPORT_C %2     ; Set flag
 ADDR_Implied
 STORE_FLAGS_%1 1
 OPCODE_EPILOG
%endmacro
