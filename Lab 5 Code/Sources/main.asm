;**************************************************************************************
;* Lab 4                                                                              *
;**************************************************************************************
;* Summary:                                                                           *
;*   -   This code seeks to request a wave and a wave period from the user and        *
;*       then output it onto it's board's DAC.                                        *
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
;WAVEFORM VARIABLES
NINT        DS.B 1    ;number of interrupts/BTI
CINT        DS.B 1    ;number of interrupts remaining
WAVEPTR     DS.W 1    ;address of first byte of wavedata
SEGPTR      DS.W 1    ;address of first byte of data in next segment, points to next DC.B
LSEG        DS.B 1    ;remaining segment length (BTIs)
CSEG        DS.B 1    ;remaining number of segments (BTIs)
VALUE       DS.W 1    ;next DAC output
SEGINC      DS.W 1    ;slope (DAC COUNTS/BTI)
;TASK VARIABLES
MMSTATE     DS.B 1    ;mastermind state variable
KPSTATE     DS.B 1    ;keypad state variable
DPSTATE     DS.B 1    ;display state variable
TCSTATE     DS.B 1    ;TC0 state variable
FGSTATE     DS.B 1    ;function generator state variable
PRSTATE     DS.B 1    ;print request state variable 
;ITCVs
NEWBTI      DS.B 1    ;flg tells function generator to compute new value 
KEY_FLG     DS.B 1    ;key has been pressed
MODE        DS.B 1    ;mode flag (0 WF select, 1 period select, 2 update FG)
PREQ        DS.B 1    ;request print
ERROR       DS.B 1    ;keeps track of error (0 none, 1 mag too large , 2 mag 0, 3 no digits)
;KEYBOARD VARIABLES
KEY_BUF     DS.B 1    ;stores key that has just been pressed
BUFFER      DS.B 3    ;stores key digits 
COUNT       DS.B 1    ;number of digits entered 
;DISPLAY VARIABLES
DBS         DS.B 1    ;display backspace
DECHO       DS.B 1    ;display echo
DWAVE       DS.B 1    ;display wave (superboolean)
DWLINE      DS.B 1    ;display wave line
SPLASH      DS.B 1    ;used to hold the splash tasks in place till complete
DPe1p       DS.B 1    ;sub-state counter for error 1
DPe2p       DS.B 1    ;sub-state counter for error 2
DPe3p       DS.B 1    ;sub-state counter for error 13
ERRORCOUNT  DS.W 1    ;used to count down for error display
L2CURSOR    DS.B 1    ;line 2: finish printing - waiting for NINT
;PRINTING VARIABLES
DPTR        DS.W 1    ;points to the next character to display
FIRSTCHAR   DS.B 1    ;flag when first character is being printed
MES         DS.W 1    ;stores the address for current message
ADDR        DS.B 1    ;stores LCD address for where message shoul be displayed
;FUNCTION GEN VARIABLES
DPRMPT      DS.B 1    ;display prompt
NEWWAVE     DS.B 1    ;allows function generator to run
NINTG       DS.B 1    ;checks if right NINT is chosen
;/------------------------------------------------------------------------------------\
;|  Main Program Code                                                                 |
;\------------------------------------------------------------------------------------/
MyCode:       SECTION
main:
  ;---CLEAR VARIABLES---
    ;clear waveform variables
      clr NINT
      clr CINT
      clrw WAVEPTR
      clrw SEGPTR
      clr LSEG
      clr CSEG
      clr VALUE
      clr NEWBTI
      clr SEGINC
    ;clear state variables
      clr MMSTATE
      clr KPSTATE
      clr DPSTATE
      clr TCSTATE
      clr FGSTATE
      clr PRSTATE
    ;clear ITCVs  
      clr MODE
      clr PREQ
      clr ERROR
      clr SPLASH
      clr DPTR
      clr DECHO
      clr DBS
      clr DWAVE
      clr DWLINE
      clr NEWWAVE
      clr L2CURSOR
    ;clear message variables
      clr COUNT
      clr DPe1p
      clr DPe2p
      clr DPe3p
      clrw ERRORCOUNT
      clr KEY_BUF
  
  TOP:
    jsr MASTERMIND        ;jumps to Mastermind task
    jsr KEYPAD            ;jumps to keypad task
    jsr DISPLAY           ;jumps to display task
    jsr TC0               ;jumps to timer channel 0 task
    jsr FUNCTIONGENERATOR ;jumps to function generator 0 task
    jsr PRINTREQUEST      ;jumps to print requesting 
    bra TOP               ;go back to TOP and loop through endlessly
  
