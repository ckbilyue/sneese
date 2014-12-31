/*

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

*/

/*

 Debug Info Dumps
 Invalid Opcode handlers
 Invalid Bus Access handlers

*/

#include <stdio.h>
#include "wrapaleg.h"

#include "debug.h"
#include "cpu/cpu.h"
#include "apu/sound.h"
#include "apu/spc.h"
#include "helper.h"
#include "snes.h"

/* PPU.asm */
extern unsigned char BG1SC,BG2SC,BG3SC,BG4SC,BG12NBA,BG34NBA;
extern unsigned short BG1HOFS,BG2HOFS,BG3HOFS,BG4HOFS;
extern unsigned short BG1VOFS,BG2VOFS,BG3VOFS,BG4VOFS;
extern unsigned char BGMODE,OBSEL,VMAIN,TM,TS,M7SEL,SETINI,INIDISP,MOSAIC;
extern unsigned char WH0,WH1,WH2,WH3,W12SEL,W34SEL,WOBJSEL;
extern unsigned char WBGLOG,WOBJLOG,CGWSEL,CGADSUB,TMW,TSW;
extern unsigned short HiSpriteAddr;

extern unsigned char OAM[512+32];      /* Buffer for OAM */

extern unsigned M7X,M7Y,M7A,M7B,M7C,M7D;
extern unsigned char APUI00a, APUI00b, APUI00c;

extern unsigned VTIMEL, HTIMEL;

unsigned OLD_PC;    /* Pre-NMI PB:PC */
unsigned char OLD_PB;
unsigned OLD_SPC_ADDRESS;
unsigned Map_Address;
unsigned Map_Byte;


FILE *debug_log_file = 0;
int dump_flag = 0;


void debug_init(void)
{
#ifdef OPCODE_TRACE_LOG
 if (!debug_log_file) debug_log_file = fopen("h:\\spc.log", "wb");
#endif
}


/* printf wrappers for asm code */
void print_str(const char *s)
{
 printf("%s", s);
}

void print_decnum(unsigned u)
{
 printf("%u", u);
}

void print_hexnum(unsigned u, int width)
{
 printf("%0*X", width, u);
}


void InvalidDMAMode()
{
 set_gfx_mode(GFX_TEXT,0,0,0,0);

#ifdef DEBUG
 DisplayStatus();
#endif

 printf("\nUnsupported DMA mode! - 0x%02X", (unsigned) Map_Byte);
 exit(1);
}

void InvalidHWRead()
{
#ifdef DEBUG
/*
 set_gfx_mode(GFX_TEXT,0,0,0,0);
 DisplayStatus();
*/
#endif
 printf("\nRead from unsupported HW address! - %02X:%04X",
  (unsigned) ((Map_Address >> 24) & 0xFF),
  (unsigned) (Map_Address & 0xFFFFFF));
/* exit(1);*/
}

void InvalidHWWrite()
{
#ifdef DEBUG
/*
 set_gfx_mode(GFX_TEXT,0,0,0,0);
 DisplayStatus();
*/
#endif

 printf("\nWrite to unsupported HW address! - %02X:%04X with 0x%02X",
  (unsigned) ((Map_Address >> 24) & 0xFFFF),
  (unsigned) (Map_Address & 0xFFFFFF),
  (unsigned) Map_Byte);
/* exit(1);*/
}

void InvalidROMWrite()
{
 printf("\nWrite to ROM ignored - %02X:%04X with 0x%02X",
  (unsigned) ((Map_Address >> 24) & 0xFF),
  (unsigned) (Map_Address & 0xFFFFFF),
  (unsigned) Map_Byte);
}

