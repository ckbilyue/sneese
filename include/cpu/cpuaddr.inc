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
;  65c816 addressing mode macros
;
; Note: As of 0.372 (11-99), be very careful when modifying this code,
; and the CPU loops! The CPU loops set eax/ebx to 0, except al/bl, and
; esi to the address of the data at PB:PC (opcode + operands),
; and the new address mode emulation expects this!
;
; Final address in ebx, or eax when address is to be stored in PC!

; Helper macro for read-modify-write operations.

;insn, addr
%macro RMW 2
 RMW_ %+ %2 %1
%endmacro


;helper macro for nonzero DL fixup/quirks
%macro Check_DL_Not_Zero 0
%ifdef S_8bit
%if S_8bit
 test dl,dl
 jz %%fixup
 add R_Cycles,byte _5A22_FAST_CYCLE
 jmp %%no_fixup
%%fixup:
 mov bh,dh 
%%no_fixup:
%else
 add dl,255
 sbb edx,edx
 and edx,_5A22_FAST_CYCLE
 add R_Cycles,edx
%endif
%endif
%endmacro


; Implied
%macro ADDR_Implied 0
 inc R_NativePC
%endmacro


; shift, rotate, increment, and decrement of registers
;  RMW 8-bit and 16-bit
; M  ASL-0A  INC-1A  ROL-2A  DEC-3A  LSR-4A  ROR-6A
;  X DEY-88  INY-C8  DEX-CA  INX-E8
%macro RMW_Accumulator 1
 ADDR_Implied
%if M_8bit
 mov al,B_A
%else
 mov eax,B_A
%endif
;add R_Cycles,_5A22_FAST_CYCLE
 %1
%if M_8bit
 mov B_A,al
%else
 mov B_A,ax
%endif
%endmacro

%macro RMW_Index_X 1
 ADDR_Implied
%if X_8bit
 mov al,B_X
%else
 mov eax,B_X
%endif
;add R_Cycles,_5A22_FAST_CYCLE
 %1
%if X_8bit
 mov B_X,al
%else
 mov B_X,ax
%endif
%endmacro

%macro RMW_Index_Y 1
 ADDR_Implied
%if X_8bit
 mov al,B_Y
%else
 mov eax,B_Y
%endif
;add R_Cycles,_5A22_FAST_CYCLE
 %1
%if X_8bit
 mov B_Y,al
%else
 mov B_Y,ax
%endif
%endmacro


; Immediate (read-only)
;  Read 8-bit and 16-bit
;    ORA-09  AND-29  EOR-49  ADC-69  BIT-89  LDY-A0  LDX-A2  LDA-A9
;    CPY-C0  CMP-C9  CPX-E0  SBC-E9
;  Read 8-bit
;    REP-C2  SEP-E2
;
%macro ADDR_Immediate 0
%endmacro

%macro READ8_Immediate 0
 mov al,[1+R_NativePC]
 add R_NativePC,byte 2
%endmacro

%macro READ16_Immediate 0
 mov al,[1+R_NativePC]
 mov ah,[2+R_NativePC]
 add R_NativePC,byte 3
%endmacro

; Absolute
;  Address = DB:a16
;  Read 8-bit and 16-bit
;    ORA-0D  BIT-2C  AND-2D  EOR-4D  ADC-6D  LDY-AC  LDA-AD  LDX-AE
;    CPY-CC  CMP-CD  CPX-EC  SBC-ED
;  Write 8-bit and 16-bit
;    STZ-9C  STY-8C  STA-8D  STX-8E
;  RMW 8-bit and 16-bit
;    TSB-0C  ASL-0E  TRB-1C  ROL-2E  LSR-4E  ROR-6E  DEC-CE  INC-EE
;
%macro ADDR_Absolute 0
 mov ebx,B_DB_Shifted
 mov bl,[1+R_NativePC]
 mov bh,[2+R_NativePC]
 add R_NativePC,byte 3
%endmacro

%macro READ8_Absolute 0
 ADDR_Absolute
 GET_BYTE
%endmacro

%macro READ16_Absolute 0
 ADDR_Absolute
 GET_WORD
%endmacro

%macro WRITE8_Absolute 1
 ADDR_Absolute
 mov al,%1
 SET_BYTE
%endmacro

%macro WRITE16_Absolute 1
 ADDR_Absolute
 mov eax,%1
 SET_WORD
%endmacro

