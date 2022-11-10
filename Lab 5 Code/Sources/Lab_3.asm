;**************************************************************************************
;* Lab 3 Code *
;**************************************************************************************
;* Summary:
;* 
;* Author: Nathan Burtnett, Tom Taylor *
;* Cal Poly University *
;* October 2022 *
;*
;* Revision History: *
;*
;**************************************************************************************
;/------------------------------------------------------------------------------------\
;| Include all associated files |
;\------------------------------------------------------------------------------------/
; The following are external files to be included during assembly
;/------------------------------------------------------------------------------------\
;| External Definitions |
;\------------------------------------------------------------------------------------/
; All labels that are referenced by the linker need an external definition
 XDEF main
;/------------------------------------------------------------------------------------\
;| External References |
;\------------------------------------------------------------------------------------/
; All labels from other files must have an external reference
 XREF ENABLE_MOTOR, DISABLE_MOTOR
 XREF STARTUP_MOTOR, UPDATE_MOTOR, CURRENT_MOTOR
 XREF STARTUP_PWM, STARTUP_ATD0, STARTUP_ATD1
 XREF OUTDACA, OUTDACB
 XREF STARTUP_ENCODER, READ_ENCODER
 XREF INITLCD, SETADDR, GETADDR, CURSOR_ON, CURSOR_OFF, DISP_OFF
 XREF OUTCHAR, OUTCHAR_AT, OUTSTRING, OUTSTRING_AT
 XREF INITKEY, LKEY_FLG, GETCHAR
 XREF LCDTEMPLATE, UPDATELCD_L1, UPDATELCD_L2
 XREF LVREF_BUF, LVACT_BUF, LERR_BUF,LEFF_BUF, LKP_BUF, LKI_BUF
 XREF Entry, ISR_KEYPAD
;/------------------------------------------------------------------------------------\
;| Assembler Equates |
;\------------------------------------------------------------------------------------/
; Constant values can be equated here
PORTP EQU $0258 ; output port for LEDs
DDRP EQU $025A
G_LED_1 EQU %00010000 ; green LED output pin for LED pair_1
R_LED_1 EQU %00100000 ; red LED output pin for LED pair_1
LED_MSK_1 EQU %00110000 ; LED pair_1
G_LED_2 EQU %01000000 ; green LED output pin for LED pair_2
R_LED_2 EQU %10000000 ; red LED output pin for LED pair_2
LED_MSK_2 EQU %11000000 ; LED pair_2
;/------------------------------------------------------------------------------------\
;| Variables in RAM |
;\------------------------------------------------------------------------------------/
; The following variables are located in unpaged RAM
DEFAULT_RAM: SECTION
;state variables
t1state:     DS.B 1
t2state:     DS.B 1
t3state:     DS.B 1
t4state:     DS.B 1
t5state:     DS.B 1
t6state:     DS.B 1
t7state:     DS.B 1
t8state:     DS.B 1
t9state:     DS.B 1
t3s0s        DS.B 1
;pattern variables
DONE_1:      DS.B 1
DONE_2:      DS.B 1
TICKS_1:     DS.W 1
TICKS_2:     DS.W 1
COUNT_1:     DS.W 1
COUNT_2:     DS.W 1
PAIR1READY   DS.B 1
PAIR2READY   DS.B 1
;display variables
DECHO:       DS.B 1
DBS:         DS.B 1
;error variables
ERROR1       DS.B 1
ERROR2       DS.B 1
t3e1l1p      DS.B 1
t3e2l1p      DS.B 1
t3e1l2p      DS.B 1
t3e2l2p      DS.B 1
ERROR_TIME   DS.W 1
TIMER_CD     DS.W 1
CLRER1       DS.B 1
;print variables
DPTR:        DS.W 1
FIRSTCHAR    DS.B 1
DIGIT_COUNT: DS.B 1
BUFFER       DS.B 5
BUFCLR       DS.B 1
KEY_FLG      DS.B 1
MOD          DS.B 1
COUNT        DS.B 1
KEY_BUF      DS.B 1
MMMES        DS.W 1
MMADD        DS.B 1
PRINTREQ     DS.B 1
;/------------------------------------------------------------------------------------\
;| Main Program Code |
;\------------------------------------------------------------------------------------/
; This code uses cooperative multitasking for Lab 2 from ME 305
MyCode: SECTION
main:
 clr t1state ; initialize all tasks to state0
 clr t2state
 clr t3state
 clr t4state
 clr t5state
 clr t6state
 clr t7state
 clr t8state
 clr t9state
 clr t3s0s
 clr t3e1l1p
 clr t3e2l1p
 clr t3e1l2p
 clr t3e2l2p
 clr MOD
 clr DPTR
 clr COUNT
 clr BUFFER
 clr DECHO
 clr DBS
 clr KEY_BUF
 clr KEY_FLG
 clr ERROR1
 clr ERROR2
 clr TIMER_CD
 clr PAIR1READY
 clr PAIR2READY
 clr PRINTREQ
 clr CLRER1
 
 movb #$01,   FIRSTCHAR  ;sets default for FIRSTCHAR to 1
 movw #$0BB8, ERROR_TIME ;3 second time delay for time that error message displays
 
 movw #100, TICKS_1 ; set default for TICKS_1
 movw #200, TICKS_2 ; set default for TICKS_2
 
 jsr INITLCD  ; initialize the LCD
 
