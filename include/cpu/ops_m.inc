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

%define OPCODE_PROLOG(op) OPCODE_LABEL OpM %+ M_8bit %+ _ %+ op


OPCODE_PROLOG(0x03) ; ORA d,s
 _ORA Stack_Relative
OPCODE_EPILOG

OPCODE_PROLOG(0x09) ; ORA #
 _ORA Immediate
OPCODE_EPILOG

OPCODE_PROLOG(0x0A) ; ASL A
 RMW _ASL,Accumulator
OPCODE_EPILOG

OPCODE_PROLOG(0x0C) ; TSB a
 RMW _TSB,Absolute
OPCODE_EPILOG

OPCODE_PROLOG(0x0D) ; ORA a
 _ORA Absolute
OPCODE_EPILOG

OPCODE_PROLOG(0x0E) ; ASL a
 RMW _ASL,Absolute
OPCODE_EPILOG

OPCODE_PROLOG(0x0F) ; ORA al
 _ORA Absolute_Long
OPCODE_EPILOG

OPCODE_PROLOG(0x13) ; ORA (d,s),y
 _ORA Stack_Relative_Indirect_Indexed
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

OPCODE_PROLOG(0x1F) ; ORA al,x
 _ORA Absolute_Long_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0x23) ; AND d,s
 _AND Stack_Relative
OPCODE_EPILOG

OPCODE_PROLOG(0x29) ; AND #
 _AND Immediate
OPCODE_EPILOG

OPCODE_PROLOG(0x2A) ; ROL A
 RMW _ROL,Accumulator
OPCODE_EPILOG

OPCODE_PROLOG(0x2C) ; BIT a
 _BIT Absolute
OPCODE_EPILOG

OPCODE_PROLOG(0x2D) ; AND a
 _AND Absolute
OPCODE_EPILOG

OPCODE_PROLOG(0x2E) ; ROL a
 RMW _ROL,Absolute
OPCODE_EPILOG

OPCODE_PROLOG(0x2F) ; AND al
 _AND Absolute_Long
OPCODE_EPILOG

OPCODE_PROLOG(0x33) ; AND (d,s),y
 _AND Stack_Relative_Indirect_Indexed
OPCODE_EPILOG

OPCODE_PROLOG(0x3A) ; DEC A
 RMW _DEC_M,Accumulator
OPCODE_EPILOG

OPCODE_PROLOG(0x3E) ; ROL a,x
 RMW _ROL,Absolute_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0x3F) ; AND al,x
 _AND Absolute_Long_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0x43) ; EOR d,s
 _EOR Stack_Relative
OPCODE_EPILOG

OPCODE_PROLOG(0x49) ; EOR #
 _EOR Immediate
OPCODE_EPILOG

OPCODE_PROLOG(0x4A) ; LSR A
 RMW _LSR,Accumulator
OPCODE_EPILOG

OPCODE_PROLOG(0x4D) ; EOR a
 _EOR Absolute
OPCODE_EPILOG

OPCODE_PROLOG(0x4E) ; LSR a
 RMW _LSR,Absolute
OPCODE_EPILOG

OPCODE_PROLOG(0x4F) ; EOR al
 _EOR Absolute_Long
OPCODE_EPILOG

OPCODE_PROLOG(0x53) ; EOR (d,s),y
 _EOR Stack_Relative_Indirect_Indexed
OPCODE_EPILOG

OPCODE_PROLOG(0x5E) ; LSR a,x
 RMW _LSR,Absolute_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0x5F) ; EOR al,x
 _EOR Absolute_Long_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0x63) ; ADC d,s
 _ADC Stack_Relative
OPCODE_EPILOG

OPCODE_PROLOG(0x69) ; ADC #
 _ADC Immediate
OPCODE_EPILOG

OPCODE_PROLOG(0x6A) ; ROR A
 RMW _ROR,Accumulator
OPCODE_EPILOG

OPCODE_PROLOG(0x6D) ; ADC a
 _ADC Absolute
OPCODE_EPILOG

OPCODE_PROLOG(0x6E) ; ROR a
 RMW _ROR,Absolute
OPCODE_EPILOG

OPCODE_PROLOG(0x6F) ; ADC al
 _ADC Absolute_Long
OPCODE_EPILOG

