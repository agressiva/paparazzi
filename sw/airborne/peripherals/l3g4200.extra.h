/*
 * Copyright (C) 2011 Gautier Hattenberger
 *
 * This file is part of paparazzi.
 *
 * paparazzi is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * paparazzi is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with paparazzi; see the file COPYING.  If not, write to
 * the Free Software Foundation, 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 */

/* driver for the gyro L3G4200 from ST
 * this extra header allows standalone operation of the L3G4200
 */

#ifndef L3G4200_EXTRA_H
#define L3G4200_EXTRA_H

#include "std.h"
#include "math/pprz_algebra_int.h"
#include "mcu_periph/i2c.h"

/* Include address and register definition */
#include "peripherals/l3g4200.h"

/* Default conf */
#ifndef L3G4200_CTRL_REG1
#define L3G4200_CTRL_REG1 0x8f // 400hz ODR, 20hz filter, run!
#endif

#ifndef L3G4200_CTRL_REG5
#define L3G4200_CTRL_REG5 0x02 // low pass filter enable
#endif

/* Default I2C address */
#ifndef L3G4200_I2C_ADDR
#define L3G4200_I2C_ADDR L3G4200_ADDR
#endif

/* Default I2C device */
#ifndef L3G4200_I2C_DEVICE
#define L3G4200_I2C_DEVICE i2c1
#endif

// Config done flag
extern bool_t l3g3200_initialized;
// Data ready flag
extern volatile bool_t l3g4200_data_available;
// Data vector
extern struct Int32Rates l3g4200_data;
// I2C transaction structure
extern struct i2c_transaction l3g4200_trans;

// TODO IRQ handling

// Functions
extern void l3g4200_init(void);
extern void l3g4200_configure(void);
extern void l3g4200_read(void);
extern void l3g4200_event(void);

// Macro for using L3G4200 in periodic function
#define l3g4200Periodic() {                 \
  if (l3g4200_initialized) l3g4200_read();  \
  else l3g4200_configure();                 \
}

#define GyroEvent(_handler) {     \
    l3g4200_event();              \
    if (l3g4200_data_available) { \
      _handler();                 \
    }                             \
  }

#endif // L3G4200_EXTRA_H