Top:
 jsr TASK_1 ; Mastermind: 
 jsr TASK_2 ; Keypad
 jsr TASK_3 ; Display
 jsr TASK_4 ; Pattern 1
 jsr TASK_5 ; Timing 1
 jsr TASK_6 ; Pattern 2
 jsr TASK_7 ; Timing 2
 jsr TASK_8 ; Delay
 jsr TASK_9 ; Print Routine
 bra Top
 
;-------------TASK_1 Mastermind---------------------------------------------------------
TASK_1: 
 ldaa t1state   ;get current t1state and branch accordingly
 lbeq t1state0
 deca
 lbeq t1state1
 deca
 lbeq t1state2
 deca
 lbeq t1state3
 deca
 lbeq t1state4
 deca
 lbeq t1state5
 deca
 lbeq t1state6
 
 t1state0:            ;initialize
  movb #$01, t1state    ;go to t1state1
  rts
  
 ;----HUB STATE---- 
 t1state1:
  tst KEY_FLG           ;tests is a key has been pressed
  lbeq exit_t1          ;branch if no key pressed
   ;if key has been pressed
    ldaa KEY_BUF        ;load a with whatever key was just pressed          
    cmpa #$08 
      lbeq t1_bs        ;if key is BS then go to BS state 
    cmpa #$0A 
      lbeq t1_ent       ;if key is ENTER then go to ENTER state
    cmpa #$F1
      lbeq t1_f1        ;if key is F1 then go to F1 state
    cmpa #$F2
      lbeq t1_f2        ;if key is F2 then go to F2 state
    ;load if in MOD state  
    ldaa MOD
    cmpa #$01
      lbge t1_dh        ;if MOD is greater than 1 then go to DIGIT_HANDLER state
  rts
 
    ;task 1 branch sub-states
    t1_bs:
      movb #$03, t1state     ;go to BS state
      rts
    t1_ent:
      movb #$06, t1state     ;go to ENT state
      rts
    t1_f1:
      movb #$04, t1state     ;go to F1 state
      rts
    t1_f2:
      movb #$05, t1state     ;go to F2 state
      rts
    t1_dh:
      movb #$02, t1state     ;if just a number go to Digit Handler
      rts
 
 ;----DIGIT HANDLER STATE---- 
 t1state2:  
  movb #$00, KEY_FLG      ;clears key flag
  ldaa COUNT              ;loads and compares count to 5
  cmpa #$05
    ;if 5 digits have been entered, just exit
    lbeq exit_t1       
    ;if 5 digits have not been entered, continue  
    movb #$01, DECHO      ;set DECHO to 1 to branch to echo in display
    ldx #BUFFER           ;loads X with address of BUFFER
    ldab KEY_BUF          ;loads B with the contents of the key pressed
    stab A,X              ;stores X index of A with B
    inc COUNT             ;increments COUNT
    movb #$01, t1state    ;go back to HUB 
    rts
 
 ;----BACKSPACE STATE----  
 t1state3:  
  tst COUNT             ;test is COUNT is 0
    ;if COUNT=0 don't BS
    lbeq exit_t1          
    ;if COUNT != 0, BS
    dec COUNT             ;Decrement COUNT
    ldaa COUNT            ;Load COUNT into acc A
    ldx #BUFFER           ;load X with address of BUFFER
    movb #$00,A,X         ;change the current BUFFER location to $00
    movb #$01, DBS        ;Set ITCV to 1 for BS
    movb #$01, t1state    ;go back to HUB
    clr KEY_BUF           ;clear the current key
    clr KEY_FLG           ;clear that a key has been pressed
    rts
    
 ;----F1 STATE---- 
 t1state4:
  ldaa MOD          
  cmpa #$02
    ;checks if F2 state is already active, if so leave
    lbeq exit_t1
    ;if MOD is not pressed 
    movb #$01, MOD        ;set MOD to 1
    clr PAIR1READY        ;stop PAIR1
    ldaa #$08             ;load a with LCD address
    tst PRINTREQ          ;test if a print has already been requested
      lbeq t1fs              ;if not then put in a request for printing a BLANK for F1
      rts                   ;otherwise leave and come back to here until a print spot is open
      
 ;----F2 STATE---                     
 t1state5: 
  ldaa MOD
  cmpa #$01
    ;checks if F1 state is already active, if so leave
    lbeq exit_t1
    ;if MOD is not pressed
    movb #$02, MOD        ;set MOD to 12
    clr PAIR2READY        ;stop PAIR2
    ldaa #$48             ;load a with LCD address
    tst PRINTREQ          ;test if a print has already been requested
      lbeq t1fs              ;if not then put in a request for printing a BLANK for F2
      rts                   ;otherwise leave and come back to here until a print spot is open

  
    t1fs: 
        ldx #BLANK            ;load what message's address we want
        stx MMMES             ;save that into an intertask variable that printing will look for
        staa MMADD            ;save that into " "
        movb #$01, PRINTREQ   ;sets high a request to print
        movb #$01, t1state    ;go back to HUB state
        clr COUNT             ;clears buffer count
        clr KEY_BUF           ;clears current key
        clr KEY_FLG           ;clears current key flag
        rts   
 ;----ENTER---- 
 t1state6:  
  tst MOD
    ;if no F1/F2 state is on then just exit
    lbeq e_exit
    ;if in F1/F2 state do following
    clr KEY_BUF           ;clear current key
    clr KEY_FLG           ;clears current key flag
    ldaa #$03             ;Set address of Cursor to first entry
      jsr SETADDR            
    ldab MOD              ;Check if in F1 or F2 state
      cmpb #$01
      lbeq ent1
      cmpb #$02
      lbeq ent2
    rts
      ;if in F1 state do enter for line 1
      ent1:
        jsr CONVERT           ;converts buffer
          cmpa #$01             ;compares error code to 1  
          beq e1l1              ;if true: jumps to error 1 for top line
          cmpa #$02             ;compares error code to 2
          beq e2l1              ;if true: jumps to error 2 for top line
        stx TICKS_1           ;if no errors, load the pattern value into TICKS1
        movb #$01,PAIR1READY  ;set PAIR1 to ready
        bra e_exit 
      ;if in F2 state do enter for line 2                   
      ent2:
        jsr CONVERT             ;converts buffer
            cmpa #$01             ;compares error code to 1 
            beq e1l2              ;if true: jumps to error 1 for top line
            cmpa #$02             ;compares error code to 2
            beq e2l2              ;if true: jumps to error 2 for top line
        stx TICKS_2             ;if no errors, load the pattern value into TICKS2
        movb #$01,PAIR2READY    ;set PAIR2 to ready
        bra e_exit              ;branch to ERROR exit
 
            e1l1:                 ;if it is error 1 on line 1
              movb #$01, ERROR1     ;set ERROR1 to 1
              clr PAIR1READY        ;stop PAIR1
              bra e_exit            ;go to ERROR exit
            e2l1:                 ;if it is error 2 on line 1
              movb #$02, ERROR1     ;set ERROR1 to 2
              clr PAIR1READY        ;stop PAIR1
              bra e_exit            ;go to ERROR exit
            e1l2:                 ;if it is error 1 on line 2
              movb #$01, ERROR2     ;set ERROR1 to 1
              clr PAIR2READY        ;stop PAIR2
              bra e_exit            ;go to ERROR exit
            e2l2:                 ;if it is error 2 on line 2
              movb #$02, ERROR2     ;set ERROR1 to 12
              clr PAIR2READY        ;stop PAIR2
              bra e_exit            ;go to ERROR exit
      ;ERROR exit                              
      e_exit:
        movb #$00, MOD          ;exits Modification state
        clr KEY_BUF             ;clears current key
        clr KEY_FLG             ;clears current key flag
        movb #$01, t1state      ;go to HUB state
        rts
  
 exit_t1:
  movb #$01, t1state          ;go to HUB state
  rts 
  
 ;-------------TASK_2 Keypad---------------------------------------------------------
 TASK_2:
 ldaa t2state ; get current t2state and branch accordingly
 beq t2state0
 deca
 beq t2state1
 deca
 beq t2state2
 rts
 
 t2state0:            ;init state
  jsr INITKEY         ;initializes keyboard
  movb #$01, t2state  ;goes to test state
  rts
  
 t2state1:            ;test state
  tst LKEY_FLG        ;checks if key has been pressed
  beq exit_t2         ;exits if none
  movb #$02, t2state  ;goes to store key state if one has been
  rts  
  
 t2state2:            ;store key state
  jsr GETCHAR           ;character placed in acc b
  cmpb #$39             ;checks if character is 0-9
  bgt exit_t2
  stab KEY_BUF          ;character stores into KEY_BUF
  movb #$01, KEY_FLG    ;sets key flag to high
  movb #$01, t2state    ;goes back to 
  rts
 
 exit_t2:
  movb #$01, t2state
  rts ;no char ready

