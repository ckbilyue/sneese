%if S_size == 8
%define OPCODE_PROLOG(op) EXPORT_C OpE1_ %+ op
%else
%define OPCODE_PROLOG(op) EXPORT_C OpE0X %+ X_8bit %+ _ %+ op
%endif


OPCODE_PROLOG(0x84) ; STY d
 _STY Direct
OPCODE_EPILOG

OPCODE_PROLOG(0x86) ; STX d
 _STX Direct
OPCODE_EPILOG

OPCODE_PROLOG(0x94) ; STY d,x
 _STY Direct_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0x96) ; STX d,y
 _STX Direct_Index_Y
OPCODE_EPILOG

%undef OPCODE_PROLOG