OPCODE_PROLOG(0x73) ; ADC (d,s),y
 _ADC Stack_Relative_Indirect_Indexed
OPCODE_EPILOG

OPCODE_PROLOG(0x7E) ; ROR a,x
 RMW _ROR,Absolute_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0x7F) ; ADC al,x
 _ADC Absolute_Long_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0x83) ; STA d,s
 _STA Stack_Relative
OPCODE_EPILOG

OPCODE_PROLOG(0x89) ; BIT #
 _BIT Immediate
OPCODE_EPILOG

OPCODE_PROLOG(0x8A) ; TXA i
 _TxA B_X
OPCODE_EPILOG

OPCODE_PROLOG(0x8D) ; STA a
 _STA Absolute
OPCODE_EPILOG

OPCODE_PROLOG(0x8F) ; STA al
 _STA Absolute_Long
OPCODE_EPILOG

OPCODE_PROLOG(0x93) ; STA (d,s),y
 _STA Stack_Relative_Indirect_Indexed
OPCODE_EPILOG

OPCODE_PROLOG(0x98) ; TYA i
 _TxA B_Y
OPCODE_EPILOG

OPCODE_PROLOG(0x99) ; STA a,y
 _STA Absolute_Index_Y
OPCODE_EPILOG

OPCODE_PROLOG(0x9C) ; STZ a
 _STZ Absolute
OPCODE_EPILOG

OPCODE_PROLOG(0x9D) ; STA a,x
 _STA Absolute_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0x9E) ; STZ a,x
 _STZ Absolute_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0x9F) ; STA al,x
 _STA Absolute_Long_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0xA3) ; LDA d,s
 _LDA Stack_Relative
OPCODE_EPILOG

OPCODE_PROLOG(0xA9) ; LDA #
 _LDA Immediate
OPCODE_EPILOG

OPCODE_PROLOG(0xAD) ; LDA a
 _LDA Absolute
OPCODE_EPILOG

OPCODE_PROLOG(0xAF) ; LDA al
 _LDA Absolute_Long
OPCODE_EPILOG

OPCODE_PROLOG(0xB3) ; LDA (d,s),y
 _LDA Stack_Relative_Indirect_Indexed
OPCODE_EPILOG

OPCODE_PROLOG(0xBF) ; LDA al,x
 _LDA Absolute_Long_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0xC3) ; CMP d,s
 _CMP Stack_Relative
OPCODE_EPILOG

OPCODE_PROLOG(0xC9) ; CMP #
 _CMP Immediate
OPCODE_EPILOG

OPCODE_PROLOG(0xCD) ; CMP a
 _CMP Absolute
OPCODE_EPILOG

OPCODE_PROLOG(0xCE) ; DEC a
 RMW _DEC_M,Absolute
OPCODE_EPILOG

OPCODE_PROLOG(0xCF) ; CMP al
 _CMP Absolute_Long
OPCODE_EPILOG

OPCODE_PROLOG(0xD3) ; CMP (d,s),y
 _CMP Stack_Relative_Indirect_Indexed
OPCODE_EPILOG

OPCODE_PROLOG(0xDE) ; DEC a,x
 RMW _DEC_M,Absolute_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0xDF) ; CMP al,x
 _CMP Absolute_Long_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0xE3) ; SBC d,s
 _SBC Stack_Relative
OPCODE_EPILOG

OPCODE_PROLOG(0xE9) ; SBC #
 _SBC Immediate
OPCODE_EPILOG

OPCODE_PROLOG(0xED) ; SBC a
 _SBC Absolute
OPCODE_EPILOG

OPCODE_PROLOG(0xEE) ; INC a
 RMW _INC_M,Absolute
OPCODE_EPILOG

OPCODE_PROLOG(0xEF) ; SBC al
 _SBC Absolute_Long
OPCODE_EPILOG

OPCODE_PROLOG(0xF3) ; SBC (d,s),y
 _SBC Stack_Relative_Indirect_Indexed
OPCODE_EPILOG

OPCODE_PROLOG(0xFE) ; INC a,x
 RMW _INC_M,Absolute_Index_X
OPCODE_EPILOG

OPCODE_PROLOG(0xFF) ; SBC al,x
 _SBC Absolute_Long_Index_X
OPCODE_EPILOG

%undef OPCODE_PROLOG
