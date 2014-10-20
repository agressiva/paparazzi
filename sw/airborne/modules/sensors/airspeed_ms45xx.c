/*
 * Copyright (C) Freek van Tienen <freek.v.tienen@gmail.com>
 *
 * This file is part of paparazzi

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

/** @file modules/sensors/airspeed_ms45xx.c
 *  Airspeed driver for the MS45xx
 */

#include "std.h"
#include "state.h"
#include "mcu_periph/i2c.h"
#include "messages.h"
#include "subsystems/datalink/downlink.h"
#include "modules/sensors/airspeed_ms45xx.h"

/** Default I2C device on Navstik is i2c3
 */
#ifndef MS45XX_I2C_DEV
#define MS45XX_I2C_DEV i2c0
#endif

/** Sensor I2C slave address (defaults 0x50, 0x6C and 0x8D) */
#define MS45XX_I2C_ADDR 0x50

/** Number of values to compute an offset at startup */
#define OFFSET_NBSAMPLES_AVRG 100

/** Number of loops before starting to store data */
#ifndef MS45XX_START_DELAY
#define MS45XX_START_DELAY 30
#endif

/** Weight for offset IIR filter */
#define MS45XX_OFFSET_FILTER 2

/** Quadratic scale factor for airspeed.
 * airspeed = sqrt(2*p_diff/density)
 * With p_diff in Pa and standard air density of 1.225 kg/m^3,
 * default airspeed scale is 2/1.225
 */
#ifndef MS45XX_AIRSPEED_SCALE
#define MS45XX_AIRSPEED_SCALE 1.6327
#endif

/** Conversion factor from psi to Pa */
#define PSI_TO_PA 6894.75729

float psi, pa;
uint16_t startup_delay;
uint16_t offset_cnt;
uint16_t airspeed_adc;
uint16_t airspeed_offset;
uint16_t temperature_adc;
uint16_t temperature;
float ms45xx_airspeed;
uint16_t diff;
uint16_t status;

struct i2c_transaction ms45xx_trans;

void ms45xx_downlink(void) {
  DOWNLINK_SEND_MS45XX_AIRSPEED(DefaultChannel, DefaultDevice,
                               &airspeed_adc, &status, &pa,
                               &temperature,
			       &ms45xx_airspeed);
}

void ms45xx_init(void) {
  startup_delay = MS45XX_START_DELAY;
  offset_cnt = OFFSET_NBSAMPLES_AVRG;

  airspeed_adc = 0;
  airspeed_offset = 0;
  temperature_adc = 0;

  ms45xx_trans.status = I2CTransDone;
      if(ms45xx_trans.status == I2CTransDone) {
    i2c_receive(&MS45XX_I2C_DEV, &ms45xx_trans, MS45XX_I2C_ADDR, 1);
  }
  
  if(ms45xx_trans.status == I2CTransFailed) {
  	// Just retry if failed
  	ms45xx_trans.status = I2CTransDone;
  }
  
}

void ms45xx_periodic(void) {
  if(startup_delay > 0) {
    --startup_delay;
    return;
  }

  // Initiate next read
  if(ms45xx_trans.status == I2CTransDone) {
    i2c_receive(&MS45XX_I2C_DEV, &ms45xx_trans, MS45XX_I2C_ADDR, 4);
  }

 // RunOnceEvery(30, ms45xx_downlink());
    DOWNLINK_SEND_MS45XX_AIRSPEED(DefaultChannel, DefaultDevice,
                               &airspeed_adc, &status, &pa,
			       &temperature,
			       &ms45xx_airspeed);
}

void ms45xx_event(void) {
  // Check if transaction is succesfull 
  if(ms45xx_trans.status == I2CTransSuccess) {

    if ((0xC0 & ms45xx_trans.buf[0]) != 0) {status = 100;} else {status = 1;}
    // Get raw values from buffer
    airspeed_adc = ((ms45xx_trans.buf[0]) << 8) + (ms45xx_trans.buf[1]);
    airspeed_adc = 0x3FFF & airspeed_adc;
   // airspeed_adc    = 0x3FFF & (((uint16_t)(ms45xx_trans.buf[0]) << 8) | (uint16_t)(ms45xx_trans.buf[1]));
   // temperature_adc = 0xFFE0 & (((uint16_t)(ms45xx_trans.buf[2]) << 8) | (uint16_t)(ms45xx_trans.buf[3]));
temperature_adc = ((ms45xx_trans.buf[2]) << 8) + (ms45xx_trans.buf[3]);
temperature = ((2000.0f * temperature_adc) / 2047) -500;  
    
    // Consider 0 as a wrong value
    if(airspeed_adc != 0 && temperature_adc != 0) {
  
      
      if(offset_cnt > 0) {
        // IIR filter to compute an initial offset
#ifndef MS45XX_AIRSPEED_OFFSET
        airspeed_offset = (MS45XX_OFFSET_FILTER * airspeed_offset + airspeed_adc) / (MS45XX_OFFSET_FILTER + 1);
#else
        airspeed_offset = MS45XX_AIRSPEED_OFFSET;
#endif

        // decrease init counter
        --offset_cnt;
      }
      else {
        // Compute airspeed
        diff = Max(airspeed_adc-airspeed_offset, 0);
	psi = diff * 0.000122085f;
	pa = (float)psi * PSI_TO_PA;
        float tmp_airspeed = sqrtf(pa * MS45XX_AIRSPEED_SCALE);

        ms45xx_airspeed = (MS45XX_OFFSET_FILTER * ms45xx_airspeed + tmp_airspeed) / (MS45XX_OFFSET_FILTER + 1.);
#if USE_AIRSPEED_MS45XX
        stateSetAirspeed_f(&ms45xx_airspeed);
#endif
      }

    }

    // Set to done
    ms45xx_trans.status = I2CTransDone;
  }
  else if(ms45xx_trans.status == I2CTransFailed) {
  	// Just retry if failed
  	ms45xx_trans.status = I2CTransDone;
  }
}
