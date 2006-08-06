%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2006, Charles Bilyue'.
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

%if S_size == 8
%define OPCODE_PROLOG(op) OPCODE_LABEL OpE1_ %+ op
%else
%define OPCODE_PROLOG(op) OPCODE_LABEL OpE0M %+ M_8bit %+ _ %+ op
%endif


OPCODE_PROLOG(0x01) ; ORA (d,x)
 _ORA Direct_Indexed_Indirect
OPCODE_EPILOG

OPCODE_PROLOG(0x04) ; TSB d
 RMW _TSB,Direct
OPCODE_EPILOG

OPCODE_PROLOG(0x05) ; ORA d
 _ORA Direct
OPCODE_EPILOG

OPCODE_PROLOG(0x06) ; ASL d
 RMW _ASL,Direct
OPCODE_EPILOG

OPCODE_PROLOG(0x07) ; ORA [d]
 _ORA Direct_Indirect_Long
OPCODE_EPILOG

OPCODE_PROLOG(0x12) ; ORA (d)
 _ORA Direct_Indirect
OPCODE_EPILOG

OPCODE_PROLOG(0x14) ; TRB d
 RMW _TRB,Direct
OPCODE_EPILOG

OPCODE_PROLOG(0x15) ; ORA d,x
 _ORA Direct_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0x16) ; ASL d,x
 RMW _ASL,Direct_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0x17) ; ORA [d],y
 _ORA Direct_Indirect_Indexed_Long
OPCODE_EPILOG

OPCODE_PROLOG(0x21) ; AND (d,x)
 _AND Direct_Indexed_Indirect
OPCODE_EPILOG

OPCODE_PROLOG(0x24) ; BIT d
 _BIT Direct
OPCODE_EPILOG

OPCODE_PROLOG(0x25) ; AND d
 _AND Direct
OPCODE_EPILOG

OPCODE_PROLOG(0x26) ; ROL d
 RMW _ROL,Direct
OPCODE_EPILOG

OPCODE_PROLOG(0x27) ; AND [d]
 _AND Direct_Indirect_Long
OPCODE_EPILOG

OPCODE_PROLOG(0x32) ; AND (d)
 _AND Direct_Indirect
OPCODE_EPILOG

OPCODE_PROLOG(0x34) ; BIT d,x
 _BIT Direct_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0x35) ; AND d,x
 _AND Direct_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0x36) ; ROL d,x
 RMW _ROL,Direct_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0x37) ; AND [d],y
 _AND Direct_Indirect_Indexed_Long
OPCODE_EPILOG

OPCODE_PROLOG(0x41) ; EOR (d,x)
 _EOR Direct_Indexed_Indirect
OPCODE_EPILOG

OPCODE_PROLOG(0x45) ; EOR d
 _EOR Direct
OPCODE_EPILOG

OPCODE_PROLOG(0x46) ; LSR d
 RMW _LSR,Direct
OPCODE_EPILOG

OPCODE_PROLOG(0x47) ; EOR [d]
 _EOR Direct_Indirect_Long
OPCODE_EPILOG

OPCODE_PROLOG(0x48) ; PHA s
 _PHA
OPCODE_EPILOG

OPCODE_PROLOG(0x52) ; EOR (d)
 _EOR Direct_Indirect
OPCODE_EPILOG

OPCODE_PROLOG(0x55) ; EOR d,x
 _EOR Direct_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0x56) ; LSR d,x
 RMW _LSR,Direct_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0x57) ; EOR [d],y
 _EOR Direct_Indirect_Indexed_Long
OPCODE_EPILOG

OPCODE_PROLOG(0x61) ; ADC (d,x)
 _ADC Direct_Indexed_Indirect
OPCODE_EPILOG

OPCODE_PROLOG(0x64) ; STZ d
 _STZ Direct
OPCODE_EPILOG

OPCODE_PROLOG(0x65) ; ADC d
 _ADC Direct
OPCODE_EPILOG

OPCODE_PROLOG(0x66) ; ROR d
 RMW _ROR,Direct
OPCODE_EPILOG

