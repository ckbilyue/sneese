/*

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2003 Charles Bilyue'.
Portions Copyright (c) 2003 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

*/

#ifndef SNEeSe_mem_h
#define SNEeSe_mem_h

#include "../misc.h"

// memblank.asm
EXTERN void (*Read_Bank8Mapping[256*8])(void);
EXTERN void (*Write_Bank8Mapping[256*8])(void);
EXTERN void *Read_Bank8Offset[256*8];
EXTERN void *Write_Bank8Offset[256*8];
EXTERN char Dummy[65536];

EXTERN void Read_Direct_Safeguard(void), Write_Direct_Safeguard(void);
EXTERN void UNSUPPORTED_READ(void),UNSUPPORTED_WRITE(void);
EXTERN void IGNORE_WRITE(void);
EXTERN void RAM_READ(void),RAM_WRITE(void);
EXTERN void PPU_READ(void),PPU_WRITE(void);

EXTERN void READ_00_3F_No_SRAM(void),READ_80_BF_No_SRAM(void);
EXTERN void WRITE_00_3F(void),WRITE_80_BF(void);
EXTERN void HWRITE_00_3F_No_SRAM(void),HWRITE_80_BF_No_SRAM(void);

EXTERN void BlankL_00_3F(void),BlankH_00_3F_No_SRAM(void);
EXTERN void BlankL_80_BF(void),BlankH_80_BF_No_SRAM(void);
EXTERN void BlankL_40_6F(void),BlankL_C0_FF(void);
EXTERN void BlankH_40_7D(void),BlankH_C0_FF(void);

// memlo.asm
EXTERN unsigned LoROM_Write[256];
EXTERN void SRAM_READ(void),SRAM_WRITE(void),SRAM_WRITE_HIROM(void);
EXTERN void SRAM_WRITE_ALT(void);
EXTERN void SRAM_WRITE_2k(void),SRAM_WRITE_4k(void);
EXTERN void READ_00_3F_2(void),READ_40_6F_2(void);
EXTERN void READ_80_BF_2(void),READ_C0_FF_2(void);

// memhi.asm
EXTERN void HWRITE_3X_BX_2k(void),HWRITE_3X_BX_4k(void);
EXTERN void (*HiROM_Read[256])(void),(*HiROM_Write[256])(void);
EXTERN void (*HiROM_Read_SRAM_ROM_30[8])(void);
EXTERN void (*HiROM_Read_SRAM_ROM_B0[8])(void);
EXTERN void (*HiROM_Read_SRAM_Blank_30[8])(void);
EXTERN void (*HiROM_Read_SRAM_Blank_B0[8])(void);
EXTERN void (*HiROM_Write_SRAM_30[8])(void);
EXTERN void (*HiROM_Write_SRAM_B0[8])(void);
EXTERN void (*HiROM_Read_No_SRAM_ROM_30)(void);
EXTERN void (*HiROM_Read_No_SRAM_ROM_B0)(void);
EXTERN void (*HiROM_Read_No_SRAM_Blank_30)(void);
EXTERN void (*HiROM_Read_No_SRAM_Blank_B0)(void);
EXTERN void (*HiROM_Write_No_SRAM_30)(void);
EXTERN void (*HiROM_Write_No_SRAM_B0)(void);
EXTERN void HREAD_40_7D(void),HREAD_C0_FF(void);

#endif /* !defined(SNEeSe_mem_h) */