;/------------------------------------------------------------------------------------\
;| Tasks                                                                              |
;\------------------------------------------------------------------------------------/
;//////////////////////////MASTERMIND//////////////////////////
MASTERMIND: ;Mastermind handeles the logic of ITCV's and what happens to keypad entries
  ldaa MMSTATE      ;loads acc A with the mastermind state variable       
  cmpa #$00
  lbeq MMState0     ;if MMSTATE is 0 go to state 0
  cmpa #$01
  lbeq MMState1     ;if MMSTATE is 1 go to state 1
  cmpa #$02
  lbeq MMState2     ;if MMSTATE is 2 go to state 2
  cmpa #$03
  lbeq MMState3     ;if MMSTATE is 3 go to state 3
  cmpa #$04
  lbeq MMState4     ;if MMSTATE is 4 go to state 4
  bgnd              ;stop program if state is undefined (error checking)

  MMState0:   ;INIT
    movb #$01, MMSTATE  ;nothing to init, go to next state
    rts
    
  MMState1:   ;HUB
    tst KEY_FLG         ;tests if key flag is set
    lbeq exit_MM        ;branch to exit if key flag is 0 
    ldaa MODE           ;check which mode the program is in
    cmpa #$00
    lbeq mode0          ;mode 0: go to mode0
    cmpa #$01
    lbeq mode1          ;mode 1: go to mode1
    cmpa #$02
    lbeq mode0          ;mode 2: go to mode0
    rts
    
    mode0:              ; waiting for waveform selection
      ldaa KEY_BUF        ;test if keybuf is 0-4
      cmpa #$30           ;\0/
      lbeq ws0            ;\ / jump to select wave
      cmpa #$31           ;\1/
      lbeq ws1            ;\ / jump to select wave
      cmpa #$32           ;\2/
      lbeq ws2            ;\ / jump to select wave
      cmpa #$33           ;\3/
      lbeq ws3            ;\ / jump to select wave
      cmpa #$34           ;\4/
      lbeq ws4            ;\ / jump to select wave
      lbra exit_MM
      
        ws0:  ;selects waveform 0 (no wave selected)
          movb #$00, DWAVE      ;change display ITCV to wave 0
          movb #$00, MODE       ;change mode to wait for another waveform selection
          bra wsexit
        ws1:    ;selects waveform 1 (SAW) 
          movb #$01, DWAVE ;change display ITCV to wave 1
          movb #$01, MODE  ;change mode to wait for nint
          bra wsexit 
        ws2:    ;selects waveform 2 (7SINE)
          movb #$02, DWAVE ;change display ITCV to wave 2
          movb #$01, MODE  ;change mode to wait for nint
          bra wsexit 
        ws3:    ;selects waveform 3 (SQUARE)
          movb #$03, DWAVE ;change display ITCV to wave 3
          movb #$01, MODE  ;change mode to wait for nint
          bra wsexit
        ws4:    ;selects waveform 4 (15SINE)
          movb #$04, DWAVE ;change display ITCV to wave 4
          movb #$01, MODE  ;change mode to wait for nint
          bra wsexit
        wsexit: ;exits wave selection
          movb #$01, DWLINE     ;ITCV for displaying wave line
          clr KEY_FLG
          rts
    mode1:              ;waiting for nint
      ldab KEY_BUF
        cmpb #$08 
        lbeq bs        ;if key is BS then go to BS state 
        cmpb #$0A 
        lbeq ent       ;if key is ENTER then go to ENTER state
        cmpb #$09
        lbge dh
        rts
   
          dh:
            movb #$02, MMSTATE     ;if just a number go to Digit Handler
            rts
          bs:
            movb #$03, MMSTATE     ;go to BS state
            rts
          ent:
            movb #$04, MMSTATE    ;go to ENT state
            rts
        
 
  MMState2:   ;DIGIT HANDLER 
  ldaa COUNT              ;loads and compares count to 3
  cmpa #$03
    lbeq exit_MM          ;if 3 digits have been entered, just exit 
  movb #$01, DECHO      ;set DECHO to 1 to branch to echo in display
  ldx #BUFFER           ;loads X with address of BUFFER
  ldab KEY_BUF          ;loads B with the contents of the key pressed
  stab A,X              ;stores X index of A with B
  inc COUNT             ;increments COUNT
  bra exit_MM
 
  MMState3:   ;BACKSPACE
  tst COUNT             ;test is COUNT is 0
    ;if COUNT=0 don't BS
    lbeq exit_MM          
    ;if COUNT != 0, BS
    dec COUNT             ;Decrement COUNT
    ldaa COUNT            ;Load COUNT into acc A
    ldx #BUFFER           ;load X with address of BUFFER
    movb #$00,A,X         ;change the current BUFFER location to $00
    movb #$01, DBS        ;Set ITCV to 1 for BS
    bra exit_MM
    
  MMState4:   ;ENTER
  ldaa #$35             ;Set address of Cursor to first entry                
  jsr SETADDR 
  tst COUNT
  beq e3             
  jsr CONVERT           ;converts buffer
    cmpa #$01             ;compares error code to 1  
      beq e1              ;if true: jumps to error 1
    cmpa #$02             ;compares error code to 2
      beq e2              ;if true: jumps to error 2 
    tfr X,D
    stab NINT              ;if no errors, load the period value into NINT
    clr COUNT
    movb #$02, MODE       ;goes back to waveform select state
    movb #$01, NEWBTI
    movb #$01, NEWWAVE
    movb #$01, NINTG
    bra exit_MM           ;leaves ENTER state
 
      e1:                 ;if it is error 1
        movb #$01, ERROR     ;set ERROR to 1
        clr COUNT
        bra exit_MM            ;go to exit
      e2:                 ;if it is error 2
        movb #$02, ERROR     ;set ERROR to 2
        clr COUNT
        bra exit_MM           ;go to exit
      e3:                 ;if it is error 3
        movb #$03, ERROR     ;set ERROR to 3
        clr COUNT
        bra exit_MM           ;go to exit  

  exit_MM:
  movb #$01, MMSTATE          ;go to HUB state
  clr KEY_FLG
  rts 


