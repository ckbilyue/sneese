%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2004 Charles Bilyue'.
Portions Copyright (c) 2003-2004 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

%endif

;%define TRAP_INVALID_JUMP
;Each opcode is followed by one or more codes which signify
; how it works with the status flags in the Processor status (P) register
; T(x) tests flags M(x) modifies flags R(x) resets flags S(x) sets flags
; flags: ENVMXDIZC
; 65c816 opcodes 0x00-0x0F:
;    00: BRK s       2,8 T(ENVMXDIZC) R(D) S(I)
;    01: ORA (d,x)   2,6 T(EM) M(NZ)
;    02: COP s       2,8 T(ENVMXDIZC) R(D) S(I)
;    03: ORA d,s     2,4 T(M) M(NZ)
;    04: TSB d       2,5 T(EM) M(Z)
;    05: ORA d       2,3 T(EM) M(NZ)
;    06: ASL d       2,5 T(EM) M(NZC)
;    07: ORA [d]     2,6 T(EM) M(NZ)
;    08: PHP s       1,3 T(ENVMXDIZC)
;    09: ORA #       2,2 T(M) M(NZ)
;    0A: ASL A       1,2 T(M) M(NZC)
;    0B: PHD s       1,4 T(E)
;    0C: TSB a       3,6 T(M) M(Z)
;    0D: ORA a       3,4 T(M) M(NZ)
;    0E: ASL a       3,6 T(M) M(NZC)
;    0F: ORA al      4,5 T(M) M(NZ)
;
; 65c816 opcodes 0x10-0x1F:
;    10: BPL r       2,2 T(EN)
;    11: ORA (d),y   2,5 T(EMX) M(NZ)
;    12: ORA (d)     2,5 T(EM) M(NZ)
;    13: ORA (d,s),y 2,7 T(M) M(NZ)
;    14: TRB d       2,5 T(EM) M(Z)
;    15: ORA d,x     2,4 T(EM) M(NZ)
;    16: ASL d,x     2,6 T(EM) M(NZC)
;    17: ORA [d],y   2,6 T(EM) M(NZ)
;    18: CLC i       1,2 R(C)
;    19: ORA a,y     3,4 T(MX) M(NZ)
;    1A: INC A       1,2 T(M) M(NZ)
;    1B: TCS i       1,2 T(E)
;    1C: TRB a       3,6 T(M) M(Z)
;    1D: ORA a,x     3,4 T(MX) M(NZ)
;    1E: ASL a,x     3,7 T(M) M(NZC)
;    1F: ORA al,x    4,5 T(M) M(NZ)
;
; 65c816 opcodes 0x20-0x2F:
;    20: JSR a       3,6 T(E)
;    21: AND (d,x)   2,6 T(EM)
;    22: JSL al      4,8 T(E)
;    23: AND d,s     2,4 T(M) M(NZ)
;    24: BIT d       2,3 T(EM) M(NVZ)
;    25: AND d       2,3 T(EM) M(NZ)
;    26: ROL d       2,5 T(EMC) M(NZC)
;    27: AND [d]     2,6 T(EM) M(NZ)
;    28: PLP s       1,4 T(E) M(NVMXDIZC)
;    29: AND #       2,2 T(M) M(NZ)
;    2A: ROL A       1,2 T(MC) M(NZC)
;    2B: PLD s       1,5 T(E) M(NZ)
;    2C: BIT a       3,4 T(M) M(NVZ)
;    2D: AND a       3,4 T(M) M(NZ)
;    2E: ROL a       3,6 T(MC) M(NZC)
;    2F: AND al      4,5 T(M) M(NZ)
;
; 65c816 opcodes 0x30-0x3F:
;    30: BMI r       2,2 T(EN)
;    31: AND (d),y   2,5 T(EMX) M(NZ)
;    32: AND (d)     2,5 T(EM) M(NZ)
;    33: AND (d,s),y 2,7 T(M) M(NZ)
;    34: BIT d,x     2,4 T(EM) M(NVZ)
;    35: AND d,x     2,4 T(EM) M(NZ)
;    36: ROL d,x     2,6 T(EMC) M(NZC)
;    37: AND [d],y   2,6 T(EM) M(NZ)
;    38: SEC i       1,2 S(C)
;    39: AND a,y     3,4 T(MX) M(NZ)
;    3A: DEC A       1,2 T(M) M(NZ)
;    3B: TSC i       1,2 M(NZ)
;    3C: BIT a,x     3,4 T(MX) M(NVZ)
;    3D: AND a,x     3,4 T(MX) M(NZ)
;    3E: ROL a,x     3,7 T(MC) M(NZC)
;    3F: AND al,x    4,5 T(M) M(NZ)
;
; 65c816 opcodes 0x40-0x4F:
;    40: RTI s       1,7 T(E) M(NVMXDIZC)
;    41: EOR (d,x)   2,6 T(EM) M(NZ)
;    42: WDM         2,2
;    43: EOR d,s     2,4 T(M) M(NZ)
;    44: MVP xya     3,7 T(X)
;    45: EOR d       2,3 T(EM) M(NZ)
;    46: LSR d       2,5 T(EM) M(NZC)
;    47: EOR [d]     2,6 T(EM) M(NZ)
;    48: PHA s       1,3 T(EM)
;    49: EOR #       2,2 T(M) M(NZ)
;    4A: LSR A       1,2 T(M) M(NZC)
;    4B: PHK s       1,3 T(E)
;    4C: JMP a       3,3
;    4D: EOR a       3,4 T(M) M(NZ)
;    4E: LSR a       3,6 T(M) M(NZC)
;    4F: EOR al      4,5 T(M) M(NZ)
;
; 65c816 opcodes 0x50-0x5F:
;    50: BVC r       2,2 T(EV)
;    51: EOR (d),y   2,5 T(EMX) M(NZ)
;    52: EOR (d)     2,5 T(EM) M(NZ)
;    53: EOR (d,s),y 2,7 T(M) M(NZ)
;    54: MVN xya     3,7 T(X)
;    55: EOR d,x     2,4 T(EM) M(NZ)
;    56: LSR d,x     2,6 T(EM) M(NZC)
;    57: EOR [d],y   2,6 T(EM) M(NZ)
;    58: CLI i       1,2 R(I)
;    59: EOR a,y     3,4 T(MX) M(NZ)
;    5A: PHY s       1,2 T(EX)
;    5B: TCD i       1,2 M(NZ)
;    5C: JML al      4,4
;    5D: EOR a,x     3,4 T(MX) M(NZ)
;    5E: LSR a,x     3,7 T(M) M(NZC)
;    5F: EOR al,x    4,5 T(M) M(NZ)
;
; 65c816 opcodes 0x60-0x6F:
;    60: RTS s       1,6 T(E)
;    61: ADC (d,x)   2,6 T(EMDC) M(NVZC)
;    62: PER s       3,6 T(E)
;    63: ADC d,s     2,4 T(MDC) M(NVZC)
;    64: STZ d       2,3 T(EM)
;    65: ADC d       2,3 T(EMDC) M(NVZC)
;    66: ROR d       2,5 T(EMC) M(NZC)
;    67: ADC [d]     2,6 T(EMDC) M(NVZC)
;    68: PLA s       1,4 T(EM) M(NZ)
;    69: ADC #       2,2 T(MDC) M(NVZC)
;    6A: ROR A       1,2 T(MC) M(NZC)
;    6B: RTL s       1,6 T(E)
;    6C: JMP (a)     3,5
;    6D: ADC a       3,4 T(MDC) M(NVZC)
;    6E: ROR a       3,6 T(MC) M(NZC)
;    6F: ADC al      4,5 T(MDC) M(NVZC)
;
; 65c816 opcodes 0x70-0x7F:
;    70: BVS r       2,2 T(EV)
;    71: ADC (d),y   2,5 T(EMXDC) M(NVZC)
;    72: ADC (d)     2,5 T(EMDC) M(NVZC)
;    73: ADC (d,s),y 2,7 T(MDC) M(NVZC)
;    74: STZ d,x     2,4 T(EM)
;    75: ADC d,x     2,4 T(EMDC) M(NVZC)
;    76: ROR d,x     2,6 T(EMC) M(NZC)
;    77: ADC [d],y   2,6 T(EMDC) M(NVZC)
;    78: SEI i       1,2 S(I)
;    79: ADC a,y     3,4 T(MXDC) M(NVZC)
;    7A: PLY s       1,4 T(EX) M(NZ)
;    7B: TDC i       1,2 M(NZ)
;    7C: JMP (a,x)   3,6
;    7D: ADC a,x     3,4 T(MXDC) M(NVZC)
;    7E: ROR a,x     3,7 T(MC) M(NZC)
;    7F: ADC al,x    4,5 T(MDC) M(NVZC)
;
; 65c816 opcodes 0x80-0x8F:
;    80: BRA r       2,2 T(E)
;    81: STA (d,x)   2,6 T(EM)
;    82: BRL rl      3,3
;    83: STA d,s     2,4 T(M)
;    84: STY d       2,3 T(EX)
;    85: STA d       2,3 T(EM)
;    86: STX d       2,3 T(EX)
;    87: STA [d]     2,6 T(EM)
;    88: DEY i       1,2 T(X) M(NZ)
;    89: BIT #       2,2 T(M) M(Z)
;    8A: TXA i       1,2 T(M) M(NZ)
;    8B: PHB s       1,3 T(E)
;    8C: STY a       3,4 T(X)
;    8D: STA a       3,4 T(M)
;    8E: STX a       3,4 T(X)
;    8F: STA al      4,5 T(M)
;
; 65c816 opcodes 0x90-0x9F:
;    90: BCC r       2,2 T(EC)
;    91: STA (d),y   2,6 T(EMX)
;    92: STA (d)     2,5 T(EM)
;    93: STA (d,s),y 2,7 T(M)
;    94: STY d,x     2,4 T(EX)
;    95: STA d,x     2,4 T(EM)
;    96: STX d,y     2,4 T(EX)
;    97: STA [d],y   2,6 T(EM)
;    98: TYA i       1,2 T(M) M(NZ)
;    99: STA a,y     3,5 T(M)
;    9A: TXS i       1,2 T(E)
;    9B: TXY i       1,2 T(X) M(NZ)
;    9C: STZ a       3,4 T(M)
;    9D: STA a,x     3,5 T(M)
;    9E: STZ a,x     3,5 T(M)
;    9F: STA al,x    4,5 T(M)
;
; 65c816 opcodes 0xA0-0xAF:
;    A0: LDY #       2,2 T(X) M(NZ)
;    A1: LDA (d,x)   2,6 T(EM) M(NZ)
;    A2: LDX #       2,2 T(X) M(NZ)
;    A3: LDA d,s     2,4 T(M) M(NZ)
;    A4: LDY d       2,3 T(EX) M(NZ)
;    A5: LDA d       2,3 T(EM) M(NZ)
;    A6: LDX d       2,3 T(EX) M(NZ)
;    A7: LDA [d]     2,6 T(EM) M(NZ)
;    A8: TAY i       1,2 T(X) M(NZ)
;    A9: LDA #       2,2 T(M) M(NZ)
;    AA: TAX i       1,2 T(X) M(NZ)
;    AB: PLB s       1,4 T(E) M(NZ)
;    AC: LDY a       3,4 T(X) M(NZ)
;    AD: LDA a       3,4 T(M) M(NZ)
;    AE: LDX a       3,4 T(X) M(NZ)
;    AF: LDA al      4,5 T(M) M(NZ)
;
; 65c816 opcodes 0xB0-0xBF:
;    B0: BCS r       2,2 T(EC)
;    B1: LDA (d),y   2,5 T(EMX) M(NZ)
;    B2: LDA (d)     2,5 T(EM) M(NZ)
;    B3: LDA (d,s),y 2,7 T(M) M(NZ)
;    B4: LDY d,x     2,4 T(EX) M(NZ)
;    B5: LDA d,x     2,4 T(EM) M(NZ)
;    B6: LDX d,y     2,4 T(EX) M(NZ)
;    B7: LDA [d],y   2,6 T(EM) M(NZ)
;    B8: CLV i       1,2 R(V)
;    B9: LDA a,y     3,4 T(MX) M(NZ)
;    BA: TSX i       1,2 T(X) M(NZ)
;    BB: TYX i       1,2 T(X) M(NZ)
;    BC: LDY a,x     3,4 T(X) M(NZ)
;    BD: LDA a,x     3,4 T(MX) M(NZ)
;    BE: LDX a,y     3,4 T(X) M(NZ)
;    BF: LDA al,x    4,5 T(M) M(NZ)
;
; 65c816 opcodes 0xC0-0xCF:
;    C0: CPY #       2,2 T(X) M(NZC)
;    C1: CMP (d,x)   2,6 T(EM) M(NZC)
;    C2: REP #       2,3 T(E) M(NVMXDIZC)
;    C3: CMP d,s     2,4 T(M) M(NZC)
;    C4: CPY d       2,3 T(EX) M(NZC)
;    C5: CMP d       2,3 T(EM) M(NZC)
;    C6: DEC d       2,5 T(EM) M(NZ)
;    C7: CMP [d]     2,6 T(EM) M(NZC)
;    C8: INY i       1,2 T(X) M(NZ)
;    C9: CMP #       2,2 T(M) M(NZC)
;    CA: DEX i       1,2 T(X) M(NZ)
;    CB: WAI i       1,3
;    CC: CPY a       3,4 T(X) M(NZC)
;    CD: CMP a       3,4 T(M) M(NZC)
;    CE: DEC a       3,6 T(M) M(NZ)
;    CF: CMP al      4,5 T(M) M(NZC)
;
; 65c816 opcodes 0xD0-0xDF:
;    D0: BNE r       2,2 T(EZ)
;    D1: CMP (d),y   2,5 T(EMX) M(NZC)
;    D2: CMP (d)     2,5 T(EM) M(NZC)
;    D3: CMP (d,s),y 2,7 T(M) M(NZC)
;    D4: PEI s       2,6 T(E)
;    D5: CMP d,x     2,4 T(EM) M(NZC)
;    D6: DEC d,x     2,6 T(EM) M(NZ)
;    D7: CMP [d],y   2,6 T(EM) M(NZC)
;    D8: CLD i       1,2 R(D)
;    D9: CMP a,y     3,4 T(MX) M(NZC)
;    DA: PHX s       1,3 T(EX)
;    DB: STP i       1,3
;    DC: JML (a)     3,6
;    DD: CMP a,x     3,4 T(MX) M(NZC)
;    DE: DEC a,x     3,7 T(M) M(NZ)
;    DF: CMP al,x    4,5 T(M) M(NZC)
;
; 65c816 opcodes 0xE0-0xEF:
;    E0: CPX #       2,2 T(X) M(NZC)
;    E1: SBC (d,x)   2,6 T(EMDC) M(NVZC)
;    E2: SEP #       2,3 T(E) M(NVMXDIZC)
;    E3: SBC d,s     2,4 T(MDC) M(NVZC)
;    E4: CPX d       2,3 T(EX) M(NZC)
;    E5: SBC d       2,3 T(EMDC) M(NVZC)
;    E6: INC d       2,5 T(EM) M(NZ)
;    E7: SBC [d]     2,6 T(EMDC) M(NVZC)
;    E8: INX i       1,2 T(X) M(NZ)
;    E9: SBC #       2,2 T(MDC) M(NVZC)
;    EA: NOP i       1,2
;    EB: XBA i       1,3 M(NZ)
;    EC: CPX a       3,4 T(X) M(NZC)
;    ED: SBC a       3,4 T(MDC) M(NVZC)
;    EE: INC a       3,6 T(M) M(NZ)
;    EF: SBC al      4,5 T(MDC) M(NVZC)
;
; 65c816 opcodes 0xF0-0xFF:
;    F0: BEQ r       2,2 T(EZ)
;    F1: SBC (d),y   2,5 T(EMXDC) M(NVZC)
;    F2: SBC (d)     2,5 T(EMDC) M(NVZC)
;    F3: SBC (d,s),y 2,7 T(MDC) M(NVZC)
;    F4: PEA s       3,5 T(E)
;    F5: SBC d,x     2,4 T(EMDC) M(NVZC)
;    F6: INC d,x     2,6 T(EM) M(NZ)
;    F7: SBC [d],y   2,6 T(EMDC) M(NVZC)
;    F8: SED i       1,2 S(D)
;    F9: SBC a,y     3,4 T(MXDC) M(NVZC)
;    FA: PLX s       1,4 T(EX) M(NZ)
;    FB: XCE i       1,2 T(EC) M(EC)
;    FC: JSR (a,x)   3,6 T(E)
;    FD: SBC a,x     3,4 T(MXDC) M(NVZC)
;    FE: INC a,x     3,7 T(M) M(NZ)
;    FF: SBC al,x    4,5 T(MDC) M(NVZC)
;

