/* DEMO.C: Main demonstration routine (brings together other modules) */

/*
 * Copyright (c) 2002-2020, Ian Chapman (Chapmip Consultancy)
 *
 * This software is licensed under the MIT license (see LICENSE.TXT)
 *
 * See README.md for further information on typical usage
 *
 */

#include <reg51.h>
#include <types.h>
#include <timing.h>
#include <ports.h>
#include <serial.h>
#include <i2c_51.h>
#include <timers.h>
#include <leds.h>


/* EXTRA SFR (AT89S53/AT89S8253 ONLY - REMOVE FOR 87C52) */

sfr SPCR = 0xD5;                                /* SPI control register */

#define SPI_DISABLE     0x04                    /* Disable SPI port */


/*  CONSTANTS   */

/* Serial interface */

#define BAUD_RATE   19200                       /* Serial baud rate */
#define BAUD_VAL    (BAUD_CLK/BAUD_RATE)        /* Serial clock in cycles */

/* LED L1 flash half-periods */

#define FLASH_INIT  (SECOND / 6)                /* 3 Hz */
#define FLASH_MAIN  (SECOND / 2)                /* 1 Hz */
#define FLASH_SLOW  (6 * (SECOND / 5))          /* 0.42 Hz (5/12 Hz) */


/* SUBROUTINES */
    
/* Wait for 1.0 second delay */

void delay_1_sec(void)
    {
    set_main_timeout(SECOND);

    while (!main_timeout)
        ;
    }


/* Wait for 10 second delay */

void delay_10_sec(void)
    {
    byte i = 10;
    
    while (i--)
        delay_1_sec();
    }


/* Initialise peripherals and supporting routines */

static void init_platform(void)
    {
    P0 |= P0_INIT_SET;                          /* Set most I/O pins to high/inputs */
    P1 |= P1_INIT_SET;
    P2 |= P2_INIT_SET;
    P3 |= P3_INIT_SET;

    SPCR = SPI_DISABLE;                         /* Disable SPI ports (AT89S53) */

    init_timers(TICK_VAL);                      /* Initialise timing functions */
    init_serial(BAUD_VAL);                      /* Initialise serial port */
    init_i2c();                                 /* Set up as I2C bus master */
    init_leds();                                /* Set up LED array */
    }


/* MAIN ROUTINE */

main()
    {
    char ch;

    init_platform();                            /* Set up dependencies */

    set_leds_on(LED_A8);                        /* Show initial state */
    delay_1_sec();

    set_leds_off(LED_A8);                       /* Move on to next state */
    set_leds_flash(LED_A7); 
    set_L1_flash(FLASH_INIT);
    delay_10_sec();

    set_leds_off(LED_A7);                       /* Move to holding state */
    set_leds_on(LED_A6);
    set_L1_flash(FLASH_MAIN);

    while (1)
        {   
        while (!(ch = get_serial_char()))       /* Wait for serial input */
            ;

        if (ch == 0x04)                         /* Exit if <CONTROL-D> */
            break;

        while (!put_serial_char(ch))            /* Echo to serial output */
            ;
        }

    set_leds_off(LED_A6);                       /* Show final state */
    set_leds_blink(LED_A5); 

    while (1)                                   /* Stick here */
        ;
    }