%macro RMW_Absolute 1
 READ %+ M_size %+ _Absolute
;add R_Cycles,_5A22_FAST_CYCLE
 %1
%if M_8bit
 SET_BYTE
%else
 SET_WORD_HL
%endif
%endmacro


; Absolute Long (corrupts eax)
;  Address = a24
;  Read 8-bit and 16-bit
;    ORA-0F  AND-2F  EOR-4F  ADC-6F  LDA-AF  CMP-CF  SBC-EF
;  Write 8-bit and 16-bit
;    STA-8F
;
%macro ADDR_Absolute_Long 0
 mov bl,[3+R_NativePC]
 shl ebx,16
 mov bl,[1+R_NativePC]
 mov bh,[2+R_NativePC]
 add R_NativePC,byte 4
%endmacro

%macro READ8_Absolute_Long 0
 ADDR_Absolute_Long
 GET_BYTE
%endmacro

%macro READ16_Absolute_Long 0
 ADDR_Absolute_Long
 GET_WORD
%endmacro

%macro WRITE8_Absolute_Long 1
 ADDR_Absolute_Long
 mov al,%1
 SET_BYTE
%endmacro

%macro WRITE16_Absolute_Long 1
 ADDR_Absolute_Long
 mov eax,%1
 SET_WORD
%endmacro

; Direct (corrupts eax)
;  Read 8-bit and 16-bit
;    ORA-05  BIT-24  AND-25  EOR-45  ADC-65  LDY-A4  LDA-A5  LDX-A6
;    CPY-C4  CMP-C5  CPX-E4  SBC-E5
;  Write 8-bit and 16-bit
;    STZ-64  STY-84  STA-85  STX-86
;  RMW 8-bit and 16-bit
;    TSB-04  ASL-06  TRB-14  ROL-26  LSR-46  ROR-66  DEC-C6  INC-E6
;

; if present, argument specifies index
%macro ADDR_Direct 0-1 0
 READ8_Immediate
%ifnidni %1,0
 add eax,%1             ;helper: index
%endif
 mov edx,B_D
 mov ebx,0xFFFF
 add eax,edx            ;(D + byte (+ index, if present))
 and ebx,eax            ;bank 00
 Check_DL_Not_Zero
%ifnidni %1,0
;add R_Cycles,_5A22_FAST_CYCLE
%endif
%endmacro

%macro READ8_Direct 0
 ADDR_Direct
 GET_BYTE
%endmacro

%macro READ16_Direct 0
 ADDR_Direct
 GET_WORD
%endmacro

%macro READ24_Direct 0
 ADDR_Direct
 GET_LONG
%endmacro

%macro WRITE8_Direct 1
 ADDR_Direct
 mov al,%1
 SET_BYTE
%endmacro

%macro WRITE16_Direct 1
 ADDR_Direct
 mov eax,%1
 SET_WORD
%endmacro

%macro RMW_Direct 1
 READ %+ M_size %+ _Direct
;add R_Cycles,_5A22_FAST_CYCLE
 %1
%if M_8bit
 SET_BYTE
%else
 SET_WORD_HL
%endif
%endmacro


; Direct Indirect Indexed (corrupts eax)
;  Read 8-bit and 16-bit
;    ORA-11  AND-31  EOR-51  ADC-71  LDA-B1  CMP-D1  SBC-F1
;  Write 8-bit and 16-bit
;    STA-91
;
; 2 bytes, 5-8 clocks

;       1   1  1   1  1 PBR,PC          Op Code     1
;       2   1  1   0  1 PBR,PC+1        DO          1
;   (if DL != 0)
;   (2) 2a  1  1   0  0 PBR,PC+1        IO          1
;       3   1  1   1  0 0,D+DO          AAL         1
;       4   1  1   1  0 0,D+DO+1        AAH         1
;   (if index across page boundary, write, or X=0)
;   (4) 4a  1  1   0  0 DBR,AAH,AAL+YL  IO          1
;       5   1  1   1  0 DBR,AA+Y        Data Low    1/0
;   (if 16-bit data)
;   (1) 5a  1  1   1  1 DBR,AA+Y+1      Data High   1/0
%macro ADDR_Direct_Indirect_Indexed 0
 READ16_Direct
 mov ebx,B_DB_Shifted
 mov bx,ax
 mov edx,B_Y
 add ebx,edx
 and ebx,0x00FFFFFF ; Ensure 24-bit address
