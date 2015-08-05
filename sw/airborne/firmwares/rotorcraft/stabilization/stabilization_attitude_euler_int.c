/*
 * Copyright (C) 2008-2009 Antoine Drouin <poinix@gmail.com>
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
 * @file stabilization_attitude_euler_int.c
 *
 * Rotorcraft attitude stabilization in euler int version.
 */

#include "generated/airframe.h"

#include "filters/low_pass_filter.h"

#include "firmwares/rotorcraft/stabilization/stabilization_attitude.h"
#include "firmwares/rotorcraft/stabilization/stabilization_attitude_rc_setpoint.h"

#include "std.h"
#include "paparazzi.h"
#include "math/pprz_algebra_int.h"
#include "state.h"

/** Time constant for second order Butterworth low pass filter
 * Default of 0.15 should give cut-off freq of 1/(2*pi*tau) ~= 1Hz
 */
#ifndef STAB_D_LOWPASS_FREQ
#define STAB_D_LOWPASS_FREQ 50   // 17 ou 32
#endif

#if STAB_D_LOWPASS_FREQ < 8
#error "It is not allowed to use a cutoff frequency lower than 8Hz due to overflow issues."
#endif

#ifndef STAB_P_LOWPASS_FREQ
#define STAB_P_LOWPASS_FREQ 26   // 32 ou 50
#endif

PRINT_CONFIG_VAR(STAB_D_LOWPASS_FREQ)

#define DT_UPDATE (1./PERIODIC_FREQUENCY)


static Butterworth2LowPass_int stab_p_filter;
static Butterworth2LowPass_int stab_q_filter;

static Butterworth2LowPass_int stab_att_phi_filter;
static Butterworth2LowPass_int stab_att_theta_filter;

struct Int32AttitudeGains  stabilization_gains;
int32_t ratep_gain, rateq_gain, rater_gain; // eu coloquei - funciona melhor 
int32_t rateSumpFiltered, rateSumqFiltered;
int32_t att_err_phi_filtered, att_err_theta_filtered;

/* warn if some gains are still negative */
#if (STABILIZATION_ATTITUDE_PHI_PGAIN < 0) || \
  (STABILIZATION_ATTITUDE_THETA_PGAIN < 0) || \
  (STABILIZATION_ATTITUDE_PSI_PGAIN < 0)   || \
  (STABILIZATION_ATTITUDE_PHI_DGAIN < 0)   || \
  (STABILIZATION_ATTITUDE_THETA_DGAIN < 0) || \
  (STABILIZATION_ATTITUDE_PSI_DGAIN < 0)   || \
  (STABILIZATION_ATTITUDE_PHI_IGAIN < 0)   || \
  (STABILIZATION_ATTITUDE_THETA_IGAIN < 0) || \
  (STABILIZATION_ATTITUDE_PSI_IGAIN  < 0)
#error "ALL control gains have to be positive!!!"
#endif

struct Int32Eulers stabilization_att_sum_err;

int32_t stabilization_att_fb_cmd[COMMANDS_NB];
int32_t stabilization_att_ff_cmd[COMMANDS_NB];

static inline void reset_psi_ref_from_body(void)
{
  //sp has been set from body using stabilization_attitude_get_yaw_i, use that value
  stab_att_ref_euler.psi = stab_att_sp_euler.psi << (REF_ANGLE_FRAC - INT32_ANGLE_FRAC);
  stab_att_ref_rate.r = 0;
  stab_att_ref_accel.r = 0;
}

#if PERIODIC_TELEMETRY
#include "subsystems/datalink/telemetry.h"