const char *CPU_OpID[256] = {
/* 00 */ "BRK"      ,"ORA (d,x)","COP"      ,"ORA d,s"      ,
/* 04 */ "TSB d"    ,"ORA d"    ,"ASL d"    ,"ORA [d]"      ,
/* 08 */ "PHP"      ,"ORA #"    ,"SLA"      ,"PHD"          ,
/* 0C */ "TSB a"    ,"ORA a"    ,"ASL a"    ,"ORA al"       ,

/* 10 */ "BPL r"    ,"ORA (d),y","ORA (d)"  ,"ORA (d,s),y"  ,
/* 14 */ "TRB d"    ,"ORA d,x"  ,"ASL d,x"  ,"ORA [d],y"    ,
/* 18 */ "CLC"      ,"ORA a,y"  ,"INA"      ,"TCS"          ,
/* 1C */ "TRB a"    ,"ORA a,x"  ,"ASL a,x"  ,"ORA al,x"     ,

/* 20 */ "JSR a"    ,"AND (d,x)","JSL al"   ,"AND d,s"      ,
/* 24 */ "BIT d"    ,"AND d"    ,"ROL d"    ,"AND [d]"      ,
/* 28 */ "PLP"      ,"AND #"    ,"RLA"      ,"PLD"          ,
/* 2C */ "BIT a"    ,"AND a"    ,"ROL a"    ,"AND al"       ,

/* 30 */ "BMI r"    ,"AND (d),y","AND (d)"  ,"AND (d,s),y"  ,
/* 34 */ "BIT d,x"  ,"AND d,x"  ,"ROL d,x"  ,"AND [d],y"    ,
/* 38 */ "SEC"      ,"AND a,y"  ,"DEA"      ,"TSC"          ,
/* 3C */ "BIT a,x"  ,"AND a,x"  ,"ROL a,x"  ,"AND al,x"     ,

/* 40 */ "RTI"      ,"EOR (d,x)","WDM *"    ,"EOR d,s"      ,
/* 44 */ "MVP"      ,"EOR d"    ,"LSR d"    ,"EOR [d]"      ,
/* 48 */ "PHA"      ,"EOR #"    ,"SRA"      ,"PHK"          ,
/* 4C */ "JMP a"    ,"EOR a"    ,"LSR a"    ,"EOR al"       ,

/* 50 */ "BVC r"    ,"EOR (d),y","EOR (d)"  ,"EOR (d,s),y"  ,
/* 54 */ "MVN"      ,"EOR d,x"  ,"LSR d,x"  ,"EOR [d],y"    ,
/* 58 */ "CLI"      ,"EOR a,y"  ,"PHY"      ,"TCD"          ,
/* 5C */ "JML al"   ,"EOR a,x"  ,"LSR a,x"  ,"EOR al,x"     ,

/* 60 */ "RTS"      ,"ADC (d,x)","PER"      ,"ADC d,s"      ,
/* 64 */ "STZ d"    ,"ADC d"    ,"ROR d"    ,"ADC [d]"      ,
/* 68 */ "PLA"      ,"ADC #"    ,"RRA"      ,"RTL"          ,
/* 6C */ "JMP (a)"  ,"ADC a"    ,"ROR a"    ,"ADC al"       ,

/* 70 */ "BVS r"    ,"ADC (d),y","ADC (d)"  ,"ADC (d,s),y"  ,
/* 74 */ "STZ d,x"  ,"ADC d,x"  ,"ROR d,x"  ,"ADC [d],y"    ,
/* 78 */ "SEI"      ,"ADC a,y"  ,"PLY"      ,"TDC"          ,
/* 7C */ "JMP (a,x)","ADC a,x"  ,"ROR a,x"  ,"ADC al,x"     ,

/* 80 */ "BRA r"    ,"STA (d,x)","BRL rl"   ,"STA d,s"      ,
/* 84 */ "STY d"    ,"STA d"    ,"STX d"    ,"STA [d]"      ,
/* 88 */ "DEY"      ,"BIT #"    ,"TXA"      ,"PHB"          ,
/* 8C */ "STY a"    ,"STA a"    ,"STX a"    ,"STA al"       ,

/* 90 */ "BCC r"    ,"STA (d),y","STA (d)"  ,"STA (d,s),y"  ,
/* 94 */ "STY d,x"  ,"STA d,x"  ,"STX d,y"  ,"STA [d],y"    ,
/* 98 */ "TYA"      ,"STA a,y"  ,"TXS"      ,"TXY"          ,
/* 9C */ "STZ a"    ,"STA a,x"  ,"STZ a,x"  ,"STA al,x"     ,

/* A0 */ "LDY #"    ,"LDA (d,x)","LDX #"    ,"LDA d,s"      ,
/* A4 */ "LDY d"    ,"LDA d"    ,"LDX d"    ,"LDA [d]"      ,
/* A8 */ "TAY"      ,"LDA #"    ,"TAX"      ,"PLB"          ,
/* AC */ "LDY a"    ,"LDA a"    ,"LDX a"    ,"LDA al"       ,

/* B0 */ "BCS r"    ,"LDA (d),y","LDA (d)"  ,"LDA (d,s),y"  ,
/* B4 */ "LDY d,x"  ,"LDA d,x"  ,"LDX d,y"  ,"LDA [d],y"    ,
/* B8 */ "CLV"      ,"LDA a,y"  ,"TSX"      ,"TYX"          ,
/* BC */ "LDY a,x"  ,"LDA a,x"  ,"LDX a,y"  ,"LDA al,x"     ,

/* C0 */ "CPY #"    ,"CMP (d,x)","REP #"    ,"CMP d,s"      ,
/* C4 */ "CPY d"    ,"CMP d"    ,"DEC d"    ,"CMP [d]"      ,
/* C8 */ "INY"      ,"CMP #"    ,"DEX"      ,"WAI"          ,
/* CC */ "CPY a"    ,"CMP a"    ,"DEC a"    ,"CMP al"       ,

/* D0 */ "BNE r"    ,"CMP (d),y","CMP (d)"  ,"CMP (d,s),y"  ,
/* D4 */ "PEI"      ,"CMP d,x"  ,"DEC d,x"  ,"CMP [d],y"    ,
/* D8 */ "CLD"      ,"CMP a,y"  ,"PHX"      ,"STP *"        ,
/* DC */ "JML (a)"  ,"CMP a,x"  ,"DEC a,x"  ,"CMP al,x"     ,

/* E0 */ "CPX #"    ,"SBC (d,x)","SEP #"    ,"SBC d,s"      ,
/* E4 */ "CPX d"    ,"SBC d"    ,"INC d"    ,"SBC [d]"      ,
/* E8 */ "INX"      ,"SBC #"    ,"NOP"      ,"XBA"          ,
/* EC */ "CPX a"    ,"SBC a"    ,"INC a"    ,"SBC al"       ,

/* F0 */ "BEQ r"    ,"SBC (d),y","SBC (d)"  ,"SBC (d,s),y"  ,
/* F4 */ "PEA"      ,"SBC d,x"  ,"INC d,x"  ,"SBC [d],y"    ,
/* F8 */ "SED"      ,"SBC a,y"  ,"PLX"      ,"XCE"          ,
/* FC */ "JSR (a,x)","SBC a,x"  ,"INC a,x"  ,"SBC al,x"
};

