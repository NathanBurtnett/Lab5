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
    bgnd
    ldd #$0139 ; load accumulator D with 313
    jsr UPDATE_MOTOR ; actuate the motor at 50% duty cycle
    bgnd

    ldd #$FEC7 ; load accumulator D with -313
    jsr UPDATE_MOTOR ; actuate the motor at -50% duty cycle
    bgnd

    ldd #$8000 ; load accumulator D with -32768
    jsr UPDATE_MOTOR ; brake the motor at 100% dut
    bgnd
    
    bra TOP               ;go back to TOP and loop through endlessly
  

;/------------------------------------------------------------------------------------\
;| Subroutines                                                                        |
;\------------------------------------------------------------------------------------/
CONVERT:  ;converts input
  pshb                           ; save B & Y 
  pshy 
  des                            ; make room for three bytes on the stack 
  des                            ;   [first byte serves as a counter] 
  des                            ;   [last two bytes serve as RESULT] 
  clr   0,SP                     ; zero these three bytes on the stack 
  clrw  1,SP 
  ldx   #BUFFER 
 
  conv_loop: 
    ldaa  0,SP 
    ldab  A,X 
    subb  #'0' 
    clra       
    addd  1,SP
    cpd   #$FF
    bge   TOO_LARGE 
    std   1,SP 
    inc   0,SP 
    dec   COUNT 
    beq   conv_done 
    ldy   #$000A 
    emul 
    cpy   #$0000 
    bne   TOO_LARGE 
    std   1,SP 
    bra   conv_loop 
  conv_done: 
    cpd   #$0000 
    beq   ZERO_MAG 
    tfr   D,X 
    clra 
    bra   exit_conversion 
  TOO_LARGE: 
    ldaa  #$01 
    bra   exit_conversion 
  ZERO_MAG: 
    ldaa  #$02 
  exit_conversion: 
    ins                            ; remove three bytes from stack 
    ins 
    ins 
    puly                           ; restore B & Y 
    pulb 
    rts                            ; end subroutine ASCII_2_Bin 

TC0ISR: ;function generator code               
  dec   CINT                    ;BTI completion check
  bne   NOT_YET
  ldd   VALUE                   ;get updated DAC_A input
  jsr   OUTDACA                 ;update DAC_A output
  movb  NINT,CINT               ;reinitialize interupt counter for new BTI
  movb  #$01,NEWBTI             ;set flag indicating beginning of a new BTI
  
  NOT_YET:  ;reset timer for next interupt
    ldd   TC0H                  ;loads TC0H into acc. D
    addd  #INTERVAL             ;adds INTERVAL to D
    std   TC0H                  ;stores D into TC0H (THIS IS THE NEW TIME SET)
    bset  TFLG1, C0F_CLEAR      ;sets TFLG1 to C0F_CLEAR
    tst ERRORCOUNT
    bne ECDEC
    rti                         ;returns to interupt
    
    ECDEC:
      dec ERRORCOUNT
      rti
    

;/------------------------------------------------------------------------------------\
;| ASCII Messages and Constant Data                                                   |
;\------------------------------------------------------------------------------------/
;MESSAGES
L1:       DC.B ' (1)SAW  (2)7SINE  (3)SQUARE  (4)15SINE ',$00 
L2SAW:    DC.B 'WAVE: SAW            NINT:     [1-->255]',$00
L27SINE:  DC.B 'WAVE: 7SINE          NINT:     [1-->255]',$00
L2SQUARE: DC.B 'WAVE: SQUARE         NINT:     [1-->255]',$00
L215SINE: DC.B 'WAVE: 15SINE         NINT:     [1-->255]',$00
LARGE:    DC.B 'MAGNITUDE TOO LARGE',$00
ZERO:     DC.B '  INVALID MAGNITUDE',$00
NADA:     DC.B '  NO DIGITS ENTERED',$00
L2CLEAR:  DC.B '                                        ',$00 


;/------------------------------------------------------------------------------------\
;| Vectors                                                                            |
;\------------------------------------------------------------------------------------/
  ORG   $FFEE                      ;Timer channel 0 vector address
  DC.W  TC0ISR
  ORG   $FFFE                    ; reset vector address
  DC.W  Entry
  ORG   $FFCE                    ; Key Wakeup interrupt vector address [Port J]
  DC.W  ISR_KEYPAD
