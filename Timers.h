/* TIMERS.H: prototypes for 87C52 Timer 2 based routines */

/*
 * Copyright (c) 2002-2020, Ian Chapman (Chapmip Consultancy)
 *
 * This software is licensed under the MIT license (see LICENSE.TXT)
 *
 * See README.md for information on typical usage
 *
 */

#include <types.h>

#pragma SAVE
#pragma REGPARMS

extern volatile bit main_timeout;
extern volatile bit aux_timeout;
extern volatile bit I2C_tout;

extern void init_timers(word period);
extern void set_main_timeout(word ticks);
extern void set_aux_timeout(word ticks);
extern void set_I2C_watchdog(void);
extern void set_L1_on(void);
extern void set_L1_off(void);
extern void set_L1_flash(byte period);

#pragma RESTORE
