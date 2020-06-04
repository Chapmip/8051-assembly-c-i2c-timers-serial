/* TIMING.H: constants related to processor clock frequency */

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

/* Processor crystal frequency and instruction cycle clock */

#define	FREQ		18432000L				/* Frequency in Hertz			*/
#define CYCLES		(FREQ/12)				/* Cycles in Hertz				*/

/* Serial bit clock (assuming SMOD=1) */

#define BAUD_CLK	(CYCLES/16)				/* Timer 1 period = BAUD_CLK / BAUD_RATE */

/* Timer 2 "tick" rate */

#define TICK_RATE	200						/* Timer tick rate (Hz)			*/
#define TICK_VAL	(CYCLES/TICK_RATE)		/* Tick period in cycles		*/

/* Timer load values for 1 second and 1 minute periods */

#define SECOND		TICK_RATE
#define MINUTE		(60*SECOND)

#pragma RESTORE