%endmacro

%macro READ8_Direct_Indirect_Indexed 0
 ADDR_Direct_Indirect_Indexed
 GET_BYTE
%endmacro

%macro READ16_Direct_Indirect_Indexed 0
 ADDR_Direct_Indirect_Indexed
 GET_WORD
%endmacro

%macro WRITE8_Direct_Indirect_Indexed 1
 ADDR_Direct_Indirect_Indexed
 mov al,%1
 SET_BYTE
%endmacro

%macro WRITE16_Direct_Indirect_Indexed 1
 ADDR_Direct_Indirect_Indexed
 mov eax,%1
 SET_WORD
%endmacro

; Direct Indirect Indexed Long (corrupts eax)
;  Read 8-bit and 16-bit
;    ORA-17  AND-37  EOR-57  ADC-77  LDA-B7  CMP-D7  SBC-F7
;  Write 8-bit and 16-bit
;    STA-97
;
; 2 bytes, 6-8 clocks
;
;       1   1  1   1  1 PBR,PC      Op Code     1
;       2   1  1   0  1 PBR,PC+1    DO          1
;   (if DL != 0)
;   (2) 2a  1  1   0  0 PBR,PC+1    IO          1
;       3   1  1   1  0 0,D+DO      AAL         1
;       4   1  1   1  0 0,D+DO+1    AAH         1
;       5   1  1   1  0 0,D+DO+2    AAB         1
;       6   1  1   1  0 AAB,AA+Y    Data Low    1/0
;   (if 16-bit data)
;   (1) 6a  1  1   1  0 AAB,AA+Y+1  Data High   1/0
%macro ADDR_Direct_Indirect_Indexed_Long 0
 ADDR_Direct_Indirect_Long B_Y
%endmacro

%macro READ8_Direct_Indirect_Indexed_Long 0
 ADDR_Direct_Indirect_Indexed_Long
 GET_BYTE
%endmacro

%macro READ16_Direct_Indirect_Indexed_Long 0
 ADDR_Direct_Indirect_Indexed_Long
 GET_WORD
%endmacro

%macro WRITE8_Direct_Indirect_Indexed_Long 1
 ADDR_Direct_Indirect_Indexed_Long
 mov al,%1
 SET_BYTE
%endmacro

%macro WRITE16_Direct_Indirect_Indexed_Long 1
 ADDR_Direct_Indirect_Indexed_Long
 mov eax,%1
 SET_WORD
%endmacro

; Direct index X (corrupts eax)
;  Read 8-bit and 16-bit
;    ORA-15  BIT-34  AND-35  EOR-55  ADC-75  LDY-B4  LDA-B5  CMP-D5
;    SBC-F5
;  Write 8-bit and 16-bit
;    STZ-74  STY-94  STA-95
;  RMW 8-bit and 16-bit
;    ASL-16  ROL-36  LSR-56  ROR-76  DEC-D6  INC-F6
;
%macro ADDR_Direct_Index_X 0
 ADDR_Direct B_X
%endmacro

%macro READ8_Direct_Index_X 0
 ADDR_Direct_Index_X
 GET_BYTE
%endmacro

%macro READ16_Direct_Index_X 0
 ADDR_Direct_Index_X
 GET_WORD
%endmacro

%macro WRITE8_Direct_Index_X 1
 ADDR_Direct_Index_X
 mov al,%1
 SET_BYTE
%endmacro

%macro WRITE16_Direct_Index_X 1
 ADDR_Direct_Index_X
 mov eax,%1
 SET_WORD
%endmacro

%macro RMW_Direct_Index_X 1
 READ %+ M_size %+ _Direct_Index_X
;add R_Cycles,_5A22_FAST_CYCLE
 %1
%if M_8bit
 SET_BYTE
%else
 SET_WORD_HL
%endif
%endmacro


; Direct index Y (corrupts eax)
;  Read 8-bit and 16-bit
;    LDX-B6
;  Write 8-bit and 16-bit
;    STX-96
;
; 2 bytes, 4-6 clocks
;
;       1   1  1   1  1 PBR,PC      Op Code     1
;       2   1  1   0  1 PBR,PC+1    DO          1
;   (if DL != 0)
;   (2) 2a  1  1   0  0 PBR,PC+1    IO          1
;       3   1  1   0  0 PBR,PC+1    IO          1
;       4   1  1   1  0 0,D+DO+Y    Data Low    1/0
;   (if 16-bit data)
;   (1) 4a  1  1   1  0 0,D+DO+Y+1  Data High   1/0
%macro ADDR_Direct_Index_Y 0
 ADDR_Direct B_Y
