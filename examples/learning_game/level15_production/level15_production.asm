; Standalone AS1600 checkpoint: VBLANK budget and production layout
        CFGVAR  "name" = "Learning Game - VBLANK budget and production layout"
        CFGVAR  "short_name" = "level15_production"
        CFGVAR  "description" = "Focused VBLANK budget and production layout checkpoint."
        ROMW 16
        INCLUDE "../../library/gimini.asm"
SCRATCH ORG $100, $100,"-RWBN"
ISRVEC RMB 2
FRAME RMB 1
VBLANK_BUDGET RMB 1
WORK_CURSOR RMB 1
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
        BYTE 102,"VBLANK budget and production layout",0
        BEGIN
        RETURN
        ENDP
MAIN: PROC
        DIS
        MVII #STACK,R6
        MVII #8,R0
 MVO R0,VBLANK_BUDGET
 CLRR R0
 MVO R0,WORK_CURSOR
@@work: MVI VBLANK_BUDGET,R0
 BEQ @@wait
 DECR R0
 MVO R0,VBLANK_BUDGET
 MVI WORK_CURSOR,R0
 INCR R0
 MVO R0,WORK_CURSOR
 B @@work
@@wait: B @@wait
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
; Honest production layout: bounded work per VBLANK, then wait.
WORK_END_DATA: DECLE 0,0,0,0,0,0,0,0
