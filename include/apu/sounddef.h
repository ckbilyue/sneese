/*

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2003 Charles Bilyue'.
Portions Copyright (c) 2003 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

*/

#ifndef SNEeSe_apu_sounddef_h
#define SNEeSe_apu_sounddef_h

#include "../misc.h"

#define OUTPUT_AUDIO_UNSIGNED_8
#define OUTPUT_AUDIO_UNSIGNED_16

#define SOUND_FREQ 32000    /* 32kHz true SNES mix speed */
#define SOUND_LAG  10       /* Lag between sound mixed and sound heard (1/LAG sec) */

#define OUTPUT_PRECISION 23
#define PREMIX_SHIFT_16 (OUTPUT_PRECISION - 16)
#define PREMIX_UPPER_LIMIT_16 (0x7FFF << PREMIX_SHIFT_16)
#define PREMIX_LOWER_LIMIT_16 (~PREMIX_UPPER_LIMIT_16)
#define PREMIX_SHIFT_8 (OUTPUT_PRECISION - 8)
#define PREMIX_UPPER_LIMIT_8 (0x7F << PREMIX_SHIFT_8)
#define PREMIX_LOWER_LIMIT_8 (~PREMIX_UPPER_LIMIT_8)

#define ENVX_PRECISION_BITS 11
#define ENVX_DOWNSHIFT_BITS (ENVX_PRECISION_BITS - 7)

#define ENVX_MAX_BASE ((unsigned) 1 << (ENVX_PRECISION_BITS))
#define ENVX_MAX (ENVX_MAX_BASE - 1)

#ifdef OUTPUT_AUDIO_UNSIGNED_8
#define OUTPUT_ZERO_BASE_8 0x80
#define OUTPUT_LOWER_LIMIT_8 0
#define OUTPUT_UPPER_LIMIT_8 0xFF
typedef unsigned char output_sample_8;
#else
#define OUTPUT_ZERO_BASE_8 0
#define OUTPUT_LOWER_LIMIT_8 -0x80
#define OUTPUT_UPPER_LIMIT_8 0x7F
typedef signed char output_sample_8;
#endif

#ifdef OUTPUT_AUDIO_UNSIGNED_16
#define OUTPUT_ZERO_BASE_16 0x8000
#define OUTPUT_LOWER_LIMIT_16 0
#define OUTPUT_UPPER_LIMIT_16 0xFFFF
typedef unsigned short output_sample_16;
#else
#define OUTPUT_ZERO_BASE_16 0
#define OUTPUT_LOWER_LIMIT_16 -0x8000
#define OUTPUT_UPPER_LIMIT_16 0x7FFF
typedef short output_sample_16;
#endif

#define BRR_PACKET_END  (1 << 0)    /* BRR end block flag */
#define BRR_PACKET_LOOP (1 << 1)    /* BRR sample loop flag */

#define DSP_MAIN_LVOL   0x0C    /* Master volume, left channel */
#define DSP_MAIN_RVOL   0x1C    /* Master volume, right channel */
#define DSP_ECHO_LVOL   0x2C    /* Echo volume, left channel */
#define DSP_ECHO_RVOL   0x3C    /* Echo volume, right channel */
#define DSP_KON         0x4C    /* Key on */
#define DSP_KOF         0x5C    /* Key off */
#define DSP_FLG         0x6C    /* Reset, mute, echo enable, noise frequency */
#define DSP_ENDX        0x7C    /* Sample played end-block */

#define DSP_EFB     0x0D    /* Echo feedback */
#define DSP_PMON    0x2D    /* Pitch modulation */
#define DSP_NON     0x3D    /* Noise enable */
#define DSP_EON     0x4D    /* Echo enable */
#define DSP_DIR     0x5D    /* Sample directory */
#define DSP_ESA     0x6D    /* Echo start address */
#define DSP_EDL     0x7D    /* Echo delay */ 

#define DSP_VOICE_LVOL      0   /* Voice volume, left channel */
#define DSP_VOICE_RVOL      1   /* Voice volume, right channel */
#define DSP_VOICE_PITCH_L   2   /* Playback pitch, low 8 bits */
#define DSP_VOICE_PITCH_H   3   /* Playback pitch, high 6 bits */
#define DSP_VOICE_SRCN      4   /* Source number */
#define DSP_VOICE_ADSR1     5   /* ADSR register 1 */
#define DSP_VOICE_ADSR2     6   /* ADSR register 2 */
#define DSP_VOICE_GAIN      7   /* GAIN register */
#define DSP_VOICE_ENVX      8   /* ADSR/GAIN envelope height */
#define DSP_VOICE_OUTX      9   /* Envelope-applied sample output */

#define DSP_FLG_RESET (1 << 7)
#define DSP_FLG_MUTE  (1 << 6)
#define DSP_FLG_NECEN (1 << 5)

#ifdef FAST_SPC
#define SPC_CLOCK_HZ (2048000)
#define TIMER_0_CYCLES_TO_TICKS_SHIFT 8
#define TIMER_1_CYCLES_TO_TICKS_SHIFT 8
#define TIMER_2_CYCLES_TO_TICKS_SHIFT 5
#define SOUND_CYCLES_TO_SAMPLES_SHIFT 6
#else
#define SPC_CLOCK_HZ (1024000)
#define TIMER_0_CYCLES_TO_TICKS_SHIFT 7
#define TIMER_1_CYCLES_TO_TICKS_SHIFT 7
#define TIMER_2_CYCLES_TO_TICKS_SHIFT 4
#define SOUND_CYCLES_TO_SAMPLES_SHIFT 5
#endif

#define TIMER_0_CYCLES_PER_TICK (SPC_CLOCK_HZ / 8000)
#define TIMER_1_CYCLES_PER_TICK (SPC_CLOCK_HZ / 8000)
#define TIMER_2_CYCLES_PER_TICK (SPC_CLOCK_HZ / 64000)
#define SOUND_CYCLES_PER_SAMPLE (SPC_CLOCK_HZ / 32000)
#define RELEASE_TIME (SOUND_CYCLES_PER_SAMPLE)

#endif /* !defined(SNEeSe_apu_sounddef_h) */
