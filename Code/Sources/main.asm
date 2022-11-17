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

V_ref:        DS.W  1                  ; reference velocity
Theta_OLD:    DS.W  1                  ; previous encoder reading
KP:           DS.W  1                  ; proportional gain
KI:           DS.W  1                  ; integral gain

UPDATE_FLG1   DS.B  1                  ; Boolean for display update for line one



;/------------------------------------------------------------------------------------\
;|  Main Program Code                                                                 |
;\------------------------------------------------------------------------------------/
; Your code goes here

MyCode:       SECTION
main:   
        
spin:   bra   spin                     ; endless horizontal loop


;/------------------------------------------------------------------------------------\
;| Subroutines                                                                        |
;\------------------------------------------------------------------------------------/
; General purpose subroutines go here


;/------------------------------------------------------------------------------------\
;| ASCII Messages and Constant Data                                                   |
;\------------------------------------------------------------------------------------/
; Any constants can be defined here


;/------------------------------------------------------------------------------------\
;| Vectors                                                                            |
;\------------------------------------------------------------------------------------/
; Add interrupt and reset vectors here
         ORG  $FFFE                    ; reset vector address
         DC.W Entry

