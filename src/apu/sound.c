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

#include <stdio.h>
#include <string.h>

#include "wrapaleg.h"

#include "helper.h"
#include "apu/sound.h"
#include "apu/sounddef.h"
#include "apu/spc.h"

//#define NO_PITCH_MODULATION /* do not remove - needs to be fixed */
//#define FAULT_ON_PITCH_MODULATION_USE

#define DSP_SPEED_HACK
//#define DUMP_SOUND

#define ZERO_ENVX_ON_VOICE_OFF
#define ZERO_OUTX_ON_VOICE_OFF

//#define LOG_SOUND_DSP_READ
//#define LOG_SOUND_DSP_WRITE
//#define LOG_SOUND_VOICE_OFF

#define MASK_PITCH_H

//#define DISALLOW_ENVX_OUTX_WRITE

#define ZERO_ENVX_ON_KEY_ON

typedef enum {
 ATTACK,    /* A of ADSR */
 DECAY,     /* D of ADSR */
 SUSTAIN,   /* S of ADSR */
 RELEASE,   /* R of ADSR */
 DECREASE,  /* GAIN linear decrease mode */
 EXP,       /* GAIN exponential decrease mode */
 INCREASE,  /* GAIN linear increase mode */
 BENT,      /* GAIN bent line increase mode */
 DIRECT,    /* Directly specify ENVX */
 VOICE_OFF  /* Voice is not playing */
} ENVSTATE;

extern unsigned char SPCRAM[65536];

unsigned char SPC_MASK;
unsigned SPC_DSP_DATA;
signed char sound_enabled;
int sound_bits;
signed char sound_echo_enabled = TRUE;
signed char sound_gauss_enabled = TRUE;

unsigned sound_cycle_latch;
unsigned sound_output_position;
unsigned sound_sample_latch;

static SNEESE_AUDIO_VOICE audio_voice = NULL_AUDIO_VOICE;
static void *sound_buffer_preload = NULL;
static output_sample_16 *noise_buffer = NULL;
static signed char *outx_buffer = NULL;    /* for pitch modulation */
static int *mix_buffer = NULL;
static signed char block_written;
#ifdef DUMP_SOUND
static signed char block_dumped;
#endif

signed char ENVX_ENABLED = -1;

unsigned char SPC_DSP[256];

// INTERNAL (static) STUFF

int main_lvol, main_rvol, main_jvol;
int echo_lvol, echo_rvol, echo_jvol;
unsigned short echo_base, echo_delay, echo_address;
int echo_feedback;
int FIR_taps[8][2];
/* FIR_coeff[0] = C7, FIR_coeff[7] = C0 */
int FIR_coeff[8];
int FIR_address;

static struct voice_state {
    short buf[4];
    short last1, last2;
    unsigned short sample_start_address;
    unsigned envx;
    unsigned env_sample_latch, voice_sample_latch, env_update_count;
    unsigned ar, dr, sl, sr;
    unsigned gain_update_count;
    int env_counter;
    int lvol, rvol, jvol;
    int outx;
    int brr_samples_left;
    unsigned step;
    int pitch_counter;
    int bufptr;
    unsigned brrptr;
    unsigned char brr_header, env_state, adsr_state, key_wait;
} SNDvoices[8];

unsigned char SNDkeys, keying_on;

static const short gauss[]={
	0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 
	0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 
	0x001, 0x001, 0x001, 0x001, 0x001, 0x001, 0x001, 0x001, 
	0x001, 0x001, 0x001, 0x002, 0x002, 0x002, 0x002, 0x002, 
	0x002, 0x002, 0x003, 0x003, 0x003, 0x003, 0x003, 0x004, 
	0x004, 0x004, 0x004, 0x004, 0x005, 0x005, 0x005, 0x005, 
	0x006, 0x006, 0x006, 0x006, 0x007, 0x007, 0x007, 0x008, 
	0x008, 0x008, 0x009, 0x009, 0x009, 0x00A, 0x00A, 0x00A, 
	0x00B, 0x00B, 0x00B, 0x00C, 0x00C, 0x00D, 0x00D, 0x00E, 
	0x00E, 0x00F, 0x00F, 0x00F, 0x010, 0x010, 0x011, 0x011, 
	0x012, 0x013, 0x013, 0x014, 0x014, 0x015, 0x015, 0x016, 
	0x017, 0x017, 0x018, 0x018, 0x019, 0x01A, 0x01B, 0x01B, 
	0x01C, 0x01D, 0x01D, 0x01E, 0x01F, 0x020, 0x020, 0x021, 
	0x022, 0x023, 0x024, 0x024, 0x025, 0x026, 0x027, 0x028, 
	0x029, 0x02A, 0x02B, 0x02C, 0x02D, 0x02E, 0x02F, 0x030, 
	0x031, 0x032, 0x033, 0x034, 0x035, 0x036, 0x037, 0x038, 
	0x03A, 0x03B, 0x03C, 0x03D, 0x03E, 0x040, 0x041, 0x042, 
	0x043, 0x045, 0x046, 0x047, 0x049, 0x04A, 0x04C, 0x04D, 
	0x04E, 0x050, 0x051, 0x053, 0x054, 0x056, 0x057, 0x059, 
	0x05A, 0x05C, 0x05E, 0x05F, 0x061, 0x063, 0x064, 0x066, 
	0x068, 0x06A, 0x06B, 0x06D, 0x06F, 0x071, 0x073, 0x075, 
	0x076, 0x078, 0x07A, 0x07C, 0x07E, 0x080, 0x082, 0x084, 
	0x086, 0x089, 0x08B, 0x08D, 0x08F, 0x091, 0x093, 0x096, 
	0x098, 0x09A, 0x09C, 0x09F, 0x0A1, 0x0A3, 0x0A6, 0x0A8, 
	0x0AB, 0x0AD, 0x0AF, 0x0B2, 0x0B4, 0x0B7, 0x0BA, 0x0BC, 
	0x0BF, 0x0C1, 0x0C4, 0x0C7, 0x0C9, 0x0CC, 0x0CF, 0x0D2, 
	0x0D4, 0x0D7, 0x0DA, 0x0DD, 0x0E0, 0x0E3, 0x0E6, 0x0E9, 
	0x0EC, 0x0EF, 0x0F2, 0x0F5, 0x0F8, 0x0FB, 0x0FE, 0x101, 
	0x104, 0x107, 0x10B, 0x10E, 0x111, 0x114, 0x118, 0x11B, 
	0x11E, 0x122, 0x125, 0x129, 0x12C, 0x130, 0x133, 0x137, 
	0x13A, 0x13E, 0x141, 0x145, 0x148, 0x14C, 0x150, 0x153, 
	0x157, 0x15B, 0x15F, 0x162, 0x166, 0x16A, 0x16E, 0x172, 
	0x176, 0x17A, 0x17D, 0x181, 0x185, 0x189, 0x18D, 0x191, 
	0x195, 0x19A, 0x19E, 0x1A2, 0x1A6, 0x1AA, 0x1AE, 0x1B2, 
	0x1B7, 0x1BB, 0x1BF, 0x1C3, 0x1C8, 0x1CC, 0x1D0, 0x1D5, 
	0x1D9, 0x1DD, 0x1E2, 0x1E6, 0x1EB, 0x1EF, 0x1F3, 0x1F8, 
	0x1FC, 0x201, 0x205, 0x20A, 0x20F, 0x213, 0x218, 0x21C, 
	0x221, 0x226, 0x22A, 0x22F, 0x233, 0x238, 0x23D, 0x241, 
	0x246, 0x24B, 0x250, 0x254, 0x259, 0x25E, 0x263, 0x267, 
	0x26C, 0x271, 0x276, 0x27B, 0x280, 0x284, 0x289, 0x28E, 
	0x293, 0x298, 0x29D, 0x2A2, 0x2A6, 0x2AB, 0x2B0, 0x2B5, 
	0x2BA, 0x2BF, 0x2C4, 0x2C9, 0x2CE, 0x2D3, 0x2D8, 0x2DC, 
	0x2E1, 0x2E6, 0x2EB, 0x2F0, 0x2F5, 0x2FA, 0x2FF, 0x304, 
	0x309, 0x30E, 0x313, 0x318, 0x31D, 0x322, 0x326, 0x32B, 
	0x330, 0x335, 0x33A, 0x33F, 0x344, 0x349, 0x34E, 0x353, 
	0x357, 0x35C, 0x361, 0x366, 0x36B, 0x370, 0x374, 0x379, 
	0x37E, 0x383, 0x388, 0x38C, 0x391, 0x396, 0x39B, 0x39F, 
	0x3A4, 0x3A9, 0x3AD, 0x3B2, 0x3B7, 0x3BB, 0x3C0, 0x3C5, 
	0x3C9, 0x3CE, 0x3D2, 0x3D7, 0x3DC, 0x3E0, 0x3E5, 0x3E9, 
	0x3ED, 0x3F2, 0x3F6, 0x3FB, 0x3FF, 0x403, 0x408, 0x40C, 
	0x410, 0x415, 0x419, 0x41D, 0x421, 0x425, 0x42A, 0x42E, 
	0x432, 0x436, 0x43A, 0x43E, 0x442, 0x446, 0x44A, 0x44E, 
	0x452, 0x455, 0x459, 0x45D, 0x461, 0x465, 0x468, 0x46C, 
	0x470, 0x473, 0x477, 0x47A, 0x47E, 0x481, 0x485, 0x488, 
	0x48C, 0x48F, 0x492, 0x496, 0x499, 0x49C, 0x49F, 0x4A2, 
	0x4A6, 0x4A9, 0x4AC, 0x4AF, 0x4B2, 0x4B5, 0x4B7, 0x4BA, 
	0x4BD, 0x4C0, 0x4C3, 0x4C5, 0x4C8, 0x4CB, 0x4CD, 0x4D0, 
	0x4D2, 0x4D5, 0x4D7, 0x4D9, 0x4DC, 0x4DE, 0x4E0, 0x4E3, 
	0x4E5, 0x4E7, 0x4E9, 0x4EB, 0x4ED, 0x4EF, 0x4F1, 0x4F3, 
	0x4F5, 0x4F6, 0x4F8, 0x4FA, 0x4FB, 0x4FD, 0x4FF, 0x500, 
	0x502, 0x503, 0x504, 0x506, 0x507, 0x508, 0x50A, 0x50B, 
	0x50C, 0x50D, 0x50E, 0x50F, 0x510, 0x511, 0x511, 0x512, 
	0x513, 0x514, 0x514, 0x515, 0x516, 0x516, 0x517, 0x517, 
	0x517, 0x518, 0x518, 0x518, 0x518, 0x518, 0x519, 0x519};

