%define OPCODE_PROLOG(op) EXPORT_C OpM %+ M_8bit %+ _ %+ op


OPCODE_PROLOG(0x0A) ; ASL A
 RMW _ASL,Accumulator
OPCODE_EPILOG

OPCODE_PROLOG(0x0C) ; TSB a
 RMW _TSB,Absolute
OPCODE_EPILOG

OPCODE_PROLOG(0x0E) ; ASL a
 RMW _ASL,Absolute
OPCODE_EPILOG

OPCODE_PROLOG(0x1A) ; INC A
 RMW _INC_M,Accumulator
OPCODE_EPILOG

OPCODE_PROLOG(0x1C) ; TRB a
 RMW _TRB,Absolute
OPCODE_EPILOG

OPCODE_PROLOG(0x1E) ; ASL a,x
 RMW _ASL,Absolute_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0x2A) ; ROL A
 RMW _ROL,Accumulator
OPCODE_EPILOG

OPCODE_PROLOG(0x2E) ; ROL a
 RMW _ROL,Absolute
OPCODE_EPILOG

OPCODE_PROLOG(0x3A) ; DEC A
 RMW _DEC_M,Accumulator
OPCODE_EPILOG

OPCODE_PROLOG(0x3E) ; ROL a,x
 RMW _ROL,Absolute_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0x4A) ; LSR A
 RMW _LSR,Accumulator
OPCODE_EPILOG

OPCODE_PROLOG(0x4E) ; LSR a
 RMW _LSR,Absolute
OPCODE_EPILOG

OPCODE_PROLOG(0x5E) ; LSR a,x
 RMW _LSR,Absolute_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0x6A) ; ROR A
 RMW _ROR,Accumulator
OPCODE_EPILOG

OPCODE_PROLOG(0x6E) ; ROR a
 RMW _ROR,Absolute
OPCODE_EPILOG

OPCODE_PROLOG(0x7E) ; ROR a,x
 RMW _ROR,Absolute_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0xCE) ; DEC a
 RMW _DEC_M,Absolute
OPCODE_EPILOG

OPCODE_PROLOG(0xDE) ; DEC a,x
 RMW _DEC_M,Absolute_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0xEE) ; INC a
 RMW _INC_M,Absolute
OPCODE_EPILOG

OPCODE_PROLOG(0xFE) ; INC a,x
 RMW _INC_M,Absolute_Index_X
OPCODE_EPILOG

%undef OPCODE_PROLOG