;%1 = vector, %2 = offset
%macro NativeInterrupt 2
 mov al,B_PB
 E0_PUSH_B
 GET_PC eax
 add eax,byte 2
 E0_PUSH_W
 E0_SETUPFLAGS          ; Put flags into true 65c816 format
 E0_PUSH_B

 mov R_NativePC,%1      ; PC = Native mode vector
 mov eax,%2
 mov B_PB,byte 0        ; Setup bank
 mov B_PBOffset,eax     ; Offset of bank 0 ROM
 STORE_FLAGS_I 1        ; Disable IRQs
 add R_NativePC,eax
%ifndef NO_FASTROM
 mov [C_LABEL(CycleTable)],byte 4   ; SlowROM bank
%endif
 STORE_FLAGS_D 0        ; Disable decimal mode
 OPCODE_EPILOG
%endmacro

;%1 = vector, %2 = offset
%macro Emu6502Interrupt 2
 GET_PC eax
 add eax,byte 2
 E1_PUSH_W
 E1_SETUPFLAGS          ; Put flags into true 65c816 format
 E1_PUSH_B

 mov R_NativePC,%1      ; PC = Native mode vector
 mov eax,%2

;7.12.2 In the Emulation mode, the PBR and DBR registers are cleared to 00
;when a hardware interrupt, BRK or COP is executed. In this case, previous
;contents of the PBR are not automatically saved.
 mov B_DB,byte 0

 mov B_PB,byte 0        ; Setup bank
 mov B_PBOffset,eax     ; Offset of bank 0 ROM
 STORE_FLAGS_I 1        ; Disable IRQs
 add R_NativePC,eax
%ifndef NO_FASTROM
 mov [C_LABEL(CycleTable)],byte 4   ; SlowROM bank
%endif
 STORE_FLAGS_D 0        ; Disable decimal mode
 OPCODE_EPILOG
%endmacro

; 00

ALIGNC
EXPORT_C E0_BRK
 NativeInterrupt B_BRK_Nvector,B_BRK_Noffset

ALIGNC
EXPORT_C E1_BRK
 Emu6502Interrupt B_IRQ_Evector,B_IRQ_Eoffset

; 01
EM_ORA Od_xO,Direct_Indexed_Indirect
E0_ORA Od_xO,Direct_Indexed_Indirect

; 02

ALIGNC
EXPORT_C E0_COP
 NativeInterrupt B_COP_Nvector,B_COP_Noffset

ALIGNC
EXPORT_C E1_COP
 Emu6502Interrupt B_COP_Evector,B_COP_Eoffset

; 03
EM_ORA d_s,Stack_Relative
E0_ORA d_s,Stack_Relative

; 04
EM_TSB d,Direct
E0_TSB d,Direct

; 05
EM_ORA d,Direct
E0_ORA d,Direct

; 06
EM_ASL d,Direct
E0_ASL d,Direct

; 07
EM_ORA IdI,Direct_Indirect_Long
E0_ORA IdI,Direct_Indirect_Long

; 08

ALIGNC
EXPORT_C E0_PHP
 inc R_NativePC
 E0_SETUPFLAGS
 E0_PUSH_B
 OPCODE_EPILOG
ALIGNC
EXPORT_C E1_PHP
 inc R_NativePC
 E1_SETUPFLAGS
 E1_PUSH_B
 OPCODE_EPILOG

; 09
EM_ORA i,Immediate
E0_ORA i,Immediate

; 0A

ALIGNC
EXPORT_C EM_SLA
 inc R_NativePC
 mov al,B_A
 add al,al
 sbb cl,cl
 mov B_A,al
 STORE_FLAGS_NZC al,cl
 OPCODE_EPILOG