static const short *G1=&gauss[256],
                 *G2=&gauss[512],
                 *G3=&gauss[255],
                 *G4=&gauss[-1];	/* Ptrs to Gaussian table */

/* How many cycles till ADSR/GAIN adjustment */

/* Thanks to Brad Martin for providing this */
static const int apu_counter_reset_value = 0x7800;
static const int counter_update_table[32] =
{
 0x0000, 0x000F, 0x0014, 0x0018, 0x001E, 0x0028, 0x0030, 0x003C,
 0x0050, 0x0060, 0x0078, 0x00A0, 0x00C0, 0x00F0, 0x0140, 0x0180,
 0x01E0, 0x0280, 0x0300, 0x03C0, 0x0500, 0x0600, 0x0780, 0x0A00,
 0x0C00, 0x0F00, 0x1400, 0x1800, 0x1E00, 0x2800, 0x3C00, 0x7800
};

#define attack_time(x) (counter_update_table[(x) * 2 + 1])
#define decay_time(x)  (counter_update_table[(x) * 2 + 16])
#define linear_time(x) (counter_update_table[(x)])
#define exp_time(x)    (counter_update_table[(x)])
#define bent_time(x)   (counter_update_table[(x)])

int noise_vol;
int noise_base;

int noise_countdown;
unsigned noise_update_count;

void Wrap_SDSP_Cyclecounter()
{
 sound_cycle_latch -= 0xF0000000;
}

void Wrap_SPC_Samplecounter()
{
 if (sound_sample_latch >= 0xF8000000)
 {
  int c;

  sound_sample_latch -= 0xF0000000;

  for (c = 0; c < 8; c++)
  {
   SNDvoices[c].env_sample_latch -= 0xF0000000;
   SNDvoices[c].voice_sample_latch -= 0xF0000000;
  }
 }
}

#ifndef INLINE
#ifdef __GNUC__
#define INLINE inline
#else
#define INLINE
#endif
#endif

static void SPC_VoiceOff(int voice, const char *reason)
{
 if (SNDkeys & BIT(voice))
 {
#ifdef LOG_SOUND_VOICE_OFF
 printf("Voice off: %d (%s)\n", voice, reason);
#endif

 SNDkeys &= ~BIT(voice);

 SNDvoices[voice].env_state = VOICE_OFF;
 SNDvoices[voice].env_update_count = 0;

#ifdef ZERO_OUTX_ON_VOICE_OFF
 SPC_DSP[(voice << 4) + DSP_VOICE_OUTX] = SNDvoices[voice].outx = 0;
#else
 SPC_DSP[(voice << 4) + DSP_VOICE_OUTX] = SNDvoices[voice].outx;
#endif
#ifdef ZERO_ENVX_ON_VOICE_OFF
 SPC_DSP[(voice << 4) + DSP_VOICE_ENVX] = SNDvoices[voice].envx = 0;
#else
 SPC_DSP[(voice << 4) + DSP_VOICE_ENVX] = SNDvoices[voice].envx >>
  ENVX_DOWNSHIT_BITS;
#endif
 }
}

static void SPC_VoicesOff(int voices, const char *reason)
{
 int voice;

 voices &= SNDkeys;

 for (voice = 0; voice < 8; voice++)
 {
  if (voices & BIT(voice))
  {
   SPC_VoiceOff(voice, reason);
  }
 }
}

static INLINE int validate_brr_address(int voice)
{
 // BRR fetch wraps past end of address space!
 SNDvoices[voice].brrptr &= BITMASK(0,15);

 return 0;
}

static int get_brr_block(int voice, struct voice_state *pvs)
{
 int output, last1, last2;

 unsigned char range, filter, input;

 last1 = pvs->last1;
 last2 = pvs->last2;

 while (pvs->pitch_counter >= 0)
 {
  if (!pvs->brr_samples_left)
  {
   if (pvs->brr_header & BRR_PACKET_END)
   {
    if (pvs->brr_header & BRR_PACKET_LOOP)
    {
       unsigned short *samp_dir = (unsigned short *)
        &SPCRAM[(int) SPC_DSP[DSP_DIR] << 8];

       int cursamp = SPC_DSP[(voice << 4) + DSP_VOICE_SRCN];

       pvs->brrptr = samp_dir[cursamp * 2 + 1];
    }
    else
    {
     SPC_VoiceOff(voice, "end block completed without loop");
    }
   }

   if (validate_brr_address(voice)) return 1;
   pvs->brr_header = SPCRAM[pvs->brrptr++];
   if (pvs->brr_header & BRR_PACKET_END)
   {
    SPC_DSP[DSP_ENDX] |= BIT(voice);
   }
   pvs->brr_samples_left = 16;
  }

  range = pvs->brr_header >> 4;
  filter = (pvs->brr_header >> 2) & 3;

  if (!(pvs->brr_samples_left-- & 1))
  {
   if (validate_brr_address(voice)) return 1;
   input = SPCRAM[pvs->brrptr] >> 4;
  }
  else
  {
   input = SPCRAM[pvs->brrptr++] & 0x0F;
  }

  output = (input ^ 8) - 8;

  if (range <= 12) output = (output << range) >> 1;
  else output &= ~0x7FF;

  if (filter)
  {
   switch (filter)
   {
    case 1:
     output += (last1 >> 1) + ((-last1) >> 5);
     break;
    case 2:
     output += last1 + ((-(last1 + (last1 >> 1))) >> 5) +
      (-last2 >> 1) + (last2 >> 5);
     break;
    case 3: default:
     output += last1 + ((-(last1 + (last1 << 2) + (last1 << 3))) >> 7) +
      (-last2 >> 1) + ((last2 + (last2 >> 1)) >> 4);
     break;
   }

   // Clip underflow/overflow (saturation)
   if (output > 0x7FFF)
    output = 0x7FFF;
   else if (output < -0x8000)
    output = -0x8000;
  }

  last2 = last1;
  pvs->bufptr = (pvs->bufptr + 1) & 3;
  last1 = pvs->buf[pvs->bufptr] = (short) (output << 1);

  pvs->pitch_counter -= 0x1000;
 }

 pvs->last1 = last1;
 pvs->last2 = last2;
 return 0;
}