;//////////////////////////KEYPAD//////////////////////////
KEYPAD: ;Keypad tests if a key has been pressed, filters it, sets a key flag high, 
        ;and loads it into a buffer for mastermind to use
 ldaa KPSTATE ; get current t2state and branch accordingly
 beq KPState0
 deca
 beq KPState1
 deca
 beq KPState2
 rts
 
 KPState0:    ;INIT
  jsr INITKEY         ;initializes keyboard
  movb #$01, KPSTATE  ;goes to test state
  rts
 KPState1:    ;TEST
  tst PREQ            
  bne exit_KP
  tst LKEY_FLG        ;checks if key has been pressed
  beq exit_KP         ;exits if none
  movb #$02, KPSTATE  ;goes to store key state if one has been
  rts  
 KPState2:    ;STORE
  jsr GETCHAR         ;character placed in acc b
  cmpb #$39           ;checks if character is 0-9
  bgt exit_KP
  stab KEY_BUF        ;character stores into KEY_BUF
  movb #$01, KEY_FLG  ;sets key flag to high
  bra exit_KP
 exit_KP:     ;EXIT
  movb #$01, KPSTATE  ;go back to state 1
  rts
;//////////////////////////DISPLAY//////////////////////////
DISPLAY:
  ldaa DPSTATE
  cmpa #$00
  lbeq DPState0       ;initialize - splash first line
  deca
  lbeq DPState1       ;splash line 1
  deca 
  lbeq DPState2       ;hub
  deca 
  lbeq DPState3       ;echo
  deca 
  lbeq DPState4       ;backspace
  deca 
  lbeq DPState5       ;error
  rts
  
  DPState0:   ;INIT
     jsr INITLCD          ;initialize the LCD 
     jsr CURSOR_ON        ;turn on cursor
     movb #$01, DPSTATE   ;go to splash state
     rts
  DPState1:   ;SPLASH
    tst SPLASH            ;test if line 1 has been splashed
    lbeq splash1          ;go to splashing line 1 
    lbne splash2
    splash1:
      ldx #L1               ;load what message's address we want
      stx MES               ;save that into an intertask variable that printing will look for
      movb #$00, ADDR       ;save that into LCD address holder
      movb #$01, PREQ       ;sets the print request flag high
      movb #$01, SPLASH     ;goes to next state
      rts
    splash2:                ;stays in state till print request is low (message done printing)
      tst PREQ                ;loads print request and checks if it is done
      beq splashe             ;goes to exit if done
      rts 
    splashe:
      movb #$02, DPSTATE    ;go to hub state
      movb #$00, SPLASH     ;turn of splash flag
      rts 
  DPState2:   ;HUB
    tst DWLINE            ;test which line to test ITCVs for
    lbne wsel             ;wave select 
    lbeq ktst             ;key test
    rts
    wsel:
      ldaa DWAVE            ;test DWAVE to see what wave is selected
      cmpa #$00
      lbeq w0               ;wave 0 
      cmpa #$01
      lbeq w1               ;wave 1
      cmpa #$02
      lbeq w2               ;wave 2 
      cmpa #$03
      lbeq w3               ;wave 3
      cmpa #$04
      lbeq w4               ;wave 4
      clr DWAVE             ;clears DWAVE ITCV
      rts
      
      w0: ;wave 0
        ldx #L2CLEAR          ;load what message's address we want
        bra w0exit
          
      w1: ;wave 1
        ldx #L2SAW          ;load what message's address we want
        bra wexit 
      w2: ;wave 2
        ldx #L27SINE          ;load what message's address we want
        bra wexit 
      w3: ;wave 3
        ldx #L2SQUARE          ;load what message's address we want
        bra wexit 
      w4: ;wave 4
        ldx #L215SINE          ;load what message's address we want
        bra wexit
              
      wexit:  ;exit waves
        stx MES               ;save that into an intertask variable that printing will look for
        movb #$40, ADDR       ;save that into " "
        movb #$01, PREQ       ;flag print request
        movb #$00, DWLINE     ;go to ktst next time through
        movb #$01, L2CURSOR   ;enables the cursor on line 2
        rts  
      w0exit: ;exit 0 wave
        stx MES               ;save that into an intertask variable that printing will look for
        movb #$40, ADDR       ;save that into " "
        movb #$01, PREQ       ;flag print request
        movb #$00, DWLINE     ;go to ktst next time through
        rts
    ktst:   
      tst DECHO             ;test if mastermind says to echo
        bne Decho  ;if DECHO = 1, branch to Decho to set DPSTATE to ECHO state
      tst DBS               ;test if mastermind says to backspace
        bne Dbs    ;if DBS = 1, branch to Dbs to set DPSTATE to BS state
      tst ERROR             ;test if Error is 1
        bne De
      rts
      Decho:  ;go to echo state
        movb #$03, DPSTATE 
        rts
      Dbs:    ;go to backspace state
        movb #$04, DPSTATE 
        rts
      De:     ;go to error state
        movb #$05, DPSTATE
        rts

  DPState3:   ;ECHO              
    ldaa #$5A             ;echo on LCD addr. Line 2: 27 + COUNT    
    adda COUNT            
    jsr SETADDR           ;sets the cursor to next location      
    ldab KEY_BUF          ;load current Key
    jsr OUTCHAR_AT        ;print character at right location
    movb #$00, DECHO      ;turn echo ITCV off
    movb #$02, DPSTATE    ;go to HUB state
    rts
  DPState4:   ;BACKSPACE
    ldaa #$5B             ;backspace on LCD addr. 28 + COUNT
    adda COUNT            ;\/
    ldab #$20             ;\/
    jsr OUTCHAR_AT        ;\/ print a blank char.
    ldaa #$5B             ;move cursor on LCD addr. 28 + COUNT
    adda COUNT            ;\/
    jsr SETADDR           ;\/
    movb #$00, DBS        ;turn off backspace ITCV 
    movb #$02, DPSTATE    ;go to HUB state
    rts
  DPState5:   ;ERROR 
    tst ERRORCOUNT        ;tests for error permanance
    lbne DPec
    ldaa ERROR            ;loads ERROR 1 to check which error message for line 1 it is
    cmpa #$01
    lbeq DPe1ps           ;if ERROR = 1, go to print error message 1
    cmpa #$02
    lbeq DPe2ps           ;if ERROR = 2, go to print error message 2
    cmpa #$03
    lbeq DPe3ps           ;if ERROR = 3, go to print error message 3  

    DPe1ps:   ;print logic for error message 1 (magnitude is too large)      
      ldaa DPe1p            ;loads the sub-state counter
      beq DPe1pa            ;starts message
      deca
      beq DPepb             ;finishes message
      rts 
        DPe1pa:   ;sets up the request to start message
          ldx #LARGE          ;load message address
          stx MES           ;stores message address
          movb #$55, ADDR    ;stores start of message location
          movb #$01, PREQ    ;sets a print request to high
          movb #$01, DPe1p  ;moves t3e1l1 logic to next state
          rts
    DPe2ps:   ;print logic for error message 2 (magnitude is too large)      
      ldaa DPe2p    ;loads the sub-state counter
      beq DPe2pa    ;starts message
      deca
      beq DPepb    ;finishes message
      rts 
        DPe2pa:     ;sets up the request to start message
          ldx #ZERO         ;load message address
          stx MES           ;stores message address
          movb #$55, ADDR   ;stores start of message location
          movb #$01, PREQ   ;sets a print request to high
          movb #$01, DPe2p  ;moves t3e1l1 logic to next state
          rts
    DPe3ps:   ;print logic for error message 1 (magnitude is too large)      
      ldaa DPe3p    ;loads the sub-state counter
      beq DPe3pa    ;starts message
      deca
      beq DPepb     ;finishes message
      rts 
        DPe3pa:     ;sets up the request to start message
          ldx #NADA         ;load message address
          stx MES           ;stores message address
          movb #$55, ADDR   ;stores start of message location
          movb #$01, PREQ   ;sets a print request to high
          movb #$01, DPe3p  ;moves t3e1l1 logic to next state
          rts
    DPepb:    ;prints until print request is done
      ldaa PREQ             ;loads and tests PRINTREQ to see if printing is done
      tsta 
      beq DPe1pe          
      rts   
    DPe1pe:   ;exit error message state once done printing    
      clr DPe1p             ;clears all substate variables
      clr DPe2p
      clr DPe3p
      clr ERROR             ;clears error ITCV
      movw #$FFFF, ERRORCOUNT   ;starts the error message permanance delay
      rts
    DPec:         ;ERROR COUNT DELAY TIMER
        decw ERRORCOUNT
        tst ERRORCOUNT
        beq DPecexit
        rts
        DPecexit:
          movb #$02, DPSTATE  ;go to the error message permanance delay
          movb #$01, DWLINE
          clrw ERRORCOUNT
          rts 
