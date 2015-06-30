/*
 * Copyright (C) 2015 Lodewijk Sikkel <l.n.c.sikkel@tudelft.nl>
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

#ifndef MISSIONLIB_BLOCKS_H
#define MISSIONLIB_BLOCKS_H

// Disable auto-data structures
#ifndef MAVLINK_NO_DATA
#define MAVLINK_NO_DATA
#endif

#include "generated/flight_plan.h"
#include "mavlink/paparazzi/mavlink.h"

extern void mavlink_block_init(void);
extern void mavlink_block_cb(uint16_t current_block);
extern void mavlink_block_message_handler(const mavlink_message_t* msg);

#endif // MISSIONLIB_BLOCKS_H