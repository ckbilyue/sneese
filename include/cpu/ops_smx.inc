%if S_size == 8
%define OPCODE_PROLOG(op) EXPORT_C OpE1_ %+ op
%else
%define OPCODE_PROLOG(op) EXPORT_C OpE0M %+ M_8bit %+ X %+ X_8bit %+ _ %+ op
%endif


OPCODE_PROLOG(0x91) ; STA (d),y
 _STA Direct_Indirect_Indexed
OPCODE_EPILOG

%undef OPCODE_PROLOG
