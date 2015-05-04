/*
 * Copyright (C) 2014 Eduardo Lavratti <agressiva@hotmail.com>
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

/** @file modules/digital_cam/dc_shoot_rc.c
 * Digital Camera remote shoot using radio channel.
 *
 * Use radio channel to take a picture.
 * Only works with fixedwing firmware.
 */

#include "dc_shoot_rc.h"
#include "dc.h"

#include "subsystems/radio_control.h"
//#include "inter_mcu.h"

#ifndef DC_RADIO_SHOOT
#error "You need to define DC_RADIO_SHOOT to a RADIO_xxx channel to use this module"
#endif

#ifndef DC_RADIO_SHOOT_DELAY 
#define DC_RADIO_SHOOT_DELAY 8
#endif

#ifndef DC_RADIO_SHOOT_THRESHOLD
#define DC_RADIO_SHOOT_THRESHOLD 1200
#endif

void dc_shoot_rc_periodic(void)
{
  static uint8_t rd_shoot = 0;
  static uint8_t rd_num = 0;
  
  if (rd_shoot == 0) // se apto a receber novo comando
  {
    //if (fbw_state->channels[DC_RADIO_SHOOT] > DC_RADIO_SHOOT_THRESHOLD) //se botao do radio apertado    (int32_t)radio_control.values[RADIO_CAM])
    if ( ((int32_t)radio_control.values[DC_RADIO_SHOOT]) > DC_RADIO_SHOOT_THRESHOLD) //se botao do radio apertado
    {
      dc_send_command(DC_SHOOT); //tira foto 
      rd_shoot = 1;
    }  
    else
    {
      rd_shoot = 0; //senao botao foi solto reseta temporizador
    }
  }
  else   // se nao esta apto a receber novo comando
  {
    if (rd_num < DC_RADIO_SHOOT_DELAY) {  //se ainda nao esta apto incrementa o contador  de tempo
    rd_num = rd_num + 1; 
    }
    else
    {
    rd_num = 0; // se esta apto habilita a receber novo comando 
    rd_shoot = 0;
    }
  }
  
}// dc_shot__rc_periodic
