/*

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

*/

#ifndef SNEeSe_input_h
#define SNEeSe_input_h

#include "misc.h"

#define JOYSTICK_MAX_JOYSTICKS 4
#define JOYSTICK_MAX_STICKS 32
#define JOYSTICK_MAX_AXES_PER_STICK 4
#define JOYSTICK_MAX_BUTTONS 256
#define JOYSTICK_OFFSET(joystick) \
 (-(1 + joystick) * (2 * (JOYSTICK_MAX_BUTTONS + \
 (JOYSTICK_MAX_STICKS * JOYSTICK_MAX_AXES_PER_STICK * 2))))

#define JOYSTICK_STICKS_OFFSET 0
#define JOYSTICK_STICK_OFFSET(stick) \
 (JOYSTICK_STICKS_OFFSET + \
 (stick * JOYSTICK_MAX_AXES_PER_STICK * 2) / 128 * 256 + \
 (stick * JOYSTICK_MAX_AXES_PER_STICK * 2) % 128)
#define JOYSTICK_BUTTONS_OFFSET \
 JOYSTICK_STICK_OFFSET(JOYSTICK_MAX_STICKS)
#define JOYSTICK_BUTTON_OFFSET(button) \
 (JOYSTICK_BUTTONS_OFFSET + button / 128 * 256 + (button & 127))

typedef struct {
 int up, down, left, right;
 int a, b, x, y, l, r, select, start;
} SNES_CONTROLLER_INPUTS;

EXTERN SNES_CONTROLLER_INPUTS input_player1, input_player2;

EXTERN signed char mouse_available;

EXTERN unsigned char CONTROLLER_1_TYPE;
EXTERN unsigned char CONTROLLER_2_TYPE;

EXTERN unsigned short MickeyRead;   /* MSB = Yyyyyyyy  LSB = Xxxxxxxx */
EXTERN unsigned char MouseButtons;

EXTERN void install_key_release_callback();
EXTERN void MickeyMouse(void);

EXTERN void scantotext(int scanc, char *text);
EXTERN int update_joystick_vkeys(void);

#endif /* !defined(SNEeSe_input_h) */
