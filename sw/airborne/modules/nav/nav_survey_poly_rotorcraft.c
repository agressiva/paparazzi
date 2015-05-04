/*
 * Copyright (C) 2008-2014 The Paparazzi Team
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
 * @file modules/nav/nav_survey_poly_rotorcraft.c
 *
 */

//#include "std.h"
//#include "mcu_periph/uart.h"
//#include "messages.h"
//#include "subsystems/datalink/downlink.h"


#include "modules/nav/nav_survey_poly_rotorcraft.h"

#include "firmwares/rotorcraft/navigation.h"
#include "state.h"
#include "autopilot.h"
#include "generated/flight_plan.h"

#ifdef DIGITAL_CAM
#include "modules/digital_cam/dc.h"
#endif

#ifndef POLY_OSAM_DEFAULT_SIZE
#define POLY_OSAM_DEFAULT_SIZE 10
#endif

#ifndef POLY_OSAM_DEFAULT_SWEEP
#define POLY_OSAM_DEFAULT_SWEEP 25
#endif

/// Default entry radius, if 0 default to half sweep
#ifndef POLY_OSAM_ENTRY_RADIUS
#define POLY_OSAM_ENTRY_RADIUS 0
#endif

/// if 0 never check for min radius
//#ifndef POLY_OSAM_MIN_RADIUS
//#define POLY_OSAM_MIN_RADIUS 1
//#endif

/// if 0 default to half sweep
#ifndef POLY_OSAM_FIRST_SWEEP_DISTANCE
#define POLY_OSAM_FIRST_SWEEP_DISTANCE 0
#endif

/// maximum number of polygon corners
#ifndef POLY_OSAM_POLYGONSIZE
#define POLY_OSAM_POLYGONSIZE 10
#endif

#ifndef POLY_OSAM_USE_FULL_CIRCLE
#define POLY_OSAM_USE_FULL_CIRCLE TRUE
#endif

uint8_t Poly_Size = POLY_OSAM_DEFAULT_SIZE;
float Poly_Sweep = POLY_OSAM_DEFAULT_SWEEP;
bool_t use_full_circle = POLY_OSAM_USE_FULL_CIRCLE;

bool_t nav_survey_poly_setup_towards(uint8_t FirstWP, uint8_t Size, float Sweep, int SecondWP)
{
  float dx = waypoints[SecondWP].enu_f.x - waypoints[FirstWP].enu_f.x;
  float dy = waypoints[SecondWP].enu_f.y - waypoints[FirstWP].enu_f.y;
  if (dx == 0.0f) { dx = 0.000000001; }
  float ang = atan(dy / dx);
  ang = DegOfRad(ang);
  
  //if values passed, use it.
  if (Size == 0) {Size = Poly_Size;}
  if (Sweep == 0) {Sweep = Poly_Sweep;}
  return nav_survey_poly_setup(FirstWP, Size, Sweep, ang);
}

struct Point2D {float x; float y;};
struct Line {float m; float b; float x;};

static void TranslateAndRotateFromWorld(struct EnuCoor_f *p, float Zrot, float transX, float transY);
static void RotateAndTranslateToWorld(struct EnuCoor_f *p, float Zrot, float transX, float transY);
static void FindInterceptOfTwoLines(float *x, float *y, struct Line L1, struct Line L2);
static float EvaluateLineForX(float y, struct Line L);

#define PolygonSize POLY_OSAM_POLYGONSIZE
#define MaxFloat   1000000000
#define MinFloat   -1000000000

#ifndef LINE_START_FUNCTION
#define LINE_START_FUNCTION {}
#endif
#ifndef LINE_STOP_FUNCTION
#define LINE_STOP_FUNCTION {}
#endif

/************** Polygon Survey **********************************************/

/** This routine will cover the enitre area of any Polygon defined in the flightplan which is a convex polygon.
 */

enum SurveyStatus { Init, Entry, Sweep, Turn };
static enum SurveyStatus CSurveyStatus;
static struct Point2D SmallestCorner;
static struct Line Edges[PolygonSize];
static float EdgeMaxY[PolygonSize];
static float EdgeMinY[PolygonSize];
static float SurveyTheta;
static float dSweep;
static float SurveyRadius;
static struct EnuCoor_f SurveyToWP;
static struct EnuCoor_f SurveyFromWP;
static struct EnuCoor_f SurveyEntry;

//static struct EnuCoor_f survey_from, survey_to;
static struct EnuCoor_i survey_from_i, survey_to_i;