#define SoundGetEnvelopeHeight(voice) (UpdateEnvelopeHeight(voice))

INLINE static unsigned UpdateEnvelopeHeight(int voice)
{
 struct voice_state *pvs;
 unsigned envx;
 unsigned samples;

 pvs = &SNDvoices[voice];
 envx = pvs->envx;

 while ((samples = pvs->voice_sample_latch - pvs->env_sample_latch) != 0)
 {
  unsigned env_update_count;

  env_update_count = pvs->env_update_count;

  /* Should we ever adjust envelope? */
  if (!env_update_count)
  {
   pvs->env_sample_latch = pvs->voice_sample_latch;
   break;
  }

  /* Is it time to adjust envelope? */
  for (;samples && pvs->env_counter > 0;
   samples--, pvs->env_sample_latch++, pvs->env_counter -= env_update_count);

  if (pvs->env_counter <= 0)
  {
   pvs->env_counter = apu_counter_reset_value;

   switch (pvs->env_state)
   {
   case ATTACK:
    if (env_update_count == attack_time(15))
    {
     envx += ENVX_MAX_BASE / 2; //add 1/2nd
    }
    else
    {
     envx += ENVX_MAX_BASE / 64; //add 1/64th
    }

    if (envx >= ENVX_MAX)
    {
     envx = ENVX_MAX;

     pvs->env_state = pvs->adsr_state = DECAY;
     pvs->env_update_count = pvs->dr;
    }
    continue;

   case DECAY:
    envx -= (((int) envx - 1) >> 8) + 1;    //mult by 1-1/256

    if ((envx <= pvs->sl) || (envx > ENVX_MAX))
    {
     pvs->env_state = pvs->adsr_state = SUSTAIN;
     pvs->env_update_count = pvs->sr;
    }
    continue;

   case SUSTAIN:
    envx -= (((int) envx - 1) >> 8) + 1;    //mult by 1-1/256
    continue;

   case RELEASE:
   //says add 1/256??  That won't release, must be subtract.
   //But how often?  Oh well, who cares, I'll just
   //pick a number. :)
    envx -= (ENVX_MAX_BASE >> 8);   //sub 1/256th
    if ((envx == 0) || (envx > ENVX_MAX))
    {
     pvs->envx = envx = 0;
     SPC_VoiceOff(voice, "release");
     break;
    }
    continue;

   case INCREASE:
    envx += (ENVX_MAX_BASE >> 6);   //add 1/64th
    if (envx >= ENVX_MAX)
    {
     pvs->env_sample_latch = pvs->voice_sample_latch;
     envx = ENVX_MAX;
     break;
    }
    continue;

   case DECREASE:
    envx -= (ENVX_MAX_BASE >> 6);   //sub 1/64th
    if ((envx == 0) || (envx > ENVX_MAX))   //underflow
    {
     pvs->env_sample_latch = pvs->voice_sample_latch;
     envx = 0;
     break;
    }
    continue;

   case EXP:
    envx -= (((int) envx - 1) >> 8) + 1;    //mult by 1-1/256

    if ((envx == 0) || (envx > ENVX_MAX))   //underflow
    {
     pvs->env_sample_latch = pvs->voice_sample_latch;
     envx = 0;
     break;
    }
    continue;

   case BENT:
    if (envx < (ENVX_MAX_BASE / 4 * 3))
     envx += ENVX_MAX_BASE / 64;    //add 1/64th
    else
     envx += ENVX_MAX_BASE / 256;   //add 1/256th
    if (envx >= ENVX_MAX)
    {
     pvs->env_sample_latch = pvs->voice_sample_latch;
     envx = ENVX_MAX;
     break;
    }
    continue;

   case DIRECT:
    {
     int gain = SPC_DSP[(voice << 4) + DSP_VOICE_GAIN];

     envx = (gain & 0x7F) << ENVX_DOWNSHIFT_BITS;
     pvs->env_sample_latch = pvs->voice_sample_latch;
     break;
    }

   case VOICE_OFF:
    {
     pvs->env_sample_latch = pvs->voice_sample_latch;
     break;
    }
   }
  }
  break;
 }

 SPC_DSP[(voice << 4) + DSP_VOICE_ENVX] = envx >> ENVX_DOWNSHIFT_BITS;
 pvs->envx = envx;

 return envx;
}

INLINE static void SPC_KeyOn(int voices)
{
 int voice, cursamp, adsr1, adsr2, gain;
 unsigned short *samp_dir = (unsigned short *)
  &SPCRAM[(int) SPC_DSP[DSP_DIR] << 8];

 if (voices)
 {
  /* Ignore voices forcibly disabled */
  voices &= SPC_MASK;

  /* Clear key-on bits when acknowledged */
  SPC_DSP[DSP_KON] &= SPC_DSP[DSP_KOF];

  /* Don't acknowledge key-on when key-off is set */
  voices &= ~SPC_DSP[DSP_KOF];

  /* 8-sample delay before key on */
  keying_on |= voices;

  for (voice = 0; voice < 8; voice++)
  {
   if (!(voices & BIT(voice))) continue;

   SNDvoices[voice].key_wait = 8;
  }
 }

 if (!keying_on) return;

 for (voice = 0; voice < 8; voice++)
 {
  struct voice_state *pvs;

  if (!(keying_on & BIT(voice))) continue;

  pvs = &SNDvoices[voice];

  if (pvs->key_wait--) continue;

  keying_on &= ~BIT(voice);

  /* Clear sample-end-block-decoded flag for voices being keyed on */
  SPC_DSP[DSP_ENDX] &= ~BIT(voice);

  cursamp = SPC_DSP[(voice << 4) + DSP_VOICE_SRCN];
  pvs->brrptr = pvs->sample_start_address = samp_dir[cursamp * 2];
  pvs->pitch_counter = 0x1000*3;
  pvs->bufptr = -1;
  pvs->brr_samples_left = 0;
  pvs->brr_header = 0;
  pvs->voice_sample_latch = pvs->env_sample_latch =
   sound_sample_latch;

  pvs->env_counter = apu_counter_reset_value;

  pvs->lvol = (signed char) SPC_DSP[(voice << 4) + DSP_VOICE_LVOL];
  pvs->rvol = (signed char) SPC_DSP[(voice << 4) + DSP_VOICE_RVOL];

  pvs->adsr_state = ATTACK;

#ifndef ZERO_ENVX_ON_KEY_ON
  // Don't set envelope to zero if sound was playing
  if (!(SNDkeys & BIT(voice)))
#endif
  {
   SPC_DSP[(voice << 4) + DSP_VOICE_ENVX] = 0;
   pvs->envx = 0;
   SPC_DSP[(voice << 4) + DSP_VOICE_OUTX] = 0;
   pvs->outx = 0;
  }

  adsr1 = SPC_DSP[(voice << 4) + DSP_VOICE_ADSR1];
  if (adsr1 & 0x80)
  {
   //ADSR mode
   adsr2 = SPC_DSP[(voice << 4) + DSP_VOICE_ADSR2];

   pvs->env_state = pvs->adsr_state;
   pvs->env_update_count = pvs->ar;
  }
  else
  {
   //GAIN mode
   gain = SPC_DSP[(voice << 4) + DSP_VOICE_GAIN];
   pvs->env_update_count = pvs->gain_update_count;

   if (gain & 0x80)
   {
    pvs->env_state = gain >> 5;
   }
   else
   {
    pvs->env_state = DIRECT;
   }
  }

  SNDkeys |= BIT(voice);
 }
}

INLINE static void SPC_KeyOff(int voices)
{
 int voice;

 SPC_DSP[DSP_KOF] = voices;

 voices &= SNDkeys;

 for (voice = 0; voice < 8; voice++)
 {
  if (voices & BIT(voice))
  {
   SNDvoices[voice].env_state = RELEASE;
   SNDvoices[voice].env_update_count = apu_counter_reset_value;
  }
 }
}

static int sound_enable_mode = 0;

static int last_position;

