; Star Dodger Level 7: SCANHAND integration
        CFGVAR  "name" = "Star Dodger 7 - SCANHAND"
        CFGVAR  "short_name" = "Star Dodger 7"
        CFGVAR  "description" = "Decode starship controls with SCANHAND."
        ROMW 16
        INCLUDE "../../library/gimini.asm"
SCRATCH ORG $100, $100,"-RWBN"
ISRVEC RMB 2
TSKQM EQU 7
TSKQHD RMB 1
TSKDQ RMB 16
SH_TMP RMB 1
SH_LR0 RMB 3
SH_LR1 RMB 3
SHDISP RMB 2
TSKQTL RMB 1
TSKQ RMB 8
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
ONES:   DECLE   C_BLU, C_BLU, C_BLU, C_BLU, C_BLU
TITLE: PROC
        BYTE 102,"STAR DODGER 7",0
        BEGIN
        RETURN
        ENDP
MAIN: PROC
        DIS
        MVII #STACK,R6
        ; SCANHAND uses SHDISP (a 16-bit table pointer), not SYSTEMVAR.
        MVII #HAND_DISPATCH,R0
 MVO R0,SHDISP
        ; The task queue and scanner state must start empty.
        CLRR R0
        MVO R0,TSKQHD
        MVO R0,TSKQTL
        MVO R0,SH_LR0
        MVO R0,SH_LR0+1
        MVO R0,SH_LR0+2
        MVO R0,SH_LR1
        MVO R0,SH_LR1+1
        MVO R0,SH_LR1+2
        MVII #VBLANK_ISR,R0
        MVO R0,ISRVEC
        SWAP R0
        MVO R0,ISRVEC+1
        EIS
@@loop:
 CALL SCANHAND
 CALL RUNQ
        B @@loop
        ENDP
VBLANK_ISR: PROC
        MVO R0, $20
        JR R5
        ENDP
HAND_DISPATCH: DECLE HAND_KEY,HAND_ACTION,HAND_DISC
; This level is intentionally a SCANHAND/task-queue scaffold. The handlers
; only record an event; the integrated Star Dodger uses the same boundary for
; starship controls.
HAND_KEY: PROC
 MVO R1,LAST_EVENT
 JR R5
 ENDP
HAND_ACTION: PROC
 MVO R1,LAST_EVENT
 JR R5
 ENDP
HAND_DISC: PROC
 MVO R1,LAST_EVENT
 JR R5
 ENDP
LAST_EVENT: DECLE 0
 INCLUDE "../../task/scanhand.asm"
 INCLUDE "../../task/taskq.asm"