static uint8_t SurveyEntryWP;
static uint8_t SurveySize;
static float SurveyCircleQdr;
static float MaxY;
uint16_t PolySurveySweepNum;
uint16_t PolySurveySweepBackNum;
float EntryRadius;

bool_t nav_survey_poly_setup(uint8_t EntryWP, uint8_t Size, float sw, float Orientation)
{
  SmallestCorner.x = 0;
  SmallestCorner.y = 0;
  int i = 0;
  float ys = 0;
  static struct EnuCoor_f EntryPoint;
  float LeftYInt;
  float RightYInt;
  float temp;
  float XIntercept1 = 0;
  float XIntercept2 = 0;
  float entry_distance;

  float PolySurveyEntryDistance = POLY_OSAM_FIRST_SWEEP_DISTANCE;
  float PolySurveyEntryRadius = POLY_OSAM_ENTRY_RADIUS;

  if (PolySurveyEntryDistance == 0) {
    entry_distance = sw / 2;
  } else {
    entry_distance = PolySurveyEntryDistance;
  }

  if (PolySurveyEntryRadius == 0) {
    EntryRadius = sw / 2;
  } else {
    EntryRadius = PolySurveyEntryRadius;
  }

  SurveyTheta = RadOfDeg(Orientation);
  PolySurveySweepNum = 0;
  PolySurveySweepBackNum = 0;

  SurveyEntryWP = EntryWP;
  SurveySize = Size;

  struct EnuCoor_f Corners[PolygonSize];

  CSurveyStatus = Init;

  if (Size == 0) {
    return TRUE;
  }

  //Don't initialize if Polygon is too big or if the orientation is not between 0 and 90
  if (Size <= PolygonSize && Orientation >= -90 && Orientation <= 90) {
    //Initialize Corners
    for (i = 0; i < Size; i++) {
      Corners[i].x = waypoints[i + EntryWP].enu_f.x;
      Corners[i].y = waypoints[i + EntryWP].enu_f.y;
    }

    //Rotate Corners so sweeps are parellel with x axis
    for (i = 0; i < Size; i++) {
      TranslateAndRotateFromWorld(&Corners[i], SurveyTheta, 0, 0);
    }

    //Find min x and min y
    SmallestCorner.y = Corners[0].y;
    SmallestCorner.x = Corners[0].x;
    for (i = 1; i < Size; i++) {
      if (Corners[i].y < SmallestCorner.y) {
        SmallestCorner.y = Corners[i].y;
      }

      if (Corners[i].x < SmallestCorner.x) {
        SmallestCorner.x = Corners[i].x;
      }
    }

    //Translate Corners all exist in quad #1
    for (i = 0; i < Size; i++) {
      TranslateAndRotateFromWorld(&Corners[i], 0, SmallestCorner.x, SmallestCorner.y);
    }

    //Rotate and Translate Entry Point
    EntryPoint.x = Corners[0].x;
    EntryPoint.y = Corners[0].y;

    //Find max y
    MaxY = Corners[0].y;
    for (i = 1; i < Size; i++) {
      if (Corners[i].y > MaxY) {
        MaxY = Corners[i].y;
      }
    }

    //Find polygon edges
    for (i = 0; i < Size; i++) {
      if (i == 0)
        if (Corners[Size - 1].x == Corners[i].x) { //Don't divide by zero!
          Edges[i].m = MaxFloat;
        } else {
          Edges[i].m = ((Corners[Size - 1].y - Corners[i].y) / (Corners[Size - 1].x - Corners[i].x));
        }
      else if (Corners[i].x == Corners[i - 1].x) {
        Edges[i].m = MaxFloat;
      } else {
        Edges[i].m = ((Corners[i].y - Corners[i - 1].y) / (Corners[i].x - Corners[i - 1].x));
      }

      //Edges[i].m = MaxFloat;
      Edges[i].b = (Corners[i].y - (Corners[i].x * Edges[i].m));
    }

    //Find Min and Max y for each line
    FindInterceptOfTwoLines(&temp, &LeftYInt, Edges[0], Edges[1]);
    FindInterceptOfTwoLines(&temp, &RightYInt, Edges[0], Edges[Size - 1]);

    if (LeftYInt > RightYInt) {
      EdgeMaxY[0] = LeftYInt;
      EdgeMinY[0] = RightYInt;
    } else {
      EdgeMaxY[0] = RightYInt;
      EdgeMinY[0] = LeftYInt;
    }

    for (i = 1; i < Size - 1; i++) {
      FindInterceptOfTwoLines(&temp, &LeftYInt, Edges[i], Edges[i + 1]);
      FindInterceptOfTwoLines(&temp, &RightYInt, Edges[i], Edges[i - 1]);

      if (LeftYInt > RightYInt) {
        EdgeMaxY[i] = LeftYInt;
        EdgeMinY[i] = RightYInt;
      } else {
        EdgeMaxY[i] = RightYInt;
        EdgeMinY[i] = LeftYInt;
      }
    }

    FindInterceptOfTwoLines(&temp, &LeftYInt, Edges[Size - 1], Edges[0]);
    FindInterceptOfTwoLines(&temp, &RightYInt, Edges[Size - 1], Edges[Size - 2]);

    if (LeftYInt > RightYInt) {
      EdgeMaxY[Size - 1] = LeftYInt;
      EdgeMinY[Size - 1] = RightYInt;
    } else {
      EdgeMaxY[Size - 1] = RightYInt;
      EdgeMinY[Size - 1] = LeftYInt;
    }

    //Find amount to increment by every sweep
    if (EntryPoint.y >= MaxY / 2) {
      entry_distance = -entry_distance;
      EntryRadius = -EntryRadius;
      dSweep = -sw;
    } else {
      EntryRadius = EntryRadius;
      dSweep = sw;
    }

    //CircleQdr tells the plane when to exit the circle
    if (dSweep >= 0) {
      SurveyCircleQdr = -DegOfRad(SurveyTheta);
    } else {
      SurveyCircleQdr = 180 - DegOfRad(SurveyTheta);
    }

    //Find y value of the first sweep
    ys = EntryPoint.y + entry_distance;

    //Find the edges which intercet the sweep line first
    for (i = 0; i < SurveySize; i++) {
      if (EdgeMinY[i] <= ys && EdgeMaxY[i] > ys) {
        XIntercept2 = XIntercept1;
        XIntercept1 = EvaluateLineForX(ys, Edges[i]);
      }
    }

    //Find point to come from and point to go to
    if (fabs(EntryPoint.x - XIntercept2) <= fabs(EntryPoint.x - XIntercept1)) {
      SurveyToWP.x = XIntercept1;
      SurveyToWP.y = ys;

      SurveyFromWP.x = XIntercept2;
      SurveyFromWP.y = ys;
    } else {
      SurveyToWP.x = XIntercept2;
      SurveyToWP.y = ys;

      SurveyFromWP.x = XIntercept1;
      SurveyFromWP.y = ys;
    }

    //Find the direction to circle
    if (ys > 0 && SurveyToWP.x > SurveyFromWP.x) {
      SurveyRadius = EntryRadius;
    } else if (ys < 0 && SurveyToWP.x < SurveyFromWP.x) {
      SurveyRadius = EntryRadius;
    } else {
      SurveyRadius = -EntryRadius;
    }

    //Find the entry circle
    SurveyEntry.x = SurveyFromWP.x;
    SurveyEntry.y = EntryPoint.y + entry_distance;// - EntryRadius;

    //Go into entry circle state
    CSurveyStatus = Entry;

    LINE_STOP_FUNCTION;
    NavVerticalAltitudeMode(waypoints[SurveyEntryWP].enu_f.z, 0.);
    nav_set_heading_deg(-Orientation +90.);

  }

  return FALSE;
}