ALIGNC
EXPORT_C E0_SLA
 inc R_NativePC
 mov eax,B_A
 add ax,ax
 sbb cl,cl
 STORE_FLAGS_N ah
 mov B_A,eax
 or al,ah
 STORE_FLAGS_C cl
 STORE_FLAGS_Z al
 OPCODE_EPILOG

; 0B
E0_PUSH16 B_D,E0_PHD,New
E1_PUSH16 B_D,E1_PHD,New

; 0C
EM_TSB a,Absolute
E0_TSB a,Absolute

; 0D
EM_ORA a,Absolute
E0_ORA a,Absolute

; 0E
EM_ASL a,Absolute
E0_ASL a,Absolute

; 0F
EM_ORA al,Absolute_Long
E0_ORA al,Absolute_Long

; 10
BFC BPL,SNES_FLAG_N

; 11
EM_ORA OdO_y,Direct_Indirect_Indexed
E0_ORA OdO_y,Direct_Indirect_Indexed

; 12
EM_ORA OdO,Direct_Indirect
E0_ORA OdO,Direct_Indirect

; 13
EM_ORA Od_sO_y,Stack_Relative_Indirect_Indexed
E0_ORA Od_sO_y,Stack_Relative_Indirect_Indexed

; 14
EM_TRB d,Direct
E0_TRB d,Direct

; 15
EM_ORA d_x,Direct_Index_X
E0_ORA d_x,Direct_Index_X

; 16
EM_ASL d_x,Direct_Index_X
E0_ASL d_x,Direct_Index_X

; 17
EM_ORA IdI_y,Direct_Indirect_Indexed_Long
E0_ORA IdI_y,Direct_Indirect_Indexed_Long

; 18
_CLx C,ALL_CLC          ; Clear Carry flag

; 19
EM_ORA a_y,Absolute_Index_Y
E0_ORA a_y,Absolute_Index_Y

; 1A

ALIGNC
EXPORT_C EM_INA
 mov al,B_A
 inc R_NativePC
 inc al
 mov B_A,al
 STORE_FLAGS_NZ al
 OPCODE_EPILOG
ALIGNC
EXPORT_C E0_INA
 mov eax,B_A
 inc R_NativePC
 inc eax
 mov B_A,ax
 STORE_FLAGS_N ah
 or al,ah
 STORE_FLAGS_Z al
 OPCODE_EPILOG

; 1B
_TxS B_A,16,E0_TCS
_TxS B_A,8,E1_TCS

; 1C
EM_TRB a,Absolute
E0_TRB a,Absolute

; 1D
EM_ORA a_x,Absolute_Index_X
E0_ORA a_x,Absolute_Index_X

; 1E
EM_ASL a_x,Absolute_Index_X
E0_ASL a_x,Absolute_Index_X

; 1F
EM_ORA al_x,Absolute_Long_Index_X
E0_ORA al_x,Absolute_Long_Index_X

; 20

ALIGNC
EXPORT_C E0_JSR_a
 GET_PC eax
%ifdef TRAP_INVALID_JUMP
 mov [C_LABEL(Map_Byte)],eax
%endif
 add eax,byte 2      ; last instruction byte PC in ax
 E0_PUSH_W           ; Address of last byte not next instruction (huh!)
 ADDR_Absolute_JMP

 mov ebx,B_PB_Shifted
 mov R_NativePC,eax
 or eax,ebx

 shr eax,13
 mov eax,[C_LABEL(Read_Bank8Offset)+eax*4]
 test eax,eax
 jz .read_non_linear

 add eax,ebx
.read_direct:

 add R_NativePC,eax
 mov B_PBOffset,eax

 OPCODE_EPILOG

.read_non_linear:
%ifdef TRAP_INVALID_JUMP
 mov byte [C_LABEL(Map_Byte)+3],0x20
 mov [C_LABEL(Map_Address)],ebx
 jmp _InvalidJump
%else
 mov eax,C_LABEL(Blank)
 jmp short .read_direct
%endif

ALIGNC
EXPORT_C E1_JSR_a
 GET_PC eax
%ifdef TRAP_INVALID_JUMP
 mov [C_LABEL(Map_Byte)],eax
%endif
 add eax,byte 2      ; last instruction byte PC in ax
 E1_PUSH_W           ; Address of last byte not next instruction (huh!)
 ADDR_Absolute_JMP

 mov ebx,B_PB_Shifted
 mov R_NativePC,eax
 or eax,ebx

 shr eax,13
 mov eax,[C_LABEL(Read_Bank8Offset)+eax*4]
 test eax,eax
 jz .read_non_linear

 add eax,ebx
.read_direct:

 add R_NativePC,eax
 mov B_PBOffset,eax

 OPCODE_EPILOG

.read_non_linear:
%ifdef TRAP_INVALID_JUMP
 mov byte [C_LABEL(Map_Byte)+3],0x20
 mov [C_LABEL(Map_Address)],ebx
 jmp _InvalidJump
%else
 mov eax,C_LABEL(Blank)
 jmp short .read_direct
%endif

; 21
EM_AND Od_xO,Direct_Indexed_Indirect
E0_AND Od_xO,Direct_Indexed_Indirect

; 22

ALIGNC
EXPORT_C E0_JSL_al      ; JSR Absolute long address
 mov al,B_PB
 E0_PUSH_B              ; Push PB
 GET_PC eax
%ifdef TRAP_INVALID_JUMP
 mov [C_LABEL(Map_Byte)],eax
%endif
 add eax,byte 3         ; Address of last byte of instruction
 E0_PUSH_W              ; Push PC

 mov al,[1+R_NativePC]
 xor ebx,ebx
 mov ah,[2+R_NativePC]
 mov bl,[3+R_NativePC]
 mov B_PB,bl
 mov R_NativePC,eax
 test [MEMSEL],bl       ; Check bus speed against PB
 mov al,[C_LABEL(FastROM_offset)]
 jnz .fastrom
 mov al,4
.fastrom:
%ifndef NO_FASTROM
 mov [C_LABEL(CycleTable)],al   ; Update bus speed
%endif
 mov edx,R_NativePC
 shl ebx,16
 add edx,ebx

 shr edx,13
 mov edx,[C_LABEL(Read_Bank8Offset)+edx*4]
 test edx,edx
 jz .read_non_linear

 add edx,ebx
.read_direct:

 add R_NativePC,edx
 mov B_PBOffset,edx

 OPCODE_EPILOG

.read_non_linear:
%ifdef TRAP_INVALID_JUMP
 mov byte [C_LABEL(Map_Byte)+3],0x22
 mov [C_LABEL(Map_Address)],ebx
 jmp _InvalidJump
%else
 mov edx,C_LABEL(Blank)
 jmp short .read_direct
%endif

ALIGNC
EXPORT_C E1_JSL_al
 mov al,B_PB
 E1_PUSH_B           ; Push PB
 GET_PC eax
%ifdef TRAP_INVALID_JUMP
 mov [C_LABEL(Map_Byte)],eax
%endif
 add eax,byte 3         ; Address of last byte of instruction
 E1_PUSH_W              ; Push PC

 mov al,[1+R_NativePC]
 xor ebx,ebx
 mov ah,[2+R_NativePC]
 mov bl,[3+R_NativePC]
 mov B_PB,bl
 mov R_NativePC,eax
 test [MEMSEL],bl       ; Check bus speed against PB
 mov al,[C_LABEL(FastROM_offset)]
 jnz .fastrom
 mov al,4
.fastrom:
%ifndef NO_FASTROM
 mov [C_LABEL(CycleTable)],al   ; Update bus speed
%endif
 mov edx,R_NativePC
 shl ebx,16
 add edx,ebx

 shr edx,13
 mov edx,[C_LABEL(Read_Bank8Offset)+edx*4]
 test edx,edx
 jz .read_non_linear

 add edx,ebx
.read_direct:

 add R_NativePC,edx
 mov B_PBOffset,edx

 OPCODE_EPILOG

.read_non_linear:
%ifdef TRAP_INVALID_JUMP
 mov byte [C_LABEL(Map_Byte)+3],0x22
 mov [C_LABEL(Map_Address)],ebx
 jmp _InvalidJump
%else
 mov edx,C_LABEL(Blank)
 jmp short .read_direct
%endif

; 23
EM_AND d_s,Stack_Relative
E0_AND d_s,Stack_Relative

; 24
EM_BIT d,Direct
E0_BIT d,Direct

; 25
EM_AND d,Direct
E0_AND d,Direct

; 26
EM_ROL d,Direct
E0_ROL d,Direct

; 27
EM_AND IdI,Direct_Indirect_Long
E0_AND IdI,Direct_Indirect_Long

; 28

ALIGNC
EXPORT_C E0_PLP
 inc R_NativePC
 E0_PULL_B
 mov bl,B_I_flag
 E0_RESTOREFLAGS

 test bl,bl
 jz .no_irq_enable
 JUMP_FLAG SNES_FLAG_I,.no_irq_enable
 mov al,CEM_Instruction_After_IRQ_Enable
 mov [CPU_Execution_Mode],al
 xor edx,edx
 SAVE_CYCLES
 mov [C_LABEL(EventTrip)],edx
 mov edx,Enabling_IRQ_Event
 LOAD_CYCLES
 mov [Event_Handler],edx

.no_irq_enable:
 SET_TABLE_MX
ALIGNC
EXPORT_C E1_PLP
 inc R_NativePC
 E1_PULL_B
 mov bl,B_I_flag
 E1_RESTOREFLAGS

 test bl,bl
 jz .no_irq_enable
 JUMP_FLAG SNES_FLAG_I,C_LABEL(CPU_RETURN),near
 mov al,CEM_Instruction_After_IRQ_Enable
 mov [CPU_Execution_Mode],al
 xor edx,edx
 SAVE_CYCLES
 mov [C_LABEL(EventTrip)],edx
 mov edx,Enabling_IRQ_Event
 LOAD_CYCLES
 mov [Event_Handler],edx

.no_irq_enable:
 OPCODE_EPILOG

; 29
EM_AND i,Immediate
E0_AND i,Immediate

; 2A

ALIGNC
EXPORT_C EM_RLA
 mov cl,B_C_flag
 mov al,B_A
 inc R_NativePC
 add cl,255 ;MAKE_CARRY
 adc al,al
 sbb cl,cl
 mov B_A,al
 STORE_FLAGS_NZC al,cl
 OPCODE_EPILOG