extern unsigned char NMITIMEN;
extern unsigned Current_Line_Timing, EventTrip;
void DisplayStatus()
{
 char Message[10];
 int c;

 printf("\n65c816 registers\n");
 printf("PB:PC %02X:%04X",
  (unsigned) OLD_PB, OLD_PC);
 printf("  DB:D  %02X:%04X",
  (unsigned) cpu_65c816_DB, cpu_65c816_D);
 printf("  S:%04X", cpu_65c816_S);
 if (cpu_65c816_P & 0x100) printf("    ENV1BDIZC\n");
 else printf("    ENVMXDIZC\n");
 printf("A:%04X  X:%04X  Y:%04X", cpu_65c816_A, cpu_65c816_X, cpu_65c816_Y);

 for (c = 0; c < 9; c++) Message[8 - c] = (cpu_65c816_P & BIT(c)) ? '1' : '0';
 Message[9] = 0;
 printf("  Opcode:%08X %s\n", (unsigned) Map_Byte, Message);
 printf("%s\n", CPU_OpID[Map_Byte & 0xFF]);

 printf("BGSC:%02X %02X %02X %02X  BGNBA: %02X %02X\n",
  (unsigned) BG1SC, (unsigned) BG2SC,
  (unsigned) BG3SC, (unsigned) BG4SC,
  (unsigned) BG12NBA, (unsigned) BG34NBA);

 printf("HOFS:%04X %04X %04X %04X\n",
  (unsigned) (BG1HOFS & 0xFFFF), (unsigned) (BG2HOFS & 0xFFFF),
  (unsigned) (BG3HOFS & 0xFFFF), (unsigned) (BG4HOFS & 0xFFFF));
 printf("VOFS:%04X %04X %04X %04X\n",
  (unsigned) (BG1VOFS & 0xFFFF), (unsigned) (BG2VOFS & 0xFFFF),
  (unsigned) (BG3VOFS & 0xFFFF), (unsigned) (BG4VOFS & 0xFFFF));
 printf("M7:%04X %04X %04X %04X - %04X,%04X\n",
  (unsigned) (M7A & 0xFFFF), (unsigned) (M7B & 0xFFFF),
  (unsigned) (M7C & 0xFFFF), (unsigned) (M7D & 0xFFFF),
  (unsigned) (M7X & 0xFFFF), (unsigned) (M7Y & 0xFFFF));

 printf("BGMODE:%02X      TM:%02X   TMW:%02X\n",
  (unsigned) BGMODE, (unsigned) TM, (unsigned) TMW);
 printf("VMAIN:%02X       TS:%02X   TSW:%02X\n",
  (unsigned) VMAIN, (unsigned) TS, (unsigned) TSW);
 printf("WH0:%02X   WH1:%02X   WH2:%02X   WH3:%02X\n",
  (unsigned) WH0, (unsigned) WH1, (unsigned) WH2, (unsigned) WH3);
 printf("WSEL 12:%02X   34:%02X   OBJ:%02X\n",
  (unsigned) W12SEL, (unsigned) W34SEL, (unsigned) WOBJSEL);
 printf("WLOG BG:%02X\tOBJ:%02X\n",
  (unsigned) WBGLOG, (unsigned) WOBJLOG);
 printf("CGWSEL:%02X\tCGADSUB:%02X\tMOSAIC:%02X\n",
  (unsigned) CGWSEL, (unsigned) CGADSUB, (unsigned) MOSAIC);

/*
 printf("OBSEL:%02X\tHiSprite:%02X\n", (unsigned) OBSEL,
  (unsigned) (HiSpriteAddr-(unsigned) OAM) & 0x1FF);
 */
 printf("M7SEL:%02X\tSETINI:%02X\tINIDISP:%02X\n",
  (unsigned) M7SEL, (unsigned) SETINI,(unsigned) INIDISP);

 if (!SPC_ENABLED)
 {
  printf("APUI00a:%02X  APUI00b:%02X  APUI00c:%02X\n",
   (unsigned) APUI00a, (unsigned) APUI00b, (unsigned) APUI00c);
 } else {
  DisplaySPC();
 }
 printf("VTIME: %04X HTIME: %04X NMITIMEN: %02X\n",
  VTIMEL, HTIMEL, (unsigned) NMITIMEN);
 printf("Current line:%04X Next event:%04X\n",
  Current_Line_Timing, EventTrip);
}


