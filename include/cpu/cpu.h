/*

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2004 Charles Bilyue'.
Portions Copyright (c) 2003-2004 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

*/

#ifndef SNEeSe_cpu_cpu_h
#define SNEeSe_cpu_cpu_h

#include "../misc.h"

EXTERN void Reset_CPU(void);
EXTERN void Do_CPU(void);

/* Interrupt vectors */
EXTERN unsigned NMI_Nvector,NMI_Evector;
EXTERN unsigned IRQ_Nvector,IRQ_Evector;
EXTERN unsigned COP_Nvector,COP_Evector;
EXTERN unsigned BRK_Nvector;

/* CPU registers and etc. */
EXTERN unsigned cpu_65c816_X;
EXTERN unsigned cpu_65c816_Y;   // X and Y indices
EXTERN unsigned cpu_65c816_A;   // Accumulator
EXTERN unsigned cpu_65c816_P;   // Flags register
EXTERN unsigned cpu_65c816_S;   // Stack pointer
EXTERN unsigned cpu_65c816_D;   // Direct Address
EXTERN unsigned cpu_65c816_PC;  // Program counter
EXTERN unsigned cpu_65c816_DB_Shifted;
EXTERN unsigned cpu_65c816_PB_Shifted;
#define cpu_65c816_DB ((unsigned char) (cpu_65c816_DB_Shifted >> 16))
#define cpu_65c816_PB ((unsigned char) (cpu_65c816_PB_Shifted >> 16))

EXTERN signed char FPS_ENABLED;
EXTERN unsigned char BREAKS_ENABLED;
EXTERN unsigned LastRenderLine;
EXTERN unsigned LastVBLLine;

#endif /* !defined(SNEeSe_cpu_cpu_h) */
