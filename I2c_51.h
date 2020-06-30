/* I2C_51.H: prototypes for 87C51 I2C bus routines */

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

extern bit  i2c_tout_err;       /* Error due to timeout, not NACK */

extern bit  init_i2c      (void);
extern void set_i2c_lng   (byte address);
extern bit  poll_i2c      (byte address);
extern bit  poll_i2c_sub  (word address);
extern bit  write_i2c     (byte address, byte idata *ptr, byte count);
extern bit  write_i2c_sub (word address, byte idata *ptr, byte count);
extern bit  write_i2c_lng (word subaddr, byte idata *ptr, byte count);
extern bit  read_i2c      (byte address, byte idata *ptr, byte count);
extern bit  read_i2c_sub  (word address, byte idata *ptr, byte count);
extern bit  read_i2c_lng  (word subaddr, byte idata *ptr, byte count);
extern bit  comp_i2c      (byte address, byte idata *ptr, byte count);
extern bit  comp_i2c_sub  (word address, byte idata *ptr, byte count);
extern bit  comp_i2c_lng  (word subaddr, byte idata *ptr, byte count);

#pragma RESTORE
