; Standalone AS1600 checkpoint: title play pause game-over state flow
        CFGVAR  "name" = "Learning Game - title play pause game-over state flow"
        CFGVAR  "short_name" = "level12_state_flow"
        CFGVAR  "description" = "Focused title play pause game-over state flow checkpoint."
        ROMW 16
        INCLUDE "../../library/gimini.asm"
SCRATCH ORG $100, $100,"-RWBN"
ISRVEC RMB 2
GAME_STATE RMB 1
STATE_TIMER RMB 1
SYSTEM ORG $2F0, $2F0,"-RWBN"
STACK RMB 32
        ORG $5000
ROMHDR: BIDECLE ZERO
        BIDECLE ZERO
        BIDECLE MAIN
        BIDECLE ZERO
        BIDECLE ONES
        BIDECLE TITLE
        DECLE $03C0
ZERO: DECLE 0,0
        DECLE C_BLU,C_BLU,C_BLU,C_BLU,C_BLU
ONES: DECLE 1
TITLE: PROC
        BYTE 102,"title play pause game-over state flow",0
        BEGIN
        RETURN
        ENDP
MAIN: PROC
        DIS
        MVII #STACK,R6
        MVII #STATE_TITLE,R0
 MVO R0,GAME_STATE
@@states: MVI GAME_STATE,R0
 INCR R0
 CMPI #STATE_GAMEOVER,R0
 BNC @@reset
 MVO R0,GAME_STATE
 B @@states
@@reset: MVII #STATE_TITLE,R0
 MVO R0,GAME_STATE
 B @@states
        MVII #VBLANK_ISR,R0
        MVO R0,ISRVEC
        SWAP R0
        MVO R0,ISRVEC+1
        EIS
@@loop:
        B @@loop
        ENDP
VBLANK_ISR: PROC
        MVO R0, $20
        JR R5
        ENDP
STATE_TITLE EQU 0
STATE_PLAY EQU 1
STATE_PAUSE EQU 2
STATE_GAMEOVER EQU 3