;-------------TASK_3 Display--------------------------------------------------------- 
 TASK_3: ldaa t3state ; get current t3state and branch accordingly
 lbeq t3state0  ;Splash Screen
 deca
 lbeq t3state1  ;Hub
 deca
 lbeq t3state2  ;ECHO
 deca
 lbeq t3state3  ;BS
 deca
 lbeq t3state4  ;ERROR1
 deca
 lbeq t3state5  ;ERROR2
 deca
 lbeq t3state6  ;INIT ERROR DELAY TIMER
 deca
 lbeq t3state7  ;DEC ERROR DELAY TIMER
 rts
 
 t3state0:            ;initialize display variables
   jsr CURSOR_ON      ;initializes cursor
   ldaa t3s0s         ;loads t3state0 sub state variable and branches accordingly
   lbeq t3s01a        
   deca
   lbeq t3s01b
   deca
   lbeq t3s02a
   deca
   lbeq t3s02b
   deca
   lbeq t3s03
   deca
   rts
  ;loads line 1 splash
  t3s01a:
    ldx #T1                 ;load what message's address we want
    stx MMMES               ;save that into an intertask variable that printing will look for
    movb #$00, MMADD        ;save that into " "
    movb #$01, PRINTREQ     ;sets the print request flag high
    movb #$01, t3s0s        ;goes to next state
    rts
    
    t3s01b:                 ;stays in state till print request is low (message done printing)
      ldaa PRINTREQ         ;loads print request and checks if it is done
      tsta 
        beq t3s0e1          ;goes to exit if done
      rts 
  ;loads line 2 splash
  t3s02a:
    ldaa CLRER1             ;checks if the clear error 1 flag if set
    cmpa #$01               ;if set, skip splash 2
      beq t3s03
      ldx #T2                 ;load what message's address we want
      stx MMMES               ;save that into an intertask variable that printing will look for
      movb #$40, MMADD        ;save that into " "
      movb #$01, PRINTREQ     ;sets the print request flag high
      movb #$03, t3s0s        ;goes to next state
      rts
    
    t3s02b:                 ;stays in state till print request is low (message done printing)
      ldaa PRINTREQ         ;loads print request and checks if it is done
      tsta 
        beq t3s03           ;goes to exit if done
      rts
  ;exits splash setup    
  t3s03:
    movb #$01, t3state      ;goes to HUB state
    movb #$00, t3s0s        ;resets sub-state branch variable
    clr CLRER1              ;clears the error 1 clear state flag
    rts  
    
  t3s0e1:
    movb #$02, t3s0s
    rts
 
 ;----HUB STATE----
 t3state1:          
  tst DECHO   ;test if mastermind says to echo
    bne t3echo  ;if DECHO = 1, branch to t3echo to set t3state to ECHO state
  tst DBS     ;test if mastermind says to backspace
    bne t3bs    ;if DBS = 1, branch to t3bs to set t3state to BS state
  ldaa ERROR1 ;test if Error is 1
  cmpa #$01   ;if ERROR1 = 1
    beq  t3e1l1 ;go to sub-state for error 1 on line 1
  cmpa #$02   ;if ERROR1 = 2 
    beq  t3e2l1 ;go to sub-sta`te for error 2 on line 1
  ldaa ERROR2
  cmpa #$01   ;if ERROR2 = 1
    beq  t3e1l2 ;go to sub-state for error 1 on line 2
  cmpa #$02   ;if ERROR2 = 2
    beq  t3e2l2 ;go to sub-state for error 2 on line 2
  rts
 
 
 t3echo:              ;sets t3 to ECHO state
  movb #$02, t3state 
  rts
  
 t3bs:                ;sets t3 to BS state
  movb #$03, t3state
  rts
  
 t3e1l1:              ;sets t3 to ERROR1 on LINE 1 state
  movb #$04, t3state
  rts
  
 t3e2l1:              ;sets t3 to ERROR2 on LINE 1 state
  movb #$04, t3state
  rts
 
 t3e1l2:              ;sets t3 to ERROR1 on LINE 2 state
  movb #$05, t3state
  rts
 
 t3e2l2:              ;sets t3 to ERROR2 on LINE 2 state
  movb #$05, t3state
  rts
  
 ;----ECHO STATE---
 t3state2:         
  ldab MOD            ;test if modifying line 1 or 2
  cmpb #$01
    lbeq echo1        ;if MOD=1 go to echo on line 1
  cmpb #$02
    lbeq echo2        ;if MOD=2 go to echo on line 2
  rts                 
    echo1:              ;echo on line 1
      ldaa #$07           ;echo on LCD addr. 7 + COUNT
      adda COUNT        
      ldab KEY_BUF        ;load current Key
        jsr OUTCHAR_AT
      movb #$00, DECHO    ;turn echo ITCV off
      movb #$01, t3state  ;go to HUB state
      rts
    echo2:              ;echo on line 2
      ldaa #$47           ;echo on LCD addr. 47 + COUNT
      adda COUNT
      ldab KEY_BUF        ;load current Key
        jsr OUTCHAR_AT
      movb #$00, DECHO    ;turn echo ITCV off
      movb #$01, t3state  ;go to HUB state
      rts
      
 ;----BACKSPACE STATE----   
 t3state3:            
  ldab MOD              ;test if modifying line 1 or 2
  cmpb #$01
    lbeq bs1            ;if MOD=1 go to backspace on line 1
  cmpb #$02
    lbeq bs2            ;if MOD=2 go to backspace on line 2
  rts
    bs1:                ;backspace on line 1
      ldaa #$08           ;backspace on LCD addr. 8 + COUNT
      adda COUNT          ;\/
      ldab #$20           ;\/
      jsr OUTCHAR_AT      ;\/ print a blank char.
      ldaa #$08           ;move cursor on LCD addr. 8 + COUNT
      adda COUNT          ;\/
      jsr SETADDR         ;\/
      movb #$00, DBS      ;turn off backspace ITCV 
      movb #$01, t3state  ;go to HUB state
      rts
    bs2:                ;backspace on line 2
      ldaa #$48           ;backspace on LCD addr. 48 + COUNT
      adda COUNT          ;\/
      ldab #$20           ;\/
      jsr OUTCHAR_AT      ;\/ print a blank char
      ldaa #$48           ;move cursor on LCD addr. 48 + COUNT
      adda COUNT          ;\/
      jsr SETADDR         ;\/
      movb #$00, DBS      ;turn off backspace ITCV 
      movb #$01, t3state  ;go to HUB state
      rts 

 ;--ERROR MESSAGE DISPLAY STATES--
 
 t3state4:  ;Display Error Line 1
   ldaa ERROR1    ;loads ERROR 1 to check which error message for line 1 it is
   cmpa #$01
   beq t3e1l1ps   ;if ERROR1 = 1, go to print error message 1
   bra t3e2l1ps   ;if ERROR1 = 2, go to print error message 2
   
    ;print logic for error message 1
    t3e1l1ps:       ;sets up the cooperative printing of error message 1      
      ldaa t3e1l1p    ;loads the sub-state counter
      beq t3e1l1pa    ;starts message
      deca
      beq t3e1l1pb    ;finishes message
      rts 
       
        t3e1l1pa:     ;sets up the request to start message
          ldx #LARGE          ;load message address
          stx MMMES           ;stores message address
          movb #$08, MMADD    ;stores start of message location
          movb #$01, PRINTREQ ;sets a print request to high
          movb #$01, t3e1l1p  ;moves t3e1l1 logic to next state
          rts
   
        t3e1l1pb:     ;prints until print request is done
          ldaa PRINTREQ       ;loads and tests PRINTREQ to see if printing is done
          tsta 
          beq t3e1l1pe
          rts 
    
    t3e1l1pe:       ;exit error message state once done printing    
      movb #$00, t3e1l1p
      movb #$06, t3state  ;go to the error message permanance delay
      rts
    
    ;print logic for error message 2
    t3e2l1ps:       ;sets up the cooperative printing of error message 1      
      ldaa t3e2l1p    ;loads the sub-state counter
      beq t3e2l1pa    ;starts message
      deca
      beq t3e2l1pb    ;finishes message
      rts 
       
        t3e2l1pa:     ;sets up the request to start message
          ldx #ZERO          ;load message address
          stx MMMES           ;stores message address
          movb #$08, MMADD    ;stores start of message location
          movb #$01, PRINTREQ ;sets a print request to high
          movb #$01, t3e2l1p  ;moves t3e2l1 logic to next state
          rts
   
        t3e2l1pb:     ;prints until print request is done
          ldaa PRINTREQ       ;loads and tests PRINTREQ to see if printing is done
          tsta 
          beq t3e2l1pe
          rts 
    
    t3e2l1pe:       ;exit error message state once done printing    
      movb #$00, t3e2l1p
      movb #$06, t3state   ;go to the error message permanance delay
      rts
                        
 t3state5:            ;Display Error Line 2
   ldaa ERROR2    ;loads ERROR 1 to check which error message for line 2 it is
   cmpa #$01
   beq t3e1l2ps   ;if ERROR1 = 1, go to print error message 1
   bra t3e2l2ps   ;if ERROR1 = 2, go to print error message 2
   
    ;print logic for error message 1
    t3e1l2ps:       ;sets up the cooperative printing of error message 1      
      ldaa t3e1l2p    ;loads the sub-state counter
      beq t3e1l2pa    ;starts message
      deca
      beq t3e1l2pb    ;finishes message
      rts 
       
        t3e1l2pa:         ;sets up the request to start message
          ldx #LARGE          ;load message address
          stx MMMES           ;stores message address
          movb #$48, MMADD    ;stores start of message location
          movb #$01, PRINTREQ ;sets a print request to high
          movb #$01, t3e1l2p  ;moves t3e1l2 logic to next state
          rts
   
        t3e1l2pb:         ;prints until print request is done
          ldaa PRINTREQ       ;loads and tests PRINTREQ to see if printing is done
          tsta 
          beq t3e1l2pe
          rts 
    
    t3e1l2pe:         ;exit error message state once done printing    
      movb #$00, t3e1l2p
      movb #$06, t3state  ;go to the error message permanance delay
      rts
    
    ;print logic for error message 2
    t3e2l2ps:       ;sets up the cooperative printing of error message 1      
      ldaa t3e2l2p    ;loads the sub-state counter
      beq t3e2l2pa    ;starts message
      deca
      beq t3e2l2pb    ;finishes message
      rts 
       
        t3e2l2pa:     ;sets up the request to start message
          ldx #ZERO          ;load message address
          stx MMMES           ;stores message address
          movb #$48, MMADD    ;stores start of message location
          movb #$01, PRINTREQ ;sets a print request to high
          movb #$01, t3e2l2p  ;moves t3e2l2 logic to next state
          rts
   
        t3e2l2pb:     ;prints until print request is done
          ldaa PRINTREQ       ;loads and tests PRINTREQ to see if printing is done
          tsta 
          beq t3e2l2pe
          rts 
    
    t3e2l2pe:         ;exit error message state once done printing   
      movb #$00, t3e2l2p
      movb #$06, t3state   ;go to the error message permanance delay
      rts
 
 ;--ERROR DELAY--                        
 t3state6: 
   ldy ERROR_TIME      ;loads acc. Y with 3 sec. error time
   sty TIMER_CD        ;moves acc. Y into Timer Countdown
   movb #$07,t3state   ;go to t3state7
   rts
                    
 t3state7:            
  decw TIMER_CD        ;decrement Timer Countdown
  ldy TIMER_CD         ;update Timer Countdown variable
  cpy #0               ;\/
  beq exit_t3          ;\/
  sty TIMER_CD         ;\/
  rts
 
 ;--ERROR EXIT-- 
 exit_t3:              ;branching function for line error states
  tst ERROR1           
  bne exit_t3_l1       ;if ERROR1 is high, go to line 1 exit
  bra exit_t3_l2       ;if ERROR2 is high, go to line 2 exit
 
 exit_t3_l1:
  clr ERROR1           ;clears ERROR1
  movb #$00,t3state    ;go to screen splash state
  movb #00, t3s0s      ;go to screen splash on line 1
  movb #$01, CLRER1    ;this variable tells the splash screen not to print a splash on line 2
  rts 
 
 exit_t3_l2:
  clr ERROR2           ;clears ERROR2
  movb #$00,t3state    ;go to screen splash state
  movb #02, t3s0s      ;go to screen splash on line 2
  rts 

 
;-------------TASK_4 Pattern_1---------------------------------------------------------
TASK_4: 
 tst PAIR1READY
 lbeq notready1

 ldaa t4state ; get current t4state and branch accordingly
 beq t4state0
 deca
 beq t4state1
 deca
 beq t4state2
 deca
 beq t4state3
 deca
 beq t4state4
 deca
 beq t4state5
 deca
 beq t4state6
 rts ; undefined state - do nothing but return
t4state0: ; init TASK_1 (not G, not R)
 bclr PORTP, LED_MSK_1 ; ensure that LEDs are off when initialized
 bset DDRP, LED_MSK_1 ; set LED_MSK_1 pins as PORTS outputs
 movb #$01, t4state ; set next state
 rts
t4state1: ; G, not R
 bset PORTP, G_LED_1 ; set state1 pattern on LEDs
 tst DONE_1 ; check TASK_1 done flag
 beq exit_t4s1 ; if not done, return
 movb #$02, t4state ; otherwise if done, set next state
exit_t4s1:
 rts
t4state2: ; not G, not R
 bclr PORTP, G_LED_1 ; set state2 pattern on LEDs
 tst DONE_1 ; check TASK_1 done flag
 beq exit_t4s2 ; if not done, return
 movb #$03, t4state ; otherwise if done, set next state
exit_t4s2:
 rts
t4state3: ; not G, R
 bset PORTP, R_LED_1 ; set state3 pattern on LEDs
 tst DONE_1 ; check TASK_1 done flag
 beq exit_t4s3 ; if not done, return
 movb #$04, t4state ; otherwise if done, set next state
exit_t4s3:
 rts
t4state4 ; not G, not R
 bclr PORTP, R_LED_1 ; set state4 pattern on LEDs
 tst DONE_1 ; check TASK_1 done flag
 beq exit_t4s4 ; if not done, return
 movb #$05, t4state ; otherwise if done, set next state
exit_t4s4:
 rts
t4state5: ; G, R
 bset PORTP, LED_MSK_1 ; set state5 pattern on LEDs
 tst DONE_1 ; check TASK_1 done flag
 beq exit_t4s5 ; if not done, return
 movb #$06, t4state ; otherwise if done, set next state
exit_t4s5:
 rts
t4state6: ; not G, not R
 bclr PORTP, LED_MSK_1 ; set state6 pattern on LEDs
 tst DONE_1 ; check TASK_1 done flag
 beq exit_t4s6 ; if not done, return
 movb #$01, t4state ; otherwise if done, set next state
exit_t4s6:
 rts ; exit TASK_1
 
notready1:
 bclr PORTP, LED_MSK_1 ; ensure that LEDs are off when initialized
 bset DDRP, LED_MSK_1
 bclr PORTP, G_LED_1 ; set state2 pattern on LED
 bclr PORTP, R_LED_1
 rts
 
;-------------TASK_5 Timing_1----------------------------------------------------------
TASK_5: 
 ldaa t5state ; get current t2state and branch accordingly
 beq t5state0
 deca
 beq t5state1
 rts ; undefined state - do nothing but return
t5state0: ; initialization for TASK_5
 movw TICKS_1, COUNT_1 ; init COUNT_1
 clr DONE_1 ; init DONE_1 to FALSE
 movb #$01, t5state ; set next state
 rts
t5state1: ; Countdown_1
 ldaa DONE_1
 cmpa #$01
 bne t5s1a ; skip reinitialization if DONE_1 is FALSE
 beq exit_t5s2 ;reinitialize if DONE_1 is TRUE  
t5s1a: ; we are here because DONE is False, because we still counting down
 decw COUNT_1
 beq COUNT_1_DONE
 rts
  COUNT_1_DONE:
   movb #$01, DONE_1
   movw TICKS_1, COUNT_1 ; init COUNT_1
   rts 
exit_t5s2:
 clr DONE_1
 rts ; exit TASK_5
  
; -------------TASK_6 Pattern_2---------------------------------------------------------
TASK_6: 
 tst PAIR2READY ;if PAIR2 is turned off then done perform Pattern_2
 lbeq notready2

 ldaa t6state ; get current t1state and branch accordingly
 beq t6state0
 deca 
 beq t6state1
 deca
 beq t6state2
 deca
 beq t6state3
 deca
 beq t6state4
 deca
 beq t6state5
 deca
 beq t6state6
 rts ; undefined state - do nothing but return
t6state0: ; init TASK_6 (not G, not R)
 bclr PORTP, LED_MSK_2 ; ensure that LEDs are off when initialized
 bset DDRP, LED_MSK_2 ; set LED_MSK_1 pins as PORTS outputs
 movb #$01, t6state ; set next state
 rts
t6state1: ; G, not R
 bset PORTP, G_LED_2 ; set state1 pattern on LEDs
 tst DONE_2 ; check TASK_6 done flag
 beq exit_t6s1 ; if not done, return
 movb #$02, t6state ; otherwise if done, set next state
exit_t6s1:
 rts
t6state2: ; not G, not R
 bclr PORTP, G_LED_2 ; set state2 pattern on LED
 tst DONE_2 ; check TASK_6 done flag
 beq exit_t6s2 ; if not done, return
 movb #$03, t6state ; otherwise if done, set next state
exit_t6s2:
 rts
t6state3: ; not G, R
 bset PORTP, R_LED_2 ; set state3 pattern on LEDs
 tst DONE_2 ; check TASK_6 done flag
 beq exit_t6s3 ; if not done, return
 movb #$04, t6state ; otherwise if done, set next state
exit_t6s3:
 rts
t6state4 ; not G, not R
 bclr PORTP, R_LED_2 ; set state4 pattern on LEDs
 tst DONE_2 ; check TASK_6 done flag
 beq exit_t6s4 ; if not done, return
 movb #$05, t6state ; otherwise if done, set next state
exit_t6s4:
 rts
t6state5: ; G, R
 bset PORTP, LED_MSK_2 ; set state5 pattern on LEDs
 tst DONE_2 ; check TASK_6 done flag
 beq exit_t6s5 ; if not done, return
 movb #$06, t6state ; otherwise if done, set next state
exit_t6s5:
 rts
t6state6: ; not G, not R
 bclr PORTP, LED_MSK_2 ; set state6 pattern on LEDs
 tst DONE_2 ; check TASK_6 done flag
 beq exit_t6s6 ; if not done, return
 movb #$01, t6state ; otherwise if done, set next state
exit_t6s6:
 rts ; exit TASK_46
 
notready2:
 bclr PORTP, LED_MSK_2 ; ensure that LEDs are off when initialized
 bset DDRP, LED_MSK_2
 bclr PORTP, G_LED_2 ; set state2 pattern on LED
 bclr PORTP, R_LED_2
 rts
 
;-------------TASK_7 Timing_2----------------------------------------------------------
TASK_7: ldaa t7state ; get current t7state and branch accordingly
 beq t7state0
 deca
 beq t7state1
 rts ; undefined state - do nothing but return
t7state0: ; initialization for TASK_7
 movw TICKS_2, COUNT_2 ; init COUNT_1
 clr DONE_2 ; init DONE_1 to FALSE
 movb #$01, t7state ; set next state
 rts
t7state1: ; Countdown_1
 ldaa DONE_2
 cmpa #$01
 bne t7s1a ; skip reinitialization if DONE_1 is FALSE
 beq exit_t7s2 ;reinitialize if DONE_1 is TRUE  
t7s1a: ; we are here because DONE is False, because we still counting down
 decw COUNT_2
 beq COUNT_2_DONE
 rts
  COUNT_2_DONE:
   movb #$01, DONE_2
   movw TICKS_2, COUNT_2 ; init COUNT_1
   rts 
exit_t7s2:
 clr DONE_2
 rts ; exit TASK_7
 
 ;-------------TASK_8 Delay 1ms---------------------------------------------------------
TASK_8: ldaa t8state ; get current t3state and branch accordingly
 beq t8state0
 deca
 beq t8state1
 rts ; undefined state - do nothing but return
t8state0: ; initialization for TASK_8
 ; no initialization required
 movb #$01, t8state ; set next state
 rts
t8state1:
 jsr DELAY_1ms
 rts ; exit TASK_8
 
 
;---TASK 9 PRINTING STUFF--;
;this is an extra task that we added so that we can do cooperative multitasking while printing
;by only letting one character be printed each run through TOP loop
;it emulates the PUTCHAR1ST (t9state2) and PUTCHAR (t9state3) subroutines 
TASK_9: ldaa t9state
 beq t9state0
 deca
 beq t9state1
 deca
 beq t9state2
 deca
 beq t9state3
 rts ; undefined state - do nothing but return
 
t9state0
 ; no initialization required
 movb #$01, t9state ; set next state
 rts

t9state1:
 tst PRINTREQ     ;if a request is made to print a message go to t9state2
 beq cexit_t9
 movb #$02, t9state
 rts
 
t9state2:           ;for the first character
 ldx MMMES          ;load message address
 stx DPTR           ;store message address in DPTR
 ldaa MMADD         ;load LCD address into acc. A
  jsr SETADDR
 movb #$03, t9state ;go to loop state
 rts

t9state3:           ;for the rest of the characters
 ldx DPTR           ;loads message address
 ldab 0,X           ;if current message is null then exit
 beq dexit_t9
 incw DPTR          ;otherwise increment DPTR
 jsr OUTCHAR        ;out a character at the LCD address
 rts
  
 dexit_t9:          ;exit state fo when done printing message
  movb #$01, t9state;go back to hub print state
  clr PRINTREQ      ;clear the print request to allow another message to print
  ldaa MOD          ;compare MOD to see if modifying line 1 or 2
  cmpa #$01         ;\/
    beq t9c1        ;\/ if MOD=1 then go to the subsequent exit and set cursor to start location 8
  cmpa #$02         ;\/
    beq t9c2        ;\/ if MOD=2 then go to the subsequent exit and set cursor to start location 48
  ldaa #$03         ;\/ else just put cursor on location 3
  jsr SETADDR
  rts
  
 t9c1:
  ldaa #$08
  jsr SETADDR
  rts
 
 t9c2:
  ldaa #$48
  jsr SETADDR
  rts 
  
 cexit_t9:
  rts

;/------------------------------------------------------------------------------------\
;| Subroutines |
;/------------------------------------------------------------------------------------/
; Add subroutines here:
DELAY_1ms:
 ldy #$0584
INNER: ; inside loop
 cpy #0
 beq EXIT
 dey
 bra INNER
EXIT:
 rts ; exit DELAY_1ms

PUTCHAR1ST:
 stx DPTR
 jsr SETADDR
 clr FIRSTCHAR
 rts

PUTCHAR:
 ldx DPTR
 ldab 0,X
 beq exit
 incw DPTR
 jsr OUTCHAR
 rts
 
exit:
  movb #$01, FIRSTCHAR
  rts

CONVERT:
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
        bcs   TOO_LARGE 
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
 
;/------------------------------------------------------------------------------------\
;| Messages |
;/------------------------------------------------------------------------------------/
; Add ASCII messages here:

T1: DC.B    'TIME1 =       <F1> to update LED1 period',$00
T2: DC.B    'TIME2 =       <F2> to update LED2 period',$00 
LARGE: DC.B 'Magnitude entered too large     ',$00
ZERO:  DC.B 'Cannot enter period of zero     ',$00
BLANK: DC.B '      ',$00

;/------------------------------------------------------------------------------------\
;| Vectors |
;\------------------------------------------------------------------------------------/
; Add interrupt and reset vectors here:
 ORG $FFFE ; reset vector address
 DC.W Entry
 ORG $FFCE
 DC.W ISR_KEYPAD