;//////////////////////////TC0//////////////////////////
TC0:
  ldaa TCSTATE
  cmpa #$00
  beq TCState0
  deca
  beq TCState1
  deca 
  beq TCState2
  rts

  TCState0:    ; Initialize - Set up all interrupts like HW4
    cli                         ;allows interupts
    bset  TIOS,   #C0           ;sets TIOS to C0
    bset  TCTL2,  #CROA_TOGGLE  ;sets TCTL2 to CROA_TOGGLE
    bset  TFLG1,  #C0F_CLEAR    ;sets TFLG1 to #C0F_CLEAR
    bset  TIE,    #C0I_SET      ;sets TIE to #C0I_SET
    bset  TSCR1,  #TEN_TSFRZ_SET;sets TSCR1 to TEN_TSFRZ_SET
    ldd   TCNT                  ;loads acc. D with TCNT
    addd  #INTERVAL             ;adds INTERVAL to D
    std   TC0H                  ;stores D into TC0H (THIS IS THE NEW TIME SET)
    movb #$01, TCSTATE
    bclr TIE, C0I_SET             ;disable timer overflow flag to trigger input
    bclr TCTL2,CROA_TOGGLE               ;stop toggle output
    rts
    
  TCState1:    ; Halted until Run (Mode 2)
    ldaa MODE                   ;If Mode = 2 (Running), enable interupts
    cmpa #$02
    bne exit_TC
    movb #02, TCSTATE           ;go to TCState2
    bset TIE, C0I_SET             ;enable timer overflow flag to trigger input
    bset TCTL2, CROA_TOGGLE              ;set output to toggle
    rts  

  TCState2:    ; Running until Halted (Mode != 2)
    ldaa MODE                   ;If Mode != 2 (Not Running), disable interupts
    cmpa #$02
    beq exit_TC
    movb #01, TCSTATE           ;go to TCState1
    bclr TIE, C0I_SET             ;disable timer overflow flag to trigger input
    bclr TCTL2,CROA_TOGGLE               ;stop toggle output
    rts
    
    exit_TC:
    rts
  