void Reset_Sound_DSP()
{
 int i, samples;

 srand(0);

 samples = 2 * SOUND_FREQ / SOUND_LAG;

 if (sound_enable_mode == 2) samples <<= 1;

 memset(SPC_DSP, 0, 256);
 SPC_DSP[DSP_FLG] = DSP_FLG_NECEN | DSP_FLG_MUTE;

 main_lvol = main_rvol = echo_lvol = echo_rvol = 0;
 echo_base = echo_delay = echo_address = echo_feedback = FIR_address = 0;

 SPC_MASK = 0xFF;
 SNDkeys = 0;
 sound_output_position = 0;
 block_written = TRUE;
#ifdef DUMP_SOUND
 block_dumped = TRUE;
#endif

 noise_vol = 0;
 noise_base = 1;
 noise_update_count = counter_update_table[0];
 noise_countdown = apu_counter_reset_value;

 sound_sample_latch = 0;

 for (i = 0; i < 8; i++)
 {
  FIR_taps[i][0] = FIR_taps[i][1] = 0;
  FIR_coeff[i] = 0;
  SNDvoices[i].last2 = SNDvoices[i].last1 = 0;
  SNDvoices[i].envx = 0;
  SNDvoices[i].outx = 0;
  SNDvoices[i].env_state = VOICE_OFF;
  SNDvoices[i].voice_sample_latch = SNDvoices[i].env_sample_latch =
   sound_sample_latch;
  SNDvoices[i].ar = attack_time(0);
  SNDvoices[i].dr = decay_time(0);
  SNDvoices[i].sr = exp_time(0);
  SNDvoices[i].sl = ENVX_MAX_BASE / 8;
  SNDvoices[i].lvol = 0;
  SNDvoices[i].rvol = 0;
  SNDvoices[i].gain_update_count = apu_counter_reset_value;
 }

 if (!sound_enable_mode) return;

 last_position = 0;

 if (sound_bits == 8)
 {
  for (i = 0; i < samples; i++)
  {
   ((output_sample_8 *) sound_buffer_preload)[i] = OUTPUT_ZERO_BASE_8;
  }
 }
 else
 {
  for (i = 0; i < samples; i++)
  {
   ((output_sample_16 *) sound_buffer_preload)[i] = OUTPUT_ZERO_BASE_16;
  }
 }

}

void Remove_Sound()
{
 if (noise_buffer)
 {
  free(noise_buffer);
  noise_buffer = 0;
 }
 if (outx_buffer)
 {
  free(outx_buffer);
  outx_buffer = 0;
 }
 if (mix_buffer)
 {
  free(mix_buffer);
  mix_buffer = 0;
 }
 if (sound_buffer_preload)
 {
  free(sound_buffer_preload);
  sound_buffer_preload = 0;
 }
 if (audio_voice.platform_interface)
 {
  platform_free_audio_voice(&audio_voice);
 }

 sound_enabled = sound_enable_mode = 0;
}

int Install_Sound(int stereo)
{
 int samples;
 if (!platform_sound_available) return 0;

 if (sound_enable_mode) Remove_Sound();

 samples = 2 * SOUND_FREQ / SOUND_LAG;

 platform_get_audio_voice(samples / 2, sound_bits, stereo, SOUND_FREQ,
  &audio_voice);

 if (sound_bits == 8)
 {
  sound_buffer_preload =
   malloc(sizeof(output_sample_8[(stereo ? 2 : 1) * samples]));
 }
 else
 {
  sound_buffer_preload =
   malloc(sizeof(output_sample_16[(stereo ? 2 : 1) * samples]));
 }

 noise_buffer = (output_sample_16 *)
  malloc(sizeof(output_sample_16 [samples]));

 outx_buffer = (char *) malloc(sizeof(char [samples]));

 mix_buffer = (int *) malloc(sizeof(int [(stereo ? 2 : 1) * samples]));

 if (!audio_voice.platform_interface || !sound_buffer_preload ||
  !noise_buffer || !outx_buffer || !mix_buffer)
 {
  Remove_Sound();
  return sound_enabled = sound_enable_mode = 0;
 }

 sound_enabled = sound_enable_mode = stereo + 1;

 return sound_enabled;

}

void update_sound_block(void)
{
 int samples;
 int data_block;
 void *sound_buffer;

#ifdef DUMP_SOUND
 static FILE *snd_dump = NULL;
#endif

 if (!sound_enabled) return;

 if (block_written && SPC_ENABLED) return;

#ifdef DUMP_SOUND
 if (!block_dumped)
 {
  block_dumped = TRUE;
  if (!snd_dump)
  {
   snd_dump = fopen("snd.dmp", "ab");
  }

  samples = SOUND_FREQ / SOUND_LAG;

  /* Write from block not being written to */
  data_block = sound_output_position >= samples ? 0 : samples;

  if (sound_enable_mode == 2)
  {
   data_block <<= 1;
   samples <<= 1;
  }

  if (sound_bits == 8)
  {
   if (snd_dump && SPC_ENABLED)
   {
    fwrite(((output_sample_8 *) sound_buffer_preload) + data_block, 1,
     sizeof(output_sample_8[samples]), snd_dump);
   }
  }
  else
  {
   if (snd_dump && SPC_ENABLED)
   {
    fwrite(((output_sample_16 *) sound_buffer_preload) + data_block, 1,
     sizeof(output_sample_16[samples]), snd_dump);
   }
  }
 }
#endif

 sound_buffer = platform_get_audio_buffer(&audio_voice);
 if (!sound_buffer) return;

 block_written = TRUE;
 samples = SOUND_FREQ / SOUND_LAG;

 /* Write from block not being written to */
 data_block = sound_output_position >= samples ? 0 : samples;

 if (sound_enable_mode == 2)
 {
  data_block <<= 1;
  samples <<= 1;
 }

 if (sound_bits == 8)
 {
  if (SPC_ENABLED)
  {
   memcpy(sound_buffer,
    ((output_sample_8 *) sound_buffer_preload) + data_block,
    sizeof(output_sample_8[samples]));
  }
  else
  {
   memset(sound_buffer, 0, sizeof(output_sample_8[samples]));
  }
 }
 else
 {
  if (SPC_ENABLED)
  {
   memcpy(sound_buffer,
    ((output_sample_16 *) sound_buffer_preload) + data_block,
    sizeof(output_sample_16[samples]));
  }
  else
  {
   memset(sound_buffer, 0, sizeof(output_sample_16[samples]));
  }
 }

 platform_free_audio_buffer(&audio_voice);
}

unsigned samples_output = 0;

INLINE static int get_brr_blocks(int voice, struct voice_state *pvs)
{
 if (pvs->pitch_counter >= 0)
 {
  return get_brr_block(voice, pvs);
 }
 return 0;
}

INLINE static void update_voice_pitch(int voice, struct voice_state *pvs,
 unsigned char pitch_modulation_enable, unsigned char voice_bit)
{
#ifndef NO_PITCH_MODULATION
 if (!(pitch_modulation_enable & voice_bit))
 {
  pvs->pitch_counter += pvs->step;
 }
 else
 {
  pvs->pitch_counter +=
   pvs->step * (SNDvoices[voice - 1].outx + 32768) / 32768;
 }
#else
 pvs->pitch_counter += pvs->step;
#endif
}

#ifndef NO_PRELOAD_OUTPUT
#define STEREO_PRELOAD_OUTPUT asm volatile("movb (%%eax),%%al" : : "a" (buf + i * 2));
#define MONO_PRELOAD_OUTPUT asm volatile("movb (%%eax),%%al" : : "a" (buf + i));
#else
#define STEREO_PRELOAD_OUTPUT
#define MONO_PRELOAD_OUTPUT
#endif

#define STEREO_DECLARE_SAMPLES_NO_ECHO \
 int mlsample, mrsample;
#define STEREO_INIT_SAMPLES_NO_ECHO \
 (mlsample = mrsample = 0);

#define STEREO_DECLARE_SAMPLES_ECHO \
 int mlsample, mrsample, elsample, ersample;
#define STEREO_INIT_SAMPLES_ECHO \
 (mlsample = mrsample = elsample = ersample = 0);

#define MONO_DECLARE_SAMPLES_NO_ECHO \
 int msample;
#define MONO_INIT_SAMPLES_NO_ECHO \
 (msample = 0);

#define MONO_DECLARE_SAMPLES_ECHO \
 int msample, esample;
#define MONO_INIT_SAMPLES_ECHO \
 (msample = esample = 0);

