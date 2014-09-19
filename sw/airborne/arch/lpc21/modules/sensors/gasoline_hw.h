#ifndef GASOLINE_HW_H
#define GASOLINE_HW_H

#include "std.h"

//#define GASOLINE_PULSE_TYPE_RISING 1
//#define GASOLINE_PULSE_TYPE_FALLING 0

extern uint32_t gas_pulse;
extern volatile bool_t gas_valid;

// Default trigger Pin is PPM pin (Tiny2/Twog)
// To use a custom trigger, you must set the flag USE_CUSTOM_TRIGGER
// and define:
// - PINSEL
// - PINSEL_VAL
// - PINSEL_BIT
// - input capture CHANNEL
#ifndef USE_CUSTOM_GASOLINE_INPUT
#define GASOLINE_PINSEL     PPM_PINSEL
#define GASOLINE_PINSEL_VAL PPM_PINSEL_VAL
#define GASOLINE_PINSEL_BIT PPM_PINSEL_BIT
#define GASOLINE_CHANNEL    2
#endif

#define __SelectCapReg(_c) T0CR ## _c
#define _SelectCapReg(_c) __SelectCapReg(_c)
#define SelectCapReg(_c) _SelectCapReg(_c)

#define __SetIntFlag(_c) TIR_CR ## _c ## I
#define _SetIntFlag(_c) __SetIntFlag(_c)
#define SetIntFlag(_c) _SetIntFlag(_c)

#define __EnableRise(_c) TCCR_CR ## _c ## _R
#define _EnableRise(_c) __EnableRise(_c)
#define EnableRise(_c) _EnableRise(_c)

#define __EnableFall(_c) TCCR_CR ## _c ## _F
#define _EnableFall(_c) __EnableFall(_c)
#define EnableFall(_c) _EnableFall(_c)

#define __EnableInt(_c) TCCR_CR ## _c ## _I
#define _EnableInt(_c) __EnableInt(_c)
#define EnableInt(_c) _EnableInt(_c)

#define GASOLINE_CR SelectCapReg(GASOLINE_CHANNEL)
#define GASOLINE_IT SetIntFlag(GASOLINE_CHANNEL)
#define GASOLINE_CRR EnableRise(GASOLINE_CHANNEL)
#define GASOLINE_CRF EnableFall(GASOLINE_CHANNEL)
#define GASOLINE_CRI EnableInt(GASOLINE_CHANNEL)

void TRIG_ISR(void);
void gasoline_hw_init ( void );

#endif /* GASOLINE_HW_H */

