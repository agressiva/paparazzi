/*
 * Copyright (C) 2012 Pranay Sinha <psinha@transition-robotics.com>
 *               2014 Eduardo Lavratti <agressiva@hotmail.com>
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

#include "led.h"
#include "subsystems/gps.h"
#include "subsystems/ahrs.h"
#include "subsystems/sensors/baro.h"
#include "subsystems/ins.h"
#include "generated/airframe.h"
#include "subsystems/electrical.h"
#include "subsystems/radio_control.h"
#include "autopilot.h"
#include "subsystems/ahrs/ahrs_aligner.h"
#include "autopilot_rc_helpers.h"
#include "subsystems/radio_control.h"
#include "firmwares/rotorcraft/guidance/guidance_v.h"

#include "led_safety_status.h"

#if defined (STM32F1) || defined(STM32F4)
#if defined (STM32F1)
#include <libopencm3/stm32/f1/gpio.h>
#include <libopencm3/stm32/f1/rcc.h>
#elif defined(STM32F4)
#include <libopencm3/stm32/f4/gpio.h>
#include <libopencm3/stm32/f4/rcc.h>
#endif
#define BEEPER_OFF      gpio_clear(BEEPER_GPIO, BEEPER_GPIO_PIN)
#define BEEPER_ON       gpio_set(BEEPER_GPIO, BEEPER_GPIO_PIN)
#define BEEPER_TOGGLE   gpio_toggle(BEEPER_GPIO, BEEPER_GPIO_PIN)
#endif

#ifndef SAFETY_WARNING_LED
#error You must define SAFETY_WARNING_LED to use this module!
#else

void led_safety_status_init(void) {
#if defined(STM32F1) || defined(STM32F2)
	GPIO_InitTypeDef GPIO_InitStructure;
  RCC_APB2PeriphClockCmd(BEEPER_GPIO_CLK, ENABLE);
  GPIO_InitStructure.GPIO_Pin = BEEPER_GPIO_PIN;
  GPIO_InitStructure.GPIO_Mode = GPIO_Mode_Out_PP;
  GPIO_InitStructure.GPIO_Speed = GPIO_Speed_2MHz;
  GPIO_Init(BEEPER_GPIO, &GPIO_InitStructure);
#elif defined(STM32F4)
  rcc_peripheral_enable_clock(&RCC_AHB1ENR, BEEPER_GPIO_CLK);
  gpio_mode_setup(BEEPER_GPIO, GPIO_MODE_OUTPUT, GPIO_PUPD_NONE, BEEPER_GPIO_PIN);
#endif
  BEEPER_OFF;
  LED_ON(SAFETY_WARNING_LED);
  led_safety_status_periodic();
}
/*
if (ahrs.status != AHRS_RUNNING || baro.status != BS_RUNNING || autopilot_mode == AP_MODE_KILL || autopilot_mode == AP_MODE_FAILSAFE)

if(autopilot_mode == AP_MODE_HOVER_Z_HOLD || autopilot_mode == AP_MODE_HOVER_CLIMB || autopilot_mode == AP_MODE_HOVER_DIRECT || autopilot_mode == AP_MODE_NAV) {	
			if (gps.fix == GPS_FIX_3D && ins_ltp_initialised == TRUE)
				set_beep_mode(BEEP_MODE_SYS_INIT, BEEP_MODE_OK);
*/