#define SAMPLE_SET(S,D) ((S) = (D))
#define SAMPLE_ADD(S,D) ((S) += (D))

#define MONO_VOICE_VOLUME_NO_ECHO(OP) \
 { \
  int jsample = (pvs->outx * (int) pvs->jvol); \
  OP(msample, jsample); \
 }

#define MONO_VOICE_VOLUME_ECHO(OP) \
 { \
  int jsample = (pvs->outx * (int) pvs->jvol); \
  OP(msample, jsample); \
  if (SPC_DSP[DSP_EON] & voice_bit) \
  { \
   OP(esample, jsample); \
  } \
 }

#define STEREO_VOICE_VOLUME_NO_ECHO(OP) \
 { \
  int lsample = (pvs->outx * (int) pvs->lvol); \
  int rsample = (pvs->outx * (int) pvs->rvol); \
  OP(mlsample, lsample); \
  OP(mrsample, rsample); \
 }

#define STEREO_VOICE_VOLUME_ECHO(OP) \
 { \
  int lsample = (pvs->outx * (int) pvs->lvol); \
  int rsample = (pvs->outx * (int) pvs->rvol); \
  OP(mlsample, lsample); \
  OP(mrsample, rsample); \
  if (SPC_DSP[DSP_EON] & voice_bit) \
  { \
   OP(elsample, lsample); \
   OP(ersample, rsample); \
  } \
 }

#define MONO_MAIN_VOLUME \
 { \
  msample = (msample * main_jvol) >> 7; \
 }

#define STEREO_MAIN_VOLUME \
 { \
  mlsample = (mlsample * main_lvol) >> 7; \
  mrsample = (mrsample * main_rvol) >> 7; \
 }

#define MONO_COMPUTE_NO_ECHO
#define MONO_COMPUTE_ECHO \
 { \
  int FIR_sample, FIR_temp_address; \
  signed short *echo_ptr = (signed short *) \
   &SPCRAM[(echo_base + echo_address) & 0xFFFF]; \
  \
  FIR_taps[FIR_address][0] = (echo_ptr[0] + echo_ptr[1]) >> 1; \
  \
  FIR_sample = FIR_taps[FIR_address][0] * FIR_coeff[0]; \
  FIR_temp_address = (FIR_address + 1) & 7; \
  FIR_sample += FIR_taps[FIR_temp_address][0] * FIR_coeff[1]; \
  FIR_temp_address = (FIR_temp_address + 1) & 7; \
  FIR_sample += FIR_taps[FIR_temp_address][0] * FIR_coeff[2]; \
  FIR_temp_address = (FIR_temp_address + 1) & 7; \
  FIR_sample += FIR_taps[FIR_temp_address][0] * FIR_coeff[3]; \
  FIR_temp_address = (FIR_temp_address + 1) & 7; \
  FIR_sample += FIR_taps[FIR_temp_address][0] * FIR_coeff[4]; \
  FIR_temp_address = (FIR_temp_address + 1) & 7; \
  FIR_sample += FIR_taps[FIR_temp_address][0] * FIR_coeff[5]; \
  FIR_temp_address = (FIR_temp_address + 1) & 7; \
  FIR_sample += FIR_taps[FIR_temp_address][0] * FIR_coeff[6]; \
  FIR_address = (FIR_temp_address + 1) & 7; \
  FIR_sample += FIR_taps[FIR_address][0] * FIR_coeff[7]; \
  msample += (FIR_sample * echo_jvol) >> 7; \
  \
  /* Store echo result with feedback if writes aren't disabled */ \
  if (!(SPC_DSP[DSP_FLG] & DSP_FLG_NECEN)) \
  { \
   FIR_sample *= echo_feedback; \
   esample = (esample >> 7) + (FIR_sample >> 14); \
   /* Saturate */ \
   if (esample >= 32767) esample = 32767; \
   else if (esample <= -32768) esample = -32768; \
   echo_ptr[0] = echo_ptr[1] = esample; \
  } \
  \
  echo_address += 4; \
  if (echo_address >= echo_delay) echo_address = 0; \
 }

#define STEREO_COMPUTE_NO_ECHO
#define STEREO_COMPUTE_ECHO \
 { \
  int FIR_lsample, FIR_rsample, FIR_temp_address; \
  short *echo_ptr = (signed short *) \
   &SPCRAM[(echo_base + echo_address) & 0xFFFF]; \
  \
  FIR_taps[FIR_address][0] = echo_ptr[0]; \
  FIR_taps[FIR_address][1] = echo_ptr[1]; \
  \
  FIR_lsample = FIR_taps[FIR_address][0] * FIR_coeff[0]; \
  FIR_rsample = FIR_taps[FIR_address][1] * FIR_coeff[0]; \
  FIR_temp_address = (FIR_address + 1) & 7; \
  FIR_lsample += FIR_taps[FIR_temp_address][0] * FIR_coeff[1]; \
  FIR_rsample += FIR_taps[FIR_temp_address][1] * FIR_coeff[1]; \
  FIR_temp_address = (FIR_temp_address + 1) & 7; \
  FIR_lsample += FIR_taps[FIR_temp_address][0] * FIR_coeff[2]; \
  FIR_rsample += FIR_taps[FIR_temp_address][1] * FIR_coeff[2]; \
  FIR_temp_address = (FIR_temp_address + 1) & 7; \
  FIR_lsample += FIR_taps[FIR_temp_address][0] * FIR_coeff[3]; \
  FIR_rsample += FIR_taps[FIR_temp_address][1] * FIR_coeff[3]; \
  FIR_temp_address = (FIR_temp_address + 1) & 7; \
  FIR_lsample += FIR_taps[FIR_temp_address][0] * FIR_coeff[4]; \
  FIR_rsample += FIR_taps[FIR_temp_address][1] * FIR_coeff[4]; \
  FIR_temp_address = (FIR_temp_address + 1) & 7; \
  FIR_lsample += FIR_taps[FIR_temp_address][0] * FIR_coeff[5]; \
  FIR_rsample += FIR_taps[FIR_temp_address][1] * FIR_coeff[5]; \
  FIR_temp_address = (FIR_temp_address + 1) & 7; \
  FIR_lsample += FIR_taps[FIR_temp_address][0] * FIR_coeff[6]; \
  FIR_rsample += FIR_taps[FIR_temp_address][1] * FIR_coeff[6]; \
  FIR_address = (FIR_temp_address + 1) & 7; \
  FIR_lsample += FIR_taps[FIR_address][0] * FIR_coeff[7]; \
  FIR_rsample += FIR_taps[FIR_address][1] * FIR_coeff[7]; \
  mlsample += (FIR_lsample * echo_lvol) >> 7; \
  mrsample += (FIR_rsample * echo_rvol) >> 7; \
  \
  /* Store echo result with feedback if writes aren't disabled */ \
  if (!(SPC_DSP[DSP_FLG] & DSP_FLG_NECEN)) \
  { \
   FIR_lsample *= echo_feedback; \
   FIR_rsample *= echo_feedback; \
   elsample = (elsample >> 7) + (FIR_lsample >> 14); \
   ersample = (ersample >> 7) + (FIR_rsample >> 14); \
   /* Saturate */ \
   if (elsample >= 32767) elsample = 32767; \
   else if (elsample <= -32768) elsample = -32768; \
   if (ersample >= 32767) ersample = 32767; \
   else if (ersample <= -32768) ersample = -32768; \
   echo_ptr[0] = elsample; \
   echo_ptr[1] = ersample; \
  } \
  \
  echo_address += 4; \
  if (echo_address >= echo_delay) echo_address = 0; \
 }


#define SAMPLE_WRITE_ZERO(BITS,A) \
 { \
  (A) = OUTPUT_ZERO_BASE_##BITS; \
 }

#define MONO_SAMPLE_WRITE_ZERO(BITS) \
 { \
  SAMPLE_WRITE_ZERO(BITS,buf[i]) \
 }

#define STEREO_SAMPLE_WRITE_ZERO(BITS) \
 { \
  SAMPLE_WRITE_ZERO(BITS,buf[i * 2]) \
  SAMPLE_WRITE_ZERO(BITS,buf[i * 2 + 1]) \
 }

