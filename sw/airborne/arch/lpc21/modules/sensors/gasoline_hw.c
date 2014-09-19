
#include "std.h"
#include "mcu_periph/sys_time.h"
#include "LPC21xx.h"
#include "gasoline_hw.h"
#include BOARD_CONFIG

uint32_t gas_pulse;
volatile bool_t gas_valid;


void TRIG_ISR() {
  static uint32_t pulse;
  pulse = pulse + 1;
  gas_pulse = pulse;
  gas_valid = TRUE;
}

void gasoline_hw_init ( void ) {
  /* select pin for capture */
  GASOLINE_PINSEL |= GASOLINE_PINSEL_VAL << GASOLINE_PINSEL_BIT;
  /* enable capture 0.2 on falling or rising edge + trigger interrupt */
#if defined GASOLINE_PULSE_TYPE_RISING
PRINT_CONFIG_MSG( "gasoline_hw: PULSE_TYPE RISING")
  T0CCR = GASOLINE_CRR | GASOLINE_CRI;
#elif defined GASOLINE_PULSE_TYPE_FALLING
PRINT_CONFIG_MSG( "gasoline_hw: PULSE_TYPE FALLING")
  T0CCR = GASOLINE_CRF | GASOLINE_CRI;
#else
#error "gasoline_hw: Unknown PULSE_TYPE"
#endif
  gas_valid = FALSE;
}