ALIGNC
EXPORT_C E0_RLA
 mov cl,B_C_flag
 mov eax,B_A
 inc R_NativePC
 add cl,255 ;MAKE_CARRY
 adc ax,ax
 sbb cl,cl
 STORE_FLAGS_N ah
 mov B_A,eax
 or al,ah
 STORE_FLAGS_C cl
 STORE_FLAGS_Z al
 OPCODE_EPILOG

; 2B
E0_PULL16 B_D,E0_PLD
E1_PULL16 B_D,E1_PLD

; 2C
EM_BIT a,Absolute
E0_BIT a,Absolute

; 2D
EM_AND a,Absolute
E0_AND a,Absolute

; 2E
EM_ROL a,Absolute
E0_ROL a,Absolute

; 2F
EM_AND al,Absolute_Long
E0_AND al,Absolute_Long

; 30
BFS BMI,SNES_FLAG_N

; 31
EM_AND OdO_y,Direct_Indirect_Indexed
E0_AND OdO_y,Direct_Indirect_Indexed

; 32
EM_AND OdO,Direct_Indirect
E0_AND OdO,Direct_Indirect

; 33
EM_AND Od_sO_y,Stack_Relative_Indirect_Indexed
E0_AND Od_sO_y,Stack_Relative_Indirect_Indexed

; 34
EM_BIT d_x,Direct_Index_X
E0_BIT d_x,Direct_Index_X

; 35
EM_AND d_x,Direct_Index_X
E0_AND d_x,Direct_Index_X

; 36
EM_ROL d_x,Direct_Index_X
E0_ROL d_x,Direct_Index_X

; 37
EM_AND IdI_y,Direct_Indirect_Indexed_Long
E0_AND IdI_y,Direct_Indirect_Indexed_Long

; 38
_SEx C,ALL_SEC          ; Set Carry flag

; 39
EM_AND a_y,Absolute_Index_Y
E0_AND a_y,Absolute_Index_Y

; 3A

ALIGNC
EXPORT_C EM_DEA
 mov al,B_A
 inc R_NativePC
 dec al
 mov B_A,al
 STORE_FLAGS_NZ al
 OPCODE_EPILOG
ALIGNC
EXPORT_C E0_DEA
 mov eax,B_A
 inc R_NativePC
 dec eax
 mov B_A,ax
 or al,ah
 STORE_FLAGS_N ah
 STORE_FLAGS_Z al
 OPCODE_EPILOG

; 3B
_TxC B_S,ALL_TSC

; 3C
EM_BIT a_x,Absolute_Index_X
E0_BIT a_x,Absolute_Index_X

; 3D
EM_AND a_x,Absolute_Index_X
E0_AND a_x,Absolute_Index_X

; 3E
EM_ROL a_x,Absolute_Index_X
E0_ROL a_x,Absolute_Index_X

; 3F
EM_AND al_x,Absolute_Long_Index_X
E0_AND al_x,Absolute_Long_Index_X

; 40

ALIGNC
EXPORT_C E0_RTI
%ifdef TRAP_INVALID_JUMP
 GET_PC eax
 mov [C_LABEL(Map_Byte)],eax
%endif
 E0_PULL_B
 mov bl,B_I_flag
 push ebx
 E0_RESTOREFLAGS
 E0_PULL_W
 mov R_NativePC,eax
 E0_PULL_B
 mov B_PB,al
 test [MEMSEL],al   ; Check bus speed against PB
 mov bl,[C_LABEL(FastROM_offset)]
 jnz .fastrom
 mov bl,4
.fastrom:
 mov ah,0
%ifndef NO_FASTROM
 mov [C_LABEL(CycleTable)],bl   ; Update bus speed
%endif
 mov edx,R_NativePC
 shl eax,16
 add edx,eax

 shr edx,13
 mov edx,[C_LABEL(Read_Bank8Offset)+edx*4]
 test edx,edx
 jz .read_non_linear

 add edx,eax
.read_direct:

 add R_NativePC,edx
 mov B_PBOffset,edx

 pop ebx

 test bl,bl
 jz .no_irq_enable
 JUMP_FLAG SNES_FLAG_I,.no_irq_enable
 mov al,CEM_Instruction_After_IRQ_Enable
 mov [CPU_Execution_Mode],al
 xor edx,edx
 SAVE_CYCLES
 mov [C_LABEL(EventTrip)],edx
 mov edx,Enabling_IRQ_Event
 LOAD_CYCLES
 mov [Event_Handler],edx

.no_irq_enable:
 SET_TABLE_MX

.read_non_linear:
%ifdef TRAP_INVALID_JUMP
 add esp,byte 4
 mov byte [C_LABEL(Map_Byte)+3],0x40
 mov [C_LABEL(Map_Address)],ebx
 jmp _InvalidJump
%else
 mov eax,C_LABEL(Blank)
 jmp .read_direct ;*
%endif

ALIGNC
EXPORT_C E1_RTI
%ifdef TRAP_INVALID_JUMP
 GET_PC eax
 mov [C_LABEL(Map_Byte)],eax
%endif
 E1_PULL_B
 mov bl,B_I_flag
 push ebx
 E1_RESTOREFLAGS
 E1_PULL_W

 mov ebx,B_PB_Shifted
 mov R_NativePC,eax
 or eax,ebx

 shr eax,13
 mov eax,[C_LABEL(Read_Bank8Offset)+eax*4]
 test eax,eax
 jz .read_non_linear

 add eax,ebx
.read_direct:

 add R_NativePC,eax
 mov B_PBOffset,eax

 pop ebx

 test bl,bl
 jz .no_irq_enable
 JUMP_FLAG SNES_FLAG_I,C_LABEL(CPU_RETURN),near
 mov al,CEM_Instruction_After_IRQ_Enable
 mov [CPU_Execution_Mode],al
 xor edx,edx
 SAVE_CYCLES
 mov [C_LABEL(EventTrip)],edx
 mov edx,Enabling_IRQ_Event
 LOAD_CYCLES
 mov [Event_Handler],edx

.no_irq_enable:
 OPCODE_EPILOG

.read_non_linear:
%ifdef TRAP_INVALID_JUMP
 add esp,byte 4
 mov byte [C_LABEL(Map_Byte)+3],0x40
 mov [C_LABEL(Map_Address)],ebx
 jmp _InvalidJump
%else
 mov eax,C_LABEL(Blank)
 jmp .read_direct
%endif

; 41
EM_EOR Od_xO,Direct_Indexed_Indirect
E0_EOR Od_xO,Direct_Indexed_Indirect

; 42
ALIGNC
EXPORT_C ALL_WDM
 add R_NativePC,byte 2
 OPCODE_EPILOG

; 43
EM_EOR d_s,Stack_Relative
E0_EOR d_s,Stack_Relative

; 44

ALIGNC
EXPORT_C E0_MVP
 ALL_MVX 0,MVP
	
ALIGNC
EXPORT_C EX_MVP
 ALL_MVX 1,MVP

; 45
EM_EOR d,Direct
E0_EOR d,Direct

; 46
EM_LSR d,Direct
E0_LSR d,Direct

; 47
EM_EOR IdI,Direct_Indirect_Long
E0_EOR IdI,Direct_Indirect_Long

; 48
E0_PUSH16 B_A,E0_PHA
E0_PUSH8 B_A,EM_PHA
E1_PUSH8 B_A,E1_PHA

; 49
EM_EOR i,Immediate
E0_EOR i,Immediate

; 4A

ALIGNC
EXPORT_C EM_SRA
 mov al,B_A
 inc R_NativePC
 shr al,byte 1
 sbb cl,cl
 mov B_A,al
 STORE_FLAGS_NZC al,cl
 OPCODE_EPILOG
ALIGNC
EXPORT_C E0_SRA
 mov eax,B_A
 inc R_NativePC
 shr eax,byte 1
 sbb cl,cl
 STORE_FLAGS_N ah
 mov B_A,eax
 or al,ah
 STORE_FLAGS_C cl
 STORE_FLAGS_Z al
 OPCODE_EPILOG

; 4B
E0_PUSH8 B_PB,E0_PHK    ; Push PB(K) onto stack
E1_PUSH8 B_PB,E1_PHK

; 4C

ALIGNC
EXPORT_C ALL_JMP_a
%ifdef TRAP_INVALID_JUMP
 GET_PC eax
 mov [C_LABEL(Map_Byte)],eax
%endif
 ADDR_Absolute_JMP

 mov ebx,B_PB_Shifted
 mov R_NativePC,eax
 or eax,ebx

 shr eax,13
 mov eax,[C_LABEL(Read_Bank8Offset)+eax*4]
 test eax,eax
 jz .read_non_linear

 add eax,ebx
.read_direct:

 add R_NativePC,eax
 mov B_PBOffset,eax

 OPCODE_EPILOG

.read_non_linear:
%ifdef TRAP_INVALID_JUMP
 mov byte [C_LABEL(Map_Byte)+3],0x4C
 mov [C_LABEL(Map_Address)],ebx
 jmp _InvalidJump
%else
 mov eax,C_LABEL(Blank)
 jmp short .read_direct
%endif

; 4D
EM_EOR a,Absolute
E0_EOR a,Absolute

; 4E
EM_LSR a,Absolute
E0_LSR a,Absolute

; 4F
EM_EOR al,Absolute_Long
E0_EOR al,Absolute_Long

; 50
BFC BVC,SNES_FLAG_V

; 51
EM_EOR OdO_y,Direct_Indirect_Indexed
E0_EOR OdO_y,Direct_Indirect_Indexed

; 52
EM_EOR OdO,Direct_Indirect
E0_EOR OdO,Direct_Indirect

; 53
EM_EOR Od_sO_y,Stack_Relative_Indirect_Indexed
E0_EOR Od_sO_y,Stack_Relative_Indirect_Indexed

; 54

ALIGNC
EXPORT_C E0_MVN
 ALL_MVX 0,MVN
	
ALIGNC
EXPORT_C EX_MVN
 ALL_MVX 1,MVN

; 55
EM_EOR d_x,Direct_Index_X
E0_EOR d_x,Direct_Index_X

; 56
EM_LSR d_x,Direct_Index_X
E0_LSR d_x,Direct_Index_X

