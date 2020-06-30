/* PORTS.H: I/O port definitions */
/* Used by C51 files (definitions for A51 files are in PORTS.INC) */

/*
 * Copyright (c) 2002-2020, Ian Chapman (Chapmip Consultancy)
 *
 * This software is licensed under the MIT license (see LICENSE.TXT)
 *
 * See README.md for information on typical usage
 *
 */

#pragma SAVE
#pragma REGPARMS

/* I/O pin allocations */
/* ADD HERE -- e.g. sbit TEST_INP = P1^5; */


/* Initial I/O port states */

#define P0_INIT_SET     0xFF            /* All I/O pins high/input on re-start */
#define P1_INIT_SET     0xFF
#define P2_INIT_SET     0xFF
#define P3_INIT_SET     0xFF

#pragma RESTORE
