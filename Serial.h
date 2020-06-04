/* SERIAL.H: prototypes for 87C51 serial input/output routines */

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

extern volatile bit serial_tx_ready;
extern volatile bit serial_rx_ready;
extern volatile bit serial_rx_overflow;

extern void init_serial(byte period);
extern void flush_serial_input(void);
extern bit  put_serial_char(char ch);
extern char get_serial_char(void);

#pragma RESTORE
