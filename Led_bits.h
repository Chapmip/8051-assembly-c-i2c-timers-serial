/* LED_BITS.H: prototypes for 87C51 LED bit manipulation routines */

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

extern void led_bits_calc(byte bmap_on, byte bmap_flash, byte idata *pair);

#pragma RESTORE