; 57
EM_EOR IdI_y,Direct_Indirect_Indexed_Long
E0_EOR IdI_y,Direct_Indirect_Indexed_Long

; 58

ALIGNC
EXPORT_C ALL_CLI
 inc R_NativePC
 mov bl,B_I_flag
 STORE_FLAGS_I ah

 test bl,bl
 jz .no_irq_enable
 mov al,CEM_Instruction_After_IRQ_Enable
 mov [CPU_Execution_Mode],al
 xor edx,edx
 SAVE_CYCLES
 mov [C_LABEL(EventTrip)],edx
 mov edx,Enabling_IRQ_Event
 LOAD_CYCLES
 mov [Event_Handler],edx

.no_irq_enable:
 OPCODE_EPILOG

; 59
EM_EOR a_y,Absolute_Index_Y
E0_EOR a_y,Absolute_Index_Y

; 5A
E0_PUSH16 B_Y,E0_PHY
E0_PUSH8 B_Y,EX_PHY
E1_PUSH8 B_Y,E1_PHY

; 5B
_TCD ALL_TCD

; 5C

ALIGNC
EXPORT_C ALL_JML_al
%ifdef TRAP_INVALID_JUMP
 GET_PC eax
 mov [C_LABEL(Map_Byte)],eax
%endif
 mov al,[1+R_NativePC]
 xor ebx,ebx
 mov ah,[2+R_NativePC]
 mov bl,[3+R_NativePC]
 mov B_PB,bl
 mov R_NativePC,eax
 test [MEMSEL],bl       ; Check bus speed against PB
 mov al,[C_LABEL(FastROM_offset)]
 jnz .fastrom
 mov al,4
.fastrom:
%ifndef NO_FASTROM
 mov [C_LABEL(CycleTable)],al   ; Update bus speed
%endif
 mov edx,R_NativePC
 shl ebx,16
 or edx,ebx

 shr edx,13
 mov edx,[C_LABEL(Read_Bank8Offset)+edx*4]
 test edx,edx
 jz .read_non_linear

 add edx,ebx
.read_direct:

 add R_NativePC,edx
 mov B_PBOffset,edx

 OPCODE_EPILOG

.read_non_linear:
%ifdef TRAP_INVALID_JUMP
 mov byte [C_LABEL(Map_Byte)+3],0x5C
 mov [C_LABEL(Map_Address)],ebx
 jmp _InvalidJump
%else
 mov edx,C_LABEL(Blank)
 jmp short .read_direct
%endif

; 5D
EM_EOR a_x,Absolute_Index_X
E0_EOR a_x,Absolute_Index_X

; 5E
EM_LSR a_x,Absolute_Index_X
E0_LSR a_x,Absolute_Index_X

; 5F
EM_EOR al_x,Absolute_Long_Index_X
E0_EOR al_x,Absolute_Long_Index_X

; 60

ALIGNC
EXPORT_C E0_RTS
%ifdef TRAP_INVALID_JUMP
 GET_PC eax
 mov [C_LABEL(Map_Byte)],eax
%endif
 E0_PULL_W
 inc ax     ; This is a MAD processor!

 mov ebx,B_PB_Shifted
 mov R_NativePC,eax
 or eax,ebx

 shr eax,13
 mov eax,[C_LABEL(Read_Bank8Offset)+eax*4]
 test eax,eax
 jz .read_non_linear

 add eax,ebx
.read_direct:

 add R_NativePC,eax
 mov B_PBOffset,eax

 OPCODE_EPILOG

.read_non_linear:
%ifdef TRAP_INVALID_JUMP
 mov byte [C_LABEL(Map_Byte)+3],0x60
 mov [C_LABEL(Map_Address)],ebx
 jmp _InvalidJump
%else
 mov eax,C_LABEL(Blank)
 jmp short .read_direct
%endif

ALIGNC
EXPORT_C E1_RTS
%ifdef TRAP_INVALID_JUMP
 GET_PC eax
 mov [C_LABEL(Map_Byte)],eax
%endif
 E1_PULL_W
 inc ax     ; This is a MAD processor!

 mov ebx,B_PB_Shifted
 mov R_NativePC,eax
 or eax,ebx

 shr eax,13
 mov eax,[C_LABEL(Read_Bank8Offset)+eax*4]
 test eax,eax
 jz .read_non_linear

 add eax,ebx
.read_direct:

 add R_NativePC,eax
 mov B_PBOffset,eax

 OPCODE_EPILOG

.read_non_linear:
%ifdef TRAP_INVALID_JUMP
 mov byte [C_LABEL(Map_Byte)+3],0x60
 mov [C_LABEL(Map_Address)],ebx
 jmp _InvalidJump
%else
 mov eax,C_LABEL(Blank)
 jmp short .read_direct
%endif

; 61
EM_ADC Od_xO,Direct_Indexed_Indirect
E0_ADC Od_xO,Direct_Indexed_Indirect

; 62

ALIGNC
EXPORT_C E0_PER
 mov al,[1+R_NativePC]
 mov ah,[2+R_NativePC]
 add R_NativePC,byte 3
 GET_PC ebx
 add eax,ebx
 E0_PUSH_W
 OPCODE_EPILOG

ALIGNC
EXPORT_C E1_PER
 mov al,[1+R_NativePC]
 mov ah,[2+R_NativePC]
 add R_NativePC,byte 3
 GET_PC ebx
 add eax,ebx
 E1_PUSH_W
 OPCODE_EPILOG

; 63
EM_ADC d_s,Stack_Relative
E0_ADC d_s,Stack_Relative

; 64
ALIGNC
EM_STZ d,Direct
E0_STZ d,Direct

; 65
EM_ADC d,Direct
E0_ADC d,Direct

; 66
EM_ROR d,Direct
E0_ROR d,Direct

; 67
EM_ADC IdI,Direct_Indirect_Long
E0_ADC IdI,Direct_Indirect_Long

; 68
E0_PULL16 B_A,E0_PLA
E0_PULL8 B_A,EM_PLA
E1_PULL8 B_A,E1_PLA

; 69
EM_ADC i,Immediate
E0_ADC i,Immediate

; 6A    ; Fixed 0.25: RRA8 didn't set NZ flags correctly

ALIGNC
EXPORT_C EM_RRA
 mov cl,B_C_flag
 mov al,B_A
 inc R_NativePC
 add cl,255 ;MAKE_CARRY
 rcr al,1
 sbb cl,cl
 mov B_A,al
 STORE_FLAGS_NZC al,cl
 OPCODE_EPILOG

ALIGNC
EXPORT_C E0_RRA
 mov cl,B_C_flag
 mov eax,B_A
 inc R_NativePC
 add cl,255 ;MAKE_CARRY
 rcr ax,1
 sbb cl,cl
 STORE_FLAGS_N ah
 mov B_A,eax
 or al,ah
 STORE_FLAGS_C cl
 STORE_FLAGS_Z al
 OPCODE_EPILOG

; 6B

ALIGNC
EXPORT_C E0_RTL
%ifdef TRAP_INVALID_JUMP
 GET_PC eax
 mov [C_LABEL(Map_Byte)],eax
%endif
 E0_PULL_W
 inc ax     ; This is a MAD processor!
 mov R_NativePC,eax
 E0_PULL_B
 mov B_PB,al
 test [MEMSEL],al   ; Check bus speed against PB
 mov bl,[C_LABEL(FastROM_offset)]
 jnz .fastrom
 mov bl,4
.fastrom:
 mov ah,0
%ifndef NO_FASTROM
 mov [C_LABEL(CycleTable)],bl   ; Update bus speed
%endif
 mov edx,R_NativePC
 shl eax,16
 or edx,eax

 shr edx,13
 mov edx,[C_LABEL(Read_Bank8Offset)+edx*4]
 test edx,edx
 jz .read_non_linear

 add edx,eax
.read_direct:

 add R_NativePC,edx
 mov B_PBOffset,edx

 OPCODE_EPILOG

.read_non_linear:
%ifdef TRAP_INVALID_JUMP
 mov byte [C_LABEL(Map_Byte)+3],0x6B
 mov [C_LABEL(Map_Address)],ebx
 jmp _InvalidJump
%else
 mov edx,C_LABEL(Blank)
 jmp short .read_direct
%endif

ALIGNC
EXPORT_C E1_RTL
%ifdef TRAP_INVALID_JUMP
 GET_PC eax
 mov [C_LABEL(Map_Byte)],eax
%endif
 E1_PULL_W
 inc ax     ; This is a MAD processor!
 mov R_NativePC,eax
 E1_PULL_B
 mov B_PB,al
 test [MEMSEL],al   ; Check bus speed against PB
 mov bl,[C_LABEL(FastROM_offset)]
 jnz .fastrom
 mov bl,4
.fastrom:
 mov ah,0
%ifndef NO_FASTROM
 mov [C_LABEL(CycleTable)],bl   ; Update bus speed
%endif
 mov edx,R_NativePC
 shl eax,16
 or edx,eax

 shr edx,13
 mov edx,[C_LABEL(Read_Bank8Offset)+edx*4]
 test edx,edx
 jz .read_non_linear

 add edx,eax
.read_direct:

 add R_NativePC,edx
 mov B_PBOffset,edx

 OPCODE_EPILOG

.read_non_linear:
%ifdef TRAP_INVALID_JUMP
 mov byte [C_LABEL(Map_Byte)+3],0x6B
 mov [C_LABEL(Map_Address)],ebx
 jmp _InvalidJump
%else
 mov edx,C_LABEL(Blank)
 jmp short .read_direct
%endif

; 6C

; JMP Absolute Indirect
; Returns PCH in %al
;  PC = (a16)
;
ALIGNC
EXPORT_C ALL_JMP_OaO
%ifdef TRAP_INVALID_JUMP
 GET_PC eax
 mov [C_LABEL(Map_Byte)],eax
%endif
 mov bl,[1+R_NativePC]
 mov bh,[2+R_NativePC]
 GET_WORD

 mov ebx,B_PB_Shifted
 mov R_NativePC,eax
 or eax,ebx

 shr eax,13
 mov eax,[C_LABEL(Read_Bank8Offset)+eax*4]
 test eax,eax
 jz .read_non_linear

 add eax,ebx
