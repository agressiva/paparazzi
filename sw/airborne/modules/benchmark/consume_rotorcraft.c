/*
 * Copyright (C) 2015 Eduardo Reginato lavratti <agressiva@hotmail.com>
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

/** @file modules/benchmarck/consume_rotorcraft.c
 * Consumo por minute
 *
 */

#include "firmwares/rotorcraft/autopilot.h"
#include "subsystems/electrical.h"
//#include "subsystems/navigation/common_nav.h"
#include "mcu_periph/uart.h"
#include "messages.h"
#include "subsystems/datalink/downlink.h"

#if PERIODIC_TELEMETRY
#include "subsystems/datalink/telemetry.h"
#endif

static float corrente_media = 0;
static float corrente_media2 = 0;

uint16_t consume = 0;
static uint16_t consumetime;

static void consume_downlink(struct transport_tx *trans, struct link_device *dev)
{
  uint16_t temp = consumetime; //autopilot_flight_time;
  pprz_msg_send_CONSUME(trans, dev, AC_ID,
                                &consume,
                                &temp);
}

void consume_init(void)
{
#if PERIODIC_TELEMETRY
  register_periodic_telemetry(DefaultPeriodic, "CONSUME", consume_downlink);
#endif
}

void consume_periodic(void)
{
 if (autopilot_in_flight)
    {
      corrente_media2 = corrente_media2*.90 + electrical.current*.10;
      //consumetime = consumetime + 1;
      //corrente_media = corrente_media + electrical.current;
      //corrente_media2 = corrente_media / consumetime;
     // uint32_t e = electrical.current; // 
      //uint32_t e = electrical.energy; //corrente consumida em mha
      //float media = corrente_media; //consumo por minuto
      consume = (uint16_t)corrente_media2;
      //temp = autopilot_flight_time;
    }
    consume_downlink(&(DefaultChannel).trans_tx, &(DefaultDevice).device);
}


 // int32_t  current;       ///< current in amps
 // int32_t  consumed;      ///< consumption in mAh
 // float    energy;        ///< consumed energy em WATT


/*
 * 15amp/h
 * 15/60 = corrente por minuto
 * 
 * 
 * mA / per minute
 * 
 * 
 * 
 * 
 * 
 */