extern unsigned char HDMAEN;
extern unsigned Current_Line_Timing;
extern unsigned char NTRL_0;
extern unsigned char NTRL_1;
extern unsigned char NTRL_2;
extern unsigned char NTRL_3;
extern unsigned char NTRL_4;
extern unsigned char NTRL_5;
extern unsigned char NTRL_6;
extern unsigned char NTRL_7;
extern unsigned char DMAP_0, DMAP_1, DMAP_2, DMAP_3;
extern unsigned char DMAP_4, DMAP_5, DMAP_6, DMAP_7;
extern unsigned char BBAD_0, BBAD_1, BBAD_2, BBAD_3;
extern unsigned char BBAD_4, BBAD_5, BBAD_6, BBAD_7;
extern unsigned char A1TL_0, A1TL_1, A1TL_2, A1TL_3;
extern unsigned char A1TL_4, A1TL_5, A1TL_6, A1TL_7;
extern unsigned char A1TH_0, A1TH_1, A1TH_2, A1TH_3;
extern unsigned char A1TH_4, A1TH_5, A1TH_6, A1TH_7;
extern unsigned char A1B_0, A1B_1, A1B_2, A1B_3;
extern unsigned char A1B_4, A1B_5, A1B_6, A1B_7;
extern unsigned char DASL_0, DASL_1, DASL_2, DASL_3;
extern unsigned char DASL_4, DASL_5, DASL_6, DASL_7;
extern unsigned char DASH_0, DASH_1, DASH_2, DASH_3;
extern unsigned char DASH_4, DASH_5, DASH_6, DASH_7;
extern unsigned char DASB_0, DASB_1, DASB_2, DASB_3;
extern unsigned char DASB_4, DASB_5, DASB_6, DASB_7;
extern unsigned char A2L_0, A2L_1, A2L_2, A2L_3;
extern unsigned char A2L_4, A2L_5, A2L_6, A2L_7;
extern unsigned char A2H_0, A2H_1, A2H_2, A2H_3;
extern unsigned char A2H_4, A2H_5, A2H_6, A2H_7;
extern unsigned char A2B_0, A2B_1, A2B_2, A2B_3;
extern unsigned char A2B_4, A2B_5, A2B_6, A2B_7;
extern unsigned Frames;

int dumping_dma = 0;

void Dump_Read(int a)
{
 printf("read: %04X\n", a & 0xFFFF);
}

void Dump_Write(int a, unsigned char b)
{
 printf("write: %04X, %02X\n", a & 0xFFFF, (unsigned) b);
}