static void send_att(struct transport_tx *trans, struct link_device *dev)
{
  struct Int32Rates *body_rate = stateGetBodyRates_i();
  struct Int32Eulers *att = stateGetNedToBodyEulers_i();
  pprz_msg_send_STAB_ATTITUDE_INT(trans, dev, AC_ID,
                                  &(body_rate->p), &(body_rate->q), &(body_rate->r),
                                  &(att->phi), &(att->theta), &(att->psi),
                                  &stab_att_sp_euler.phi,
                                  &stab_att_sp_euler.theta,
                                  &stab_att_sp_euler.psi,
                                  &stabilization_att_sum_err.phi,
                                  &stabilization_att_sum_err.theta,
                                  &stabilization_att_sum_err.psi,
                                  &stabilization_att_fb_cmd[COMMAND_ROLL],
                                  &stabilization_att_fb_cmd[COMMAND_PITCH],
                                  &stabilization_att_fb_cmd[COMMAND_YAW],
                                  &stabilization_att_ff_cmd[COMMAND_ROLL],
                                  &stabilization_att_ff_cmd[COMMAND_PITCH],
                                  &stabilization_att_ff_cmd[COMMAND_YAW],
                                  &stabilization_cmd[COMMAND_ROLL],
                                  &stabilization_cmd[COMMAND_PITCH],
                                  &stabilization_cmd[COMMAND_YAW]);
}

static void send_att_ref(struct transport_tx *trans, struct link_device *dev)
{
  pprz_msg_send_STAB_ATTITUDE_REF_INT(trans, dev, AC_ID,
                                      &stab_att_sp_euler.phi,
                                      &stab_att_sp_euler.theta,
                                      &stab_att_sp_euler.psi,
                                      &stab_att_ref_euler.phi,
                                      &stab_att_ref_euler.theta,
                                      &stab_att_ref_euler.psi,
                                      &stab_att_ref_rate.p,
                                      &stab_att_ref_rate.q,
                                      &stab_att_ref_rate.r,
                                      &stab_att_ref_accel.p,
                                      &stab_att_ref_accel.q,
                                      &stab_att_ref_accel.r);
}
#endif

void stabilization_attitude_init(void)
{

  stabilization_attitude_ref_init();


  VECT3_ASSIGN(stabilization_gains.p,
               STABILIZATION_ATTITUDE_PHI_PGAIN,
               STABILIZATION_ATTITUDE_THETA_PGAIN,
               STABILIZATION_ATTITUDE_PSI_PGAIN);

  VECT3_ASSIGN(stabilization_gains.d,
               STABILIZATION_ATTITUDE_PHI_DGAIN,
               STABILIZATION_ATTITUDE_THETA_DGAIN,
               STABILIZATION_ATTITUDE_PSI_DGAIN);

  VECT3_ASSIGN(stabilization_gains.i,
               STABILIZATION_ATTITUDE_PHI_IGAIN,
               STABILIZATION_ATTITUDE_THETA_IGAIN,
               STABILIZATION_ATTITUDE_PSI_IGAIN);

  VECT3_ASSIGN(stabilization_gains.dd,
               STABILIZATION_ATTITUDE_PHI_DDGAIN,
               STABILIZATION_ATTITUDE_THETA_DDGAIN,
               STABILIZATION_ATTITUDE_PSI_DDGAIN);

  INT_EULERS_ZERO(stabilization_att_sum_err);
  
  init_butterworth_2_low_pass_int(&stab_p_filter, STAB_D_LOWPASS_FREQ, DT_UPDATE, 0);
  init_butterworth_2_low_pass_int(&stab_q_filter, STAB_D_LOWPASS_FREQ, DT_UPDATE, 0);
  
  init_butterworth_2_low_pass_int(&stab_att_phi_filter, STAB_P_LOWPASS_FREQ, DT_UPDATE, 0);
  init_butterworth_2_low_pass_int(&stab_att_theta_filter, STAB_P_LOWPASS_FREQ, DT_UPDATE, 0);

#if PERIODIC_TELEMETRY
  register_periodic_telemetry(DefaultPeriodic, "STAB_ATTITUDE", send_att);
  register_periodic_telemetry(DefaultPeriodic, "STAB_ATTITUDE_REF", send_att_ref);
#endif
}

void stabilization_attitude_read_rc(bool_t in_flight, bool_t in_carefree, bool_t coordinated_turn)
{
  stabilization_attitude_read_rc_setpoint_eulers(&stab_att_sp_euler, in_flight, in_carefree, coordinated_turn);
}