void led_safety_status_periodic(void) {
  static uint8_t old_autopilot_mode = 0 ;
  static uint8_t beep = 0 ;

  //if mode changed
  if (autopilot_mode != old_autopilot_mode) {
    beep = 10;
    old_autopilot_mode = autopilot_mode;
  }

  if (!stateIsAttitudeValid()) {
    RunOnceEvery(5, {beep=3;});
  }
  else
  #ifdef MIN_BAT_LEVEL
  if  ((autopilot_mode != AP_MODE_KILL) && (electrical.vsupply < ((LOW_BAT_LEVEL) * 10))){  //bateria no nivel minimo
    RunOnceEvery(5, {LED_TOGGLE(SAFETY_WARNING_LED);beep=4;});
  }
  else if  ((autopilot_mode != AP_MODE_KILL) && (electrical.vsupply < ((CRITIC_BAT_LEVEL) * 10))){  //bateria no nivel minimo
    RunOnceEvery(10, {LED_TOGGLE(SAFETY_WARNING_LED);beep=4;});
  }
  else if  ((autopilot_mode != AP_MODE_KILL) && (electrical.vsupply < ((CRITIC_BAT_LEVEL - 0.4) * 10))){ // bateria no nivel critico
     RunOnceEvery(20, {LED_TOGGLE(SAFETY_WARNING_LED);beep=4;});
  }
  else
#endif
  if (radio_control.status == RC_LOST || radio_control.status == RC_REALLY_LOST){ //radio desligado
  //  RunXTimesEvery(  0,  60, 30, 2, {LED_TOGGLE(SAFETY_WARNING_LED);BEEPER_TOGGLE;});  //0,60,30,7
  //  RunXTimesEvery(130, 130, 60, 1, {LED_TOGGLE(SAFETY_WARNING_LED);BEEPER_TOGGLE;}); //130,130,60,6
   RunXTimesEvery(  0,  60, 30, 2, { beep = 40;});
  }
 
 // gps nao locado em modo que precisa de gps
 else if (autopilot_mode == AP_MODE_HOVER_Z_HOLD || autopilot_mode == AP_MODE_HOVER_CLIMB || autopilot_mode == AP_MODE_HOVER_DIRECT || autopilot_mode == AP_MODE_NAV){
    if ((gps.num_sv < 5) || !(gps.fix == GPS_FIX_3D)){
    RunXTimesEvery( 1, 240, 100, 1, {LED_ON(SAFETY_WARNING_LED); beep = 2;})
    RunXTimesEvery( 0, 240, 100, 1, {LED_OFF(SAFETY_WARNING_LED);});
      }
  }
  
 // else if (!ahrs_is_aligned() || baro.status != BS_RUNNING || autopilot_mode == AP_MODE_KILL || autopilot_mode == AP_MODE_FAILSAFE){
 // else if (!ahrs_is_aligned() || ins_impl.baro_initialized != TRUE || !autopilot_mode == AP_MODE_KILL || autopilot_mode == AP_MODE_FAILSAFE){
 //  else if (!ahrs_is_aligned() || autopilot_mode == AP_MODE_KILL || autopilot_mode == AP_MODE_FAILSAFE){
  
 
  else if (  ((THROTTLE_STICK_DOWN() && !YAW_STICK_CENTERED()) && !autopilot_motors_on) ){
    RunOnceEvery(20, {LED_TOGGLE(SAFETY_WARNING_LED);beep=2;});
  }
 
  else if (autopilot_mode == AP_MODE_KILL){
    LED_OFF(SAFETY_WARNING_LED);
  }  
  
  else {
    LED_ON(SAFETY_WARNING_LED);
  }

    // else if ((autopilot_mode == AP_MODE_ATTITUDE_RC_CLIMB || autopilot_mode == AP_MODE_HOVER_CLIMB) && autopilot_motors_on) {
  if (guidance_v_mode == GUIDANCE_V_MODE_RC_CLIMB && autopilot_motors_on) {
    int32_t rc_zd;
    uint8_t temp;
    static uint8_t temp1;

    rc_zd = abs((MAX_PPRZ / 2) - (int32_t)radio_control.values[RADIO_THROTTLE]);
    DeadBand(rc_zd, (MAX_PPRZ/10));
    if (rc_zd == 0) {temp1 =0;}
    if (rc_zd > 0) {
      temp =  abs ((rc_zd - 4800)/200);
      temp1 ++;
      if (temp1 == temp){
        beep = 2;
        temp1 = 0;
      }
    }
  }
  
  
  
  // beep routine
  if (beep > 1){
    beep --;
    BEEPER_ON;
  }
  else if (beep == 1){
    BEEPER_OFF;
    beep = 0;
  }
  
  
//led_safety_status_periodic end
}
#endif
