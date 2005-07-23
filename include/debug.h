/*

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

*/

#ifndef SNEeSe_debug_h
#define SNEeSe_debug_h

#include "misc.h"

/* #define OPCODE_TRACE_LOG */

EXTERN FILE *debug_log_file;

EXTERN void debug_init(void);


EXTERN void InvalidDMAMode(void);

EXTERN void DisplayStatus(void);
EXTERN void InvalidOpcode(void);
EXTERN void InvalidHWRead(void);
EXTERN void InvalidHWWrite(void);
EXTERN void InvalidROMWrite(void);

EXTERN void DisplaySPC(void);
EXTERN void InvalidSPCOpcode(void);
EXTERN void InvalidSPCHWRead(void);
EXTERN void InvalidSPCHWWrite(void);
EXTERN void InvalidSPCROMWrite(void);

EXTERN const char *SPC_OpID[256];


EXTERN unsigned OLD_PC;     /* Pre-NMI PB:PC */
EXTERN unsigned char OLD_PB;
EXTERN unsigned OLD_SPC_ADDRESS;
EXTERN unsigned Map_Address;
EXTERN unsigned Map_Byte;

EXTERN RGB DebugPal[];

EXTERN unsigned char DEBUG_STRING[];
EXTERN unsigned char DEBUG_VALUE1;
EXTERN unsigned char DEBUG_VALUE2;
EXTERN unsigned char DEBUG_VALUE3;
EXTERN unsigned char DEBUG_VALUE4;
EXTERN unsigned char DEBUG_VALUE5;
EXTERN unsigned char DEBUG_VALUE6;
EXTERN unsigned char DEBUG_VALUE7;
EXTERN unsigned char DEBUG_VALUE8;

EXTERN void Display_Debug(void);

#endif /* !defined(SNEeSe_debug_h) */
