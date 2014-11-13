/*
 * Copyright (C) 2011-2013 The Paparazzi Team
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

/**
 * @file modules/sensors/baro_ms5611_i2c.c
 * Measurement Specialties (Intersema) MS5611-01BA pressure/temperature sensor interface for I2C.
 *
 */


#include "modules/sensors/baro_ms5611_i2c.h"

#include "math/pprz_isa.h"
#include "mcu_periph/sys_time.h"
#include "subsystems/abi.h"
#include "mcu_periph/uart.h"
#include "messages.h"
#include "subsystems/datalink/downlink.h"


#ifndef MS5611_I2C_DEV
#define MS5611_I2C_DEV i2c0
#endif

/* address can be 0xEC or 0xEE (CSB\ low = 0xEE) */
#ifndef MS5611_SLAVE_ADDR
#define MS5611_SLAVE_ADDR 0xEE
#endif

#if PERIODIC_TELEMETRY
#include "subsystems/datalink/telemetry.h"
#endif

struct Ms5611_I2c baro_ms5611;

float fbaroms, ftempms;
float baro_ms5611_alt;
bool_t baro_ms5611_alt_valid;
bool_t baro_ms5611_enabled;

float baro_ms5611_r;
float baro_ms5611_sigma2;

static void baro_ms5611_downlink(struct transport_tx *trans, struct link_device *dev) {
    ftempms = baro_ms5611.data.temperature / 100.;
    fbaroms = baro_ms5611.data.pressure / 100.;
    pprz_msg_send_BARO_MS5611(trans, dev, AC_ID, 
                              &baro_ms5611.data.d1, &baro_ms5611.data.d2,
                              &fbaroms, &ftempms);
}

void baro_ms5611_init(void) {
  ms5611_i2c_init(&baro_ms5611, &MS5611_I2C_DEV, MS5611_SLAVE_ADDR);

  baro_ms5611_enabled = TRUE;
  baro_ms5611_alt_valid = FALSE;

  baro_ms5611_r = BARO_MS5611_R;
  baro_ms5611_sigma2 = BARO_MS5611_SIGMA2;
#if PERIODIC_TELEMETRY
  register_periodic_telemetry(DefaultPeriodic, "BARO_MS5611", baro_ms5611_downlink);
#endif
}

void baro_ms5611_periodic_check( void ) {

  ms5611_i2c_periodic_check(&baro_ms5611);

#if MS5611_SYNC_SEND
  // send coeff every 30s
  RunOnceEvery((30*BARO_MS5611_PERIODIC_CHECK_FREQ), baro_ms5611_send_coeff());
#endif
}

/// trigger new measurement or initialize if needed
void baro_ms5611_read(void) {
  if (sys_time.nb_sec > 1) {
    ms5611_i2c_read(&baro_ms5611);
  }
}

void baro_ms5611_event( void ) {

  ms5611_i2c_event(&baro_ms5611);

  if (baro_ms5611.data_available) {
    float pressure = (float)baro_ms5611.data.pressure;
    AbiSendMsgBARO_ABS(BARO_MS5611_SENDER_ID, &pressure);
    float temp = baro_ms5611.data.temperature / 100.0f;
    AbiSendMsgTEMPERATURE(BARO_MS5611_SENDER_ID, &temp);
    baro_ms5611.data_available = FALSE;

    baro_ms5611_alt = pprz_isa_altitude_of_pressure(pressure);
    baro_ms5611_alt_valid = TRUE;

#ifdef MS5611_SYNC_SEND
   baro_ms5611_downlink(&(DefaultChannel).trans_tx, &(DefaultDevice).device);
#endif
  }
}

void baro_ms5611_send_coeff(void) {
  if (baro_ms5611.initialized) {
    DOWNLINK_SEND_MS5611_COEFF(DefaultChannel, DefaultDevice,
                               &baro_ms5611.data.c[0],
                               &baro_ms5611.data.c[1],
                               &baro_ms5611.data.c[2],
                               &baro_ms5611.data.c[3],
                               &baro_ms5611.data.c[4],
                               &baro_ms5611.data.c[5],
                               &baro_ms5611.data.c[6],
                               &baro_ms5611.data.c[7]);
  }
}
