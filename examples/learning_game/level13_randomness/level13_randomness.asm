; Standalone AS1600 checkpoint: RAND use
        CFGVAR  "name" = "Learning Game - RAND use"
        CFGVAR  "short_name" = "level13_randomness"
        CFGVAR  "description" = "Focused RAND use checkpoint."
        ROMW 16
        INCLUDE "../../library/gimini.asm"
SCRATCH ORG $100, $100,"-RWBN"
ISRVEC RMB 2
SEED RMB 1
RANDOM_VALUE RMB 1
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
        BYTE 102,"RAND use",0
        BEGIN
        RETURN
        ENDP
MAIN: PROC
        DIS
        MVII #STACK,R6
        MVII #$1234,R0
 MVO R0,SEED
@@rnd: CALL RAND
 MVO R0,RANDOM_VALUE
 B @@rnd
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
RAND: MVI SEED,R0
 RLC R0
 XORI #$002D,R0
 MVO R0,SEED
 JR R5
