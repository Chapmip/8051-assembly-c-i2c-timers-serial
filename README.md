# 8051 assembly code modules for I2C, Timers and Serial functions

These assembly code modules for the [8051 series](https://www.nxp.com/docs/en/data-sheet/8XC51_8XC52.pdf) of 8-bit microcontrollers are drawn from several of my commercial designs.  They demonstrate the way that "bare-metal" assembly code (for speed) can be integrated successfully with 'C' code middleware and application code in a readable fashion.  I have removed any commercially-sensitive elements and included a "vanilla" demonstration application that utilises all of the modules so that the combined package can be adopted by others for learning, prototyping or implementation.

# Quick links

* [History](https://github.com/Chapmip/8051-assembly-c-i2c-timers-serial/blob/master/README.md#history)
* [Hierarchy of code modules](https://github.com/Chapmip/8051-assembly-c-i2c-timers-serial/blob/master/README.md#hierarchy-of-code-modules)
* [Descriptions of code modules](https://github.com/Chapmip/8051-assembly-c-i2c-timers-serial/blob/master/README.md#descriptions-of-code-modules)
* [`Demo.c` module](https://github.com/Chapmip/8051-assembly-c-i2c-timers-serial/blob/master/README.md#democ-module)
* [`Timers.a51` module](https://github.com/Chapmip/8051-assembly-c-i2c-timers-serial/blob/master/README.md#timersa51-module-and-header-file)
* [`I2c_51.a51` module](https://github.com/Chapmip/8051-assembly-c-i2c-timers-serial/blob/master/README.md#i2c_51a51-module-and-header-file)
* [`Led_bits.a51` module](https://github.com/Chapmip/8051-assembly-c-i2c-timers-serial/blob/master/README.md#led_bitsa51-module-and-header-file)
* [`Leds.c` module](https://github.com/Chapmip/8051-assembly-c-i2c-timers-serial/blob/master/README.md#ledsc-module-and-header-file)
* [`Serial.a51` module](https://github.com/Chapmip/8051-assembly-c-i2c-timers-serial/blob/master/README.md#seriala51-module-and-header-file)
* [Other header files](https://github.com/Chapmip/8051-assembly-c-i2c-timers-serial/blob/master/README.md#other-header-files)
* [References](https://github.com/Chapmip/8051-assembly-c-i2c-timers-serial/blob/master/README.md#references)

# History

I created these assembly code modules during the early 2000s for various commercial products using [8051-series](https://www.nxp.com/docs/en/data-sheet/8XC51_8XC52.pdf) microcontrollers from Philips (now NXP) and Atmel.  As such, they are well tried-and-tested, at least within my own range of use cases.  I believe that they remain applicable to the still-available modern derivatives of this microcontroller family.

My toolchain for the development of this code was an early version of the Keil A51/C51 assembler/compiler/linker running in an MS-DOS command window under Windows 98.  Despite the ancient provenance of this setup, I believe that it should still be readily possible to work with this code using a modern toolchain (not necessarily Keil).  The 8051 instruction set has not changed, so the code itself should not require any modifications beyond the accommodation of any special functions on new microcontroller variants.  It is possible, though, that some changes may be needed to some of the assembler directives, or perhaps even the framework for integrating assembly routines into 'C' code.  Consult your assembler and compiler manuals for assistance!

# Hierarchy of code modules

The code modules in this repository fall into the following hierarchy:

![Hierarchy of 8051 code modules](/photos/8051-code-hierarchy.png?raw=true "Hierarchy of 8051 code modules")

# Descriptions of code modules

The individual code modules are described below, together with guidance on their use.

## [`Demo.c`](/Demo.c) module

The `Demo.c` module serves only as a demonstration application that integrates the other modules and shows how they can operate together.

### External hardware requirements

The minimum requirement to demonstrate the running of this demonstration application is an LED connected via a series resistor (say 560 ohms) to the Vdd (+5V) supply from the P1.7 pin.  This diagnostic LED will also confirm that the `Timer.a51` module is operating as expected.

To show the functionality of the `I2c_51.a51`, `Leds.c` and `Led_bits.a51` modules, it is necessary to connect a [PCA9551 8-bit I2C-bus LED driver](https://www.nxp.com/docs/en/data-sheet/PCA9551.pdf) to the nominated I2C bus lines P0.0 (SCL) and P0.1 (SDA).  These two pins must also be fitted with pull-up resistors to the Vdd (+5V) supply, as they operate only in "open-drain" mode.  These resistors should be in the range 2k2 to 6k8 ohms: the exact values are not critical provided that short leads (< 20cm) are used to connect the PCA9551.  The only PCA 9551 outputs exercised by `Demo.c` are LED7, LED6, LED5 and LED4, so only these outputs need to be connected to LEDs through suitable series resistors (say 560 ohms) up to the Vdd (+5V) supply.

To show the functionality of the `Serial.a51` module, it is necessary to connect a serial device **at logic levels** (0V to Vdd) to P3.0 (TXD output from microcontroller) and P3.1 (RXD serial input to microcontroller).  It is also necessary to connect P2.7 (/CTS input to microcontroller) to ground, in order to indicate that the connected serial device is ready to receive serial data from the microcontroller.

### `Demo.c` operation

On startup, the `main()` code in this module:

* Initialises I/O ports on microcontroller to starting states (all high by default)
* Disables the SPI port function (example for an [AT89S53](http://ww1.microchip.com/downloads/en/devicedoc/doc0787.pdf) microcontroller — remove if not implemented on chosen device)
* Initialises the `Timer.a51`, `Serial.a51`, `I2c_51.a51` and `Leds.a51` module functions
* For one second, lights (steadily) the LED7 output from the PCA9551 (defined in code as `LED_A8`)
* For ten seconds, flashes the LED6 output from the PCA9551 (defined in code as `LED_A7`) and flashes quickly (3Hz) the diagnostic LED (on P1.7)
* Lights (steadily) the LED5 output from the PCA9551 (defined in code as `LED_A6`) and flashes slowly (1Hz) the diagnostic LED (on P1.7)

At this point, the `main()` code waits in a serial input loop in which it:

* Waits for a serial input character to arrive on the P3.1 (RXD) line at 19,200 baud (8 data bits, no parity bit, 1 stop bit)
* If the serial input character is anything other than a `<CONTROL-D>` (ASCII 4), then it is echoed back as a serial output character sent on the P3.0 (TXD) line in the same format
* If the serial input characted is a `<CONTROL-D>` (ASCII 4), then the serial input loop is terminated, otherwise it repeats as above.

When the serial input loop is terminated, the `main()` code:

* Switches off the LED5 output from the PCA9551
* Starts flashing the LED4 output from the PCA9551 (defined in code as `LED_A5`)
* Enters an infinite loop, to be continued until the microcontroller is reset or power-cycled.

## [`Timers.a51`](/Timers.a51) module (and [`header`](/Timers.h) file)

The `Timers.a51` module provides the following interrupt-driven background services:

* Two general-purpose timeout timers
* An I2C bus inactivity timeout timer (for the `I2c_51.a51` module)
* Ability to flash an LED (on P1.7 by default)
* Optional periodic watchdog resetting for AT89S53 and AT89S8253 microcontrollers

The `Timer.a51` module is only suitable for an 8052-variant microcontroller (e.g. [87C52](https://www.nxp.com/docs/en/data-sheet/8XC51_8XC52.pdf), [AT89S53](http://ww1.microchip.com/downloads/en/devicedoc/doc0787.pdf) and [AT89S8253](http://ww1.microchip.com/downloads/en/devicedoc/doc3286.pdf)) as it relies on Timer 2, which is not provided on a basic 8051 device.

*Note: One of the quirks of my old version of the assembler was that it did not intrinsically support the extra registers in an 8052 microcontroller as compared to the base 8051 version.  I therefore added equates to the `Timers.a51` code (highlighted by asterisks in my comments) to cover these extra registers and function bits.  It is possible that more recent assemblers include these definitions by default and will raise an error when they are re-defined by my code.  The simple solution should be to remove the highlighted section from my code.*

### `init_timers()` function

**Purpose:**

Initialises the `Timers.a51` module, including setting up regular Timer 2 interrupts ("ticks") at the specified periodic interval.

**Arguments:**

Unsigned 16-bit `period` specifying the number of CPU cycles between Timer 2 interrupts (see `CYCLES` frequency in [`Timing.h`](/Timing.h))

**Returns:**

None

### `set_main_timeout()` function

**Purpose:**

Configures the `main_timeout` flag (see below) to be set automatically after the specified number of Timer 2 ticks have elapsed (clears `main_timeout` initially).

**Arguments:**

Unsigned 16-bit `ticks` specifying the number of Timer 2 "ticks" (see `TICK_RATE` frequency in [`Timing.h`](/Timing.h)) before `main_timeout` is set

**Returns:**

None

### `main_timeout` status bit

**Purpose:**

Indicates whether a main timeout period set up using `set_main_timeout()` has expired.

**Values:**

* 1 (true bit) if main timeout period has expired
* 0 (false bit) if main timeout timer is still running

**Transitions:**

* Set by Timer 2 interrupt routine when the main timeout period expires — and also set initially by `init_timers()` 
* Cleared at first when `set_main_timeout()` is called

### `set_aux_timeout()` function

**Purpose:**

Configures the `aux_timeout` flag (see below) to be set automatically after the specified number of Timer 2 ticks have elapsed (clears `aux_timeout` initially).

**Arguments:**

Unsigned 16-bit `ticks` specifying the number of Timer 2 "ticks" (see `TICK_RATE` frequency in [`Timing.h`](/Timing.h)) before `aux_timeout` is set

**Returns:**

None

### `aux_timeout` status bit

**Purpose:**

Indicates whether an auxiliary timeout period set up using `set_aux_timeout()` has expired.

**Values:**

* 1 (true bit) if auxiliary timeout period has expired
* 0 (false bit) if auxiliary timeout timer is still running

**Transitions:**

* Set by Timer 2 interrupt routine when the auxiliary timeout period expires — and also set initially by `init_timers()` 
* Cleared at first when `set_aux_timeout()` is called

### `set_I2C_watchdog()` function

**Purpose:**

Configures an I2C bus watchdog timer so that the `i2c_tout` flag (see below) is set automatically once 256 Timer 2 "ticks" (see `TICK_RATE` frequency in [`Timing.h`](/Timing.h)) have elapsed (clears `i2c_tout` initially).

**Arguments:**

None

**Returns:**

None

### `i2c_tout` status bit

**Purpose:**

Indicates whether the I2C bus watchdog timer period set up using `set_I2C_watchdog()` has expired.

**Values:**

* 1 (true bit) if I2C bus watchdog timeout period has expired
* 0 (false bit) if I2C bus watchdog timeout timer is still running

**Transitions:**

* Set by Timer 2 interrupt routine when the I2C bus watchdog timeout period expires — and also set initially by `init_timers()` 
* Cleared at first when `set_I2C_watchdog()` is called

### `set_L1_on()` function

**Purpose:**

Switches on (steadily) directly-connected LED (on P1.7 by default)

**Arguments:**

None

**Returns:**

None

### `set_L1_off()` function

**Purpose:**

Switches off (steadily) directly-connected LED (on P1.7 by default).

**Arguments:**

None

**Returns:**

None

### `set_L1_flash()` function

**Purpose:**

Configures directly-connected LED (on P1.7 by default) to flash automatically with a specified half-period.

**Arguments:**

Unsigned 8-bit `period` specifying the number of Timer 2 "ticks" (see `TICK_RATE` frequency in [`Timing.h`](/Timing.h)) for a flash half-period (i.e. 2 x half-period for a full cycle)

**Returns:**

None

## [`I2c_51.a51`](/I2c_51.a51) module (and [`header`](/I2c_51.h) file)

The `I2c_51.a51` module provides I2C bus master functions to communicate with one or more I2C bus slave devices.

The 8051 microcontroller does not provide a hardware I2C peripheral, so these functions are achieved by "bit-banging" I/O ports in the foreground.  As written, this module depends on the `Timers.a51` module to provide an I2C bus watchdog timer to guard against the possibility of a bus malfunction leading to a "lock-up" condition.  If it is not possible to provide this dependency, then the `set_I2C_watchdog()` function can be stubbed out and the `i2c_tout()` status bit forced to zero.

The `I2c_51.a51` module should run on any 8051-variant microcontroller.

By default (see [`Ports.inc`](/Ports.inc)), the I2C bus lines are assigned to P0.0 (SCL) and P0.1 (SDA).

*Important note: In this module, the 7-bit bus addresses for I2C slaves must be presented in left-justified 8-bit format (i.e. shifted to the left by one bit, which is the same as multiplying it by two).  It is therefore important to inspect carefully the data sheet for an I2C slave, as some present the slave address in unshifted 7-bit format whereas others show it in a left-justified position.  In any case, the least significant bit of an 8-bit slave address presented as an argument to the `I2c_51.a51` functions is always discarded.*

### `init_i2c()` function

**Purpose:**

Attempts to initialise the I2C bus by releasing the SCL and SDA lines from the microcontroller side, then sending a series of 9 clock pulses to release the SDA line in the event that a slave device has jammed up partway through a transaction.

**Arguments:**

None

**Returns:**

* 1 if the I2C bus was initialised successfully
* 0 if an I2C bus timeout occurred during the operation (indicating that the bus remains jammed)

### `set_i2c_lng()` function

**Purpose:**

Must be called prior to invoking any of the `..._i2c_lng()` functions in order to specify the I2C slave bus address (main 7-bit address for the device) for those operations.  This is necessary because the interface definition between assembly code and 'C' code does not allow passing of the full set of arguments that would otherwise needed for these function calls.  

**Arguments:**

Unsigned 8-bit `address` containing 7-bit slave address as its upper 7 bits (the least significant bit is ignored).  See important note [above](https://github.com/Chapmip/8051-assembly-c-i2c-timers-serial/blob/master/README.md#i2c_51a51-module-and-header-file) — depending on the way that the slave address is specified, it may be necessary to shift it one bit to the left (i.e. multiply it by two) before providing it as an 8-bit argument.

**Returns:**

None

### `i2c_tout_err` status bit

**Purpose:**

Indicates that the failure of a previous I2C bus function was caused by a timeout on the I2C bus, as opposed to the lack of an acknowledgement from a slave device.

**Values:**

* 1 (true bit) if the previous I2C bus operation failed due to an I2C bus timeout
* 0 (false bit) if the previous I2C bus operation either succeeded or failed due to the lack of an acknowledgement from a slave device

**Transitions:**

Updated prior to exit by all functions in the `I2c_51.a51` module **except** `set_i2c_lng()`.

### `poll_i2c()` function

**Purpose:**

Polls for the presence or absence of an I2C bus slave at the specified I2C bus address.

**Arguments:**

Unsigned 8-bit `address` containing 7-bit slave address as its upper 7 bits (the least significant bit is ignored).  See important note [above](https://github.com/Chapmip/8051-assembly-c-i2c-timers-serial/blob/master/README.md#i2c_51a51-module-and-header-file) — depending on the way that the slave address is specified, it may be necessary to shift it one bit to the left (i.e. multiply it by two) before providing it as an 8-bit argument.

**Returns:**

* 1 if the I2C slave responded
* 0 if the I2C slave did not respond or an I2C bus timeout occurred during the operation

### `poll_i2c_sub()` function

**Purpose:**

Polls for the presence or absence of an I2C bus slave at the specified I2C bus address and sub-address within the device.

**Arguments:**

Unsigned 16-bit `address` consisting of two 8-bit fields:

* Most significant byte contains the 7-bit slave address as its upper 7 bits (the least significant bit is ignored).  See important note [above](https://github.com/Chapmip/8051-assembly-c-i2c-timers-serial/blob/master/README.md#i2c_51a51-module-and-header-file) — depending on the way that the slave address is specified, it may be necessary to shift it one bit to the left (i.e. multiply it by two) before providing it as an 8-bit argument.
* Least significant byte contains the 8-bit sub-address to be accessed within the I2C slave device.

**Returns:**

* 1 if the I2C slave responded
* 0 if the I2C slave did not respond or an I2C bus timeout occurred during the operation

### `write_i2c()` function

**Purpose:**

Attempts to write data from an array in internal RAM to an I2C bus slave at the specified I2C bus address without any sub-addressing within the device.

**Arguments:**

Unsigned 8-bit `address` containing 7-bit slave address as its upper 7 bits (the least significant bit is ignored).  See important note [above](https://github.com/Chapmip/8051-assembly-c-i2c-timers-serial/blob/master/README.md#i2c_51a51-module-and-header-file) — depending on the way that the slave address is specified, it may be necessary to shift it one bit to the left (i.e. multiply it by two) before providing it as an 8-bit argument.

Pointer `ptr` to an array of unsigned 8-bit data values in internal RAM

Unsigned 8-bit `count` of the number of values to write (should be <= `sizeof` array pointed to by `ptr`)

**Returns:**

* 1 if the I2C slave responded
* 0 if the I2C slave did not respond or an I2C bus timeout occurred during the operation

### `write_i2c_sub()` function

**Purpose:**

Attempts to write data from an array in internal RAM to an I2C bus slave at the specified I2C bus address and starting sub-address within the device.

**Arguments:**

Unsigned 16-bit `address` consisting of two 8-bit fields:

* Most significant byte contains the 7-bit slave address as its upper 7 bits (the least significant bit is ignored).  See important note [above](https://github.com/Chapmip/8051-assembly-c-i2c-timers-serial/blob/master/README.md#i2c_51a51-module-and-header-file) — depending on the way that the slave address is specified, it may be necessary to shift it one bit to the left (i.e. multiply it by two) before providing it as an 8-bit argument.
* Least significant byte contains the 8-bit starting sub-address to be accessed within the I2C slave device.

Pointer `ptr` to an array of unsigned 8-bit data values in internal RAM

Unsigned 8-bit `count` of the number of values to write (should be <= `sizeof` array pointed to by `ptr`)

**Returns:**

* 1 if the I2C slave responded
* 0 if the I2C slave did not respond or an I2C bus timeout occurred during the operation

### `write_i2c_lng()` function

**Purpose:**

Attempts to write data  from an array in internal RAM to an I2C bus slave at the specified I2C bus address and long starting sub-address (16 bits) within the device.

*It is essential that `set_i2c_lng()` is called with the required I2C bus address with the slave before invoking this function*

**Arguments:**

Unsigned 16-bit `subaddr` is the starting sub-address (long 16 bit form) to be accessed within the I2C slave device

Pointer `ptr` to an array of unsigned 8-bit data values in internal RAM

Unsigned 8-bit `count` of the number of values to write (should be <= `sizeof` array pointed to by `ptr`)

**Returns:**

* 1 if the I2C slave responded
* 0 if the I2C slave did not respond or an I2C bus timeout occurred during the operation

### `read_i2c()` function

**Purpose:**

Attempts to read data to an array in internal RAM from an I2C bus slave at the specified I2C bus address without any sub-addressing within the device.

**Arguments:**

Unsigned 8-bit `address` containing 7-bit slave address as its upper 7 bits (the least significant bit is ignored).  See important note [above](https://github.com/Chapmip/8051-assembly-c-i2c-timers-serial/blob/master/README.md#i2c_51a51-module-and-header-file) — depending on the way that the slave address is specified, it may be necessary to shift it one bit to the left (i.e. multiply it by two) before providing it as an 8-bit argument.

Pointer `ptr` to an array of unsigned 8-bit data values in internal RAM

Unsigned 8-bit `count` of the number of values to read (should be <= `sizeof` array pointed to by `ptr`)

**Returns:**

* 1 if the I2C slave responded
* 0 if the I2C slave did not respond or an I2C bus timeout occurred during the operation

### `read_i2c_sub()` function

**Purpose:**

Attempts to read data to an array in internal RAM from an I2C bus slave at the specified I2C bus address and starting sub-address within the device.

**Arguments:**

Unsigned 16-bit `address` consisting of two 8-bit fields:

* Most significant byte contains the 7-bit slave address as its upper 7 bits (the least significant bit is ignored).  See important note [above](https://github.com/Chapmip/8051-assembly-c-i2c-timers-serial/blob/master/README.md#i2c_51a51-module-and-header-file) — depending on the way that the slave address is specified, it may be necessary to shift it one bit to the left (i.e. multiply it by two) before providing it as an 8-bit argument.
* Least significant byte contains the 8-bit starting sub-address to be accessed within the I2C slave device.

Pointer `ptr` to an array of unsigned 8-bit data values in internal RAM

Unsigned 8-bit `count` of the number of values to read (should be <= `sizeof` array pointed to by `ptr`)

**Returns:**

* 1 if the I2C slave responded
* 0 if the I2C slave did not respond or an I2C bus timeout occurred during the operation

### `read_i2c_lng()` function

**Purpose:**

Attempts to read data to an array in internal RAM from an I2C bus slave at the specified I2C bus address and long starting sub-address (16 bits) within the device.

*It is essential that `set_i2c_lng()` is called with the required I2C bus address with the slave before invoking this function*

**Arguments:**

Unsigned 16-bit `subaddr` is the starting sub-address (long 16 bit form) to be accessed within the I2C slave device

Pointer `ptr` to an array of unsigned 8-bit data values in internal RAM

Unsigned 8-bit `count` of the number of values to read (should be <= `sizeof` array pointed to by `ptr`)

**Returns:**

* 1 if the I2C slave responded
* 0 if the I2C slave did not respond or an I2C bus timeout occurred during the operation

### `comp_i2c()` function

**Purpose:**

Attempts to compare data in an array in internal RAM with that read from an I2C bus slave at the specified I2C bus address without any sub-addressing within the device.

**Arguments:**

Unsigned 8-bit `address` containing 7-bit slave address as its upper 7 bits (the least significant bit is ignored).  See important note [above](https://github.com/Chapmip/8051-assembly-c-i2c-timers-serial/blob/master/README.md#i2c_51a51-module-and-header-file) — depending on the way that the slave address is specified, it may be necessary to shift it one bit to the left (i.e. multiply it by two) before providing it as an 8-bit argument.

Pointer `ptr` to an array of unsigned 8-bit data values in internal RAM

Unsigned 8-bit `count` of the number of values to compare (should be <= `sizeof` array pointed to by `ptr`)

**Returns:**

* 1 if the operation completed with an exact match between the data in the slave device and that in the array in internal RAM
* 0 if the data in the slave device does not match that in the array in internal RAM, or if the I2C slave did not respond or an I2C bus timeout occurred during the operation

### `comp_i2c_sub()` function

**Purpose:**

Attempts to compare data in an array in internal RAM with that read from an I2C bus slave at the specified I2C bus address and starting sub-address within the device.  This routine may be useful to confirm that a previous write to a series of sub-addresses (for example, in a memory device) has been successful.

**Arguments:**

Unsigned 16-bit `address` consisting of two 8-bit fields:

* Most significant byte contains the 7-bit slave address as its upper 7 bits (the least significant bit is ignored).  See important note [above](https://github.com/Chapmip/8051-assembly-c-i2c-timers-serial/blob/master/README.md#i2c_51a51-module-and-header-file) — depending on the way that the slave address is specified, it may be necessary to shift it one bit to the left (i.e. multiply it by two) before providing it as an 8-bit argument.
* Least significant byte contains the 8-bit starting sub-address to be accessed within the I2C slave device.

Pointer `ptr` to an array of unsigned 8-bit data values in internal RAM

Unsigned 8-bit `count` of the number of values to compare (should be <= `sizeof` array pointed to by `ptr`)

**Returns:**

* 1 if the operation completed with an exact match between the data in the slave device and that in the array in internal RAM
* 0 if the data in the slave device does not match that in the array in internal RAM, or if the I2C slave did not respond or an I2C bus timeout occurred during the operation

### `comp_i2c_lng()` function

**Purpose:**

Attempts to compare data in an array in internal RAM with that read from an I2C bus slave at the specified I2C bus address and long starting sub-address (16 bits) within the device.  This routine may be useful to confirm that a previous write to a series of sub-addresses (for example, in a memory device) has been successful.

*It is essential that `set_i2c_lng()` is called with the required I2C bus address with the slave before invoking this function*

**Arguments:**

Unsigned 16-bit `subaddr` is the starting sub-address (long 16 bit form) to be accessed within the I2C slave device

Pointer `ptr` to an array of unsigned 8-bit data values in internal RAM

Unsigned 8-bit `count` of the number of values to compare (should be <= `sizeof` array pointed to by `ptr`)

**Returns:**

* 1 if the operation completed with an exact match between the data in the slave device and that in the array in internal RAM
* 0 if the data in the slave device does not match that in the array in internal RAM, or if the I2C slave did not respond or an I2C bus timeout occurred during the operation

## [`Led_bits.a51`](/Led_bits.a51) module (and [`header`](/Led_bits.h) file)

The `Led_bits.a51` is a helper module providing efficient assembly code functions to support the `Leds.c` module.

### `led_bits_calc()` function

**Purpose:**

Converts a pair of bitmaps for 8 LEDs ('on' and 'flash' states) into the correct pair of register states for a [PCA9551 8-bit I2C-bus LED driver](https://www.nxp.com/docs/en/data-sheet/PCA9551.pdf).

**Arguments:**

Unsigned 8-bit bitmaps `bmap_on` and `bmap_flash`, plus pointer `pair` to a pair of unsigned 8-bit values in internal RAM to receive the converted output

**Returns:**

No explicit return values, but the two 8-bit values pointed to by `pair` are updated to the converted values

## [`Leds.c`](/Leds.c) module (and [`header`](/Leds.h) file)

The `Leds.c` module draws upon the `I2c_51.a51` and `Led_bits.a51` modules to provide an abstracted interface to an 8-bit LED array controlled by a [PCA9551 8-bit I2C-bus LED driver](https://www.nxp.com/docs/en/data-sheet/PCA9551.pdf) 

### `init_leds()` function

**Purpose:**

Initialises the `Leds.c` module, clearing the 8-bit LED array to an "all off" state (see `clear_leds()` below).

**Arguments:**

None

**Returns:**

None

### `clear_leds()` function

**Purpose:**

Clears the 8-bit LED array to an "all off" state.

**Arguments:**

None

**Returns:**

None

### `set_leds_on()` function

**Purpose:**

Switches on (steadily) those LEDs in the array for which the associated bit in the bit map is set (those with the bit clear are unaffected).

**Arguments:**

Unsigned 8-bit bitmap in which the LEDs to be switched on steadily are set to 1

**Returns:**

None

### `set_leds_off()` function

**Purpose:**

Switches off (steadily) those LEDs in the array for which the associated bit in the bit map is set (those with the bit clear are unaffected).

**Arguments:**

Unsigned 8-bit bitmap in which the LEDs to be switched off steadily are set to 1

**Returns:**

None

### `set_leds_flash()` function

**Purpose:**

Sets to flashing mode those LEDs in the array for which the associated bit in the bit map is set (those with the bit clear are unaffected).

**Arguments:**

Unsigned 8-bit bitmap in which the LEDs to be set to flashing mode are set to 1

**Returns:**

None

### `set_leds_blink()` function

**Purpose:**

Sets to blinking mode those LEDs in the array for which the associated bit in the bit map is set (those with the bit clear are unaffected).

**Arguments:**

Unsigned 8-bit bitmap in which the LEDs to be set to blinking mode are set to 1

**Returns:**

None

### `update_leds()` function

**Purpose:**

Forces an update of the LEDs from the externally visible values `leds_on` and `leds_flash`, which are normally manipulated implictly by the `set_leds_...()` functions.

**Arguments:**

None

**Returns:**

None

### `leds_on` byte value

**Purpose:**

Holds an 8-bit bitmap containing half of the state of each associated LED.

**Values:**

For each bit in the bitmap:

* 1 if LED is on or flashing
* 0 if LED is off or blinking

**Transitions:**

Changed by `init_leds()`, `clear_leds()`, `set_leds_on()`, `set_leds_off()`, `set_leds_flash()`, `set_leds_blink()` — or by external action

### `leds_flash` byte value

**Purpose:**

Holds an 8-bit bitmap containing half of the state of each associated LED.

**Values:**

For each bit in the bitmap:

* 1 if LED is flashing or blinking
* 0 if LED is on or off

**Transitions:**

Changed by `init_leds()`, `clear_leds()`, `set_leds_on()`, `set_leds_off()`, `set_leds_flash()`, `set_leds_blink()` — or by external action

## [`Serial.a51`](/Serial.a51) module (and [`header`](/Serial.h) file)

The `Serial.a51` module provides the following interrupt-driven background services:

* Placing incoming serial characters from the hardware UART into a receive buffer (if there is space)
* Updating the /RTS handshake output line to high (false) when the receive buffer reaches a "nearly full" state
* Setting a flag when space becomes available in the hardware UART for an outgoing serial character

The `Serial.a51` module will run on any 8051-variant microcontroller as long as there is adequate space available in the internal RAM for the desired size of receive buffer.

*Note: The `put_serial_char()` and `get_serial_char()` functions provided here are **non-blocking** (i.e. they return immediately whether or not the operation can be carried out immediately).  This was done by design so that these routines could be used within a cooperative multitasking regime with more than one finite state machine running concurently.  It is easy to convert these operations into blocking calls by adding a `while` loop around thee function calls (see `Demo.c`) to block until either the associated status bit becomes true or the call to the relevant function returns a success indication.*

### `init_serial()` function

**Purpose:**

Initialises the `Serial.a51` module, including setting up serial interrupts ("ticks"), flushing the receive buffer and configuring the UART (using Timer 1) to operate at the specified baud rate.

**Arguments:**

Unsigned 8-bit `period` specifying the specified baud rate (see `BAUD_CLK` in [`Timing.h`](/Timing.h)), which is adjusted by one as per the 8051 data sheet before loading it into the Timer 1 auto-reload register

**Returns:**

None

### `flush_serial_input()` function

**Purpose:**

Empties the receive buffer of any characters, returning with it empty.

**Arguments:**

None

**Returns:**

None

### `put_serial_char()` function

**Purpose:**

Attempts to send a serial character through the UART **without blocking** (i.e. returns immediately whether or not the character can be sent).

**Arguments:**

8-bit `ch` is the character to attempt to send

**Returns:**

* 1 (true bit) if character is successfully dispatched to the UART
* 0 (false bit) if either the UART transmitter is still busy or the /CTS handshake input line is high (false)

### `serial_tx_ready` status bit

**Purpose:**

Indicates whether the UART transmitter is ready to accept a character to send (i.e. not busy), so that a call to `put_serial_char()` will succeed unless the /CTS handshake input line is high (false).

**Values:**

* 1 (true bit) if UART transmitter is ready to accept a character to send
* 0 (false bit) if UART transmitter is still busy on a previous transmission

**Transitions:**

* Set by serial interrupt routine when the UART becomes free — and also by `init_serial()` 
* Cleared by `put_serial_char()` when a character is successfully dispatched to the UART

### `get_serial_char()` function

**Purpose:**

Attempts to extract a serial character from the receive buffer **without blocking** (i.e. returns immediately whether or not a character can be extracted), updating the /RTS handshake output line to low (true) if removal of a character brings the receive buffer to a "nearly empty" state.

**Arguments:**

None

**Returns:**

* 8-bit zero (ASCII `NUL`) if the receive buffer is empty (i.e. no character available to extract)
* 8-bit `ch` is the extracted character if the receive buffer was not previously empty

### `serial_rx_ready` status bit

**Purpose:**

Indicates whether the receive buffer contains any characters, so that a call to `put_serial_char()` will succeed.

**Values:**

* 1 (true bit) if receive buffer contains at least one character
* 0 (false bit) if receive buffer is empty

**Transitions:**

* Set by serial interrupt routine when new receive character arrives
* Cleared by `get_serial_char()` when it empties receive buffer — and also by `flush_serial_input()` or `init_serial()`

### `serial_rx_overflow` status bit

**Purpose:**

Indicates whether the receive buffer has overflowed, so that the most recently received characters have not been captured.

**Values:**

* 1 (true bit) if receive buffer has overflowed
* 0 (false bit) if receive buffer is empty

**Transitions:**

* Set by serial interrupt routine when overflow occurs
* Cleared by a call to `flush_serial_input()` or `init_serial()`

## Other header files

The following stand-alone header files provide definitions for the system as a whole:

* [`Timing.h`](/Timing.h) — Calculates system timing values from crystal frequency for microcontroller and desired Timer 2 tick rate
* [`Ports.h`](/Ports.h) — Provides microcontroller port definitions required by 'C' code modules (only `Demo.c` here)
* [`Ports.inc`](/Ports.inc) — Provides microcontroller port definitions required by assembly code modules (`Timers.a51`, `I2c_51.a51` and `Serial.a51`)
* [`Types.h`](/Types.h) — Type definitions for unsigned 8-bit, 16-bit and 32-bit values, plus useful manipulation macros

# References

* [80C51/87C51/80C52/87C52 8-bit microcontroller family](https://www.nxp.com/docs/en/data-sheet/8XC51_8XC52.pdf)
* [AT89S53 — 8-bit 8051-derivative Microcontroller with 12K Bytes Flash](http://ww1.microchip.com/downloads/en/devicedoc/doc0787.pdf)
* [AT89S8253 — 8-bit 8051-derivative Microcontroller with 12K Bytes Flash](http://ww1.microchip.com/downloads/en/devicedoc/doc3286.pdf)
* [PCA9551 — 8-bit I2C-bus LED driver with programmable blink rates](https://www.nxp.com/docs/en/data-sheet/PCA9551.pdf)
* [8051 Microcontrollers Hardware Manual](http://ww1.microchip.com/downloads/en/DeviceDoc/doc4316.pdf)
