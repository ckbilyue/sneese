%if S_size == 8
%define OPCODE_PROLOG(op) OPCODE_LABEL OpE1_ %+ op
%else
%define OPCODE_PROLOG(op) OPCODE_LABEL OpE0M %+ M_8bit %+ X %+ X_8bit %+ _ %+ op
%endif


OPCODE_PROLOG(0x11) ; ORA (d),y
 _ORA Direct_Indirect_Indexed
OPCODE_EPILOG

OPCODE_PROLOG(0x31) ; AND (d),y
 _AND Direct_Indirect_Indexed
OPCODE_EPILOG

OPCODE_PROLOG(0x51) ; EOR (d),y
 _EOR Direct_Indirect_Indexed
OPCODE_EPILOG

OPCODE_PROLOG(0x71) ; ADC (d),y
 _ADC Direct_Indirect_Indexed
OPCODE_EPILOG

OPCODE_PROLOG(0x91) ; STA (d),y
 _STA Direct_Indirect_Indexed
OPCODE_EPILOG

OPCODE_PROLOG(0xB1) ; LDA (d),y
 _LDA Direct_Indirect_Indexed
OPCODE_EPILOG

OPCODE_PROLOG(0xD1) ; CMP (d),y
 _CMP Direct_Indirect_Indexed
OPCODE_EPILOG

OPCODE_PROLOG(0xF1) ; SBC (d),y
 _SBC Direct_Indirect_Indexed
OPCODE_EPILOG

%undef OPCODE_PROLOG