%endmacro

%macro READ8_Direct_Index_Y 0
 ADDR_Direct_Index_Y
 GET_BYTE
%endmacro

%macro READ16_Direct_Index_Y 0
 ADDR_Direct_Index_Y
 GET_WORD
%endmacro

%macro WRITE8_Direct_Index_Y 1
 ADDR_Direct_Index_Y
 mov al,%1
 SET_BYTE
%endmacro

%macro WRITE16_Direct_Index_Y 1
 ADDR_Direct_Index_Y
 mov eax,%1
 SET_WORD
%endmacro

; Direct Indexed Indirect (corrupts eax)
;  Read 8-bit and 16-bit
;    ORA-01  AND-21  EOR-41  ADC-61  LDA-A1  CMP-C1  SBC-E1
;  Write 8-bit and 16-bit
;    STA-81
;
; 2 bytes, 6-8 clocks
;
;       1   1  1   1  1 PBR,PC      Op Code     1
;       2   1  1   0  1 PBR,PC+1    DO          1
;   (if DL != 0)
;   (2) 2a  1  1   0  0 PBR,PC+1    IO          1
;       3   1  1   0  0 PBR,PC+1    IO          1
;       4   1  1   1  0 0,D+DO+X    AAL         1
;       5   1  1   1  0 0,D+DO+X+1  AAH         1
;       6   1  1   1  0 DBR,AA      Data Low    1/0
;   (if 16-bit data)
;   (1) 6a  1  1   1  0 DBR,AA+1    Data High   1/0
%macro ADDR_Direct_Indexed_Indirect 0
 READ16_Direct_Index_X
 mov ebx,B_DB_Shifted
 mov bx,ax
%endmacro

%macro READ8_Direct_Indexed_Indirect 0
 ADDR_Direct_Indexed_Indirect
 GET_BYTE
%endmacro

%macro READ16_Direct_Indexed_Indirect 0
 ADDR_Direct_Indexed_Indirect
 GET_WORD
%endmacro

%macro WRITE8_Direct_Indexed_Indirect 1
 ADDR_Direct_Indexed_Indirect
 mov al,%1
 SET_BYTE
%endmacro

%macro WRITE16_Direct_Indexed_Indirect 1
 ADDR_Direct_Indexed_Indirect
 mov eax,%1
 SET_WORD
%endmacro

; Absolute Index X (corrupts eax)
;  Read 8-bit and 16-bit
;    ORA-1D  BIT-3C  AND-3D  EOR-5D  ADC-7D  LDY-BC  LDA-BD  CMP-DD
;    SBC-FD
;  Write 8-bit and 16-bit
;    STZ-9E  STA-9D
;  RMW 8-bit and 16-bit
;    ASL-1E  ROL-3E  LSR-5E  ROR-7E  DEC-DE  INC-FE
;
%macro ADDR_Absolute_Index_X 0
 mov ebx,B_DB_Shifted
 mov bl,[1+R_NativePC]
 mov eax,B_X
 mov bh,[2+R_NativePC]
 add R_NativePC,byte 3
 add ebx,eax
 and ebx,0x00FFFFFF ; Ensure 24-bit address
%endmacro

%macro READ8_Absolute_Index_X 0
 ADDR_Absolute_Index_X
 GET_BYTE
%endmacro

%macro READ16_Absolute_Index_X 0
 ADDR_Absolute_Index_X
 GET_WORD
%endmacro

%macro WRITE8_Absolute_Index_X 1
 ADDR_Absolute_Index_X
 mov al,%1
 SET_BYTE
%endmacro

%macro WRITE16_Absolute_Index_X 1
 ADDR_Absolute_Index_X
 mov eax,%1
 SET_WORD
%endmacro

%macro RMW_Absolute_Index_X 1
 READ %+ M_size %+ _Absolute_Index_X ;_5A22_FAST_CYCLE
;add R_Cycles,_5A22_FAST_CYCLE
 %1
%if M_8bit
 SET_BYTE
%else
 SET_WORD_HL
%endif
%endmacro


