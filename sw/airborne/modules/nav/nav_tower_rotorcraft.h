/*
 * Copyright (C) 2007-2009  ENAC, Pascal Brisset, Antoine Drouin
 *                    2015  NAC-VA, Eduardo Lavratti
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
 * @file modules/nav/nav_tower_rotorcraft.h
 *
 * Automatic survey of a tower for rotorcraft.
 *
 * Rectangle is defined by two points, sweep can be south-north or west-east.
 */

#ifndef NAV_TOWER_ROTORCRAFT_H
#define NAV_TOWER_ROTORCRAFT_H

#include "firmwares/rotorcraft/navigation.h"
extern float carrot1;
extern int8_t sign_radius;
extern bool_t nav_tower_run(struct EnuCoor_i *wp_center, int32_t radius);

#define NavTower(_center, _radius) { \
    nav_tower_run(&waypoints[_center].enu_i, POS_BFP_OF_REAL(_radius)); \
  }

#endif // NAV_TOWER_ROTORCRAFT_H