;//////////////////////////FUNCTION GENERATOR//////////////////////////
FUNCTIONGENERATOR:
  ldaa FGSTATE
  cmpa #$00
  lbeq FGState0 
  cmpa #$01
  lbeq FGState1
  cmpa #$02
  lbeq FGState2
  cmpa #$03
  lbeq FGState3
  cmpa #$04
  lbeq FGState4
  rts
  
  FGState0: ;INIT
    tst NEWWAVE
    lbeq s4e
    movb #$01, FGSTATE
    rts

  FGState1: ;WAITING FOR WAVE
    tst DWAVE
      lbeq FGexit
    ldaa DWAVE
    cmpa #$01
    lbeq wave1
    cmpa #$02
    lbeq wave2
    cmpa #$03
    lbeq wave3
    cmpa #$04
    lbeq wave4
    rts
    
    wave1: ;select waveform 1 (SAW)
      ldx  #SAW
      stx WAVEPTR
      lbra wave_exit
    wave2: ;select waveform 2 (7SINE)
      ldx  #SINE7
      stx WAVEPTR
      lbra wave_exit
    wave3: ;select waveform 3 (SQUARE)
      ldx #SQUARE
      stx WAVEPTR
      lbra wave_exit
    wave4: ;select waveform 4 (15SINE)
      ldx #SINE15
      stx WAVEPTR
      lbra wave_exit
    wave_exit:  
      movb #$02, FGSTATE
      rts

  FGState2: ;NEW WAVE
    ldx   WAVEPTR     ;point to start of data for wave
    movb  0,X,CSEG    ;get number of wave segments
    movw  1,X,VALUE   ;get initial value for DAC
    movb  3,X,LSEG    ;load segment length
    movw  4,X,SEGINC  ;load segment increment
    inx
    inx
    inx
    inx
    inx
    inx
    stx   SEGPTR      ;store incremented SEGPTR for next segment
    movb  #$01,DPRMPT ;set flag for display of NINT prompt
    movb  #$03,FGSTATE;set next state
    rts
  
  FGState3: ;CHECK NINT
    tst NINTG
    beq s4e
    movb #$00, NEWWAVE
    movb #$00, NINTG
    movb #$04, FGSTATE
    ldaa LSEG
    adda #$01
    staa LSEG
    rts
    
    s4e: rts
       
  FGState4: ;DISPLAY WAVE
    tst NEWWAVE
    bne fgs4c
    tst NEWBTI
    beq fgs4e
    dec   LSEG        ;decrement segment length counter
      bne   fgs4b     ;if not at end, simply update DAC output
    dec   CSEG        ;if at end, decrement segment counter
      bne   fgs4a     ;if not last segment, skip reinit of wave
    ldx   WAVEPTR     ;point to start of data for wave
    movb  0,X,CSEG    ;get number of wave segments
    inx               ;inc SEGPTR to start of first segment
    inx
    inx
    stx   SEGPTR      ;store incremented SEGPTR
    fgs4a:            
      ldx   SEGPTR      ;point to start of new segment
      movb  0,X,LSEG    ;initialize segment length counter
      movw  1,X,SEGINC  ;load segment increment
      inx               ;inc SEGPTR to next segment
      inx
      inx
      stx   SEGPTR      ;store incremented SEGPTR
    fgs4b:              
      ldd   VALUE       ;get current DAC input value
      addd  SEGINC      ;add SEGINC to current DAC input value
      std   VALUE       ;store incremented DAC input value
      bra   fgs4d  
    fgs4c: movb #$01, FGSTATE   ;set next state   
    fgs4d: clr  NEWBTI
    fgs4e: rts
      
   FGexit:
      rts

