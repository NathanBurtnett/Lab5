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

              XDEF  RUN:        DS.B 1      ;Boolean indicating controller is running
              XDEF  CL:         DS.B 1      ;Boolean for closed-loop active

              XDEF  v_ref:      DS.W 1      ;reference velocity
              XDEF  Theta_OLD   DS.W 1      ;previous encoder reading
              XDEF  KP:         DS.W 1      ;proportional gain [1024*KP]
              XDEF  KI:         DS.W 1      ;integral gain [1024*KI]

              XDEF  UPDATE_FLG1 DS.B 1      ;Boolean for display update for line one

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

              XREF  Vact_DISP:  DS.W 1        ;actual velocity display value
              XREF  ERR_DSIP:   DS.W 1        ;error display value
              XREF  EFF_DISP:   DS.W 1        ;effort display value

              XREF  FREDENTRY:  DS.W 1        ;LAB 5 INTERFACE subroutine
            
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
  clr LVREF_BUF
  clr LVACT_BUF
  clr LVACT_BUF
  clr 

  ;SETUP INSTRUCTIONS
  jsr STARTUP_ENCODER   ;initialize encoder
  jsr READ_ENCODER      ;returns encoder count in D
  std ENCODER_COUNT     ;store the count in a 16-bit variable in RAM

  jsr STARTUP_PWM       ;initialize PWM module
  jsr STARTUP_MOTOR     ;initialize motor in disabled state

  jsr ENABLE_MOTOR      ;enable motor operation

  jsr INITLCD
  jsr LCDTEMPLATE       ;initializes the LCD
  bgnd
  

  TOP:
    ;Good
    ldd #$0000
    jsr SATCHECK
    jsr UPDATE_MOTOR ; actuate the motor at 50% duty cycle
    jsr UPDATELCD_L1
    jsr UPDATELCD_L2
    bgnd
    ;Overflow Positive (Return $0271)
    ldd #$0272
    jsr SATCHECK
    jsr UPDATE_MOTOR ; actuate the motor at 50% duty cycle
    jsr UPDATELCD_L1
    jsr UPDATELCD_L2  
    bgnd
    ;Overflow Negative (Return $FD8F)
    ldd #$FD8E
    jsr SATCHECK
    jsr UPDATE_MOTOR ; actuate the motor at 50% duty cycle
    jsr UPDATELCD_L1
    jsr UPDATELCD_L2  
    bgnd
    ;Negative (Return Value)
    ldd #$FF00
    jsr SATCHECK
    jsr UPDATE_MOTOR ; actuate the motor at 50% duty cycle
    jsr UPDATELCD_L1
    jsr UPDATELCD_L2  
    bgnd
    ;Positive (Return Value)
    ldd #$0010
    jsr SATCHECK
    jsr UPDATE_MOTOR ; actuate the motor at 50% duty cycle
    jsr UPDATELCD_L1
    jsr UPDATELCD_L2  
    bgnd

    bra TOP               ;go back to TOP and loop through endlessly

    jsr FREDENTRY         ;
    spin: bra TOP

;||||||||||||||||||||||||||||||||||ISR|||||||||||||||||||||||||||||||||||||||||||||||||
 TC0ISR:
  bset PORTT, $80           ;turn on PORTT pin 8 to begin ISR timing

  inc UPDATE_COUNT          ;unless UPDATE_COUNT = 0, skip saving
  bne measurements          ; display variables
  movw V_act, V_act_DISP    ;take a snapshot of variables to enable
  movw ERR, ERR_DSIP        ; consistent display
  movw EFF, EFF_DISP
  movb #$01, UPDATE_FLG1    ;set UPDATEFLG1 when appropriate

  measurements:
    ;read encoder value
    jsr   READ_ENCODER          ;read encoder position
    std   Theta_NEW             ;store it
    ;compute 2-point difference to get speed
    subd  Theta_OLD             ;compute displacement since last reading
    std   V_act                 ;store displacement as actual speed
    movw  Theta_NEW, Theta_OLD  ;move current raeading to previous reading

  ;CALCULATE VACT
    ;VACT = (THETANEW-THETAOLD)/(1BTI)
  ;CALCULATE ERROR (VREF-VACT)
  ;CALCULATE CONTROLER EFFORT
  ;CALCULATE PWM INPUT


;/------------------------------------------------------------------------------------\
;| Subroutines                                                                        |
;\------------------------------------------------------------------------------------/

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
