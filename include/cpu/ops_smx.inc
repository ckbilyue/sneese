%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2015, Charles Bilyue.
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