OPCODE_PROLOG(0x67) ; ADC [d]
 _ADC Direct_Indirect_Long
OPCODE_EPILOG

OPCODE_PROLOG(0x68) ; PLA s
 _PLA
OPCODE_EPILOG

OPCODE_PROLOG(0x72) ; ADC (d)
 _ADC Direct_Indirect
OPCODE_EPILOG

OPCODE_PROLOG(0x74) ; STZ d,x
 _STZ Direct_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0x75) ; ADC d,x
 _ADC Direct_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0x76) ; ROR d,x
 RMW _ROR,Direct_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0x77) ; ADC [d],y
 _ADC Direct_Indirect_Indexed_Long
OPCODE_EPILOG

OPCODE_PROLOG(0x81) ; STA (d,x)
 _STA Direct_Indexed_Indirect
OPCODE_EPILOG

OPCODE_PROLOG(0x85) ; STA d
 _STA Direct
OPCODE_EPILOG

OPCODE_PROLOG(0x87) ; STA [d]
 _STA Direct_Indirect_Long
OPCODE_EPILOG

OPCODE_PROLOG(0x92) ; STA (d)
 _STA Direct_Indirect
OPCODE_EPILOG

OPCODE_PROLOG(0x95) ; STA d,x
 _STA Direct_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0x97) ; STA [d],y
 _STA Direct_Indirect_Indexed_Long
OPCODE_EPILOG

OPCODE_PROLOG(0xA1) ; LDA (d,x)
 _LDA Direct_Indexed_Indirect
OPCODE_EPILOG

OPCODE_PROLOG(0xA5) ; LDA d
 _LDA Direct
OPCODE_EPILOG

OPCODE_PROLOG(0xA7) ; LDA [d]
 _LDA Direct_Indirect_Long
OPCODE_EPILOG

OPCODE_PROLOG(0xB2) ; LDA (d)
 _LDA Direct_Indirect
OPCODE_EPILOG

OPCODE_PROLOG(0xB5) ; LDA d,x
 _LDA Direct_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0xB7) ; LDA [d],y
 _LDA Direct_Indirect_Indexed_Long
OPCODE_EPILOG

OPCODE_PROLOG(0xC1) ; CMP (d,x)
 _CMP Direct_Indexed_Indirect
OPCODE_EPILOG

OPCODE_PROLOG(0xC5) ; CMP d
 _CMP Direct
OPCODE_EPILOG

OPCODE_PROLOG(0xC6) ; DEC d
 RMW _DEC_M,Direct
OPCODE_EPILOG

OPCODE_PROLOG(0xC7) ; CMP [d]
 _CMP Direct_Indirect_Long
OPCODE_EPILOG

OPCODE_PROLOG(0xD2) ; CMP (d)
 _CMP Direct_Indirect
OPCODE_EPILOG

OPCODE_PROLOG(0xD5) ; CMP d,x
 _CMP Direct_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0xD6) ; DEC d,x
 RMW _DEC_M,Direct_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0xD7) ; CMP [d],y
 _CMP Direct_Indirect_Indexed_Long
OPCODE_EPILOG

OPCODE_PROLOG(0xE1) ; SBC (d,x)
 _SBC Direct_Indexed_Indirect
OPCODE_EPILOG

OPCODE_PROLOG(0xE5) ; SBC d
 _SBC Direct
OPCODE_EPILOG

OPCODE_PROLOG(0xE6) ; INC d
 RMW _INC_M,Direct
OPCODE_EPILOG

OPCODE_PROLOG(0xE7) ; SBC [d]
 _SBC Direct_Indirect_Long
OPCODE_EPILOG

OPCODE_PROLOG(0xF2) ; SBC (d)
 _SBC Direct_Indirect
OPCODE_EPILOG

OPCODE_PROLOG(0xF5) ; SBC d,x
 _SBC Direct_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0xF6) ; INC d,x
 RMW _INC_M,Direct_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0xF7) ; SBC [d],y
 _SBC Direct_Indirect_Indexed_Long
OPCODE_EPILOG

%undef OPCODE_PROLOG
