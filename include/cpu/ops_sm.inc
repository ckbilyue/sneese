%if S_size == 8
%define OPCODE_PROLOG(op) EXPORT_C OpE1_ %+ op
%else
%define OPCODE_PROLOG(op) EXPORT_C OpE0M %+ M_8bit %+ _ %+ op
%endif



%undef OPCODE_PROLOG