;//////////////////////////PRINTREQUEST//////////////////////////     
PRINTREQUEST:
  ldaa PRSTATE
  cmpa #$00
  lbeq PRState0 
  cmpa #$01
  lbeq PRState1
  cmpa #$02
  lbeq PRState2
  cmpa #$03
  lbeq PRState3
  rts
  
  PRState0: ;INIT
    movb #$01, PRSTATE ; set next state
    rts

  PRState1: ;TEST PRINT REQUEST
    tst PREQ            ;if a request is made to print a message go to t9state2
    beq PRexit
    movb #$02, PRSTATE
    rts
 
  PRState2: ;PRINT FIRST CHARACTER
    ldx MES             ;load message address
    stx DPTR            ;store message address in DPTR
    ldaa ADDR           ;load LCD address into acc. A
    jsr SETADDR
    movb #$03, PRSTATE  ;go to loop state
    rts

  PRState3: ;PRINT OTHER CHARACTERS
    ldx DPTR            ;loads message address
    ldab 0,X            ;if current message is null then exit
    beq PRexitDONE
    incw DPTR           ;otherwise increment DPTR
    jsr OUTCHAR         ;out a character at the LCD address
    rts
  
    PRexitDONE:         ;exit state fo when done printing message
      movb #$01, PRSTATE ;go back to hub print state
      movb #$00, PREQ    ;clear the print request to allow another message to print
      ldaa #$35
      jsr SETADDR
      tst L2CURSOR
      bne PRec
      rts
      PRec:
        clr L2CURSOR    ;clears the cursor for line 2 ITCV
        ldaa #$5B       
        jsr SETADDR 
        rts
  
    PRexit:
      rts

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
;WAVEFORMS
TRIANGLE: ;sets up data for TRIANGLE waveform
    DC.B  3                  ; number of segments for TRIANGLE 
    DC.W  2048               ; initial DAC input value 
    DC.B  50                 ; length for segment_1 
    DC.W  30                 ; increment for segment_1 
    DC.B  100                ; length for segment_2 
    DC.W  -30                ; increment for segment_2 
    DC.B  50                 ; length for segment_3 
    DC.W  30                 ; increment for segment_3
