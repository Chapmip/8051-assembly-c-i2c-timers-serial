/* LEDS.C: LED array control routines */

/*
 * Copyright (c) 2002-2020, Ian Chapman (Chapmip Consultancy)
 *
 * This software is licensed under the MIT license (see LICENSE.TXT)
 *
 * The PCA9551 is a handy I2C slave device that can drive an array of 8 LEDs
 * each independently configurable as on, off, flashing or blinking
 *
 * These routines encapsulate the functionality of the PCA9551 I2C slave
 * 
 * See README.md for further information on typical usage
 *
 */

#include <reg51.h>
#include <types.h>
#include <i2c_51.h>
#include <led_bits.h>
#include <leds.h>


/* CONSTANTS */

/* I2C bus address of PCA9551 slave device */

#define LEDS_BUS_ADDR		0xCA			/* LED array controller */


/* I2C sub-addresses for PCA9551 internal registers */

#define FLASH_SUB_ADDR		0x11			/* Flash mode control registers */
#define BLINK_SUB_ADDR		0x13			/* Blink mode control registers */
#define LEDS_SUB_ADDR		0x15			/* LED mode control registers */


/* Prescaler and PWM values for flash and blink modes (PCA9551) */

#define PSC_FLASH			 18				/* 500 ms flash period (2 Hz) */
#define PWM_FLASH			128				/* 50% flash duty cycle */

#define PSC_BLINK			 75				/* 2000 ms blink period (0.5 Hz) */
#define PWM_BLINK			 64				/* 75% blink duty cycle */


/* EXTERNALLY-ACCESSIBLE VARIABLES */

byte data leds_on;							/* Bitmap of on or flashing LEDs */
byte data leds_flash;						/* Bitmap of flashing or blinking LEDs */


/* SUBROUTINES */

/* Initialise LED array (all off) */
/* Does NOT change flash mode settings from initial defaults */

void init_leds(void)
	{
	clear_leds();
	}


/* Switch off all LEDs in array */

void clear_leds(void)
	{
	leds_on = 0x00;
	leds_flash = 0x00;

	update_leds();
	}


/* Switch on selected LEDs in array */

void set_leds_on(byte bitmask)
	{
	leds_on    |= bitmask;				/* Inverted by led_bits_calc() */
	leds_flash &= ~bitmask;

	update_leds();
	}


/* Switch off selected LEDs in array */

void set_leds_off(byte bitmask)
	{
	leds_on    &= ~bitmask;				/* Inverted by led_bits_calc() */
	leds_flash &= ~bitmask;

	update_leds();
	}


/* Configure prescaler and PWM values for flash mode on LED array */
/* Ignores any I2C bus errors (e.g. device not present) */

static void config_leds_flash(void)
	{
	byte pair[2];

	pair[0] = PSC_FLASH;
	pair[1] = PWM_FLASH;

	(void) write_i2c_sub((LEDS_BUS_ADDR << 8) + FLASH_SUB_ADDR, pair, 2);
	}	


/* Configure prescaler and PWM values for blink mode on LED array */
/* Ignores any I2C bus errors (e.g. device not present) */

static void config_leds_blink(void)
	{
	byte pair[2];

	pair[0] = PSC_BLINK;
	pair[1] = PWM_BLINK;

	(void) write_i2c_sub((LEDS_BUS_ADDR << 8) + BLINK_SUB_ADDR, pair, 2);
	}	


/* Sets selected LEDs in array to flash mode */

void set_leds_flash(byte bitmask)
	{
	leds_on    |= bitmask;				/* Inverted by led_bits_calc() */
	leds_flash |= bitmask;

	config_leds_flash();
	update_leds();
	}


/* Sets selected LEDs in array to blink mode */

void set_leds_blink(byte bitmask)
	{
	leds_on    &= ~bitmask;				/* Inverted by led_bits_calc() */
	leds_flash |= bitmask;

	config_leds_blink();
	update_leds();
	}


/* Updates LED array with current leds_on and leds_flash values */
/* Ignores any I2C bus errors (e.g. device not present) */

void update_leds(void)
	{
	byte pair[2];

	led_bits_calc(leds_on, leds_flash, pair);
	(void) write_i2c_sub((LEDS_BUS_ADDR << 8) + LEDS_SUB_ADDR, pair, 2);
	}	
