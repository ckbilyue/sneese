/*

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2003 Charles Bilyue'.
Portions Copyright (c) 2003 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

*/

/*
 Virtual game controller 'key' emulation

 Bit 7 of scancode is still reserved for make/break codes.

 Each controller begins at 0 - (1024 * controller #).
 Each controller is allowed up to 32 sticks, each with 4 axes.
 Each controller is allowed up to 256 buttons.

 Scancode layout is:
     0- 127: sticks  0-15, axes 0-3, directions 0-1
   256- 383: sticks 16-31, axes 0-3, directions 0-1
   512- 639: buttons   0-127
   768- 895: buttons 128-255
 */

#include <ctype.h>

#include "wrapaleg.h"

#include "input.h"
#include "helper.h"
#include "cpu/cpu.h"
#include "apu/sound.h"

/* PPU.asm */
extern unsigned char Layering_Mode;
extern unsigned char Layer_Disable_Mask;
extern unsigned char Offset_Change_Disable;
extern void Update_Layering(void);
extern void Toggle_Offset_Change(void);


SNES_CONTROLLER_INPUTS input_player1, input_player2;

signed char mouse_available;

unsigned char CONTROLLER_1_TYPE;
unsigned char CONTROLLER_2_TYPE;

volatile char key_released[KEY_MAX];

static void key_release_callback(int scancode)
{
 key_released[scancode & ~0x80] |= (scancode & 0x80);
}
END_OF_STATIC_FUNCTION(key_release_callback);

void install_key_release_callback()
{
 int i;
 static int key_release_callback_installed = (0 != 0);

 if (key_release_callback_installed) return;

 LOCK_FUNCTION(key_release_callback);
 LOCK_VARIABLE(key_released);

 for (i = 0; i < KEY_MAX; i++) key_released[i] = -1;

 keyboard_lowlevel_callback = key_release_callback;
 key_release_callback_installed = (0 == 0);
}

int UPDATE_KEYS(void)
{
 if (keyboard_needs_poll()) poll_keyboard();

 if (key[KEY_F1] && key_released[KEY_F1] != 0)
 {
  key_released[KEY_F1] = 0; SPC_MASK ^= 1;
 }

 if (key[KEY_F2] && key_released[KEY_F2] != 0)
 {
  key_released[KEY_F2] = 0; SPC_MASK ^= 2;
 }

 if (key[KEY_F3] && key_released[KEY_F3] != 0)
 {
  key_released[KEY_F3] = 0; SPC_MASK ^= 4;
 }

 if (key[KEY_F4] && key_released[KEY_F4] != 0)
 {
  key_released[KEY_F4] = 0; SPC_MASK ^= 8;
 }

 if (key[KEY_F5] && key_released[KEY_F5] != 0)
 {
  key_released[KEY_F5] = 0; SPC_MASK ^= 0x10;
 }

 if (key[KEY_F6] && key_released[KEY_F6] != 0)
 {
  key_released[KEY_F6] = 0; SPC_MASK ^= 0x20;
 }

 if (key[KEY_F7] && key_released[KEY_F7] != 0)
 {
  key_released[KEY_F7] = 0; SPC_MASK ^= 0x40;
 }

 if (key[KEY_F8] && key_released[KEY_F8] != 0)
 {
  key_released[KEY_F8] = 0; SPC_MASK ^= 0x80;
 }

 if (key[KEY_F11] && key_released[KEY_F11] != 0)
 {
  key_released[KEY_F11] = 0; FPS_ENABLED ^= (0 - 1);
 }

 if (key[KEY_F12] && key_released[KEY_F12] != 0)
 {
  key_released[KEY_F12] = 0; BREAKS_ENABLED ^= (0 - 1);
 }

 if (key[KEY_1] && key_released[KEY_1] != 0)
 {
  key_released[KEY_1] = 0; Layer_Disable_Mask ^= 1;
 }

 if (key[KEY_2] && key_released[KEY_2] != 0)
 {
  key_released[KEY_2] = 0; Layer_Disable_Mask ^= 2;
 }

 if (key[KEY_3] && key_released[KEY_3] != 0)
 {
  key_released[KEY_3] = 0; Layer_Disable_Mask ^= 4;
 }

 if (key[KEY_4] && key_released[KEY_4] != 0)
 {
  key_released[KEY_4] = 0; Layer_Disable_Mask ^= 8;
 }

 if (key[KEY_5] && key_released[KEY_5] != 0)
 {
  key_released[KEY_5] = 0; Layer_Disable_Mask ^= 0x10;
 }

 if (key[KEY_7] && key_released[KEY_7] != 0)
 {
  key_released[KEY_7] = 0; Toggle_Offset_Change();
 }

 if (key[KEY_6] && key_released[KEY_6] != 0)
 {
  key_released[KEY_6] = 0;
  if (Offset_Change_Disable != 0) Toggle_Offset_Change();
  Layering_Mode = 0;
  Layer_Disable_Mask = 0xFF;
  SPC_MASK = 0xFF;
 }

 if (key[KEY_8] && key_released[KEY_8] != 0)
 {
  key_released[KEY_8] = 0;
  if (Layering_Mode++ >= 2) Layering_Mode = 0;
 }

 Update_Layering();

 if (key[KEY_0] && key_released[KEY_0] != 0)
 {
  key_released[KEY_0] = 0;
  OutputScreen();
 }

 if (key[KEY_ESC] && key_released[KEY_ESC] != 0)
 {
  key_released[KEY_ESC] = 0;
  return (0 == 0);
 }

 while (key[KEY_F9]);

 if (key[KEY_F10])
 {
extern volatile unsigned Timer_Counter_Throttle;
  while (key[KEY_F10]);
  while (!key[KEY_F10] && !key[KEY_F11]);
  Timer_Counter_Throttle = 0;
 }

 return (0 != 0);
}

