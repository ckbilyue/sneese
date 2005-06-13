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

#ifndef SNEeSe_apu_spc_h
#define SNEeSe_apu_spc_h

#include "../misc.h"

#define SPC_CTRL SPCRAM[0xF1]
#define SPC_DSP_ADDR SPCRAM[0xF2]

EXTERN void SPC_START(unsigned cycles);
EXTERN void Make_SPC(void);
EXTERN void Reset_SPC(void);
EXTERN unsigned char get_SPC_PSW(void);
/*
EXTERN unsigned char SPC_PORT0R, SPC_PORT1R, SPC_PORT2R, SPC_PORT3R;
EXTERN unsigned char SPC_PORT0W, SPC_PORT1W, SPC_PORT2W, SPC_PORT3W;
EXTERN unsigned _SPC_PC, _SPC_SP, _SPC_YA;
EXTERN unsigned char _SPC_A, _SPC_Y, _SPC_X, _SPC_PSW;
EXTERN unsigned char SPC_ROM_CODE[64];

EXTERN unsigned TotalCycles;

EXTERN unsigned SPC_T0_cycle_latch;
EXTERN unsigned SPC_T0_position, SPC_T0_target;

EXTERN unsigned SPC_T1_cycle_latch;
EXTERN unsigned SPC_T1_position, SPC_T1_target;

EXTERN unsigned SPC_T2_cycle_latch;
EXTERN unsigned SPC_T2_position, SPC_T2_target;

EXTERN unsigned char SPC_T0_counter, SPC_T1_counter, SPC_T2_counter;

EXTERN unsigned SPC_Cycles;
*/

typedef struct
{
  unsigned cycle_latch;
  short position;
  short target;
  unsigned char counter;
} SPC700_TIMER;

typedef union
{
  unsigned short w;

  struct
  {
    unsigned char l;
    unsigned char h;
  } b;
} word_2b;

typedef struct
{
  /* Number of cycles to execute for SPC */
  unsigned Cycles;
  unsigned last_cycles;

  unsigned TotalCycles;
  int WorkCycles;

  unsigned char PORT_R[4];

  unsigned char PORT_W[4];

  void *FFC0_Address;

  word_2b PC;
  word_2b YA;
  word_2b address;
  word_2b address2;
  word_2b direct_page;
  word_2b data16;
  unsigned char SP;
  unsigned char X;
  unsigned char cycle;

  unsigned char opcode;
  unsigned char data;
  unsigned char data2;
  unsigned char offset;

  /* Processor status word */
  unsigned char PSW;

  unsigned char N_flag, V_flag, P_flag, B_flag;
  unsigned char H_flag, I_flag, Z_flag, C_flag;

  SPC700_TIMER timers[3];

} SPC700_CONTEXT;

extern SPC700_CONTEXT *active_context;


#ifndef SNEeSe_apu_spc700_c
#define SPC_T0_cycle_latch  (active_context->timers[0].cycle_latch)
#define SPC_T0_position     (active_context->timers[0].position)
#define SPC_T0_target       (active_context->timers[0].target)
#define SPC_T0_counter      (active_context->timers[0].counter)

#define SPC_T1_cycle_latch  (active_context->timers[1].cycle_latch)
#define SPC_T1_position     (active_context->timers[1].position)
#define SPC_T1_target       (active_context->timers[1].target)
#define SPC_T1_counter      (active_context->timers[1].counter)

#define SPC_T2_cycle_latch  (active_context->timers[2].cycle_latch)
#define SPC_T2_position     (active_context->timers[2].position)
#define SPC_T2_target       (active_context->timers[2].target)
#define SPC_T2_counter      (active_context->timers[2].counter)

#define TotalCycles         (active_context->TotalCycles)

#define SPC_PORT0R          (active_context->PORT_R[0])
#define SPC_PORT1R          (active_context->PORT_R[1])
#define SPC_PORT2R          (active_context->PORT_R[2])
#define SPC_PORT3R          (active_context->PORT_R[3])

#define SPC_PORT0W          (active_context->PORT_W[0])
#define SPC_PORT1W          (active_context->PORT_W[1])
#define SPC_PORT2W          (active_context->PORT_W[2])
#define SPC_PORT3W          (active_context->PORT_W[3])

#define _SPC_PC             (active_context->PC.w)
#define _SPC_SP             (active_context->SP)
#define _SPC_YA             (active_context->YA.w)
#define _SPC_A              (active_context->YA.b.l)
#define _SPC_Y              (active_context->YA.b.h)
#define _SPC_X              (active_context->X)
#define _SPC_PSW            (active_context->PSW)

#define SPC_Cycles          (active_context->Cycles)

#endif /* !defined(SNEeSe_apu_spc700_c) */


#endif /* !defined(SNEeSe_apu_spc_h) */