void Dump_DMA(int b)
{
 if (!dumping_dma && !(b & ~0xFF)) return;

 switch (b)
 {
  case 0:
   printf("Frame %d\n", Frames);
   break;
  case 1:
   printf("HDMA relatch\n");
   break;
  case 2:
   printf("HDMA line %d\n", Current_Line_Timing);
   break;
  default:
   printf("DMA %d executed at line %d\n", b & 0xFF, Current_Line_Timing);
 }

 if (!(b & ~0xFF))
 {
  printf("HDMAEN:%02X\n", (unsigned) HDMAEN);
 }

 if (!(b & ~0xFF) || b & BIT(0))
 {
  printf("%02X %02X %02X %02X%02X%02X %02X%02X%02X %02X%02X%02X\n",
   (unsigned) DMAP_0,(unsigned) BBAD_0,(unsigned) NTRL_0,
   (unsigned) A1B_0,(unsigned) A1TH_0,(unsigned) A1TL_0,
   (unsigned) A2B_0,(unsigned) A2H_0,(unsigned) A2L_0,
   (unsigned) DASB_0,(unsigned) DASH_0,(unsigned) DASL_0);
 }

 if (!(b & ~0xFF) || b & BIT(1))
 {
  printf("%02X %02X %02X %02X%02X%02X %02X%02X%02X %02X%02X%02X\n",
   (unsigned) DMAP_1,(unsigned) BBAD_1,(unsigned) NTRL_1,
   (unsigned) A1B_1,(unsigned) A1TH_1,(unsigned) A1TL_1,
   (unsigned) A2B_1,(unsigned) A2H_1,(unsigned) A2L_1,
   (unsigned) DASB_1,(unsigned) DASH_1,(unsigned) DASL_1);
 }

 if (!(b & ~0xFF) || b & BIT(2))
 {
  printf("%02X %02X %02X %02X%02X%02X %02X%02X%02X %02X%02X%02X\n",
   (unsigned) DMAP_2,(unsigned) BBAD_2,(unsigned) NTRL_2,
   (unsigned) A1B_2,(unsigned) A1TH_2,(unsigned) A1TL_2,
   (unsigned) A2B_2,(unsigned) A2H_2,(unsigned) A2L_2,
   (unsigned) DASB_2,(unsigned) DASH_2,(unsigned) DASL_2);
 }

 if (!(b & ~0xFF) || b & BIT(3))
 {
  printf("%02X %02X %02X %02X%02X%02X %02X%02X%02X %02X%02X%02X\n",
   (unsigned) DMAP_3,(unsigned) BBAD_3,(unsigned) NTRL_3,
   (unsigned) A1B_3,(unsigned) A1TH_3,(unsigned) A1TL_3,
   (unsigned) A2B_3,(unsigned) A2H_3,(unsigned) A2L_3,
   (unsigned) DASB_3,(unsigned) DASH_3,(unsigned) DASL_3);
 }

 if (!(b & ~0xFF) || b & BIT(4))
 {
  printf("%02X %02X %02X %02X%02X%02X %02X%02X%02X %02X%02X%02X\n",
   (unsigned) DMAP_4,(unsigned) BBAD_4,(unsigned) NTRL_4,
   (unsigned) A1B_4,(unsigned) A1TH_4,(unsigned) A1TL_4,
   (unsigned) A2B_4,(unsigned) A2H_4,(unsigned) A2L_4,
   (unsigned) DASB_4,(unsigned) DASH_4,(unsigned) DASL_4);
 }

 if (!(b & ~0xFF) || b & BIT(5))
 {
  printf("%02X %02X %02X %02X%02X%02X %02X%02X%02X %02X%02X%02X\n",
   (unsigned) DMAP_5,(unsigned) BBAD_5,(unsigned) NTRL_5,
   (unsigned) A1B_5,(unsigned) A1TH_5,(unsigned) A1TL_5,
   (unsigned) A2B_5,(unsigned) A2H_5,(unsigned) A2L_5,
   (unsigned) DASB_5,(unsigned) DASH_5,(unsigned) DASL_5);
 }

 if (!(b & ~0xFF) || b & BIT(6))
 {
  printf("%02X %02X %02X %02X%02X%02X %02X%02X%02X %02X%02X%02X\n",
   (unsigned) DMAP_6,(unsigned) BBAD_6,(unsigned) NTRL_6,
   (unsigned) A1B_6,(unsigned) A1TH_6,(unsigned) A1TL_6,
   (unsigned) A2B_6,(unsigned) A2H_6,(unsigned) A2L_6,
   (unsigned) DASB_6,(unsigned) DASH_6,(unsigned) DASL_6);
 }

 if (!(b & ~0xFF) || b & BIT(7))
 {
  printf("%02X %02X %02X %02X%02X%02X %02X%02X%02X %02X%02X%02X\n",
   (unsigned) DMAP_7,(unsigned) BBAD_7,(unsigned) NTRL_7,
   (unsigned) A1B_7,(unsigned) A1TH_7,(unsigned) A1TL_7,
   (unsigned) A2B_7,(unsigned) A2H_7,(unsigned) A2L_7,
   (unsigned) DASB_7,(unsigned) DASH_7,(unsigned) DASL_7);
 }
}

void InvalidOpcode()
{
 set_gfx_mode(GFX_TEXT,0,0,0,0);

#ifdef DEBUG
 DisplayStatus();
#endif

 printf("Unemulated 65c816 opcode 0x%02X (%s)\n",
  (unsigned) Map_Byte, CPU_OpID[Map_Byte]);
 printf("At address %02X:%04X\n",(unsigned) ((Map_Address >> 24) & 0xFF),
  (unsigned) (Map_Address & 0xFFFFFF));

 save_debug_dumps();

 exit(1);
}

void InvalidJump()
{
 set_gfx_mode(GFX_TEXT,0,0,0,0);

#ifdef DEBUG
 DisplayStatus();
#endif

 printf("65c816 jump to non-linear mapped address space (%02X:%04X)\n",
  (unsigned) ((Map_Address >> 16) & 0xFF), (unsigned) (Map_Address & 0xFFFF));
 printf("Opcode %02X at address %02X:%04X\n",
  (unsigned) ((Map_Byte >> 24) & 0xFF),
  (unsigned) ((Map_Byte >> 16) & 0xFF), (unsigned) (Map_Byte & 0xFFFF));

 save_debug_dumps();

 exit(1);
}

void InvalidSPCHWRead()
{
 printf("\nRead from unsupported SPC HW address! - %04X",
  (unsigned) (Map_Address & 0xFFFF));
}