//=========================================================================================================================
bool_t nav_survey_poly_run(void)
{

  struct EnuCoor_f C;
  struct EnuCoor_f ToP;
  struct EnuCoor_f FromP;
  float ys;
  static struct EnuCoor_f LastPoint;
  int i;
  bool_t LastHalfSweep;
  static bool_t HalfSweep = FALSE;
  float XIntercept1 = 0;
  float XIntercept2 = 0;
  float DInt1 = 0;
  float DInt2 = 0;
  //float min_radius = POLY_OSAM_MIN_RADIUS;

  switch (CSurveyStatus) {
    case Entry:
      C = SurveyEntry;
      RotateAndTranslateToWorld(&C, 0, SmallestCorner.x, SmallestCorner.y);
      RotateAndTranslateToWorld(&C, SurveyTheta, 0, 0);

      ENU_BFP_OF_REAL(survey_from_i, C);
      horizontal_mode = HORIZONTAL_MODE_ROUTE;
      VECT3_COPY(navigation_target, survey_from_i);      

      if ( ((nav_approaching_from(&survey_from_i, NULL, 0)) && (fabsf(stateGetPositionEnu_f()->z - waypoints[SurveyEntryWP].enu_f.z)) < 1.) ) {
        CSurveyStatus = Sweep;
        nav_init_stage();
        LINE_START_FUNCTION;
      }
      break;
    case Sweep:
      LastHalfSweep = HalfSweep;
      ToP = SurveyToWP;
      FromP = SurveyFromWP;

      //Rotate and Translate de plane position to local world
      C.x = stateGetPositionEnu_f()->x;
      C.y = stateGetPositionEnu_f()->y;
      TranslateAndRotateFromWorld(&C, SurveyTheta, 0, 0);
      TranslateAndRotateFromWorld(&C, 0, SmallestCorner.x, SmallestCorner.y);

#ifdef DIGITAL_CAM
      {
        //calc distance from line start and plane position (use only X position because y can be far due to wind or other factor)
        float dist = FromP.x - C.x;

        // verify if plane are less than 10 meter from line start
        if ((dc_autoshoot == DC_AUTOSHOOT_STOP) && (fabs(dist) < 10)) {
          LINE_START_FUNCTION;
        }
      }
#endif

      //Rotate and Translate Line points into real world
      RotateAndTranslateToWorld(&ToP, 0, SmallestCorner.x, SmallestCorner.y);
      RotateAndTranslateToWorld(&ToP, SurveyTheta, 0, 0);

      RotateAndTranslateToWorld(&FromP, 0, SmallestCorner.x, SmallestCorner.y);
      RotateAndTranslateToWorld(&FromP, SurveyTheta, 0, 0);

      //follow the line
      ENU_BFP_OF_REAL(survey_to_i, ToP);
      ENU_BFP_OF_REAL(survey_from_i, FromP);

      horizontal_mode = HORIZONTAL_MODE_ROUTE;
      nav_route(&survey_from_i, &survey_to_i);      
      
      if (nav_approaching_from(&survey_to_i, NULL, 0)) {
	LastPoint = SurveyToWP;

        float temp1;
        temp1 = fabsf(FromP.x - ToP.x) / dc_distance_interval;
        double inteiro;
        double fract = modf (temp1 , &inteiro);
	
	//fprintf(stderr,"dist %f temp %f fract %f\n",(FromP.x - ToP.x), temp, fract );
        if (fract > .5) {
          dc_send_command(DC_SHOOT); //if last shot is more than shot_distance/2 from the corner take a picture in the corner before go to the next sweep
        }
        
	
        if (LastPoint.y + dSweep >= MaxY || LastPoint.y + dSweep <= 0) { //Your out of the Polygon so Sweep Back or Half Sweep
          if (LastPoint.y + (dSweep / 2) >= MaxY || LastPoint.y + (dSweep / 2) <= 0) { //Sweep back
            dSweep = -dSweep;
            if (LastHalfSweep) {
              HalfSweep = FALSE;
              ys = LastPoint.y + (dSweep);
            } else {
              HalfSweep = TRUE;
              ys = LastPoint.y + (dSweep / 2);
            }

            if (dSweep >= 0) {
              SurveyCircleQdr = -DegOfRad(SurveyTheta);
            } else {
              SurveyCircleQdr = 180 - DegOfRad(SurveyTheta);
            }
            PolySurveySweepBackNum++;
          } else { // Half Sweep forward
            ys = LastPoint.y + (dSweep / 2);

            if (dSweep >= 0) {
              SurveyCircleQdr = -DegOfRad(SurveyTheta);
            } else {
              SurveyCircleQdr = 180 - DegOfRad(SurveyTheta);
            }
            HalfSweep = TRUE;
          }

        } else { // Normal sweep
          //Find y value of the first sweep
          HalfSweep = FALSE;
          ys = LastPoint.y + dSweep;
        }

        //Find the edges which intercet the sweep line first
        for (i = 0; i < SurveySize; i++) {
          if (EdgeMinY[i] < ys && EdgeMaxY[i] >= ys) {
            XIntercept2 = XIntercept1;
            XIntercept1 = EvaluateLineForX(ys, Edges[i]);
          }
        }

        //Find point to come from and point to go to
        DInt1 = XIntercept1 -  LastPoint.x;
        DInt2 = XIntercept2 - LastPoint.x;

        if (DInt1 * DInt2 >= 0) {
          if (fabs(DInt2) <= fabs(DInt1)) {
            SurveyToWP.x = XIntercept1;
            SurveyToWP.y = ys;

            SurveyFromWP.x = XIntercept2;
            SurveyFromWP.y = ys;
          } else {
            SurveyToWP.x = XIntercept2;
            SurveyToWP.y = ys;

            SurveyFromWP.x = XIntercept1;
            SurveyFromWP.y = ys;
          }
        } else {
          if ((SurveyToWP.x - SurveyFromWP.x) > 0 && DInt2 > 0) {
            SurveyToWP.x = XIntercept1;
            SurveyToWP.y = ys;

            SurveyFromWP.x = XIntercept2;
            SurveyFromWP.y = ys;
          } else if ((SurveyToWP.x - SurveyFromWP.x) < 0 && DInt2 < 0) {
            SurveyToWP.x = XIntercept1;
            SurveyToWP.y = ys;

            SurveyFromWP.x = XIntercept2;
            SurveyFromWP.y = ys;
          } else {
            SurveyToWP.x = XIntercept2;
            SurveyToWP.y = ys;

            SurveyFromWP.x = XIntercept1;
            SurveyFromWP.y = ys;
          }
        }

/*        //Find the radius to circle
        if (!HalfSweep || use_full_circle) {
          temp = dSweep / 2;
        } else {
          temp = dSweep / 4;
        }

        //if less than min radius
        if (fabs(temp) < min_radius) {
          if (temp < 0) { temp = -min_radius; } else { temp = min_radius; }
        }


        //Find the direction to circle
        if (ys > 0 && SurveyToWP.x > SurveyFromWP.x) {
          SurveyRadius = temp;
        } else if (ys < 0 && SurveyToWP.x < SurveyFromWP.x) {
          SurveyRadius = temp;
        } else {
          SurveyRadius = -temp;
        }
*/
        
        //Go into circle state
        CSurveyStatus = Turn;
        nav_init_stage();
        LINE_STOP_FUNCTION;

        PolySurveySweepNum++;
      }

      break;
    case Turn:
      FromP = LastPoint;
      ToP = SurveyFromWP;
      
      //Rotate and Translate Line points into real world
      RotateAndTranslateToWorld(&ToP, 0, SmallestCorner.x, SmallestCorner.y);
      RotateAndTranslateToWorld(&ToP, SurveyTheta, 0, 0);

      RotateAndTranslateToWorld(&FromP, 0, SmallestCorner.x, SmallestCorner.y);
      RotateAndTranslateToWorld(&FromP, SurveyTheta, 0, 0);

      //follow the line
      ENU_BFP_OF_REAL(survey_to_i, ToP);
      ENU_BFP_OF_REAL(survey_from_i, FromP);

      horizontal_mode = HORIZONTAL_MODE_ROUTE;
      nav_route(&survey_from_i, &survey_to_i);  

      if (nav_approaching_from(&survey_to_i, NULL, 0)) {
        CSurveyStatus = Sweep;
        nav_init_stage();
        LINE_START_FUNCTION;
      }

      break;
    case Init:
      return FALSE;
    default:
      return FALSE;
  }
  
  return TRUE;

}