; Absolute Index Y (corrupts eax)
;  Read 8-bit and 16-bit
;    ORA-19  AND-39  EOR-59  ADC-79  LDA-B9  LDX-BE  CMP-D9  SBC-F9
;  Write 8-bit and 16-bit
;    STA-99
;
; 3 bytes, 4-6 clocks
;
;       1   1  1   1  1 PBR,PC      Op code     1
;       2   1  1   0  1 PBR,PC+1    AAL         1
;       3   1  1   0  1 PBR,PC+2    AAH         1
;   (if index across page boundary, write, or X=0)
;   (4) 3a  1  1   0  0 DBR,AAH,AAL+YL  IO      1
;       4   1  1   1  0 DBR,AA+Y    Data Low    1/0
;   (if 16-bit data)
;   (1) 4a  1  1   1  0 DBR,AA+Y+1  Data High   1/0
%macro ADDR_Absolute_Index_Y 0
 mov ebx,B_DB_Shifted
 mov bl,[1+R_NativePC]
 mov eax,B_Y
 mov bh,[2+R_NativePC]
 add R_NativePC,byte 3
 add ebx,eax
 and ebx,0x00FFFFFF ; Ensure 24-bit address
%endmacro

%macro READ8_Absolute_Index_Y 0
 ADDR_Absolute_Index_Y
 GET_BYTE
%endmacro

%macro READ16_Absolute_Index_Y 0
 ADDR_Absolute_Index_Y
 GET_WORD
%endmacro

%macro WRITE8_Absolute_Index_Y 1
 ADDR_Absolute_Index_Y
 mov al,%1
 SET_BYTE
%endmacro

%macro WRITE16_Absolute_Index_Y 1
 ADDR_Absolute_Index_Y
 mov eax,%1
 SET_WORD
%endmacro

; Absolute Long Index X (corrupts eax)
;  Read 8-bit and 16-bit
;    ORA-1F  AND-3F  EOR-5F  ADC-7F  LDA-BF  CMP-DF  SBC-FF
;  Write 8-bit and 16-bit
;    STA-9F
;
; 4 bytes, 5-6 clocks
;
;       1   1  1   1  1 PBR,PC      Op Code     1
;       2   1  1   0  1 PBR,PC+1    AAL         1
;       3   1  1   0  1 PBR,PC+7    AAH         1
;       4   1  1   0  1 PBA,PC+3    AAB         1
;       5   1  1   1  0 AAB,AA+X    Data Low    1/0
;   (if 16-bit data)
;   (1) 5a  1  1   1  0 AAB,AA+X+1  Data High   1/0
%macro ADDR_Absolute_Long_Index_X 0
 mov bl,[3+R_NativePC]
 shl ebx,16
 mov bl,[1+R_NativePC]
 mov eax,B_X
 mov bh,[2+R_NativePC]
 add R_NativePC,byte 4
 add ebx,eax
 and ebx,0x00FFFFFF ; Ensure 24-bit address
%endmacro

%macro READ8_Absolute_Long_Index_X 0
 ADDR_Absolute_Long_Index_X
 GET_BYTE
%endmacro

%macro READ16_Absolute_Long_Index_X 0
 ADDR_Absolute_Long_Index_X
 GET_WORD
%endmacro

%macro WRITE8_Absolute_Long_Index_X 1
 ADDR_Absolute_Long_Index_X
 mov al,%1
 SET_BYTE
%endmacro

%macro WRITE16_Absolute_Long_Index_X 1
 ADDR_Absolute_Long_Index_X
 mov eax,%1
 SET_WORD
%endmacro