void InvalidSPCHWWrite()
{
 printf("\nWrite to unsupported SPC HW address! - %04X with 0x%02X",
  (unsigned) (Map_Address & 0xFFFF),
  (unsigned) Map_Byte);
}

void InvalidSPCROMWrite()
{
 printf("\nWrite to SPC ROM ignored - %04X with 0x%02X",
  (unsigned) (Map_Address & 0xFFFF),
  (unsigned) Map_Byte);
}

const char *SPC_OpID[256] = {
 "NOP"            ,"TCALL 0"        ,"SET1 dp.0"      ,"BBS dp.0,rel"   ,
 "OR A,dp"        ,"OR A,labs"      ,"OR A,(X)"       ,"OR A,(dp+X)"    ,
 "OR A,#imm"      ,"OR dp(d),dp(s)" ,"OR1 C,mem.bit"  ,"ASL dp"         ,
 "ASL labs"       ,"PUSH PSW"       ,"TSET1 labs"     ,"BRK"            ,

 "BPL rel"        ,"TCALL 1"        ,"CLR1 dp.0"      ,"BBC dp.0,rel"   ,
 "OR A,dp+X"      ,"OR A,labs+X"    ,"OR A,labs+Y"    ,"OR A,(dp)+Y"    ,
 "OR dp,#imm"     ,"OR (X),(Y)"     ,"DECW dp"        ,"ASL dp+X"       ,
 "ASL A"          ,"DEC X"          ,"CMP X,labs"     ,"JMP (abs,x)"    ,

 "CLRP"           ,"TCALL 2"        ,"SET1 dp.1"      ,"BBS dp.1,rel"   ,
 "AND A,dp"       ,"AND A,labs"     ,"AND A,(X)"      ,"AND A,(dp+X)"   ,
 "AND A,#imm"     ,"AND dp(d),dp(s)","OR1 C,/mem.bit" ,"ROL dp"         ,
 "ROL labs"       ,"PUSH A"         ,"CBNE dp"        ,"BRA rel"        ,

 "BMI rel"        ,"TCALL 3"        ,"CLR1 dp.1"      ,"BBC dp.1,rel"   ,
 "AND A,dp+X"     ,"AND A,labs+X"   ,"AND A,labs+Y"   ,"AND A,(dp)+Y"   ,
 "AND dp,#imm"    ,"AND (X),(Y)"    ,"INCW dp"        ,"ROL dp+X"       ,
 "ROL A"          ,"INC X"          ,"CMP X,dp"       ,"CALL labs"      ,

 "SETP"           ,"TCALL 4"        ,"SET1 dp.2"      ,"BBS dp.2,rel"   ,
 "EOR A,dp"       ,"EOR A,labs"     ,"EOR A,(X)"      ,"EOR A,(dp+X)"   ,
 "EOR A,#imm"     ,"EOR dp(d),dp(s)","AND1 C,mem.bit" ,"LSR dp"         ,
 "LSR labs"       ,"PUSH X"         ,"TCLR1 labs"     ,"PCALL upage"    ,

 "BVC rel"        ,"TCALL 5"        ,"CLR1 dp.2"      ,"BBC dp.2,rel"   ,
 "EOR A,dp+X"     ,"EOR A,labs+X"   ,"EOR A,labs+Y"   ,"EOR A,(dp)+Y"   ,
 "EOR dp,#imm"    ,"EOR (X),(Y)"    ,"CMPW YA,dp"     ,"LSR dp+X"       ,
 "LSR A"          ,"MOV X,A"        ,"CMP Y,labs"     ,"JMP labs"       ,

 "CLRC"           ,"TCALL 6"        ,"SET1 dp.3"      ,"BBS dp.3,rel"   ,
 "CMP A,dp"       ,"CMP A,labs"     ,"CMP A,(X)"      ,"CMP A,(dp+X)"   ,
 "CMP A,#imm"     ,"CMP dp(d),dp(s)","AND1 C,/mem.bit","ROR dp"         ,
 "ROR labs"       ,"PUSH Y"         ,"DBNZ dp,rel"    ,"RET"            ,

 "BVS rel"        ,"TCALL 7"        ,"CLR1 dp.3"      ,"BBC dp.3,rel"   ,
 "CMP A,dp+X"     ,"CMP A,labs+X"   ,"CMP A,labs+Y"   ,"CMP A,(dp)+Y"   ,
 "CMP dp,#imm"    ,"CMP (X),(Y)"    ,"ADDW YA,dp"     ,"ROR dp+X"       ,
 "ROR A"          ,"MOV A,X"        ,"CMP Y,dp"       ,"RETI"           ,

 "SETC"           ,"TCALL 8"        ,"SET1 dp.4"      ,"BBS dp.4,rel"   ,
 "ADC A,dp"       ,"ADC A,labs"     ,"ADC A,(X)"      ,"ADC A,(dp+X)"   ,
 "ADC A,#imm"     ,"ADC dp(d),dp(s)","EOR1 C,mem.bit" ,"DEC dp"         ,
 "DEC labs"       ,"MOV Y,#imm"     ,"POP PSW"        ,"MOV dp,#imm"    ,

 "BCC rel"        ,"TCALL 9"        ,"CLR1 dp.4"      ,"BBC dp.4,rel"   ,
 "ADC A,dp+X"     ,"ADC A,labs+X"   ,"ADC A,labs+Y"   ,"ADC A,(dp)+Y"   ,
 "ADC dp,#imm"    ,"ADC (X),(Y)"    ,"SUBW YA,dp"     ,"DEC dp+X"       ,
 "DEC A"          ,"MOV X,SP"       ,"DIV YA,X"       ,"XCN A"          ,

 "EI"             ,"TCALL 10"       ,"SET1 dp.5"      ,"BBS dp.5,rel"   ,
 "SBC A,dp"       ,"SBC A,labs"     ,"SBC A,(X)"      ,"SBC A,(dp+X)"   ,
 "SBC A,#imm"     ,"SBC dp(d),dp(s)","MOV1 C,mem.bit" ,"INC dp"         ,
 "INC labs"       ,"CMP Y,#imm"     ,"POP A"          ,"MOV (X)+,A"     ,

 "BCS rel"        ,"TCALL 11"       ,"CLR1 dp.5"      ,"BBC dp.5,rel"   ,
 "SBC A,dp+X"     ,"SBC A,labs+X"   ,"SBC A,labs+Y"   ,"SBC A,(dp)+Y"   ,
 "SBC dp,#imm"    ,"SBC (X),(Y)"    ,"MOVW YA,dp"     ,"INC dp+X"       ,
 "INC A"          ,"MOV SP,X"       ,"DAS A"          ,"MOV A,(X)+"     ,

 "DI"             ,"TCALL 12"       ,"SET1 dp.6"      ,"BBS dp.6,rel"   ,
 "MOV dp,A"       ,"MOV labs,A"     ,"MOV (X),A"      ,"MOV (dp+X),A"   ,
 "CMP X,#imm"     ,"MOV labs,X"     ,"MOV1 mem.bit,C" ,"MOV dp,Y"       ,
 "MOV labs,Y"     ,"MOV X,#imm"     ,"POP X"          ,"MUL YA"         ,

 "BNE rel"        ,"TCALL 13"       ,"CLR1 dp.6"      ,"BBC dp.6,rel"   ,
 "MOV dp+X,A"     ,"MOV labs+X,A"   ,"MOV labs+Y,A"   ,"MOV (dp)+Y,A"   ,
 "MOV dp,X"       ,"MOV dp+Y,X"     ,"MOVW dp,YA"     ,"MOV dp+X,Y"     ,
 "DEC Y"          ,"MOV A,Y"        ,"CBNE dp+X,rel"  ,"DAA A"          ,

 "CLRV"           ,"TCALL 14"       ,"SET1 dp.7"      ,"BBS dp.7,rel"   ,
 "MOV A,dp"       ,"MOV A,labs"     ,"MOV A,(X)"      ,"MOV A,(dp+X)"   ,
 "MOV A,#imm"     ,"MOV X,labs"     ,"NOT1 mem.bit"   ,"MOV Y,dp"       ,
 "MOV Y,labs"     ,"NOTC"           ,"POP Y"          ,"SLEEP"          ,

 "BEQ rel"        ,"TCALL 15"       ,"CLR1 dp.7"      ,"BBC dp.7,rel"   ,
 "MOV A,dp+X"     ,"MOV A,labs+X"   ,"MOV A,labs+Y"   ,"MOV A,(dp)+Y"   ,
 "MOV X,dp"       ,"MOV X,dp+Y"     ,"MOV dp(d),dp(s)","MOV Y,dp+X"     ,
 "INC Y"          ,"MOV Y,A"        ,"DBNZ Y,rel"     ,"STOP"
};