.read_direct:

 add R_NativePC,eax
 mov B_PBOffset,eax

 OPCODE_EPILOG

.read_non_linear:
%ifdef TRAP_INVALID_JUMP
 mov byte [C_LABEL(Map_Byte)+3],0x6C
 mov [C_LABEL(Map_Address)],ebx
 jmp _InvalidJump
%else
 mov eax,C_LABEL(Blank)
 jmp short .read_direct
%endif

; 6D
EM_ADC a,Absolute
E0_ADC a,Absolute

; 6E
EM_ROR a,Absolute
E0_ROR a,Absolute

; 6F
EM_ADC al,Absolute_Long
E0_ADC al,Absolute_Long

; 70
BFS BVS,SNES_FLAG_V

; 71
EM_ADC OdO_y,Direct_Indirect_Indexed
E0_ADC OdO_y,Direct_Indirect_Indexed

; 72
EM_ADC OdO,Direct_Indirect
E0_ADC OdO,Direct_Indirect

; 73
EM_ADC Od_sO_y,Stack_Relative_Indirect_Indexed
E0_ADC Od_sO_y,Stack_Relative_Indirect_Indexed

; 74
EM_STZ d_x,Direct_Index_X
E0_STZ d_x,Direct_Index_X

; 75
EM_ADC d_x,Direct_Index_X
E0_ADC d_x,Direct_Index_X

; 76
EM_ROR d_x,Direct_Index_X
E0_ROR d_x,Direct_Index_X

; 77
EM_ADC IdI_y,Direct_Indirect_Indexed_Long
E0_ADC IdI_y,Direct_Indirect_Indexed_Long

; 78
_SEx I,ALL_SEI          ; Set Interrupt disable flag

; 79
EM_ADC a_y,Absolute_Index_Y
E0_ADC a_y,Absolute_Index_Y

; 7A
E0_PULL16 B_Y,E0_PLY
E0_PULL8 B_Y,EX_PLY
E1_PULL8 B_Y,E1_PLY

; 7B
_TxC B_D,ALL_TDC

; 7C

ALIGNC
EXPORT_C ALL_JMP_Oa_xO
%ifdef TRAP_INVALID_JUMP
 GET_PC eax
 mov [C_LABEL(Map_Byte)],eax
%endif
 ADDR_Absolute_Indexed_Indirect

 mov ebx,B_PB_Shifted
 mov R_NativePC,eax
 or eax,ebx

 shr eax,13
 mov eax,[C_LABEL(Read_Bank8Offset)+eax*4]
 test eax,eax
 jz .read_non_linear

 add eax,ebx
.read_direct:

 add R_NativePC,eax
 mov B_PBOffset,eax

 OPCODE_EPILOG

.read_non_linear:
%ifdef TRAP_INVALID_JUMP
 mov byte [C_LABEL(Map_Byte)+3],0x7C
 mov [C_LABEL(Map_Address)],ebx
 jmp _InvalidJump
%else
 mov eax,C_LABEL(Blank)
 jmp short .read_direct
%endif

; 7D
EM_ADC a_x,Absolute_Index_X
E0_ADC a_x,Absolute_Index_X

; 7E
EM_ROR a_x,Absolute_Index_X
E0_ROR a_x,Absolute_Index_X

; 7F
EM_ADC al_x,Absolute_Long_Index_X
E0_ADC al_x,Absolute_Long_Index_X

; 80

ALIGNC
EXPORT_C ALL_BRA
 movsx eax,byte [1+R_NativePC]
 add R_NativePC,byte 2
 add R_NativePC,eax
 OPCODE_EPILOG

; 81
EM_STA Od_xO,Direct_Indexed_Indirect
E0_STA Od_xO,Direct_Indexed_Indirect

; 82
                                 
ALIGNC
EXPORT_C ALL_BRL        ; Branch always long (-32768 to 32767)
 mov al,[1+R_NativePC]
 GET_PC ebx
%ifdef TRAP_INVALID_JUMP
 mov [C_LABEL(Map_Byte)],ebx
%endif
 mov ah,[2+R_NativePC]
 add ebx,byte 3
 add eax,ebx
 and eax,0xFFFF
 mov ebx,B_PB_Shifted
 mov R_NativePC,eax
 or eax,ebx

 shr eax,13
 mov eax,[C_LABEL(Read_Bank8Offset)+eax*4]
 test eax,eax
 jz .read_non_linear

 add eax,ebx
.read_direct:

 add R_NativePC,eax
 mov B_PBOffset,eax

 OPCODE_EPILOG

.read_non_linear:
%ifdef TRAP_INVALID_JUMP
 mov byte [C_LABEL(Map_Byte)+3],0x82
 mov [C_LABEL(Map_Address)],ebx
 jmp _InvalidJump
%else
 mov eax,C_LABEL(Blank)
 jmp short .read_direct
%endif

; 83
EM_STA d_s,Stack_Relative
E0_STA d_s,Stack_Relative

; 84
EX_STY d,Direct
E0_STY d,Direct

; 85
EM_STA d,Direct
E0_STA d,Direct

; 86
EX_STX d,Direct
E0_STX d,Direct

; 87
EM_STA IdI,Direct_Indirect_Long
E0_STA IdI,Direct_Indirect_Long

; 88

ALIGNC
EXPORT_C EX_DEY
 mov al,B_Y
 inc R_NativePC
 dec al
 mov B_Y,al
 STORE_FLAGS_NZ al
 OPCODE_EPILOG
ALIGNC
EXPORT_C E0_DEY
 mov eax,B_Y
 inc R_NativePC
 dec eax
 mov B_Y,ax
 or al,ah
 STORE_FLAGS_N ah
 STORE_FLAGS_Z al
 OPCODE_EPILOG

; 89    ; Differs from norm, only sets Z flag

ALIGNC
EXPORT_C EM_BIT_i
 mov al,[1+R_NativePC]
 mov cl,B_A
 add R_NativePC,byte 2
 and al,cl
 STORE_FLAGS_Z al
 OPCODE_EPILOG
ALIGNC
EXPORT_C E0_BIT_i
 mov al,[1+R_NativePC]
 mov ecx,B_A
 mov ah,[2+R_NativePC]
 add R_NativePC,byte 3
 and eax,ecx
 or al,ah
 STORE_FLAGS_Z al
 OPCODE_EPILOG

; 8A
_TxA B_X,8,EM_TXA
_TxA B_X,16,E0_TXA

; 8B
E0_PUSH8 B_DB,E0_PHB    ; Push DB(B) onto stack
E1_PUSH8 B_DB,E1_PHB

; 8C
EX_STY a,Absolute
E0_STY a,Absolute

; 8D
EM_STA a,Absolute
E0_STA a,Absolute

; 8E
EX_STX a,Absolute
E0_STX a,Absolute

; 8F
EM_STA al,Absolute_Long
E0_STA al,Absolute_Long

; 90
BFC BCC,SNES_FLAG_C

; 91
EM_STA OdO_y,Direct_Indirect_Indexed
E0_STA OdO_y,Direct_Indirect_Indexed

; 92
EM_STA OdO,Direct_Indirect
E0_STA OdO,Direct_Indirect

; 93
EM_STA Od_sO_y,Stack_Relative_Indirect_Indexed
E0_STA Od_sO_y,Stack_Relative_Indirect_Indexed

; 94
EX_STY d_x,Direct_Index_X
E0_STY d_x,Direct_Index_X

; 95
EM_STA d_x,Direct_Index_X
E0_STA d_x,Direct_Index_X

; 96
EX_STX d_y,Direct_Index_Y
E0_STX d_y,Direct_Index_Y

; 97
EM_STA IdI_y,Direct_Indirect_Indexed_Long
E0_STA IdI_y,Direct_Indirect_Indexed_Long

; 98
_TxA B_Y,8,EM_TYA
_TxA B_Y,16,E0_TYA

; 99
EM_STA a_y,Absolute_Index_Y
E0_STA a_y,Absolute_Index_Y

; 9A
_TxS B_X,16,E0_TXS
_TxS B_X,8,E1_TXS

; 9B
_TxY B_X,8,EX_TXY
_TxY B_X,16,E0_TXY

; 9C
EM_STZ a,Absolute
E0_STZ a,Absolute

; 9D
EM_STA a_x,Absolute_Index_X
E0_STA a_x,Absolute_Index_X

; 9E
EM_STZ a_x,Absolute_Index_X
E0_STZ a_x,Absolute_Index_X

; 9F
EM_STA al_x,Absolute_Long_Index_X
E0_STA al_x,Absolute_Long_Index_X

; A0
EX_LDY i,Immediate
E0_LDY i,Immediate

; A1
EM_LDA Od_xO,Direct_Indexed_Indirect
E0_LDA Od_xO,Direct_Indexed_Indirect

; A2
EX_LDX i,Immediate
E0_LDX i,Immediate

; A3
EM_LDA d_s,Stack_Relative
E0_LDA d_s,Stack_Relative

; A4
EX_LDY d,Direct
E0_LDY d,Direct

; A5
EM_LDA d,Direct
E0_LDA d,Direct

; A6
EX_LDX d,Direct
E0_LDX d,Direct

; A7
EM_LDA IdI,Direct_Indirect_Long
E0_LDA IdI,Direct_Indirect_Long

; A8
_TxY B_A,8,EX_TAY
_TxY B_A,16,E0_TAY

; A9
EM_LDA i,Immediate
E0_LDA i,Immediate

; AA
_TxX B_A,8,EX_TAX
_TxX B_A,16,E0_TAX

; AB
E0_PULL8 B_DB,E0_PLB    ; Pull DB(B) from stack
E1_PULL8 B_DB,E1_PLB

; AC
EX_LDY a,Absolute
E0_LDY a,Absolute

; AD
EM_LDA a,Absolute
E0_LDA a,Absolute

; AE
EX_LDX a,Absolute
E0_LDX a,Absolute

; AF
EM_LDA al,Absolute_Long
E0_LDA al,Absolute_Long

; B0
BFS BCS,SNES_FLAG_C

; B1
EM_LDA OdO_y,Direct_Indirect_Indexed
E0_LDA OdO_y,Direct_Indirect_Indexed

; B2
EM_LDA OdO,Direct_Indirect
E0_LDA OdO,Direct_Indirect