; Direct Indirect (corrupts eax)
;  Read 8-bit and 16-bit
;    ORA-12  AND-32  EOR-52  ADC-72  LDA-B2  CMP-D2  SBC-F2
;  Write 8-bit and 16-bit
;    STA-92
;  Push address (doesn't use these macros)
;    PEI-D4
;
; 2 bytes, 5-7 cycles
;
;       1   1  1   1  1 PBR,PC      Op Code     1
;       2   1  1   0  1 PBR,PC+1    DO          1
;   (if DL != 0)
;   (2) 2a  1  1   0  0 PBR,PC+1    IO          1
;       3   1  1   1  0 0,D+DO      AAL         1
;       1   1  1   1  0 0,D+DO+1    AAH         1
;       5   1  1   1  0 DBR,AA      Data Low    1/0
;   (if 16-bit data)
;   (1) 5a  1  1   1  0 DBR,AA+1    Data Low    1/0
%macro ADDR_Direct_Indirect 0
 READ16_Direct
 mov ebx,B_DB_Shifted
 mov bx,ax
%endmacro

%macro READ8_Direct_Indirect 0
 ADDR_Direct_Indirect
 GET_BYTE
%endmacro

%macro READ16_Direct_Indirect 0
 ADDR_Direct_Indirect
 GET_WORD
%endmacro

%macro WRITE8_Direct_Indirect 1
 ADDR_Direct_Indirect
 mov al,%1
 SET_BYTE
%endmacro

%macro WRITE16_Direct_Indirect 1
 ADDR_Direct_Indirect
 mov eax,%1
 SET_WORD
%endmacro

; Direct Indirect Long (corrupts eax)
;  Read 8-bit and 16-bit
;    ORA-07  AND-27  EOR-47  ADC-67  LDA-A7  CMP-C7  SBC-E7
;  Write 8-bit and 16-bit
;    STA-87
;
; 2 bytes, 6-8 cycles
;
;       1   1  1   1  1 PBR,PC      Op Code     1
;       2   1  1   0  1 PBR,PC+1    DO          1
;   (if DL != 0)
;   (2) 2a  1  1   0  0 PBR,PC+1    IO          1
;       3   1  1   1  0 0,D+DO      AAL         1
;       4   1  1   1  0 0,D+DO+1    AAH         1
;       5   1  1   1  0 0,D+DO+2    AAB         1
;       6   1  1   1  0 AAB,AA      Data Low    1/0
;   (if 16-bit data)
;   (1) 6a  1  1   1  0 AAB,AA+1    Data High   1/0
; if present, argument specifies index
%macro ADDR_Direct_Indirect_Long 0-1 0
 READ24_Direct
%ifnidni %1,0           ;helper: index
 mov ebx,0xFFFFFF       ;clip for indexing
 add eax,%1
 and ebx,eax
%else
 mov ebx,eax
%endif
%endmacro

%macro READ8_Direct_Indirect_Long 0
 ADDR_Direct_Indirect_Long
 GET_BYTE
%endmacro

%macro READ16_Direct_Indirect_Long 0
 ADDR_Direct_Indirect_Long
 GET_WORD
%endmacro

%macro WRITE8_Direct_Indirect_Long 1
 ADDR_Direct_Indirect_Long
 mov al,%1
 SET_BYTE
%endmacro

%macro WRITE16_Direct_Indirect_Long 1
 ADDR_Direct_Indirect_Long
 mov eax,%1
 SET_WORD
%endmacro

; Stack Relative (corrupts eax)
;  Read 8-bit and 16-bit
;    ORA-03  AND-23  EOR-43  ADC-63  LDA-A3  CMP-C3  SBC-E3
;  Write 8-bit and 16-bit
;    STA-83
;
; 2 bytes, 4-5 cycles
;
;       1   1  1   1  1 PBR,PC      Op Code     1
;       2   1  1   0  1 PBR,PC+1    SO          1
;       3   1  1   0  0 PBR,PC+1    IO          1
;       4   1  1   1  0 0,S+SO      Data Low    1/0
;   (if 16-bit data)
;   (1) 4a  1  1   1  0 0,S+SO+1    Data High   1/0
%macro ADDR_Stack_Relative 0
 READ8_Immediate
 mov ebx,B_S    ; Add stack pointer to make address
 add ebx,eax
 and ebx,0x0000FFFF
%endmacro

%macro READ8_Stack_Relative 0
 ADDR_Stack_Relative
 GET_BYTE
%endmacro

%macro READ16_Stack_Relative 0
 ADDR_Stack_Relative
 GET_WORD
%endmacro

%macro WRITE8_Stack_Relative 1
 ADDR_Stack_Relative
 mov al,%1
 SET_BYTE
%endmacro

%macro WRITE16_Stack_Relative 1
 ADDR_Stack_Relative
 mov eax,%1
 SET_WORD
%endmacro

; Stack Relative Indirect Indexed (corrupts eax)
;  Read 8-bit and 16-bit
;    ORA-13  AND-33  EOR-53  ADC-73  LDA-B3  CMP-D3  SBC-F3
;  Write 8-bit and 16-bit
;    STA-93
;
; 2 bytes, 7-8 cycles
;
;       1   1  1   1  1 PBR,PC      Op Code     1
;       2   1  1   0  1 PBR,PC+1    SO          1
;       3   1  1   0  0 PBR,PC+1    IO          1
;       4   1  1   1  0 0,S+SO      AAL         1
;       5   1  1   1  0 0,S+SO+1    AAH         1
;       6   1  1   0  0 0,S+SO+1    IO          1
;       7   1  1   1  0 DBR,AA+Y    Data Low    1/0
;   (if 16-bit data)
;   (1) 7a  1  1   1  0 DBR,AA+Y+1  Data High   1/0
%macro ADDR_Stack_Relative_Indirect_Indexed 0
 ADDR_Stack_Relative
 mov eax,B_DB_Shifted
 GET_WORD
 mov ebx,B_Y
 add ebx,eax
 and ebx,0x00FFFFFF ; Ensure 24-bit address
%endmacro

%macro READ8_Stack_Relative_Indirect_Indexed 0
 ADDR_Stack_Relative_Indirect_Indexed
 GET_BYTE
%endmacro

%macro READ16_Stack_Relative_Indirect_Indexed 0
 ADDR_Stack_Relative_Indirect_Indexed
 GET_WORD
%endmacro

%macro WRITE8_Stack_Relative_Indirect_Indexed 1
 ADDR_Stack_Relative_Indirect_Indexed
 mov al,%1
 SET_BYTE
%endmacro

%macro WRITE16_Stack_Relative_Indirect_Indexed 1
 ADDR_Stack_Relative_Indirect_Indexed
 mov eax,%1
 SET_WORD
%endmacro

; Absolute Indexed Indirect (corrupts eax)
; Returns new PC in %ax
;  Address = (PB:X+a16)
;  Address set to PC
;    JMP-7C
;
; 3 bytes, 6 cycles
;
;       1   1  1   1  1 PBR,PC      Op Code     1
;       2   1  1   0  1 PBR,PC+1    AAL         1
;       3   1  1   0  1 PBR,PC+2    AAH         1
;       4   1  1   0  0 PBR,PC+2    IO          1
;       5   1  1   0  1 PBR,AA+X    NEW PCL     1
;       6   1  1   0  1 PBR,AA+X+1  NEW PCH     1
;       1   1  1   1  1 PBR,NEWPC   New Op Code 1
;
;    JSR-FC
;
; 3 bytes, 8 cycles
;
;       1   1  1   1  1 PBR,PC      Op Code     1
;       2   1  1   0  1 PBR,PC+1    AAL         1
;       3   1  1   1  0 0,S         PCH         0
;       4   1  1   1  0 0,S-1       PCL         0
;       5   1  1   0  1 PBR,PC+2    AAH         1
;       6   1  1   0  0 PBR,PC+2    IO          1
;       7   1  1   0  1 PBR,AA+X    NEW PCL     1
;       8   1  1   0  1 PBR,AA+X+1  NEW PCH     1
;       1   1  1   1  1 PBR,NEWPC   New Op Code 1
%macro ADDR_Absolute_Indexed_Indirect 0
 mov ebx,B_PB_Shifted
 mov bl,[1+R_NativePC]
 mov bh,[2+R_NativePC]
 mov eax,B_X
 add bx,ax
 GET_WORD
%endmacro

; Absolute (corrupts eax)
;  Address = a16
;  Address set to PC
;    JSR-20
;
; 3 bytes, 6 cycles
;
;       1   1  1   1  1 PBR,PC      Op Code     1
;       2   1  1   0  1 PBA,PC+1    NEW FCC     1
;       3   1  1   0  1 PBR,PC+2    NEW PCH     1
;       4   1  1   0  0 PBR,PC+2    IO          1
;       5   1  1   1  0 0,S         PCH         0
;       6   1  1   1  0 0,S-1       PCL         0
;       1   1  1   1  1 PBA,NEWPC   New Op Code 1
;
;    JMP-4C
;
; 3 bytes, 3 cycles
;
;       1   1  1   1  1 PBR,PC      Op Code     1
;       2   1  1   0  1 PBR,PC+1    NEW PCL     1
;       3   1  1   0  1 PBR,PC+2    NEW PCH     1
;       1   1  1   1  1 PBR,NEWPC   New Op Code 1
%macro ADDR_Absolute_JMP 0
 mov al,[1+R_NativePC]
 mov ah,[2+R_NativePC]
%endmacro
