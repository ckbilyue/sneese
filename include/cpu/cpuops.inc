%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2005, Charles Bilyue'.
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


;S,M,X
%macro Setup_Opcode_Sizes 3
%define S_size %1
%if S_size == 8
%define S_8bit 1
%else
%define S_8bit 0
%endif

%define M_size %2
%if M_size == 8
%define M_8bit 1
%else
%define M_8bit 0
%endif

%define X_size %3
%if X_size == 8
%define X_8bit 1
%else
%define X_8bit 0
%endif
%endmacro


%macro Clear_Opcode_Sizes 0
%undef S_size
%undef S_8bit
%undef M_size
%undef M_8bit
%undef X_size
%undef X_8bit
%endmacro

%macro OPCODE_LABEL 1
ALIGNC
EXPORT %1
%endmacro


Setup_Opcode_Sizes 8,8,8
%include "cpu/ops_s.inc"
%include "cpu/ops_sm.inc"
%include "cpu/ops_sx.inc"
%include "cpu/ops_smx.inc"
Clear_Opcode_Sizes

Setup_Opcode_Sizes 16,8,8
%include "cpu/ops_s.inc"
%include "cpu/ops_sm.inc"
%include "cpu/ops_sx.inc"
%include "cpu/ops_smx.inc"
Clear_Opcode_Sizes

Setup_Opcode_Sizes 16,16,16
%include "cpu/ops_sm.inc"
%include "cpu/ops_sx.inc"
%include "cpu/ops_smx.inc"
Clear_Opcode_Sizes

Setup_Opcode_Sizes 16,8,16
%include "cpu/ops_smx.inc"
Clear_Opcode_Sizes

Setup_Opcode_Sizes 16,16,8
%include "cpu/ops_smx.inc"
Clear_Opcode_Sizes

Setup_Opcode_Sizes 16,8,8
%include "cpu/ops_m.inc"
%include "cpu/ops_x.inc"
%include "cpu/ops_mx.inc"
Clear_Opcode_Sizes

Setup_Opcode_Sizes 16,16,16
%include "cpu/ops_m.inc"
%include "cpu/ops_x.inc"
%include "cpu/ops_mx.inc"
Clear_Opcode_Sizes

Setup_Opcode_Sizes 16,8,16
%include "cpu/ops_mx.inc"
Clear_Opcode_Sizes

Setup_Opcode_Sizes 16,16,8
%include "cpu/ops_mx.inc"
Clear_Opcode_Sizes


%define OPCODE_PROLOG(op) OPCODE_LABEL Op_ %+ op


OPCODE_PROLOG(0x18) ; CLC i
 _CLx C         ; Clear Carry flag
OPCODE_EPILOG

OPCODE_PROLOG(0x38) ; SEC i
 _SEx C         ; Set Carry flag
OPCODE_EPILOG

OPCODE_PROLOG(0x3B) ; TSC i
 _TxC B_S
OPCODE_EPILOG

OPCODE_PROLOG(0x42) ; WDM
 READ8_Immediate
OPCODE_EPILOG

OPCODE_PROLOG(0x4C) ; JMP a
 ADDR_Absolute_JMP
 mov R_PC,ax
OPCODE_EPILOG

OPCODE_PROLOG(0x58) ; CLI i
 mov cl,B_I_flag
 _CLx I         ; Clear Interrupt disable flag

 test cl,cl
 jz .no_irq_enable
 xor edx,edx
 SAVE_CYCLES
 mov [C_LABEL(EventTrip)],edx
 mov edx,Enabling_IRQ_Event
 LOAD_CYCLES
 mov [Event_Handler],edx

.no_irq_enable:
OPCODE_EPILOG

OPCODE_PROLOG(0x5B) ; TCD i
 _TCD
OPCODE_EPILOG

OPCODE_PROLOG(0x5C) ; JML al
 ADDR_Absolute_Long_JMP
 mov R_PBPC,eax
 shr eax,16
 mov B_PB,al
OPCODE_EPILOG

OPCODE_PROLOG(0x6C) ; JMP (a)
 ADDR_Absolute_Indirect_JMP
 mov R_PC,ax
OPCODE_EPILOG

OPCODE_PROLOG(0x78) ; SEI i
 _SEx I         ; Set Interrupt disable flag
OPCODE_EPILOG

OPCODE_PROLOG(0x7B) ; TDC i
 _TxC B_D
OPCODE_EPILOG

OPCODE_PROLOG(0x7C) ; JMP (a,x)
 ADDR_Absolute_Indexed_Indirect
 mov R_PC,ax
OPCODE_EPILOG

OPCODE_PROLOG(0x82) ; BRL rl
; Branch always long (-32768 to 32767)
 READ16_Immediate
 add R_Cycles,_5A22_FAST_CYCLE
 add R_PC,ax
OPCODE_EPILOG

OPCODE_PROLOG(0xB8) ; CLV i
 _CLx V         ; Clear oVerflow flag
OPCODE_EPILOG

; Wait for interrupt
OPCODE_PROLOG(0xCB) ; WAI i
%ifndef WAI_DELAY
 add R_Cycles,_5A22_FAST_CYCLE * 2
%endif

 mov al,[IRQ_pin]
 test al,al
 jnz .irq_active

 ; Put CPU in WAI mode
 mov byte [CPU_Execution_Mode],CEM_Waiting_For_Interrupt
 ; Trigger next event
 test R_Cycles,R_Cycles
 jge HANDLE_EVENT
 xor R_Cycles,R_Cycles
 jmp HANDLE_EVENT
ALIGNC
.irq_active:
 inc R_PC

%ifdef WAI_DELAY
 ; WAI delay after interrupt signal: 2 IO
 add R_Cycles,_5A22_FAST_CYCLE * 2
%endif
OPCODE_EPILOG

OPCODE_PROLOG(0xD8) ; CLC i
 _CLx D         ; Clear Decimal mode flag
OPCODE_EPILOG

; Stop the clock
OPCODE_PROLOG(0xDB) ; STP i
 add R_Cycles,_5A22_FAST_CYCLE * 2

 ; Put CPU in STP mode
 mov byte [CPU_Execution_Mode],CEM_Clock_Stopped
 ; Trigger next event
 test R_Cycles,R_Cycles
 jge HANDLE_EVENT
 xor R_Cycles,R_Cycles
 jmp HANDLE_EVENT
OPCODE_EPILOG

OPCODE_PROLOG(0xDC) ; JML [a]
 ADDR_Absolute_Indirect_Long_JMP
 mov R_PBPC,eax
 shr eax,16
 mov B_PB,al
OPCODE_EPILOG

OPCODE_PROLOG(0xEA) ; NOP i
 ADDR_Implied
OPCODE_EPILOG

OPCODE_PROLOG(0xEB) ; XBA i
 ADDR_Implied
 mov ah,B_A
 add R_Cycles,_5A22_FAST_CYCLE
 mov al,B_B
 STORE_FLAGS_NZ al
 mov B_A,eax
OPCODE_EPILOG

OPCODE_PROLOG(0xF8) ; SED i
 _SEx D         ; Set Decimal mode flag
OPCODE_EPILOG
