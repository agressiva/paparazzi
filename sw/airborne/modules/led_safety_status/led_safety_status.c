/*
 * Copyright (C) 2012 Pranay Sinha <psinha@transition-robotics.com>
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

#include "led_safety_status.h"

#if defined (STM32F1) || defined(STM32F4)
#if defined (STM32F1)
#include <libopencm3/stm32/f1/gpio.h>
#include <libopencm3/stm32/f1/rcc.h>
#elif defined(STM32F4)
#include <libopencm3/stm32/f4/gpio.h>
#include <libopencm3/stm32/f4/rcc.h>
#endif
#define BEEPER_OFF 		gpio_clear(BEEPER_GPIO, BEEPER_GPIO_PIN)
#define BEEPER_ON 		gpio_set(BEEPER_GPIO, BEEPER_GPIO_PIN)
#define BEEPER_TOGGLE         gpio_toggle(BEEPER_GPIO, BEEPER_GPIO_PIN)
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
  if (autopilot_mode != old_autopilot_mode) { //if mode changed
  }

  #ifdef MIN_BAT_LEVEL
  if  ((autopilot_mode != AP_MODE_KILL) && (electrical.vsupply < ((MIN_BAT_LEVEL -0.8) * 10))){  //bateria no nivel minimo
    RunOnceEvery(5, {LED_TOGGLE(SAFETY_WARNING_LED);BEEPER_TOGGLE;});
  }
  else if  ((autopilot_mode != AP_MODE_KILL) && (electrical.vsupply < ((MIN_BAT_LEVEL -0.5) * 10))){  //bateria no nivel minimo
    RunOnceEvery(10, {LED_TOGGLE(SAFETY_WARNING_LED);BEEPER_TOGGLE;});
  }
  else if  ((autopilot_mode != AP_MODE_KILL) && (electrical.vsupply < ((MIN_BAT_LEVEL) * 10))){ // bateria no nivel critico
     RunOnceEvery(20, {LED_TOGGLE(SAFETY_WARNING_LED);BEEPER_TOGGLE;});
   // RunXTimesEvery(0, 300, 10, 10, {LED_TOGGLE(SAFETY_WARNING_LED);BEEPER_TOGGLE;});
  }
  else
#endif
  if (radio_control.status == RC_LOST || radio_control.status == RC_REALLY_LOST){ //radio desligado
    RunXTimesEvery(  0,  60, 30, 2, {LED_TOGGLE(SAFETY_WARNING_LED);BEEPER_TOGGLE;});  //0,60,30,7
    RunXTimesEvery(130, 130, 60, 1, {LED_TOGGLE(SAFETY_WARNING_LED);BEEPER_TOGGLE;}); //130,130,60,6
  }
 
 // gps nao locado em modo que precisa de gps
 else if (autopilot_mode == AP_MODE_HOVER_Z_HOLD || autopilot_mode == AP_MODE_HOVER_CLIMB || autopilot_mode == AP_MODE_HOVER_DIRECT || autopilot_mode == AP_MODE_NAV){
    if ((gps.num_sv < 5) || !(gps.fix == GPS_FIX_3D)){
    //if ((gps.num_sv < 5) || !(gps.fix == GPS_FIX_3D && ins.status == INS_RUNNING)){
    //if ((gps.num_sv < 5) || !(gps.fix == GPS_FIX_3D && ins_ltp_initialised == TRUE)){
      RunXTimesEvery( 3, 240, 100, 1, {LED_ON(SAFETY_WARNING_LED);BEEPER_ON;})
      RunXTimesEvery( 0, 240, 100, 1, {LED_OFF(SAFETY_WARNING_LED);BEEPER_OFF;});
      }
  }
  
 // else if (ahrs.status != AHRS_RUNNING || baro.status != BS_RUNNING || autopilot_mode == AP_MODE_KILL || autopilot_mode == AP_MODE_FAILSAFE){
 // else if (ahrs.status != AHRS_RUNNING || ins_impl.baro_initialized != TRUE || !autopilot_mode == AP_MODE_KILL || autopilot_mode == AP_MODE_FAILSAFE){

//  else if (ahrs.status != AHRS_RUNNING || autopilot_mode == AP_MODE_KILL || autopilot_mode == AP_MODE_FAILSAFE){
//    RunXTimesEvery( 4, 260, 100, 2, {LED_ON(SAFETY_WARNING_LED);BEEPER_ON;});
//    RunXTimesEvery( 0, 260, 100, 2, {LED_OFF(SAFETY_WARNING_LED);BEEPER_OFF;});
//  }
  
  // se tentar ligar o motor e AP= KILL   (autopilot_mode == AP_MODE_KILL || autopilot_mode == AP_MODE_FAILSAFE) &&
  
  else if (  ((THROTTLE_STICK_DOWN() && !YAW_STICK_CENTERED()) && !autopilot_motors_on) ){
    RunOnceEvery(20, {LED_TOGGLE(SAFETY_WARNING_LED);BEEPER_TOGGLE;});
  }
  /*  else if (!THROTTLE_STICK_DOWN() && !autopilot_motors_on){
    RunXTimesEvery(20, 240, 100, 2, {LED_ON(SAFETY_WARNING_LED);BEEPER_ON;});
    RunXTimesEvery( 0, 240, 100, 2, {LED_OFF(SAFETY_WARNING_LED);BEEPER_OFF;});
  }
  else if (!ROLL_STICK_CENTERED() && !autopilot_motors_on){
    RunXTimesEvery(20, 240, 100, 3, {LED_ON(SAFETY_WARNING_LED);BEEPER_ON;});
    RunXTimesEvery( 0, 240, 100, 3, {LED_OFF(SAFETY_WARNING_LED);BEEPER_OFF;});
  }
  else if (!PITCH_STICK_CENTERED() && !autopilot_motors_on){
    RunXTimesEvery(20, 240, 100, 4, {LED_ON(SAFETY_WARNING_LED);BEEPER_ON;});
    RunXTimesEvery( 0, 240, 100, 4, {LED_OFF(SAFETY_WARNING_LED);BEEPER_OFF;});
  }
  else if (!YAW_STICK_CENTERED() && !autopilot_motors_on){
    RunXTimesEvery(20, 240, 100, 5, {LED_ON(SAFETY_WARNING_LED);BEEPER_ON;});
    RunXTimesEvery( 0, 240, 100, 5, {LED_OFF(SAFETY_WARNING_LED);BEEPER_OFF;});
  }*/
  else {
    LED_ON(SAFETY_WARNING_LED);
    BEEPER_OFF;
  }
}
#endif
