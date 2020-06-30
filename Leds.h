/* LEDS.H: prototypes for LED array control routines */

/*
 * Copyright (c) 2002-2020, Ian Chapman (Chapmip Consultancy)
 *
 * This software is licensed under the MIT license (see LICENSE.TXT)
 *
 * See README.md for further information on typical usage
 *
 */

#include <types.h>

#pragma SAVE
#pragma REGPARMS

extern byte data leds_on;                   /* Bitmap of on or flashing LEDs */
extern byte data leds_flash;                /* Bitmap of flashing or blinking LEDs */

extern void init_leds(void);
extern void clear_leds(void);

extern void set_leds_on(byte bitmask);
extern void set_leds_off(byte bitmask);
extern void set_leds_flash(byte bitmask);
extern void set_leds_blink(byte bitmask);

extern void update_leds(void);


/* Bit masks for individual LEDs in array */

#define LED_A8      0x80
#define LED_A7      0x40
#define LED_A6      0x20
#define LED_A5      0x10
#define LED_A4      0x08
#define LED_A3      0x04
#define LED_A2      0x02
#define LED_A1      0x01

#pragma RESTORE