#define SAMPLE_CLIP_AND_WRITE(BITS,A,S) \
 { \
  if ((S) <= PREMIX_LOWER_LIMIT_##BITS) \
   (S) = OUTPUT_LOWER_LIMIT_##BITS; \
  else if ((S) >= PREMIX_UPPER_LIMIT_##BITS) \
   (S) = OUTPUT_UPPER_LIMIT_##BITS; \
  else (S) = OUTPUT_ZERO_BASE_##BITS + \
   ((S) >> PREMIX_SHIFT_##BITS); \
 \
 (A) = (S); \
 }

#define MONO_SAMPLE_CLIP_AND_WRITE(BITS) \
 SAMPLE_CLIP_AND_WRITE(BITS,buf[i],msample)

#define STEREO_SAMPLE_CLIP_AND_WRITE(BITS) \
 SAMPLE_CLIP_AND_WRITE(BITS,buf[i * 2],mlsample) \
 SAMPLE_CLIP_AND_WRITE(BITS,buf[i * 2 + 1],mrsample)

/* NOTE: Clip with sign-extension before last sample is added in */
#define GET_OUTX_GAUSS \
 do \
 { \
  pvs->outx = ( \
  ((( \
   ((((int) G4[-(pvs->pitch_counter >> 4)] * \
    pvs->buf[(pvs->bufptr - 3) & 3]) >> 11) & ~1) + \
   ((((int) G3[-(pvs->pitch_counter >> 4)] * \
    pvs->buf[(pvs->bufptr - 2) & 3]) >> 11) & ~1) + \
   ((((int) G2[(pvs->pitch_counter >> 4)] * \
    pvs->buf[(pvs->bufptr - 1) & 3]) >> 11) & ~1)) \
  & 0xFFFF) ^ 0x8000) - 0x8000) + \
  ((((int) G1[(pvs->pitch_counter >> 4)] * \
   pvs->buf[(pvs->bufptr) & 3]) >> 11) & ~1); \
  if (pvs->outx <= -32768) pvs->outx = -32768; \
  else if (pvs->outx >= 32767) pvs->outx = 32767; \
 } while (0)

#define GET_OUTX_NO_GAUSS pvs->outx = pvs->buf[(pvs->bufptr - 3) & 3]

#define MIX(BITS,CHANNELS,GAUSS,ECHO) \
     { \
/*    int voice_samples_generated[8] = { 0, 0, 0, 0, 0, 0, 0, 0 }; */ \
/*    int max_samples_generated; */ \
 \
      output_sample_##BITS *buf = \
       (output_sample_##BITS *) sound_buffer_preload; \
 \
      unsigned i; \
      int samples_left = samples; \
 \
      for (i = first; samples_left/*&& SNDkeys*/; samples_left--) \
      { \
       CHANNELS##_DECLARE_SAMPLES_##ECHO \
 \
       CHANNELS##_PRELOAD_OUTPUT \
 \
       CHANNELS##_INIT_SAMPLES_##ECHO \
       for (voice = 0, voice_bit = 1; voice < 8; voice++, voice_bit <<= 1) \
       { \
        struct voice_state *pvs; \
        if (!(SNDkeys & voice_bit)) continue; \
 \
        pvs = &SNDvoices[voice]; \
        if (get_brr_blocks(voice,pvs)) continue; \
 \
        if (SPC_DSP[DSP_NON] & voice_bit) \
         pvs->outx = noise_buffer [i]; \
        else \
         GET_OUTX_##GAUSS; \
 \
        update_voice_pitch(voice, pvs, pitch_modulation_enable, voice_bit); \
 \
        pvs->outx = (pvs->outx \
         * (int) SoundGetEnvelopeHeight(voice)) >> ENVX_PRECISION_BITS; \
 \
        pvs->outx &= ~1; \
 \
        CHANNELS##_VOICE_VOLUME_##ECHO(SAMPLE_ADD) \
 \
        pvs->voice_sample_latch ++; \
 \
       } \
 \
       if (!(SPC_DSP[DSP_FLG] & DSP_FLG_MUTE)) \
       { \
        CHANNELS##_MAIN_VOLUME \
        CHANNELS##_COMPUTE_##ECHO \
        CHANNELS##_SAMPLE_CLIP_AND_WRITE(BITS) \
       } \
       else \
       { \
        CHANNELS##_COMPUTE_##ECHO \
        CHANNELS##_SAMPLE_WRITE_ZERO(BITS) \
       } \
 \
       if (++i >= buffer_size) \
        i = 0; \
      } \
 \
      for (; samples_left; samples_left--) \
      { \
       CHANNELS##_DECLARE_SAMPLES_##ECHO \
 \
       CHANNELS##_PRELOAD_OUTPUT \
 \
       CHANNELS##_INIT_SAMPLES_##ECHO \
 \
       CHANNELS##_COMPUTE_##ECHO \
 \
       if (!(SPC_DSP[DSP_FLG] & DSP_FLG_MUTE)) \
       { \
        CHANNELS##_SAMPLE_CLIP_AND_WRITE(BITS) \
       } \
       else \
       { \
        CHANNELS##_SAMPLE_WRITE_ZERO(BITS) \
       } \
 \
       if (++i >= buffer_size) \
        i = 0; \
      } \
 \
      sound_output_position = i; \
     }

/*
 Echo notes

  Output sample generation is shared between main and echo outputs until
 after channel multiplication.  All channels are then mixed into the main
 output, and those enabled (via DSP EON register) for echo are mixed for
 the echo region.
  The echo region receives the resulting sum of the aforementioned and
 mixed channel output and the product of the result of the FIR filter
 multiplied by the echo feedback (DSP EFB register) setting.
  The echo output begins with the address in the echo region that the new
 echo data will be written to.  That address is read (two 16-bit stereo
 samples) and placed in a queue for the FIR filter.
  The eight values in the FIR filter queue are then multiplied
 respectively by the eight FIR filter coefficients (DSP C0-C7 registers)
 from oldest to newest.
  The resulting value is multipled by echo feedback to be added to the
 channel mix output as described above; in addition, it is multiplied by
 the echo output volume and mixed with the main output, played by the
 output device.
  The echo region address is reset to 0 when it has reached or exceeded
 the buffer length for the specified echo delay (DSP EDL register),
 which is EDL * 2048 bytes (EDL * 512 samples).
*/

#define MIX_BITS(BITS) \
 { \
  if (stereo) \
  /* emulate audio in stereo */ \
  { \
   MIX_CHANNELS(BITS,STEREO) \
  } \
  else \
  /* emulate audio in mono */ \
  { \
   MIX_CHANNELS(BITS,MONO) \
  } \
 }

#define MIX_CHANNELS(BITS,CHANNELS) \
 { \
  if (sound_gauss_enabled) \
  /* emulate 4-point pitch-regulated gaussian interpolation */ \
  { \
   MIX_GAUSS(BITS,CHANNELS,GAUSS) \
  } \
  else \
  /* no interpolation */ \
  { \
   MIX_GAUSS(BITS,CHANNELS,NO_GAUSS) \
  } \
 }

#define MIX_GAUSS(BITS,CHANNELS,GAUSS) \
 { \
  if (sound_echo_enabled) \
  /* emulate echo with corresponding FIR filter and SPC RAM update */ \
  { \
   MIX(BITS,CHANNELS,GAUSS,ECHO) \
  } \
  else \
  /* no echo emulation */ \
  { \
   MIX(BITS,CHANNELS,GAUSS,NO_ECHO) \
  } \
 }


void mix_voices(unsigned first, unsigned samples, unsigned buffer_size,
 int sound_bits, int stereo)
{
    int voice;
    unsigned char voice_bit;
    unsigned char pitch_modulation_enable;

    // pitch modulation is not available for noise channels or channel 0
    pitch_modulation_enable = SPC_DSP[DSP_PMON] & ~SPC_DSP[DSP_NON] & ~1;
#ifdef FAULT_ON_PITCH_MODULATION_USE
    if (pitch_modulation_enable & SNDkeys) asm("ud2");
#endif

    if (sound_bits == 8)
    /* 8-bit */
    {
     MIX_BITS(8)
    }
    else
    /* 16-bit */
    {
     MIX_BITS(16)
    }
}

/* update_sound()
 * This function is called to synchronize the sound DSP sample
 *  generation to the current SPC700 CPU timing.
 * Active voices are processed and mixed into the sound buffer.
 * This function MUST be called often enough that no more than one
 *  complete buffer of samples are processed per call.
 */
void update_sound(void)
{
    unsigned first, samples, buffer_size;
    int voice;
    unsigned char voices_were_on;
    unsigned char voice_bit;

    if (!SPC_ENABLED) return;

    samples = ((TotalCycles + SOUND_CYCLES_PER_SAMPLE) -
     sound_cycle_latch) / SOUND_CYCLES_PER_SAMPLE;
    if (!samples) return;

    if (SPC_DSP[DSP_FLG] & DSP_FLG_RESET)
    {
     SPC_DSP[DSP_FLG] |= DSP_FLG_RESET | DSP_FLG_NECEN | DSP_FLG_MUTE;

     SPC_VoicesOff(SNDkeys, "DSP reset");
     SNDkeys = 0;

     SPC_DSP[DSP_ENDX] = 0;
     SPC_DSP[DSP_KON] = 0;
     SPC_DSP[DSP_KOF] = 0;

     FIR_address = 0;
     echo_address = 0;
    }

    SPC_KeyOn(SPC_DSP[DSP_KON]);
    SPC_KeyOff(SPC_DSP[DSP_KOF]);

    sound_cycle_latch = (TotalCycles + SOUND_CYCLES_PER_SAMPLE) &
     ~(SOUND_CYCLES_PER_SAMPLE - 1);

    sound_sample_latch += samples;

    if (!sound_enabled) return;
    samples_output += samples;

    first = sound_output_position;

    buffer_size = 2 * SOUND_FREQ / SOUND_LAG;

    // Are we completing a block?
    if (((first % (SOUND_FREQ / SOUND_LAG)) + samples) >=
     (SOUND_FREQ / SOUND_LAG))
    {
     block_written = FALSE;
#ifdef DUMP_SOUND
     block_dumped = FALSE;
#endif
    }

    if (SNDkeys & ~SPC_MASK)
    {
     SPC_VoicesOff(~SPC_MASK, "SPC_MASK");
    }

    {
     unsigned i;
     int samples_left = samples;

     for (i = first; samples_left && noise_update_count; samples_left--)
     {
      int feedback;


      noise_countdown -= noise_update_count;

      if (noise_base & 0x4000)
      {
       noise_vol += (noise_base & 1) ? noise_base : -noise_base;
      }
      else
      {
       noise_vol >>= 1;
      }

      feedback = (noise_base << 13) ^ (noise_base << 14);
      noise_base = (feedback & 0x4000) | (noise_base >> 1);

      if (SNDkeys & SPC_DSP[DSP_NON])
      {
       noise_buffer [i] = noise_vol << 1;
      }

      if (++i >= buffer_size)
       i = 0;
     }

     if (SNDkeys & SPC_DSP[DSP_NON])
     {
      for (; samples_left; samples_left--)
      {
       noise_buffer [i] = noise_vol << 1;
       if (++i >= buffer_size)
        i = 0;
      }
     }
    }

    voices_were_on = SNDkeys;

    main_jvol = (main_lvol + main_rvol) >> 1;
    echo_jvol = (echo_lvol + echo_rvol) >> 1;

    for (voice = 0, voice_bit = 1; voice < 8; voice++, voice_bit <<= 1)
    {
        struct voice_state *pvs;

        if (!(SNDkeys & voice_bit)) continue;

        pvs = &SNDvoices[voice];

        if (sound_enabled == 1)
        {
         pvs->jvol = (pvs->lvol + pvs->rvol) >> 1;
        }

        pvs->step = ((unsigned) *(unsigned short *)&SPC_DSP[(voice << 4) + DSP_VOICE_PITCH_L]);
    }

/* MMX mixing notes
 *  PMADDWD takes two sets of four 16-bit words. abcd(r), efgh(r/m).
 *  Each 16-bit word in source is multiplied by its respective word in
 *  destination. Then the high 2 results are added and stored as the
 *  high 32-bit result, and the low 2 results are added and stored
 *  as the low 32-bit result.
 *
 *  For audio channel mixing, propose that source contain channel volumes
 *  and destination contain channel sample height.
 *
 *  In Stereo, high pair of 16-bit words are for two channels, left side,
 *  and low pair of 16-bit words are for two channels, right side.
 *
 *  In Mono, instead of left and right side, two independent samples
 *  are processed at once.
 *
 *  After all channels have been volume-adjusted, PADDD is used to combine
 *  them, and PACKSSDW converts them back to 16-bit samples for output.
 */

    mix_voices(first, samples, buffer_size, sound_bits,
     sound_enabled == 2 ? 1 : 0);

    for (voice = 0, voice_bit = 1; voice < 8; voice++, voice_bit <<= 1)
    {
        if (voices_were_on & voice_bit)
        {
         /* If voice was on, but turned off for any reason */
         if (!(SNDkeys & voice_bit))
         {
          SPC_VoiceOff(voice, "?");
         }
         else
         {
          /* If voice was on, and is still on */
          SPC_DSP[(voice << 4) + DSP_VOICE_OUTX] =
           SNDvoices[voice].outx >> 8;
         }
        }
    }
}

void SPC_READ_DSP()
{
    int addr_lo = SPC_DSP_ADDR & 0xF;
    int addr_hi = SPC_DSP_ADDR >> 4;

#ifdef LOG_SOUND_DSP_READ
    printf("\nread @ %08X,%04X: %02X", TotalCycles, (unsigned) _SPC_PC, (unsigned) SPC_DSP_ADDR);
#endif

#ifdef DSP_SPEED_HACK
    /* if we're not reading endx */
    if (SPC_DSP_ADDR != DSP_ENDX)
    {
     /* if we're reading envx or outx but voice is off */
     if (addr_lo == DSP_VOICE_ENVX || addr_lo == DSP_VOICE_OUTX)
     {
      if (!(SNDkeys & BIT(addr_hi)))
      {
#ifdef LOG_SOUND_DSP_READ
       printf(" %02X", SPC_DSP[SPC_DSP_ADDR]);
#endif
       return;
      }
     }
     else
     {
#ifdef LOG_SOUND_DSP_READ
      printf(" %02X", SPC_DSP[SPC_DSP_ADDR]);
#endif
      return;
     }
    }
#endif

//  printf("\nSound update");

    update_sound();

    switch(addr_lo)
    {
    case DSP_VOICE_ENVX:
                if (!sound_enabled) SNDvoices[addr_hi].voice_sample_latch =
                 sound_sample_latch;
#if defined(ZERO_ENVX_ON_VOICE_OFF) && !defined(DSP_SPEED_HACK)
                if (ENVX_ENABLED && (SNDkeys & BIT(addr_hi)))
#else
                if (ENVX_ENABLED)
#endif
                 UpdateEnvelopeHeight(addr_hi); // >> ENVX_DOWNSHIFT_BITS;
                else
                 SPC_DSP[SPC_DSP_ADDR] = 0;

                break;
    }
#ifdef LOG_SOUND_DSP_READ
    printf(" %02X", SPC_DSP[SPC_DSP_ADDR]);
#endif
}

void SPC_WRITE_DSP()
{
 int i;
 int addr_lo = SPC_DSP_ADDR & 0xF;
 int addr_hi = SPC_DSP_ADDR >> 4;

 if (addr_hi > 7)
 {
  SPC_DSP[SPC_DSP_ADDR] = SPC_DSP_DATA;
  return;
 }

#ifdef LOG_SOUND_DSP_WRITE
 printf("\nwrite @ %08X,%04X: %02X %02X", TotalCycles, (unsigned) _SPC_PC,
  (unsigned) SPC_DSP_ADDR, (unsigned) SPC_DSP_DATA);
#endif

#ifdef DSP_SPEED_HACK
 /* if we're not writing to flg or endx */
 if (addr_lo != 0x0C || addr_hi < 6)
 /* and write would not change data, return */
 if (SPC_DSP[SPC_DSP_ADDR] == SPC_DSP_DATA) return;

 /* if it's not a voice register for a voice that's not on */
 if (addr_lo > 9 ||
  ((SNDkeys | (SPC_DSP[DSP_KON] & ~SPC_DSP[DSP_KOF])) & BIT(addr_hi)))
 {
#endif

  update_sound();

//printf("\nSound update");
#ifdef DSP_SPEED_HACK
 }
#endif

 switch (addr_lo)
 {
 // break just means nothing needs to be done right now
 // Commented cases are unsupported registers, or do-nothing cases

 // Channel - volume left
 case DSP_VOICE_LVOL:
  SNDvoices[addr_hi].lvol = (signed char) SPC_DSP_DATA;
  break;

 // Channel - volume right
 case DSP_VOICE_RVOL:
  SNDvoices[addr_hi].rvol = (signed char) SPC_DSP_DATA;
  break;
/*
 // Channel - pitch low bits (0-7)
 case DSP_VOICE_PITCH_L:
  break;
 */

#ifdef MASK_PITCH_H
 // Channel - pitch high bits (8-13)
 case DSP_VOICE_PITCH_H:
  SPC_DSP_DATA &= 0x3F;
  break;
#endif
/*
 // Channel - source number
 case DSP_VOICE_SRCN:
  break;
 */
 // Channel - ADSR 1
 case DSP_VOICE_ADSR1:
  if (!sound_enabled) SNDvoices[addr_hi].voice_sample_latch =
   sound_sample_latch;
  if (SNDkeys & BIT(addr_hi)) UpdateEnvelopeHeight(addr_hi);

  SNDvoices[addr_hi].ar = attack_time(SPC_DSP_DATA & 0xF);
  SNDvoices[addr_hi].dr = decay_time((SPC_DSP_DATA >> 4) & 7);

  /* If voice releasing or not playing, nothing else to update */
  if (!(SNDkeys & BIT(addr_hi)) ||
   SNDvoices[addr_hi].env_state == RELEASE) break;

  if (SNDvoices[addr_hi].env_state == ATTACK)
   SNDvoices[addr_hi].env_update_count = SNDvoices[addr_hi].ar;
  else if (SNDvoices[addr_hi].env_state == DECAY)
   SNDvoices[addr_hi].env_update_count = SNDvoices[addr_hi].dr;

  if (SPC_DSP_DATA & 0x80)
  {
   // switch to ADSR (use old state if voice was switched since last key on)
   if (!(SPC_DSP[SPC_DSP_ADDR] & 0x80))
   {
    SNDvoices[addr_hi].env_state = SNDvoices[addr_hi].adsr_state;

    switch (SNDvoices[addr_hi].env_state)
    {
     case ATTACK:
      SNDvoices[addr_hi].env_update_count = SNDvoices[addr_hi].ar;
      break;
     case DECAY:
      SNDvoices[addr_hi].env_update_count = SNDvoices[addr_hi].dr;
      break;
     case SUSTAIN:
      SNDvoices[addr_hi].env_update_count = SNDvoices[addr_hi].sr;
      break;
    }
   }
  }
  else
  {
   // switch to a GAIN mode
   i = SPC_DSP[(addr_hi << 4) + DSP_VOICE_GAIN];

   SNDvoices[addr_hi].env_update_count =
    SNDvoices[addr_hi].gain_update_count;

   if (i & 0x80)
   {
    SNDvoices[addr_hi].env_state = i >> 5;
   }
   else
   {
    SNDvoices[addr_hi].env_state = DIRECT;
   }
  }
  break;

 // Channel - ADSR 2
 case DSP_VOICE_ADSR2:
  if (!sound_enabled) SNDvoices[addr_hi].voice_sample_latch =
   sound_sample_latch;
  if (SNDkeys & BIT(addr_hi)) UpdateEnvelopeHeight(addr_hi);

  SNDvoices[addr_hi].sr = exp_time(SPC_DSP_DATA & 0x1F);
  SNDvoices[addr_hi].sl = ((SPC_DSP_DATA >> 5) == 7) ? ENVX_MAX :
   (ENVX_MAX_BASE / 8) * ((SPC_DSP_DATA >> 5) + 1);

  if (SNDvoices[addr_hi].env_state == SUSTAIN)
   SNDvoices[addr_hi].env_update_count = SNDvoices[addr_hi].sr;

  break;

 // Channel - GAIN
 case DSP_VOICE_GAIN:
  if (!sound_enabled) SNDvoices[addr_hi].voice_sample_latch =
   sound_sample_latch;
  if (SNDkeys & BIT(addr_hi)) UpdateEnvelopeHeight(addr_hi);

  if (SPC_DSP_DATA & 0x80)
  {
   switch (SPC_DSP_DATA >> 5)
   {
    case INCREASE:
    case DECREASE:
     SNDvoices[addr_hi].gain_update_count =
      linear_time(SPC_DSP_DATA & 0x1F);
     break;

    case BENT:
     SNDvoices[addr_hi].gain_update_count =
      bent_time(SPC_DSP_DATA & 0x1F);
     break;

    case EXP:
     SNDvoices[addr_hi].gain_update_count =
      exp_time(SPC_DSP_DATA & 0x1F);
   }
  }
  else
  {
   SNDvoices[addr_hi].gain_update_count = apu_counter_reset_value;
  }

  /* If voice releasing or not playing, nothing else to update */
  if (!(SNDkeys & BIT(addr_hi)) ||
   SNDvoices[addr_hi].env_state == RELEASE) break;

  /* is gain enabled? */
  if (!(SPC_DSP[(addr_hi << 4) + DSP_VOICE_ADSR1] & 0x80))
  {
   SNDvoices[addr_hi].env_update_count =
    SNDvoices[addr_hi].gain_update_count;

   if (SPC_DSP_DATA & 0x80)
   {
    SNDvoices[addr_hi].env_state = SPC_DSP_DATA >> 5;
   }
   else
   {
    SNDvoices[addr_hi].env_state = DIRECT;
   }
  }

  break;

 case DSP_VOICE_ENVX:
 case DSP_VOICE_OUTX:
#ifdef DISALLOW_ENVX_OUTX_WRITE
  return;
#else
  break;
#endif

 // These are general registers
 case 0xC:
  switch (addr_hi)
  {
  // Main volume - left
  case DSP_MAIN_LVOL >> 4:
   main_lvol = (signed char) SPC_DSP_DATA;
   break;

  // Main volume - right
  case DSP_MAIN_RVOL >> 4:
   main_rvol = (signed char) SPC_DSP_DATA;
   break;

  // Echo volume - left
  case DSP_ECHO_LVOL >> 4:
   echo_lvol = (signed char) SPC_DSP_DATA;
   break;

  // Echo volume - right
  case DSP_ECHO_RVOL >> 4:
   echo_rvol = (signed char) SPC_DSP_DATA;
   break;

  // Key on
  case DSP_KON >> 4:
   break;

  // Key off
  case DSP_KOF >> 4:
   break;

  // Reset, mute, echo enable, noise clock select
  case DSP_FLG >> 4:
   noise_update_count = counter_update_table[SPC_DSP_DATA & 0x1F];
   break;

  // Sample end-block decoded
  case DSP_ENDX >> 4:
   SPC_DSP_DATA = 0;
   break;
  }

  break;

 case 0xD:
  switch (addr_hi)
  {
  // Echo Feedback
  case DSP_EFB >> 4:
   echo_feedback = (signed char) SPC_DSP_DATA;
   break;
  // Pitch modulation
//case DSP_PMON >> 4:
// break;
  // Noise enable
//case DSP_NON >> 4:
// break;
  // Echo enable
//case DSP_EON >> 4:
// break;
  // Source directory address
//case DSP_DIR >> 4:
// break;
  // Echo start address
  case DSP_ESA >> 4:
   echo_base = (unsigned) SPC_DSP_DATA << 8;
   break;
  // Echo delay
  case DSP_EDL >> 4:
   echo_delay = (SPC_DSP_DATA & 0x0F) << 11;
   break;
  }
  break;

 // FIR echo filter
 case 0xF:
  FIR_coeff[7 - addr_hi] = (signed char) SPC_DSP_DATA;
  break;
 }
 SPC_DSP[SPC_DSP_ADDR] = SPC_DSP_DATA;
}

void sound_pause(void)
{
 if (sound_enabled) platform_pause_audio_voice(&audio_voice);
}

void sound_resume(void)
{
 if (sound_enabled) platform_resume_audio_voice(&audio_voice);
}

#ifdef ALLEGRO_DOS
BEGIN_DIGI_DRIVER_LIST
 DIGI_DRIVER_SOUNDSCAPE
 DIGI_DRIVER_AUDIODRIVE
 DIGI_DRIVER_WINSOUNDSYS
 DIGI_DRIVER_SB
END_DIGI_DRIVER_LIST

BEGIN_MIDI_DRIVER_LIST
END_MIDI_DRIVER_LIST
#endif
