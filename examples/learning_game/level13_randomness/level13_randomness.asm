; Star Dodger Level 13: RAND use for meteor variation
        CFGVAR  "name" = "Star Dodger 13 - Random Meteors"
        CFGVAR  "short_name" = "Star Dodger 13"
        CFGVAR  "description" = "Use bounded randomness for meteor variation."
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
        BYTE 102,"STAR DODGER 13",0
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
