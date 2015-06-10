/*
 * Copyright (C) 2015  NAC-VA, Eduardo Lavratti
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

/**
 * @file modules/nav/nav_tower_rotorcraft.c
 *
 * tower survey for rotorcraft.
 *
 * Rectangle is defined by two points, sweep can be south-north or west-east.
 */

#include <stdio.h>

#include "mcu_periph/uart.h"
#include "messages.h"
#include "subsystems/datalink/downlink.h"

#if PERIODIC_TELEMETRY
#include "subsystems/datalink/telemetry.h"
#endif

#include "firmwares/rotorcraft/navigation.h"

#include "modules/nav/nav_tower_rotorcraft.h"
#include "state.h"

#include "generated/flight_plan.h"

int32_t carrot1;
int8_t sign_radius;

#define CARROT_DIST (12 << 8) //12
bool_t nav_tower_run(struct EnuCoor_i *wp_center, int32_t radius)
{
    struct Int32Vect2 pos_diff;
    VECT2_DIFF(pos_diff, *stateGetPositionEnu_i(), *wp_center);

    // store last qdr
    int32_t last_qdr = nav_circle_qdr;
    // compute qdr
    nav_circle_qdr = int32_atan2(pos_diff.y, pos_diff.x);
    // increment circle radians
    if (nav_circle_radians != 0) {
      int32_t angle_diff = nav_circle_qdr - last_qdr;
      INT32_ANGLE_NORMALIZE(angle_diff);
      nav_circle_radians += angle_diff;
    } else {
      // Smallest angle to increment at next step
      nav_circle_radians = 1;
    }

    // direction of rotation
 //int8_t sign_radius = radius > 0 ? 1 : -1;
    // absolute radius
    int32_t abs_radius = abs(radius);
    //carrot_angle = ((CARROT_DIST << INT32_ANGLE_FRAC) / abs_radius);
    Bound(carrot_angle, (INT32_ANGLE_PI / 16), INT32_ANGLE_PI_4);
    carrot_angle = nav_circle_qdr - carrot1;
    
          fprintf(stderr,"qdr:%d carrot_Ang:%d\n",nav_circle_qdr,carrot_angle );

    int32_t s_carrot, c_carrot;
    PPRZ_ITRIG_SIN(s_carrot, carrot_angle);
    PPRZ_ITRIG_COS(c_carrot, carrot_angle);
    // compute setpoint
    VECT2_ASSIGN(pos_diff, abs_radius * c_carrot, abs_radius * s_carrot);
    INT32_VECT2_RSHIFT(pos_diff, pos_diff, INT32_TRIG_FRAC);
    VECT2_SUM(navigation_target, *wp_center, pos_diff);

  nav_circle_center = *wp_center;
  nav_circle_radius = radius;
  horizontal_mode = HORIZONTAL_MODE_CIRCLE;

  return TRUE;
}



bool_t nav_tower_setup(void)
{
fprintf(stderr,"teste %d %d\n",1,2 );

  
  return FALSE;
}

