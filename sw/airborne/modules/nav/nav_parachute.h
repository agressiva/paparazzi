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

#ifndef NAV_PARACHUTE_H
#define NAV_PARACHUTE_H

#include "std.h"
#include "firmwares/fixedwing/nav.h"

/** periodic 4Hz function */
extern void nav_parachute_periodic(void);
extern unit_t nav_release_parachute(void);
extern unit_t nav_close_parachute(void);


#define NavParachuteReleaseHatch() nav_release_parachute()
#define NavParachuteCloseHatch() ({ ap_state->commands[COMMAND_PARACHUTE] = MAX_PPRZ; })

#endif // NAV_PARACHUTE_H