void DisplaySPC()
{
 char Message[9];
 int c;

 printf("SPC registers\n");
 printf("PC:%04X  SP:%04X  NVPBHIZC\n", _SPC_PC, _SPC_SP);

 _SPC_PSW = get_SPC_PSW();
 for (c = 0; c < 8; c++) Message[7 - c] = (_SPC_PSW & BIT(c)) ? '1' : '0';
 Message[8] = 0;

 printf("A:%02X  X:%02X  Y:%02X  %s\n",
  (unsigned) _SPC_A, (unsigned) _SPC_X, (unsigned) _SPC_Y, Message);

 printf("SPC R  0:%02X  1:%02X  2:%02X  3:%02X\n",
  (unsigned) SPC_PORT0R, (unsigned) SPC_PORT1R,
  (unsigned) SPC_PORT2R, (unsigned) SPC_PORT3R);
 printf("SPC W  0:%02X  1:%02X  2:%02X  3:%02X\n",
  (unsigned) SPC_PORT0W, (unsigned) SPC_PORT1W,
  (unsigned) SPC_PORT2W, (unsigned) SPC_PORT3W);
 printf("SPC counters:%1X %1X %1X targets:%02X %02X %02X CTRL:%02X\n",
  SPC_T0_counter, SPC_T1_counter, SPC_T2_counter,
  SPC_T0_target & 0xFF, SPC_T1_target & 0xFF, SPC_T2_target & 0xFF,
  SPC_CTRL);
}