; B3
EM_LDA Od_sO_y,Stack_Relative_Indirect_Indexed
E0_LDA Od_sO_y,Stack_Relative_Indirect_Indexed

; B4
EX_LDY d_x,Direct_Index_X
E0_LDY d_x,Direct_Index_X

; B5
EM_LDA d_x,Direct_Index_X
E0_LDA d_x,Direct_Index_X

; B6
EX_LDX d_y,Direct_Index_Y
E0_LDX d_y,Direct_Index_Y

; B7
EM_LDA IdI_y,Direct_Indirect_Indexed_Long
E0_LDA IdI_y,Direct_Indirect_Indexed_Long

; B8
_CLx V,ALL_CLV          ; Clear oVerflow flag

; B9
EM_LDA a_y,Absolute_Index_Y
E0_LDA a_y,Absolute_Index_Y

; BA
_TxX B_S,8,EX_TSX
_TxX B_S,16,E0_TSX

; BB
_TxX B_Y,8,EX_TYX
_TxX B_Y,16,E0_TYX

; BC
EX_LDY a_x,Absolute_Index_X
E0_LDY a_x,Absolute_Index_X

; BD
EM_LDA a_x,Absolute_Index_X
E0_LDA a_x,Absolute_Index_X

; BE
EX_LDX a_y,Absolute_Index_Y
E0_LDX a_y,Absolute_Index_Y

; BF
EM_LDA al_x,Absolute_Long_Index_X
E0_LDA al_x,Absolute_Long_Index_X

; C0
EX_CPY i,Immediate
E0_CPY i,Immediate

; C1
EM_CMP Od_xO,Direct_Indexed_Indirect
E0_CMP Od_xO,Direct_Indexed_Indirect

; C2

ALIGNC
EXPORT_C E0_REP
 mov al,[1+R_NativePC]
 mov bl,B_I_flag

 test al,REAL_SNES_FLAG_C
 jz .no_change_carry
 STORE_FLAGS_C ah
.no_change_carry:

 test al,REAL_SNES_FLAG_Z
 jz .no_change_zero
 STORE_FLAGS_Z al
.no_change_zero:

 test al,REAL_SNES_FLAG_I
 jz .no_change_interrupt_disable
 STORE_FLAGS_I ah
.no_change_interrupt_disable:

 test al,REAL_SNES_FLAG_D
 jz .no_change_decimal_mode
 STORE_FLAGS_D ah
.no_change_decimal_mode:

 test al,REAL_SNES_FLAG_X
 jz .no_change_index_size
 STORE_FLAGS_X ah
.no_change_index_size:

 test al,REAL_SNES_FLAG_M
 jz .no_change_memory_size
 STORE_FLAGS_M ah
.no_change_memory_size:

 test al,REAL_SNES_FLAG_V
 jz .no_change_overflow
 STORE_FLAGS_V ah
.no_change_overflow:

 test al,REAL_SNES_FLAG_N
 jz .no_change_negative
 STORE_FLAGS_N ah
.no_change_negative:

 add R_NativePC,byte 2

 test bl,bl
 jz .no_irq_enable
 JUMP_FLAG SNES_FLAG_I,.no_irq_enable
 mov al,CEM_Instruction_After_IRQ_Enable
 mov [CPU_Execution_Mode],al
 xor edx,edx
 SAVE_CYCLES
 mov [C_LABEL(EventTrip)],edx
 mov edx,Enabling_IRQ_Event
 LOAD_CYCLES
 mov [Event_Handler],edx

.no_irq_enable:
 SET_TABLE_MX

ALIGNC
EXPORT_C E1_REP
 mov al,[1+R_NativePC]
 mov bl,B_I_flag

 test al,REAL_SNES_FLAG_C
 jz .no_change_carry
 STORE_FLAGS_C ah
.no_change_carry:

 test al,REAL_SNES_FLAG_Z
 jz .no_change_zero
 STORE_FLAGS_Z al
.no_change_zero:

 test al,REAL_SNES_FLAG_I
 jz .no_change_interrupt_disable
 STORE_FLAGS_I ah
.no_change_interrupt_disable:

 test al,REAL_SNES_FLAG_D
 jz .no_change_decimal_mode
 STORE_FLAGS_D ah
.no_change_decimal_mode:

 test al,REAL_SNES_FLAG_V
 jz .no_change_overflow
 STORE_FLAGS_V ah
.no_change_overflow:

 test al,REAL_SNES_FLAG_N
 jz .no_change_negative
 STORE_FLAGS_N ah
.no_change_negative:

 add R_NativePC,byte 2

 test bl,bl
 jz .no_irq_enable
 JUMP_FLAG SNES_FLAG_I,C_LABEL(CPU_RETURN),near
 mov al,CEM_Instruction_After_IRQ_Enable
 mov [CPU_Execution_Mode],al
 xor edx,edx
 SAVE_CYCLES
 mov [C_LABEL(EventTrip)],edx
 mov edx,Enabling_IRQ_Event
 LOAD_CYCLES
 mov [Event_Handler],edx

.no_irq_enable:
 OPCODE_EPILOG

; C3
EM_CMP d_s,Stack_Relative
E0_CMP d_s,Stack_Relative

; C4
EX_CPY d,Direct
E0_CPY d,Direct

; C5
EM_CMP d,Direct
E0_CMP d,Direct

; C6
EM_DEC d,Direct
E0_DEC d,Direct

; C7
EM_CMP IdI,Direct_Indirect_Long
E0_CMP IdI,Direct_Indirect_Long

; C8

ALIGNC
EXPORT_C EX_INY
 mov al,B_Y
 inc R_NativePC
 inc al
 mov B_Y,al
 STORE_FLAGS_NZ al
 OPCODE_EPILOG
ALIGNC
EXPORT_C E0_INY
 mov eax,B_Y
 inc R_NativePC
 inc eax
 mov B_Y,ax
 or al,ah
 STORE_FLAGS_N ah
 STORE_FLAGS_Z al
 OPCODE_EPILOG

; C9
EM_CMP i,Immediate
E0_CMP i,Immediate

; CA

ALIGNC
EXPORT_C EX_DEX
 mov al,B_X
 inc R_NativePC
 dec al
 mov B_X,al
 STORE_FLAGS_NZ al
 OPCODE_EPILOG
ALIGNC
EXPORT_C E0_DEX
 mov eax,B_X
 inc R_NativePC
 dec eax
 mov B_X,ax
 or al,ah
 STORE_FLAGS_N ah
 STORE_FLAGS_Z al
 OPCODE_EPILOG

; CB

ALIGNC
EXPORT_C ALL_WAI        ; Wait for interrupt
 mov al,[IRQ_pin]
 test al,al
 jnz .irq_active

%ifndef ADD_CYCLES_FIRST
 pop ebx
 add R_Cycles,ebx
%endif

 ; Put CPU in WAI mode
 mov byte [CPU_Execution_Mode],CEM_Waiting_For_Interrupt
 ; Trigger next event
 test R_Cycles,R_Cycles
 jge near HANDLE_EVENT
 xor R_Cycles,R_Cycles
 jmp HANDLE_EVENT
ALIGNC
.irq_active:
 inc R_NativePC

%ifdef WAI_DELAY
 ; WAI delay after interrupt signal: 2 IO
 add R_Cycles,byte 12   ;*
%endif

 OPCODE_EPILOG

; CC
EX_CPY a,Absolute
E0_CPY a,Absolute

; CD
EM_CMP a,Absolute
E0_CMP a,Absolute

; CE
EM_DEC a,Absolute
E0_DEC a,Absolute

; CF
EM_CMP al,Absolute_Long
E0_CMP al,Absolute_Long

; D0
BFC BNE,SNES_FLAG_Z

; D1
EM_CMP OdO_y,Direct_Indirect_Indexed
E0_CMP OdO_y,Direct_Indirect_Indexed

; D2
EM_CMP OdO,Direct_Indirect
E0_CMP OdO,Direct_Indirect

; D3
EM_CMP Od_sO_y,Stack_Relative_Indirect_Indexed
E0_CMP Od_sO_y,Stack_Relative_Indirect_Indexed

; D4

ALIGNC
EXPORT_C E0_PEI
 READ16_Direct
 E0_PUSH_W
 OPCODE_EPILOG

ALIGNC
EXPORT_C E1_PEI
 READ16_Direct
 E1_PUSH_W
 OPCODE_EPILOG

; D5
EM_CMP d_x,Direct_Index_X
E0_CMP d_x,Direct_Index_X

; D6
EM_DEC d_x,Direct_Index_X
E0_DEC d_x,Direct_Index_X

; D7
EM_CMP IdI_y,Direct_Indirect_Indexed_Long
E0_CMP IdI_y,Direct_Indirect_Indexed_Long

; D8
_CLx D,ALL_CLD          ; Clear Decimal mode flag

; D9
EM_CMP a_y,Absolute_Index_Y
E0_CMP a_y,Absolute_Index_Y

; DA
E0_PUSH16 B_X,E0_PHX
E0_PUSH8 B_X,EX_PHX
E1_PUSH8 B_X,E1_PHX

; DB
ALIGNC
EXPORT_C ALL_STP
%ifndef ADD_CYCLES_FIRST
 pop ebx
 add R_Cycles,ebx
%endif

 ; Put CPU in STP mode
 mov byte [CPU_Execution_Mode],CEM_Clock_Stopped
 ; Trigger next event
 test R_Cycles,R_Cycles
 jge near HANDLE_EVENT
 xor R_Cycles,R_Cycles
 jmp HANDLE_EVENT

; DC

; JML Absolute Indirect Long
;  PB:PC = [a16]
;
ALIGNC
EXPORT_C ALL_JML_OaO
%ifdef TRAP_INVALID_JUMP
 GET_PC eax
 mov [C_LABEL(Map_Byte)],eax
%endif
 mov bl,[1+R_NativePC]
 mov bh,[2+R_NativePC]
 GET_WORD

 inc ebx
 mov R_NativePC,eax
 and ebx,0x00FFFFFF ; Ensure 24-bit address
 GET_BYTE
 mov B_PB,al
 test [MEMSEL],al   ; Check bus speed against PB
 mov bl,[C_LABEL(FastROM_offset)]
 jnz .fastrom
 mov bl,4
.fastrom:
 mov ah,0
%ifndef NO_FASTROM
 mov [C_LABEL(CycleTable)],bl   ; Update bus speed
