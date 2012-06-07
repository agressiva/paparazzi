#ifndef L3G4200
#define L3G4200
#endif

/* default I2C address */
#define L3G4200_ADDR            0xD2
#define L3G4200_ADDR_ALT        0xD0


/* Registers */
#define L3G4200_WHO_AM_I 0x0F

#define L3G4200_REG_CTRL_REG1 0x20
#define L3G4200_REG_CTRL_REG2 0x21
#define L3G4200_REG_CTRL_REG3 0x22
#define L3G4200_REG_CTRL_REG4 0x23
#define L3G4200_REG_CTRL_REG5 0x24
#define L3G4200_REG_REFERENCE 0x25
#define L3G4200_REG_OUT_TEMP 0x26
#define L3G4200_REG_STATUS_REG 0x27

#define L3G4200_REG_OUT_X_L 0x28
#define L3G4200_REG_OUT_X_H 0x29
#define L3G4200_REG_OUT_Y_L 0x2A
#define L3G4200_REG_OUT_Y_H 0x2B
#define L3G4200_REG_OUT_Z_L 0x2C
#define L3G4200_REG_OUT_Z_H 0x2D

#define L3G4200_REG_FIFO_CTRL_REG 0x2E
#define L3G4200_REG_FIFO_SRC_REG 0x2F

#define L3G4200_REG_INT1_CFG 0x30
#define L3G4200_REG_INT1_SRC 0x31
#define L3G4200_REG_INT1_THS_XH 0x32
#define L3G4200_REG_INT1_THS_XL 0x33
#define L3G4200_REG_INT1_THS_YH 0x34
#define L3G4200_REG_INT1_THS_YL 0x35
#define L3G4200_REG_INT1_THS_ZH 0x36
#define L3G4200_REG_INT1_THS_ZL 0x37
#define L3G4200_REG_INT1_DURATION 0x38
