%if 0

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2005, Charles Bilyue'.
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

%define OPCODE_PROLOG(op) OPCODE_LABEL OpM %+ M_8bit %+ X %+ X_8bit %+ _ %+ op


OPCODE_PROLOG(0x19) ; ORA a,y
 _ORA Absolute_Index_Y
OPCODE_EPILOG

OPCODE_PROLOG(0x1D) ; ORA a,x
 _ORA Absolute_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0x39) ; AND a,y
 _AND Absolute_Index_Y
OPCODE_EPILOG

OPCODE_PROLOG(0x3C) ; BIT a,x
 _BIT Absolute_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0x3D) ; AND a,x
 _AND Absolute_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0x59) ; EOR a,y
 _EOR Absolute_Index_Y
OPCODE_EPILOG

OPCODE_PROLOG(0x5D) ; EOR a,x
 _EOR Absolute_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0x79) ; ADC a,y
 _ADC Absolute_Index_Y
OPCODE_EPILOG

OPCODE_PROLOG(0x7D) ; ADC a,x
 _ADC Absolute_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0xB9) ; LDA a,y
 _LDA Absolute_Index_Y
OPCODE_EPILOG

OPCODE_PROLOG(0xBD) ; LDA a,x
 _LDA Absolute_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0xD9) ; CMP a,y
 _CMP Absolute_Index_Y
OPCODE_EPILOG

OPCODE_PROLOG(0xDD) ; CMP a,x
 _CMP Absolute_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0xF9) ; SBC a,y
 _SBC Absolute_Index_Y
OPCODE_EPILOG

OPCODE_PROLOG(0xFD) ; SBC a,x
 _SBC Absolute_Index_X
OPCODE_EPILOG

%undef OPCODE_PROLOG