char fast_forward_enabled(void)
{
 if (keyboard_needs_poll()) poll_keyboard();

 return key[KEY_TILDE];
}

unsigned short MickeyRead;  /* MSB = Yyyyyyyy  LSB = Xxxxxxxx */
unsigned char MouseButtons;

void MickeyMouse()
{
 int mx,my;

 get_mouse_mickeys(&mx, &my);

 MouseButtons=mouse_b << 6;   /* save button state at time of read */

 MickeyRead = 0;
 if (mx < 0)
 {
  MickeyRead |= 0x80;
  mx = -mx;
 }
 MickeyRead |= (mx >> 1) & 0x7F;
 if (my < 0)
 {
  MickeyRead |= 0x8000;
  my = -my;
 }
 MickeyRead |= ((my >> 1) & 0x7F) << 8;
}

extern unsigned char NMITIMEN;
extern unsigned char Controller1_Pos, Controller23_Pos, Controller45_Pos;
extern unsigned char JOY1L, JOY1H, JOY2L, JOY2H;
extern unsigned char JOY3L, JOY3H, JOY4L, JOY4H;

int joystick_vkey_state(int vkey)
{
 int joystick, stick, axis, button;

 joystick = (vkey + 1) / JOYSTICK_OFFSET(0);
 if (joystick >= num_joysticks) return FALSE;

 vkey -= JOYSTICK_OFFSET(joystick);

 if (vkey < JOYSTICK_BUTTONS_OFFSET)
 {
  stick = (((vkey & ~255) >> 1) + (vkey & 127)) /
   (JOYSTICK_MAX_AXES_PER_STICK * 2);

  if (stick >= joy[joystick].num_sticks) return FALSE;

  vkey &= (JOYSTICK_MAX_AXES_PER_STICK * 2) - 1;

  axis = vkey >> 1;

  if (axis >= joy[joystick].stick[stick].num_axis) return FALSE;

  if (!(vkey & 1))
  {
   return joy[joystick].stick[stick].axis[vkey >> 1].d1;
  }
  else
  {
   return joy[joystick].stick[stick].axis[vkey >> 1].d2;
  }
 }


 /* If we get here, it's a button */
 vkey -= JOYSTICK_BUTTONS_OFFSET;

 button = (((vkey & ~255) >> 1) + (vkey & 127));

 if (button >= joy[joystick].num_buttons) return FALSE;

 return joy[joystick].button[button].b;
}

int get_vkey_state(int vkey)
{
 if (vkey < 0) return joystick_vkey_state(vkey);

 return key[vkey];
}

