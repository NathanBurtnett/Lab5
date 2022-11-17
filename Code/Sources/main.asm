;**************************************************************************************
;* Blank Project Main [includes LibV2.2]                                              *
;**************************************************************************************
;* Summary:                                                                           *
;*   -                                                                                *
;*                                                                                    *
;* Author: YOUR NAME                                                                  *
;*   Cal Poly University                                                              *
;*   Spring 2022                                                                      *
;*                                                                                    *
;* Revision History:                                                                  *
;*   -                                                                                *
;*                                                                                    *
;* ToDo:                                                                              *
;*   -                                                                                *
;**************************************************************************************

;/------------------------------------------------------------------------------------\
;| Include all associated files                                                       |
;\------------------------------------------------------------------------------------/
; The following are external files to be included during assembly
              XDEF  main
              XDEF  Theta_OLD, RUN, CL, V_ref, KP, KI, UPDATE_FLG1  
;/------------------------------------------------------------------------------------\
;| External References                                                                |
;\------------------------------------------------------------------------------------/
; All labels from other files must have an external reference

              XREF  ENABLE_MOTOR, DISABLE_MOTOR
              XREF  STARTUP_MOTOR, UPDATE_MOTOR, CURRENT_MOTOR 
              XREF  STARTUP_PWM, STARTUP_ATD0, STARTUP_ATD1   
              XREF  OUTDACA, OUTDACB
              XREF  STARTUP_ENCODER, READ_ENCODER
              XREF  DELAY_MILLI, DELAY_MICRO
              XREF  INITLCD, SETADDR, GETADDR, CURSOR_ON, DISP_OFF
              XREF  OUTCHAR, OUTCHAR_AT, OUTSTRING, OUTSTRING_AT
              XREF  INITKEY, LKEY_FLG, GETCHAR
              XREF  LCDTEMPLATE, UPDATELCD_L1, UPDATELCD_L2
              XREF  LVREF_BUF, LVACT_BUF, LERR_BUF,LEFF_BUF, LKP_BUF, LKI_BUF
              XREF  Entry, ISR_KEYPAD
            
              XREF  V_act_DISP, ERR_DISP, EFF_DISP
              XREF  FREDENTRY
            
;/------------------------------------------------------------------------------------\
;| Assembler Equates                                                                  |
;\------------------------------------------------------------------------------------/
; Constant values can be equated here

TFLG1         EQU   $004E
TC0           EQU   $0050
C0F           EQU   %00000001          ; timer channel 0 output compare bit
PORTT         EQU   $0240              ; PORTT pin 8 to be used for interrupt timing
LOWER_LIM     EQU   -625               ; number for max reverse duty cycle
UPPER_LIM     EQU   625                ; number for max forward duty cycle

;/------------------------------------------------------------------------------------\
;| Variables in RAM                                                                   |
;\------------------------------------------------------------------------------------/
; The following variables are located in unpaged ram

DEFAULT_RAM:  SECTION

RUN:          DS.B  1                  ; Boolean indicating controller is running
CL:           DS.B  1                  ; Boolean for closed-loop active

V_act:        DS.W  1
V_ref:        DS.W  1                  ; reference velocity
Theta_OLD:    DS.W  1                  ; previous encoder reading
Theta_NEW:    DS.W  1                  ;
ENCODER_COUNT: DS.W  1                  ; encoder cound
KP:           DS.W  1                  ; proportional gain
KPRES:        DS.W  1                  ; proportional gain result
KI:           DS.W  1                  ; integral gain
KIRES:        DS.W  1                  ; intergral gain result

APRE          DS.W  1                  ; pi controller output
ASTAR         DS.W  1                  ; saturation checked pi controller output

ERROR:        DS.W  1                  ; the current error of the system
ESUM:         DS.W  1                  ; reiman sum of errors

EFF:          DS.W  1                  ; current effort of motor

ERR:          DS.W  1
TEMP:         DS.W  1
UPDATE_COUNT: DS.W  1



UPDATE_FLG1   DS.B  1                  ; Boolean for display update for line one


;/------------------------------------------------------------------------------------\
;|  Main Program Code                                                                 |
;\------------------------------------------------------------------------------------/
; Your code goes here

MyCode:       SECTION
main:   
;CLEAR VARIABLES 
    clrw LVREF_BUF
    clrw LVACT_BUF
    clrw LVACT_BUF

    clr RUN
    clr CL

    clrw V_act
    clrw V_ref
    clrw Theta_NEW
    clrw Theta_OLD
    clrw ENCODER_COUNT
    clrw KP 
    clrw KPRES
    clrw KI 
    clrw KPRES

    clrw ESUM
    clrw ERROR
    clrw APRE
    clrw ASTAR
    


    clrw EFF
    clr UPDATE_FLG1
    clrw UPDATE_COUNT

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
    jsr TC0ISR
    jsr FREDENTRY        
    bra TOP



;||||||||||||||||||||||||||||||||||ISR|||||||||||||||||||||||||||||||||||||||||||||||||
TC0ISR:
  bset PORTT, $80           ;turn on PORTT pin 8 to begin ISR timing
  
  inc UPDATE_COUNT          ;unless UPDATE_COUNT = 0, skip saving
  bne measurements          ; display variables
  movw V_act, V_act_DISP    ;take a snapshot of variables to enable
  movw ERR, ERR_DISP        ; consistent display
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
    errorcalc:  ; compute error
        ldd   V_ref
        subd  V_act
        std   ERROR
        ldy   ESUM
        jsr   DSATADD
        std   ESUM
    kicalc:     ;compute Ki
        ldy KI
        emul 
        ldx #$0400
        idiv 
        stx KIRES
    kpcalc:     ;compute Kp
        ldd ERROR
        ldy KP
        emul 
        ldx #$0400
        idiv 
        stx KPRES
    pisum:     ;add Kp and Ki
        ldd KPRES
        ldy KIRES
        jsr DSATADD
        std APRE
    pisatcheck:    ;satcheck
        jsr SATCHECK
        std ASTAR
    effcalc:    ;calculate effort
        ldy #$0271
        emul
        ldx #$0064
        idiv
        stx EFF
    motorset:   ;set motor speed
        ldd ASTAR
        jsr UPDATE_MOTOR
    uctest:
        ldd UPDATE_COUNT
        cpd #$01F4
        beq ucexit:
        rti

        ucexit:
            clr UPDATE_COUNT
            rti

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
; Any constants can be defined here


;/------------------------------------------------------------------------------------\
;| Vectors                                                                            |
;\------------------------------------------------------------------------------------/
; Add interrupt and reset vectors here
  ORG   $FFEE                       ;Timer channel 0 vector address
  DC.W  TC0ISR
  ORG   $FFFE                       ; reset vector address
  DC.W  Entry


