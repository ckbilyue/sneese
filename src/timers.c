/*

SNEeSe, an Open Source Super NES emulator.


Copyright (c) 1998-2004 Charles Bilyue'.
Portions Copyright (c) 2003-2004 Daniel Horchner.

This is free software.  See 'LICENSE' for details.
You must read and accept the license prior to use.

*/

#include "wrapaleg.h"

/* timer handlers and counters
    all of these should be locked - if they shouldn't be, they should be
    moved out of this file!
   Timer_Handler_Profile, Timer_Counter_Profile
    200Hz timer for determining relative CPU usage
   Timer_Handler_Throttle, Timer_Counter_Throttle
    variable timer, used for speed throttling (50-60Hz or so)
 */

#ifdef DEBUG
volatile unsigned Timer_Counter_Profile = 0,
 CPU_Profile_Last = 0, CPU_Profile_Test = 0,
 SPC_Profile_Last = 0, SPC_Profile_Test = 0,
 GFX_Profile_Last = 0, GFX_Profile_Test = 0;

static void Timer_Handler_Profile(){ Timer_Counter_Profile++; }
END_OF_STATIC_FUNCTION(Timer_Handler_Profile);

#endif

volatile unsigned FPSTicks; /* was extern "C" */
volatile unsigned Timer_Counter_Throttle;
unsigned Frametime;

static void Timer_Handler_Throttle(){
 Timer_Counter_Throttle++; FPSTicks++;
}
END_OF_STATIC_FUNCTION(Timer_Handler_Throttle);

/* timer interface code
 * timers_init()
    locks timer handlers/counters, installs Allegro timer
 * timers_enable(throttle_time)
    installs timers, sets timing for speed throttle
 * timers_disable()
    removes timers
 * timers_shutdown()
    removes Allegro timer
 */
static int timers_ready = FALSE;
static int timers_enabled = FALSE;
static int timers_locked = FALSE;

void timers_init()
{
 if (!timers_locked)
 {
#ifdef DEBUG
  LOCK_FUNCTION(Timer_Handler_Profile);
  LOCK_VARIABLE(Timer_Counter_Profile);
#endif

  LOCK_FUNCTION(Timer_Handler_Throttle);
  LOCK_VARIABLE(Timer_Counter_Throttle);
  LOCK_VARIABLE(FPSTicks);
  timers_locked = TRUE;
 }
 if (!timers_ready)
 {
  install_timer();
  timers_ready = TRUE;
 }
}

void timers_enable(unsigned throttle_time)
{
 if (!timers_enabled)
 {
#ifdef DEBUG
  install_int_ex(Timer_Handler_Profile, MSEC_TO_TIMER(5));
#endif
  install_int_ex(Timer_Handler_Throttle, throttle_time);
  timers_enabled = TRUE;
 }
}

void timers_disable()
{
 if (timers_enabled)
 {
#ifdef DEBUG
  remove_int(Timer_Handler_Profile);
#endif
  remove_int(Timer_Handler_Throttle);
  timers_enabled = FALSE;
 }
}

void timers_shutdown()
{
 if (timers_ready)
 {
  timers_disable();
  remove_timer();
  timers_ready = FALSE;
 }
}

void set_timer_throttle_hz(int hertz)
{
 Frametime = BPS_TO_TIMER(hertz);
}

void set_timer_throttle_ms(int msec)
{
 Frametime = MSEC_TO_TIMER(msec);
}

void set_timer_throttle_ticks(int ticks)
{
 Frametime = ticks;
}