void update_controller(const SNES_CONTROLLER_INPUTS *input,
 unsigned char *JOYL, unsigned char *JOYH)
{
 if (CONTROLLER_1_TYPE != 1)
 {
  *JOYL = 0;

  /* Is A pressed? */
  if (get_vkey_state(input->a)) *JOYL |= 0x80;
  /* Is X pressed? */
  if (get_vkey_state(input->x)) *JOYL |= 0x40;
  /* Is L pressed? */
  if (get_vkey_state(input->l)) *JOYL |= 0x20;
  /* Is R pressed? */
  if (get_vkey_state(input->r)) *JOYL |= 0x10;

  *JOYH = 0;

  /* Is B pressed? */
  if (get_vkey_state(input->b)) *JOYH |= 0x80;
  /* Is Y pressed? */
  if (get_vkey_state(input->y)) *JOYH |= 0x40;
  /* Is SELECT pressed? */
  if (get_vkey_state(input->select)) *JOYH |= 0x20;
  /* Is START pressed? */
  if (get_vkey_state(input->start)) *JOYH |= 0x10;
  /* Is UP or DOWN pressed? */
  if (get_vkey_state(input->up)) *JOYH |=
   !get_vkey_state(input->down) ? 0x08 : 0;
  else *JOYH |= get_vkey_state(input->down) ? 0x04 : 0;
  /* Is LEFT or RIGHT pressed? */
  if (get_vkey_state(input->left)) *JOYH |=
   !get_vkey_state(input->right) ? 0x02 : 0;
  else *JOYH |= get_vkey_state(input->right) ? 0x01 : 0;
 }
}

/* JOYPAD UPDATE FUNCTION */
/* now called during VBL to accomodate JOYC1 & JOYC2 */
void update_controllers(void)
{
 if (keyboard_needs_poll()) poll_keyboard();

 poll_joystick();

 if (CONTROLLER_1_TYPE == 1 || CONTROLLER_2_TYPE == 1)
 /* mouse */
 {
  MickeyMouse();
 }

 /* reset controllers */
 if (NMITIMEN & 1)
 {
  Controller1_Pos = Controller23_Pos = Controller45_Pos = 0;
 }

 /* update controller 1 */
 update_controller(&input_player1, &JOY1L, &JOY1H);

 /* update controller 2 */
 update_controller(&input_player2, &JOY2L, &JOY2H);
}

void joyscantotext(int vkey, char *text)
{
 int joystick, stick;

 joystick = (vkey + 1) / JOYSTICK_OFFSET(0);
 vkey -= JOYSTICK_OFFSET(joystick);

 if (vkey < JOYSTICK_BUTTONS_OFFSET)
 {
  stick = (((vkey & ~255) >> 1) + (vkey & 127)) /
   (JOYSTICK_MAX_AXES_PER_STICK * 2);

  vkey &= (JOYSTICK_MAX_AXES_PER_STICK * 2) - 1;

  if (!(vkey & 1))
  {
   sprintf(text, "J%dS%dA%d-", joystick + 1, stick + 1, (vkey >> 1) + 1);
  }
  else
  {
   sprintf(text, "J%dS%dA%d+", joystick + 1, stick + 1, (vkey >> 1) + 1);
  }
 }
 else
 {
  vkey -= JOYSTICK_BUTTONS_OFFSET;

  sprintf(text, "J%dB%d", joystick + 1,
   (((vkey & ~255) >> 1) + (vkey & 127)) + 1);
 }
}

