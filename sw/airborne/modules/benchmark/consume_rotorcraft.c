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

#include "firmwares/fixedwing/autopilot.h"
#include "subsystems/electrical.h"
#include "subsystems/navigation/common_nav.h"
#include "mcu_periph/uart.h"
#include "messages.h"
#include "subsystems/datalink/downlink.h"

#if PERIODIC_TELEMETRY
#include "subsystems/datalink/telemetry.h"
#endif

static struct FloatVect2 last_pos = {0.0, 0.0};
static float total_distance = 0;
uint16_t consumo = 0;

static void consume_downlink(struct transport_tx *trans, struct link_device *dev)
{
  uint16_t temp = total_distance;
  pprz_msg_send_CONSUME(trans, dev, AC_ID,
                                &consumo,
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
  if (autopilot_flight_time)
    {
      total_distance = total_distance + delta;
      uint16_t e = electrical.energy;
      float media = total_distance / e;
      consume = 1000 / media; //(Amp/Km)
    }
    consume_downlink(&(DefaultChannel).trans_tx, &(DefaultDevice).device);
}
