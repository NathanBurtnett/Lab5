;**************************************************************************************
;* Lab 5                                                                            *
;**************************************************************************************
;* Summary:                                                                           *
;*                                     *
;*                                                                                    *
;* Author: Nathan Burtnett, Tom Taylor                                                *
;*   Cal Poly University                                                              *
;*   Fall 2022                                                                        *
;*                                                                                    *
;* Revision History:                                                                  *
;*   -                                                                                *                                                                            
;**************************************************************************************

;/------------------------------------------------------------------------------------\
;| External Definitions                                                               |
;\------------------------------------------------------------------------------------/
              XDEF  main
;/------------------------------------------------------------------------------------\
;| External References                                                                |
;\------------------------------------------------------------------------------------/
              XREF  ENABLE_MOTOR, DISABLE_MOTOR
              XREF  STARTUP_MOTOR, UPDATE_MOTOR, CURRENT_MOTOR
              XREF  STARTUP_PWM, STARTUP_ATD0, STARTUP_ATD1
              XREF  OUTDACA, OUTDACB
              XREF  STARTUP_ENCODER, READ_ENCODER
              XREF  INITLCD, SETADDR, GETADDR, CURSOR_ON, CURSOR_OFF, DISP_OFF
              XREF  OUTCHAR, OUTCHAR_AT, OUTSTRING, OUTSTRING_AT
              XREF  INITKEY, LKEY_FLG, GETCHAR
              XREF  LCDTEMPLATE, UPDATELCD_L1, UPDATELCD_L2
              XREF  LVREF_BUF, LVACT_BUF, LERR_BUF,LEFF_BUF, LKP_BUF, LKI_BUF
              XREF  Entry, ISR_KEYPAD
            
;/------------------------------------------------------------------------------------\
;| Assembler Equates                                                                  |
;\------------------------------------------------------------------------------------/
;INTERRUPT EQUATES
INTERVAL      EQU   $03E8     ;sets interval

TIOS          EQU   $0040     ;sets location of TIOS
C0            EQU   %00000001 ;sets value of C0 which will go into TIOS

TCTL2         EQU   $0049     ;sets location of TCTL2
CROA_TOGGLE   EQU   %00000001 ;sets value of CROA_TOGGLE which will go into TIOS

TFLG1         EQU   $004E     ;sets location of TFLG1
C0F_CLEAR     EQU   %00000001 ;sets value C0F_CLEAR which will go into TFLG1

TIE           EQU   $004C     ;sets location of TIE
C0I_SET       EQU   %00000001 ;sets value C0I_SET which will go into TIE

TSCR1         EQU   $0046     ;sets location of TSCR1
TEN_TSFRZ_SET EQU   %10100000 ;sets value TEN_TSFRZ_SET which will go into TSCR1
TCNT          EQU   $0044     ;sets location of TCNT
TC0H          EQU   $0050     ;sets location of TC0H
;/------------------------------------------------------------------------------------\
;| Variables in RAM                                                                   |
;\------------------------------------------------------------------------------------/
DEFAULT_RAM:  SECTION

ENCODER_COUNT   DS.W 1  ;stores a count for enocoder
TEMP            DS.W      1
;/------------------------------------------------------------------------------------\
;|  Main Program Code                                                                 |
;\------------------------------------------------------------------------------------/
MyCode:       SECTION
main:
  ;CLEAR VARIABLES 

  ;SETUP INSTRUCTIONS
  jsr STARTUP_ENCODER   ;initialize encoder
  jsr READ_ENCODER      ;returns encoder count in D
  std ENCODER_COUNT     ;store the count in a 16-bit variable in RAM

  jsr STARTUP_PWM       ;initialize PWM module
  jsr STARTUP_MOTOR     ;initialize motor in disabled state

  jsr ENABLE_MOTOR      ;enable motor operation

  TOP:
    ;Good
    ldd #$0000
    jsr SATCHECK
    jsr UPDATE_MOTOR ; actuate the motor at 50% duty cycle
    jsr READ_ENCODER
    std ENCODER_COUNT
    bgnd
    ;Overflow Positive (Return $0271)
    ldd #$0272
    jsr SATCHECK
    jsr UPDATE_MOTOR ; actuate the motor at 50% duty cycle
    jsr READ_ENCODER
    std ENCODER_COUNT
    bgnd
    ;Overflow Negative (Return $FD8F)
    ldd #$FD8E
    jsr SATCHECK
    jsr UPDATE_MOTOR ; actuate the motor at 50% duty cycle
    jsr READ_ENCODER
    std ENCODER_COUNT
    bgnd
    ;Negative (Return Value)
    ldd #$FF00
    jsr SATCHECK
    jsr UPDATE_MOTOR ; actuate the motor at 50% duty cycle
    jsr READ_ENCODER
    std ENCODER_COUNT
    bgnd
    ;Positive (Return Value)
    ldd #$0010
    jsr SATCHECK
    jsr UPDATE_MOTOR ; actuate the motor at 50% duty cycle
    jsr READ_ENCODER
    std ENCODER_COUNT
    bgnd

    bra TOP               ;go back to TOP and loop through endlessly


    ldd #$0000 ; load accumulator D with 313
    jsr UPDATE_MOTOR ; actuate the motor at 50% duty cycle
    jsr READ_ENCODER
    std ENCODER_COUNT
    
    ldd #$FEC7 ; load accumulator D with -313
    jsr UPDATE_MOTOR ; actuate the motor at -50% duty cycle
    bgnd

    ldd #$8000 ; load accumulator D with -32768
    jsr UPDATE_MOTOR ; brake the motor at 100% dut
    bgnd

;/------------------------------------------------------------------------------------\
;| Subroutines                                                                        |
;\------------------------------------------------------------------------------------/
SATCHECK:
  pshx
  pshc
  cpd #$0000
  bmi NEGATIVE
  bgt POSITIVE
  bra SATCHECK_exit
  POSITIVE:
    cpd #$0271
    ble SATCHECK_exit
    ldd #$0271
    bra SATCHECK_exit
  NEGATIVE:
    cpd #$FD8F
    bge SATCHECK_exit
    ldd #$FD8F
  SATCHECK_exit:
    pulc 
    pulx
    rts




DSATADD:
  pshx                ;pushes x to stack
  pshc                ;pushes c to stack
  sty TEMP            ;stores acc y value in TEMP
  addd TEMP           ;adds acc D to TEMP
  bvs DSATADD_OF    ;if Overflow is set then branch, otherwise just fall to exit
  
DSATADD_exit:
  pulc                ;puls c from stack
  pulx                ;puls x from stack
  rts                 ;end subroutine

DSATADD_OF:         ;tests overflow
  cpy #$0000          ;compares TEMP with hex 0
  bmi DSATADD_OFN          ;branches if value is negative
  ldd #$7FFF          ;loads acc D with positive overflow
  bra DSATADD_exit    ;goes to end subroutine

DSATADD_OFN:        ;sets negative overflow
  ldd #$8000          ;loads acc D with negative overflow
  bra DSATADD_exit    ;goes to end subroutine  

;/------------------------------------------------------------------------------------\
;| ASCII Messages and Constant Data                                                   |
;\------------------------------------------------------------------------------------/

;/------------------------------------------------------------------------------------\
;| Vectors                                                                            |
;\------------------------------------------------------------------------------------/
  ORG   $FFFE                    ; reset vector address
  DC.W  Entry
  ORG   $FFCE                    ; Key Wakeup interrupt vector address [Port J]
  DC.W  ISR_KEYPAD