%endif
 mov edx,R_NativePC
 shl eax,16
 or edx,eax

 shr edx,13
 mov edx,[C_LABEL(Read_Bank8Offset)+edx*4]
 test edx,edx
 jz .read_non_linear

 add edx,eax
.read_direct:

 add R_NativePC,edx
 mov B_PBOffset,edx

 OPCODE_EPILOG

.read_non_linear:
%ifdef TRAP_INVALID_JUMP
 mov byte [C_LABEL(Map_Byte)+3],0xDC
 mov [C_LABEL(Map_Address)],ebx
 jmp _InvalidJump
%else
 mov edx,C_LABEL(Blank)
 jmp short .read_direct
%endif

; DD
EM_CMP a_x,Absolute_Index_X
E0_CMP a_x,Absolute_Index_X

; DE
EM_DEC a_x,Absolute_Index_X
E0_DEC a_x,Absolute_Index_X

; DF
EM_CMP al_x,Absolute_Long_Index_X
E0_CMP al_x,Absolute_Long_Index_X

; E0
EX_CPX i,Immediate
E0_CPX i,Immediate

; E1
EM_SBC Od_xO,Direct_Indexed_Indirect
E0_SBC Od_xO,Direct_Indexed_Indirect

; E2

ALIGNC
EXPORT_C E0_SEP
 mov al,[1+R_NativePC]

 test al,REAL_SNES_FLAG_C
 jz .no_change_carry
 STORE_FLAGS_C al
.no_change_carry:

 test al,REAL_SNES_FLAG_Z
 jz .no_change_zero
 STORE_FLAGS_Z ah
.no_change_zero:

 test al,REAL_SNES_FLAG_I
 jz .no_change_interrupt_disable
 STORE_FLAGS_I al
.no_change_interrupt_disable:

 test al,REAL_SNES_FLAG_D
 jz .no_change_decimal_mode
 STORE_FLAGS_D al
.no_change_decimal_mode:

 test al,REAL_SNES_FLAG_X
 jz .no_change_index_size
 STORE_FLAGS_X al
.no_change_index_size:

 test al,REAL_SNES_FLAG_M
 jz .no_change_memory_size
 STORE_FLAGS_M al
.no_change_memory_size:

 test al,REAL_SNES_FLAG_V
 jz .no_change_overflow
 STORE_FLAGS_V al
.no_change_overflow:

 test al,REAL_SNES_FLAG_N
 jz .no_change_negative
 STORE_FLAGS_N al
.no_change_negative:

 add R_NativePC,byte 2

 SET_TABLE_MX

ALIGNC
EXPORT_C E1_SEP
 mov al,[1+R_NativePC]

 test al,REAL_SNES_FLAG_C
 jz .no_change_carry
 STORE_FLAGS_C al
.no_change_carry:

 test al,REAL_SNES_FLAG_Z
 jz .no_change_zero
 STORE_FLAGS_Z ah
.no_change_zero:

 test al,REAL_SNES_FLAG_I
 jz .no_change_interrupt_disable
 STORE_FLAGS_I al
.no_change_interrupt_disable:

 test al,REAL_SNES_FLAG_D
 jz .no_change_decimal_mode
 STORE_FLAGS_D al
.no_change_decimal_mode:

 test al,REAL_SNES_FLAG_V
 jz .no_change_overflow
 STORE_FLAGS_V al
.no_change_overflow:

 test al,REAL_SNES_FLAG_N
 jz .no_change_negative
 STORE_FLAGS_N al
.no_change_negative:

 add R_NativePC,byte 2

 OPCODE_EPILOG

; E3
EM_SBC d_s,Stack_Relative
E0_SBC d_s,Stack_Relative

; E4
EX_CPX d,Direct
E0_CPX d,Direct

; E5
EM_SBC d,Direct
E0_SBC d,Direct

; E6
EM_INC d,Direct
E0_INC d,Direct

; E7
EM_SBC IdI,Direct_Indirect_Long
E0_SBC IdI,Direct_Indirect_Long

; E8

ALIGNC
EXPORT_C EX_INX
 mov al,B_X
 inc R_NativePC
 inc al
 mov B_X,al
 STORE_FLAGS_NZ al
 OPCODE_EPILOG
ALIGNC
EXPORT_C E0_INX
 mov eax,B_X
 inc R_NativePC
 inc eax
 mov B_X,ax
 or al,ah
 STORE_FLAGS_N ah
 STORE_FLAGS_Z al
 OPCODE_EPILOG

; E9
EM_SBC i,Immediate
E0_SBC i,Immediate

; EA

ALIGNC
EXPORT_C ALL_NOP
 inc R_NativePC
 OPCODE_EPILOG

; EB

ALIGNC
EXPORT_C ALL_XBA
 mov ah,B_A
 inc R_NativePC
 mov al,B_B
 STORE_FLAGS_NZ al
 mov B_A,eax
 OPCODE_EPILOG

; EC
EX_CPX a,Absolute
E0_CPX a,Absolute

; ED
EM_SBC a,Absolute
E0_SBC a,Absolute

; EE
EM_INC a,Absolute
E0_INC a,Absolute

; EF
EM_SBC al,Absolute_Long
E0_SBC al,Absolute_Long

; F0
BFS BEQ,SNES_FLAG_Z

; F1
EM_SBC OdO_y,Direct_Indirect_Indexed
E0_SBC OdO_y,Direct_Indirect_Indexed

; F2
EM_SBC OdO,Direct_Indirect
E0_SBC OdO,Direct_Indirect

; F3
EM_SBC Od_sO_y,Stack_Relative_Indirect_Indexed
E0_SBC Od_sO_y,Stack_Relative_Indirect_Indexed

; F4

ALIGNC
EXPORT_C E0_PEA
 mov al,[1+R_NativePC]
 mov ah,[2+R_NativePC]
 add R_NativePC,byte 3
 E0_PUSH_W
 OPCODE_EPILOG

ALIGNC
EXPORT_C E1_PEA
 mov al,[1+R_NativePC]
 mov ah,[2+R_NativePC]
 add R_NativePC,byte 3
 E1_PUSH_W
 OPCODE_EPILOG

; F5
EM_SBC d_x,Direct_Index_X
E0_SBC d_x,Direct_Index_X

; F6
EM_INC d_x,Direct_Index_X
E0_INC d_x,Direct_Index_X

; F7
EM_SBC IdI_y,Direct_Indirect_Indexed_Long
E0_SBC IdI_y,Direct_Indirect_Indexed_Long

; F8
_SEx D,ALL_SED          ; Set Decimal mode flag

; F9
EM_SBC a_y,Absolute_Index_Y
E0_SBC a_y,Absolute_Index_Y

; FA
E0_PULL16 B_X,E0_PLX
E0_PULL8 B_X,EX_PLX
E1_PULL8 B_X,E1_PLX

; FB

ALIGNC
EXPORT_C E0_XCE
 inc R_NativePC

 JUMP_NOT_FLAG SNES_FLAG_C,C_LABEL(CPU_RETURN),near
 mov B_XH,ah
 mov B_YH,ah
 STORE_FLAGS_C ah
 mov al,1
 STORE_FLAGS_E al
 STORE_FLAGS_B al
 STORE_FLAGS_1 al
 mov B_SH,al
 mov dword [OpTable],OpTableE1  ; Set current opcode emulation table
 OPCODE_EPILOG

ALIGNC
EXPORT_C E1_XCE
 inc R_NativePC

 JUMP_FLAG SNES_FLAG_C,C_LABEL(CPU_RETURN),near
 STORE_FLAGS_E ah
 mov al,1
 STORE_FLAGS_C al
 STORE_FLAGS_M al
 STORE_FLAGS_X al
 mov dword [OpTable],OpTableMX  ; Set current opcode emulation table
 OPCODE_EPILOG

; FC

ALIGNC
EXPORT_C E0_JSR_Oa_xO
 GET_PC eax
%ifdef TRAP_INVALID_JUMP
 mov [C_LABEL(Map_Byte)],eax
%endif
 add eax,byte 2     ; last instruction byte PC in ax
 E0_PUSH_W          ; Address of last byte not next instruction (huh!)
 ADDR_Absolute_Indexed_Indirect

 mov ebx,B_PB_Shifted
 mov R_NativePC,eax
 or eax,ebx

 shr eax,13
 mov eax,[C_LABEL(Read_Bank8Offset)+eax*4]
 test eax,eax
 jz .read_non_linear

 add eax,ebx
.read_direct:

 add R_NativePC,eax
 mov B_PBOffset,eax

 OPCODE_EPILOG

.read_non_linear:
%ifdef TRAP_INVALID_JUMP
 mov byte [C_LABEL(Map_Byte)+3],0xFC
 mov [C_LABEL(Map_Address)],ebx
 jmp _InvalidJump
%else
 mov eax,C_LABEL(Blank)
 jmp short .read_direct
%endif

ALIGNC
EXPORT_C E1_JSR_Oa_xO
 GET_PC eax
%ifdef TRAP_INVALID_JUMP
 mov [C_LABEL(Map_Byte)],eax
%endif
 add eax,byte 2     ; last instruction byte PC in ax
 E1_PUSH_W          ; Address of last byte not next instruction (huh!)
 ADDR_Absolute_Indexed_Indirect

 mov ebx,B_PB_Shifted
 mov R_NativePC,eax
 or eax,ebx

 shr eax,13
 mov eax,[C_LABEL(Read_Bank8Offset)+eax*4]
 test eax,eax
 jz .read_non_linear

 add eax,ebx
.read_direct:

 add R_NativePC,eax
 mov B_PBOffset,eax

 OPCODE_EPILOG

.read_non_linear:
%ifdef TRAP_INVALID_JUMP
 mov byte [C_LABEL(Map_Byte)+3],0xFC
 mov [C_LABEL(Map_Address)],ebx
 jmp _InvalidJump
%else
 mov eax,C_LABEL(Blank)
 jmp short .read_direct
%endif

; FD
EM_SBC a_x,Absolute_Index_X
E0_SBC a_x,Absolute_Index_X

; FE
EM_INC a_x,Absolute_Index_X
E0_INC a_x,Absolute_Index_X

; FF
EM_SBC al_x,Absolute_Long_Index_X
E0_SBC al_x,Absolute_Long_Index_X