SQUARE:   ;sets up data for SQUARE waveform 
    DC.B  4                 ; number of segments for SQUARE 
    DC.W  3276              ; initial DAC input value
    DC.B  9                 ; length for segment_1
    DC.W  0                 ; increment for segment_1
    DC.B  1                 ; length for segment_2
    DC.W  -3276             ; increment for segment_2
    DC.B  9                 ; length for segment_3
    DC.W  0                 ; increment for segment_3
    DC.B  1                 ; length for segment_4
    DC.W  3276              ; increment for segment_4
SAW:      ;sets up data for SAW waveform
    DC.B  2                 ; number of segments for SAWTOOTH 
    DC.W  0                 ; initial DAC input value
    DC.B  19                ; length for segment_1
    DC.W  172               ; increment for segment_1
    DC.B  1                 ; length for segment_2
    DC.W  -3268             ; increment for segment_2
SINE7:    ;sets up data for 7SINE waveform 
    DC.B  7                 ; number of segments for SINE-7 
    DC.W  2048              ; initial DAC input value 
    DC.B  25                ; length for segment_1 
    DC.W  32                ; increment for segment_1 
    DC.B  50                ; length for segment_2 
    DC.W  16                ; increment for segment_2 
    DC.B  50                ; length for segment_3 
    DC.W  -16               ; increment for segment_3 
    DC.B  50                ; length for segment_4 
    DC.W  -32               ; increment for segment_4 
    DC.B  50                ; length for segment_5 
    DC.W  -16               ; increment for segment_5 
    DC.B  50                ; length for segment_6 
    DC.W  16                ; increment for segment_6 
    DC.B  25                ; length for segment_7 
    DC.W  32                ; increment for segment_7