void stabilization_attitude_enter(void)
{
  stab_att_sp_euler.psi = stateGetNedToBodyEulers_i()->psi;
  reset_psi_ref_from_body();
  INT_EULERS_ZERO(stabilization_att_sum_err);
}

void stabilization_attitude_set_failsafe_setpoint(void)
{
  stab_att_sp_euler.phi = 0;
  stab_att_sp_euler.theta = 0;
  stab_att_sp_euler.psi = stateGetNedToBodyEulers_i()->psi;
}

void stabilization_attitude_set_rpy_setpoint_i(struct Int32Eulers *rpy)
{
  stab_att_sp_euler = *rpy;
}

void stabilization_attitude_set_earth_cmd_i(struct Int32Vect2 *cmd, int32_t heading)
{
  /* Rotate horizontal commands to body frame by psi */
  int32_t psi = stateGetNedToBodyEulers_i()->psi;
  int32_t s_psi, c_psi;
  PPRZ_ITRIG_SIN(s_psi, psi);
  PPRZ_ITRIG_COS(c_psi, psi);
  stab_att_sp_euler.phi = (-s_psi * cmd->x + c_psi * cmd->y) >> INT32_TRIG_FRAC;
  stab_att_sp_euler.theta = -(c_psi * cmd->x + s_psi * cmd->y) >> INT32_TRIG_FRAC;
  stab_att_sp_euler.psi = heading;
}

#define OFFSET_AND_ROUND(_a, _b) (((_a)+(1<<((_b)-1)))>>(_b))
#define OFFSET_AND_ROUND2(_a, _b) (((_a)+(1<<((_b)-1))-((_a)<0?1:0))>>(_b))

#define MAX_SUM_ERR 4000000
//#define IERROR_SCALE 8 // ========================================

