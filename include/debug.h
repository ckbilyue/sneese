/*

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2003 Charles Bilyue'.
Portions Copyright (c) 2003 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

*/

#ifndef SNEeSe_debug_h
#define SNEeSe_debug_h

#include "misc.h"

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