SINE15:   ;sets up data for 15SINE waveform 
    DC.B  15                 ; number of segments for SINE 
    DC.W  2048               ; initial DAC input value 
    DC.B  10                 ; length for segment_1 
    DC.W  41                 ; increment for segment_1 
    DC.B  21                 ; length for segment_2 
    DC.W  37                 ; increment for segment_2 
    DC.B  21                 ; length for segment_3 
    DC.W  25                 ; increment for segment_3 
    DC.B  21                 ; length for segment_4 
    DC.W  9                  ; increment for segment_4 
    DC.B  21                 ; length for segment_5 
    DC.W  -9                 ; increment for segment_5 
    DC.B  21                 ; length for segment_6 
    DC.W  -25                ; increment for segment_6 
    DC.B  21                 ; length for segment_7 
    DC.W  -37                ; increment for segment_7 
    DC.B  20                 ; length for segment_8 
    DC.W  -41                ; increment for segment_8 
    DC.B  21                 ; length for segment_9 
    DC.W  -37                ; increment for segment_9 
    DC.B  21                 ; length for segment_10 
    DC.W  -25                ; increment for segment_10 
    DC.B  21                 ; length for segment_11 
    DC.W  -9                 ; increment for segment_11 
    DC.B  21                 ; length for segment_12 
    DC.W  9                  ; increment for segment_12 
    DC.B  21                 ; length for segment_13 
    DC.W  25                 ; increment for segment_13 
    DC.B  21                 ; length for segment_14 
    DC.W  37                 ; increment for segment_14 
    DC.B  10                 ; length for segment_15 
    DC.W  41                 ; increment for segment_15 
  

;/------------------------------------------------------------------------------------\
;| Vectors                                                                            |
;\------------------------------------------------------------------------------------/
  ORG   $FFEE                      ;Timer channel 0 vector address
  DC.W  TC0ISR
  ORG   $FFFE                    ; reset vector address
  DC.W  Entry
  ORG   $FFCE                    ; Key Wakeup interrupt vector address [Port J]
  DC.W  ISR_KEYPAD