void stabilization_attitude_run(bool_t  in_flight)
{
      static int32_t rateSumq, rateSum1q, rateSum2q;
      static int32_t rateSump, rateSum1p, rateSum2p;
      static int32_t rateSumr, rateSum1r, rateSum2r;

  /* update reference */
  stabilization_attitude_ref_update();

  /* compute feedforward command */
  stabilization_att_ff_cmd[COMMAND_ROLL] =0;//    OFFSET_AND_ROUND(stabilization_gains.dd.x * stab_att_ref_accel.p, 5);
  stabilization_att_ff_cmd[COMMAND_PITCH] = 0; //    OFFSET_AND_ROUND(stabilization_gains.dd.y * stab_att_ref_accel.q, 5);
  stabilization_att_ff_cmd[COMMAND_YAW] =0;//    OFFSET_AND_ROUND(stabilization_gains.dd.z * stab_att_ref_accel.r, 5);

  /* compute feedback command */
  /* attitude error            */
  const struct Int32Eulers att_ref_scaled = {
    OFFSET_AND_ROUND(stab_att_ref_euler.phi, (REF_ANGLE_FRAC - INT32_ANGLE_FRAC)),
    OFFSET_AND_ROUND(stab_att_ref_euler.theta, (REF_ANGLE_FRAC - INT32_ANGLE_FRAC)),
    OFFSET_AND_ROUND(stab_att_ref_euler.psi, (REF_ANGLE_FRAC - INT32_ANGLE_FRAC))
  };
  struct Int32Eulers att_err;
  struct Int32Eulers *ltp_to_body_euler = stateGetNedToBodyEulers_i();
  EULERS_DIFF(att_err, att_ref_scaled, (*ltp_to_body_euler));
  INT32_ANGLE_NORMALIZE(att_err.psi);

  if (in_flight) {
    /* scale att_Err */
 //   struct Int32Eulers scaled_att_err;
 //   EULERS_SDIV(scaled_att_err,att_err,IERROR_SCALE);

    /* update integrator */
    EULERS_ADD(stabilization_att_sum_err, att_err);
    EULERS_BOUND_CUBE(stabilization_att_sum_err, -MAX_SUM_ERR, MAX_SUM_ERR);
  } else {
    INT_EULERS_ZERO(stabilization_att_sum_err);
  }

  /* rate error                */
  const struct Int32Rates rate_ref_scaled = {
    OFFSET_AND_ROUND(stab_att_ref_rate.p, (REF_RATE_FRAC - INT32_RATE_FRAC)),
    OFFSET_AND_ROUND(stab_att_ref_rate.q, (REF_RATE_FRAC - INT32_RATE_FRAC)),
    OFFSET_AND_ROUND(stab_att_ref_rate.r, (REF_RATE_FRAC - INT32_RATE_FRAC))
  };
  struct Int32Rates rate_err;
  struct Int32Rates *body_rate = stateGetBodyRates_i();
  RATES_DIFF(rate_err, rate_ref_scaled, (*body_rate));

  /* PID                  */
  //3stage moving average filter
  rateSump = rateSum1p + rateSum2p + rate_err.p;
  rateSum2p = rateSum1p;
  rateSum1p = rate_err.p;
  rateSumpFiltered = update_butterworth_2_low_pass_int(&stab_p_filter, rateSump);
  att_err_phi_filtered = update_butterworth_2_low_pass_int(&stab_att_phi_filter, att_err.phi);
  
  stabilization_att_fb_cmd[COMMAND_ROLL] =
    stabilization_gains.p.x    * att_err_phi_filtered + //att_err.phi
    stabilization_gains.d.x    * rate_err.p +
    stabilization_gains.dd.x   * rateSump + //rateSumpFiltered + //
    OFFSET_AND_ROUND2((stabilization_gains.i.x  * stabilization_att_sum_err.phi), 10); //10

  rateSumq = rateSum1q + rateSum2q + rate_err.q;
  rateSum2q = rateSum1q;
  rateSum1q = rate_err.q;    
  rateSumpFiltered = update_butterworth_2_low_pass_int(&stab_q_filter, rateSumq);
  att_err_theta_filtered = update_butterworth_2_low_pass_int(&stab_att_theta_filter, att_err.theta);
  
  stabilization_att_fb_cmd[COMMAND_PITCH] =
    stabilization_gains.p.y    * att_err_theta_filtered + //att_err.theta
    stabilization_gains.d.y    * rate_err.q +
    stabilization_gains.dd.y   * rateSumq + //rateSumpFiltered + //
    OFFSET_AND_ROUND2((stabilization_gains.i.y  * stabilization_att_sum_err.theta), 10); //10

  rateSumr = rateSum1r + rateSum2r + rate_err.r;
  rateSum2r = rateSum1r;
  rateSum1r = rate_err.r;   

  stabilization_att_fb_cmd[COMMAND_YAW] =
    stabilization_gains.p.z    * att_err.psi +
    stabilization_gains.d.z    * rate_err.r +
    stabilization_gains.dd.z   * rateSumr + 
    OFFSET_AND_ROUND2((stabilization_gains.i.z  * stabilization_att_sum_err.psi), 10); //10


  /* with P gain of 100, att_err of 180deg (3.14 rad)
   * fb cmd: 100 * 3.14 * 2^12 / 2^CMD_SHIFT = 628
   * max possible command is 9600
   */
#define CMD_SHIFT 11

  /* sum feedforward and feedback */
  stabilization_cmd[COMMAND_ROLL] =
    OFFSET_AND_ROUND((stabilization_att_fb_cmd[COMMAND_ROLL] + stabilization_att_ff_cmd[COMMAND_ROLL]), CMD_SHIFT);

  stabilization_cmd[COMMAND_PITCH] =
    OFFSET_AND_ROUND((stabilization_att_fb_cmd[COMMAND_PITCH] + stabilization_att_ff_cmd[COMMAND_PITCH]), CMD_SHIFT);

  stabilization_cmd[COMMAND_YAW] =
    OFFSET_AND_ROUND((stabilization_att_fb_cmd[COMMAND_YAW] + stabilization_att_ff_cmd[COMMAND_YAW]), CMD_SHIFT);

  /* bound the result */
  BoundAbs(stabilization_cmd[COMMAND_ROLL], MAX_PPRZ/3);
  BoundAbs(stabilization_cmd[COMMAND_PITCH], MAX_PPRZ/3);
  BoundAbs(stabilization_cmd[COMMAND_YAW], MAX_PPRZ/2);

}
