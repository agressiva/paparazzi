/*
 *
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
 */

/* Driver for L3G4200
 */

#include "peripherals/l3g4200.extra.h"
#include "std.h"

#define ITG_CONF_UNINIT 0
#define ITG_CONF_REG1   1
#define ITG_CONF_REG5   2
#define ITG_CONF_DONE   3


// Data ready flag
volatile bool_t l3g4200_data_available;
// Data vector
struct Int32Rates l3g4200_data;
// I2C transaction structure
struct i2c_transaction l3g4200_i2c_trans;
// Init flag
bool_t l3g4200_initialized;
uint8_t l3g4200_init_status;

// TODO IRQ handling

void l3g4200_init(void)
{
  l3g4200_i2c_trans.status = I2CTransDone;
  l3g4200_i2c_trans.slave_addr = L3G4200_I2C_ADDR;
  l3g4200_initialized = FALSE;
  l3g4200_init_status = ITG_CONF_UNINIT;
}

// Configuration function called once before normal use
static void l3g4200_send_config(void)
{
  switch (l3g4200_init_status) {
    case ITG_CONF_REG1:
      l3g4200_i2c_trans.buf[0] = L3G4200_REG_CTRL_REG1;
      l3g4200_i2c_trans.buf[1] = L3G4200_CTRL_REG1;
      I2CTransmit(L3G4200_I2C_DEVICE, l3g4200_i2c_trans, L3G4200_I2C_ADDR, 2);
      l3g4200_init_status++;
      break;
    case ITG_CONF_REG5:
      l3g4200_i2c_trans.buf[0] = L3G4200_REG_CTRL_REG5;
      l3g4200_i2c_trans.buf[1] = L3G4200_CTRL_REG5;
      I2CTransmit(L3G4200_I2C_DEVICE, l3g4200_i2c_trans, L3G4200_I2C_ADDR, 2);
      l3g4200_init_status++;
      break;
    case ITG_CONF_DONE:
      l3g4200_initialized = TRUE;
      l3g4200_i2c_trans.status = I2CTransDone;
      break;
    default:
      break;
  }
}

// Configure
void l3g4200_configure(void)
{
  if (l3g4200_init_status == ITG_CONF_UNINIT) {
    l3g4200_init_status++;
    if (l3g4200_i2c_trans.status == I2CTransSuccess || l3g4200_i2c_trans.status == I2CTransDone) {
      l3g4200_send_config();
    }
  }
}

// Normal reading
void l3g4200_read(void)
{
  if (l3g4200_initialized && l3g4200_i2c_trans.status == I2CTransDone) {
    l3g4200_i2c_trans.buf[0] = l3g4200_REG_INT_STATUS;
    I2CTransceive(l3g4200_I2C_DEVICE, l3g4200_i2c_trans, L3G4200_I2C_ADDR, 1, 9);
  }
}

#define Int16FromBuf(_buf,_idx) ((int16_t)((_buf[_idx]<<8) | _buf[_idx+1]))

void l3g4200_event(void)
{
  if (l3g4200_initialized) {
    if (l3g4200_i2c_trans.status == I2CTransFailed) {
      l3g4200_i2c_trans.status = I2CTransDone;
    }
    else if (l3g4200_i2c_trans.status == I2CTransSuccess) {
      // Successfull reading and new data available
      if (l3g4200_i2c_trans.buf[0] & 0x01) {
        // New data available
        l3g4200_data.p = Int16FromBuf(l3g4200_i2c_trans.buf,3);
        l3g4200_data.q = Int16FromBuf(l3g4200_i2c_trans.buf,5);
        l3g4200_data.r = Int16FromBuf(l3g4200_i2c_trans.buf,7);
        l3g4200_data_available = TRUE;
      }
      l3g4200_i2c_trans.status = I2CTransDone;
    }
  }
  else if (!l3g4200_initialized && l3g4200_init_status != ITG_CONF_UNINIT) { // Configuring
    if (l3g4200_i2c_trans.status == I2CTransSuccess || l3g4200_i2c_trans.status == I2CTransDone) {
      l3g4200_i2c_trans.status = I2CTransDone;
      l3g4200_send_config();
    }
    if (l3g4200_i2c_trans.status == I2CTransFailed) {
      l3g4200_init_status--;
      l3g4200_i2c_trans.status = I2CTransDone;
      l3g4200_send_config(); // Retry config (TODO max retry)
    }
  }
}

