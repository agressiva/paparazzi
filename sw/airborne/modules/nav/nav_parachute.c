/*
 * Copyright (C) 2007-2009  ENAC, Pascal Brisset, Antoine Drouin
 *                   2015 NAC-VA, Eduardo Lavratti         
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
 * @file modules/nav/nav_parachute.c
 *
 * Navigation module to release parachute at a given point
 * taking into account the wind and ground speed
 */


#include "nav_parachute.h"
#include "inter_mcu.h"

unit_t nav_release_parachute(void)
{
  ap_state->commands[COMMAND_PARACHUTE] = MIN_PPRZ;
  return 0;
}

unit_t nav_close_parachute(void)
{
  ap_state->commands[COMMAND_PARACHUTE] = MAX_PPRZ;
  return 0;
}

/*
#ifndef RC_PARACHUTE_RELEASE
#error "You need to define RC_PARACHUTE_RELEASE to a RADIO_xxx channel to use this module"
#endif  */

#ifndef RC_PARACHUTE_THRESHOLD
#define RC_PARACHUTE_THRESHOLD 3000
#endif 

void nav_parachute_periodic(void)
{
  static bool_t old_parachute_state = 0;
  bool_t parachute_state = 0;
  
  if (fbw_state->channels[RC_PARACHUTE_RELEASE] >  RC_PARACHUTE_THRESHOLD) {parachute_state = FALSE;}
  else parachute_state = TRUE; 

  if (old_parachute_state != parachute_state) 
  {
    if (parachute_state == TRUE)
    {
      nav_release_parachute();
    }
    else
    {
      nav_close_parachute();
    }
  }
  old_parachute_state = parachute_state;

  
}