/* Simple at present... register dump will be done l8r */
void InvalidSPCOpcode()
{
 set_gfx_mode(GFX_TEXT,0,0,0,0);

 DisplaySPC();

 printf("Unemulated SPC opcode 0x%02X (%s)\n",
  (unsigned) Map_Byte, SPC_OpID[Map_Byte]);
 printf("At address 0x%04X\n", (unsigned) (Map_Address & 0xFFFF));

#ifdef DEBUG
 printf("Old Address 0x%04X\n", OLD_SPC_ADDRESS);
 save_debug_dumps();
#endif

 exit(1);
}

RGB DebugPal[]={{63,63,63,0}};

unsigned char DEBUG_STRING[]="Voice : %d";

unsigned char DEBUG_VALUE1=0;
unsigned char DEBUG_VALUE2=0;
unsigned char DEBUG_VALUE3=0;
unsigned char DEBUG_VALUE4=0;
unsigned char DEBUG_VALUE5=0;
unsigned char DEBUG_VALUE6=0;
unsigned char DEBUG_VALUE7=0;
unsigned char DEBUG_VALUE8=0;

extern unsigned Timer_Counter_Throttle;
void Display_Debug()
{
/*
 set_palette_range(&DebugPal[-255],255,255,TRUE);   // Set the GUI palette up.
 textprintf(screen,font,50,50,255,"Throttle: %u",Timer_Counter_Throttle);
 textprintf(screen,font,50,50,255,DEBUG_STRING,(int)DEBUG_VALUE1);
 textprintf(screen,font,50,60,255,DEBUG_STRING,(int)DEBUG_VALUE2);
 textprintf(screen,font,50,70,255,DEBUG_STRING,(int)DEBUG_VALUE3);
 textprintf(screen,font,50,80,255,DEBUG_STRING,(int)DEBUG_VALUE4);
 textprintf(screen,font,50,90,255,DEBUG_STRING,(int)DEBUG_VALUE5);
 textprintf(screen,font,50,100,255,DEBUG_STRING,(int)DEBUG_VALUE6);
 textprintf(screen,font,50,110,255,DEBUG_STRING,(int)DEBUG_VALUE7);
 textprintf(screen,font,50,120,255,DEBUG_STRING,(int)DEBUG_VALUE8);
 */
}

void opcode_trace_5A22(unsigned char opcode)
{
 if (!debug_log_file) return;
 if (!dump_flag)
 {
/*
  if (cpu_65c816_PB == 0x00 && cpu_65c816_PC == 0x81F7) dump_flag = 1;
  else
 */
   return;
 }
 fprintf(debug_log_file, "%s DB:%02X D:%04X S:%04X X:%04X Y:%04X A:%04X PB:PC %02X:%04X Op:%02X\n",
   cpu_65c816_P & 0x100 ? "ENVB1DIZC" : "ENVMXDIZC",
   cpu_65c816_DB & 0xFF, cpu_65c816_D & 0xFFFF, cpu_65c816_S & 0xFFFF,
   cpu_65c816_X & 0xFFFF, cpu_65c816_Y & 0xFFFF, cpu_65c816_A & 0xFFFF,
   cpu_65c816_PB & 0xFF, cpu_65c816_PC & 0xFFFF, opcode & 0xFF);
 fprintf(debug_log_file, "%c%c%c%c%c%c%c%c%c %s\n",
   cpu_65c816_P & 0x100 ? '1' : '0',
   cpu_65c816_P & 0x80 ? '1' : '0', cpu_65c816_P & 0x40 ? '1' : '0',
   cpu_65c816_P & 0x20 ? '1' : '0', cpu_65c816_P & 0x10 ? '1' : '0',
   cpu_65c816_P & 0x08 ? '1' : '0', cpu_65c816_P & 0x04 ? '1' : '0',
   cpu_65c816_P & 0x02 ? '1' : '0', cpu_65c816_P & 0x01 ? '1' : '0',
   CPU_OpID[opcode]);
}


void check_op(unsigned pbpc, unsigned cycles, unsigned mode,
 unsigned event_handler, unsigned event_trip,
 unsigned fixed_handler, unsigned fixed_trip)
{
 if (key[KEY_M])
 {
  printf("%06X @ %3d - %3d - %08X @ %5d, %08X @ %5d\n",
   pbpc & BITMASK(0,23), cycles, mode,
   event_handler, event_trip,
   fixed_handler, fixed_trip);
 }
}