//============================================================================================================================================
/*
  Translates point so (transX, transY) are (0,0) then rotates the point around z by Zrot
*/
void TranslateAndRotateFromWorld(struct EnuCoor_f *p, float Zrot, float transX, float transY)
{
  float temp;

  p->x = p->x - transX;
  p->y = p->y - transY;

  temp = p->x;
  p->x = p->x * cosf(Zrot) + p->y * sinf(Zrot);
  p->y = -temp * sinf(Zrot) + p->y * cosf(Zrot);
}

/// Rotates point round z by -Zrot then translates so (0,0) becomes (transX,transY)
void RotateAndTranslateToWorld(struct EnuCoor_f *p, float Zrot, float transX, float transY)
{
  float temp = p->x;

  p->x = p->x * cosf(Zrot) - p->y * sinf(Zrot);
  p->y = temp * sinf(Zrot) + p->y * cosf(Zrot);

  p->x = p->x + transX;
  p->y = p->y + transY;
}

void FindInterceptOfTwoLines(float *x, float *y, struct Line L1, struct Line L2)
{
  *x = ((L2.b - L1.b) / (L1.m - L2.m));
  *y = L1.m * (*x) + L1.b;
}


float EvaluateLineForX(float y, struct Line L)
{
  return ((y - L.b) / L.m);
}