void scantotext(int scanc, char *text)
{
 if (scanc < 0)
 {
  joyscantotext(scanc, text);
  return;
 }
 text[0]=toupper(scancode_to_ascii(scanc));
 text[1]=0;
 switch(scanc)
 {
  case KEY_ALT: strcpy(text,"LAlt"); break;
  case KEY_ALTGR: strcpy(text,"RAlt"); break;
  case KEY_BACKSPACE: strcpy(text,"Bksp"); break;
  case KEY_CAPSLOCK: strcpy(text,"Caps"); break;
  case KEY_DEL: strcpy(text,"Del"); break;
  case KEY_DOWN: strcpy(text,"Down"); break;
  case KEY_END: strcpy(text,"End"); break;
  case KEY_ENTER: strcpy(text,"Ent"); break;
  case KEY_ENTER_PAD: strcpy(text,"GEnt"); break;
  case KEY_HOME: strcpy(text,"Home"); break;
  case KEY_INSERT: strcpy(text,"Ins"); break;
  case KEY_LCONTROL: strcpy(text,"LCtl"); break;
  case KEY_LEFT: strcpy(text,"Left"); break;
  case KEY_LSHIFT: strcpy(text,"LShf"); break;
  case KEY_LWIN: strcpy(text,"LWin"); break;
  case KEY_MENU: strcpy(text,"Menu"); break;
  case KEY_PGDN: strcpy(text,"PgDn"); break;
  case KEY_PGUP: strcpy(text,"PgUp"); break;
  case KEY_RCONTROL: strcpy(text,"RCtl"); break;
  case KEY_RIGHT: strcpy(text,"Rght"); break;
  case KEY_RSHIFT: strcpy(text,"RShf"); break;
  case KEY_RWIN: strcpy(text,"RWin"); break;
  case KEY_SPACE: strcpy(text,"Spc"); break;
  case KEY_TAB: strcpy(text,"Tab"); break;
  case KEY_UP: strcpy(text,"Up"); break;
  case KEY_F1: strcpy(text,"F1"); break;
  case KEY_F2: strcpy(text,"F2"); break;
  case KEY_F3: strcpy(text,"F3"); break;
  case KEY_F4: strcpy(text,"F4"); break;
  case KEY_F5: strcpy(text,"F5"); break;
  case KEY_F6: strcpy(text,"F6"); break;
  case KEY_F7: strcpy(text,"F7"); break;
  case KEY_F8: strcpy(text,"F8"); break;
  case KEY_F9: strcpy(text,"F9"); break;
  case KEY_F10: strcpy(text,"F10"); break;
  case KEY_F11: strcpy(text,"F11"); break;
  case KEY_F12: strcpy(text,"F12"); break;
  case KEY_0_PAD: strcpy(text,"Num0"); break;
  case KEY_1_PAD: strcpy(text,"Num1"); break;
  case KEY_2_PAD: strcpy(text,"Num2"); break;
  case KEY_3_PAD: strcpy(text,"Num3"); break;
  case KEY_4_PAD: strcpy(text,"Num4"); break;
  case KEY_5_PAD: strcpy(text,"Num5"); break;
  case KEY_6_PAD: strcpy(text,"Num6"); break;
  case KEY_7_PAD: strcpy(text,"Num7"); break;
  case KEY_8_PAD: strcpy(text,"Num8"); break;
  case KEY_9_PAD: strcpy(text,"Num9"); break;
  case KEY_PLUS_PAD: strcpy(text,"Num+"); break;
  case KEY_MINUS_PAD: strcpy(text,"Num-"); break;
  case KEY_SLASH_PAD: strcpy(text,"Num/"); break;
  case KEY_ASTERISK: strcpy(text,"Num*"); break;
  case KEY_DEL_PAD: strcpy(text,"Num."); break;
 }
}

// 4 joysticks, 256 buttons, 32 sticks * 4 axes * 2 directions
signed char joystick_key[4][2][256];

int joystick_axis_direction_to_vkey(int joystick, int stick, int axis,
 int direction)
{
 return JOYSTICK_OFFSET(joystick) + JOYSTICK_STICK_OFFSET(stick) +
  axis * 2 + direction;
}

int joystick_button_to_vkey(int joystick, int button)
{
 return JOYSTICK_OFFSET(joystick) + JOYSTICK_BUTTON_OFFSET(button);
}

int update_joystick_vkeys(void)
{
 int last_vkey = 0;
 int joystick, stick, axis, button;

 poll_joystick();

 for (joystick = 0; joystick < 4; joystick++)
 {
  if (joystick >= num_joysticks) break;

  for (stick = 0; stick < 32; stick++)
  {
   if (stick >= joy[joystick].num_sticks) break;

   for (axis = 0; axis < 4; axis++)
   {
    if (axis >= joy[joystick].stick[stick].num_axis) break;

    if (!last_vkey &&
     !joystick_key[joystick][0][stick * 4 + axis * 2 + 0] &&
     joy[joystick].stick[stick].axis[axis].d1)
    {
     last_vkey =
      joystick_axis_direction_to_vkey(joystick, stick, axis, 0);
    }

    joystick_key[joystick][0][stick * 4 + axis * 2 + 0] =
     joy[joystick].stick[stick].axis[axis].d1;

    if (!last_vkey &&
     !joystick_key[joystick][0][stick * 4 + axis * 2 + 1] &&
     joy[joystick].stick[stick].axis[axis].d2)
    {
     last_vkey =
      joystick_axis_direction_to_vkey(joystick, stick, axis, 1);
    }

    joystick_key[joystick][0][stick * 4 + axis * 2 + 1] =
     joy[joystick].stick[stick].axis[axis].d2;
   }
  }

  for (button = 0; button < 256; button++)
  {
   if (button >= joy[joystick].num_buttons) break;

   if (!last_vkey &&
    !joystick_key[joystick][1][button] && joy[joystick].button[button].b)
   {
    last_vkey = joystick_button_to_vkey(joystick, button);
   }

   joystick_key[joystick][1][button] = joy[joystick].button[button].b;
  }
 }

 return last_vkey;
}
