; Standalone AS1600 checkpoint: HUD text and score
        CFGVAR  "name" = "Learning Game - HUD text and score"
        CFGVAR  "short_name" = "level11_hud_text"
        CFGVAR  "description" = "Focused HUD text and score checkpoint."
        ROMW 16
        INCLUDE "../../library/gimini.asm"
SCRATCH ORG $100, $100,"-RWBN"
ISRVEC RMB 2
SCORE RMB 1
HUD_PTR RMB 1
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
        BYTE 102,"HUD text and score",0
        BEGIN
        RETURN
        ENDP
MAIN: PROC
        DIS
        MVII #STACK,R6
        CLRR R0
 MVO R0,SCORE
 MVII #HUD_TEXT,R0
 MVO R0,HUD_PTR
@@score: MVI SCORE,R0
 INCR R0
 MVO R0,SCORE
 ANDI #15,R0
 ADDI #$0200,R0
 MVO R0,$0200
 B @@score
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
HUD_TEXT: DECLE $0018,$0015,$0014,$0000,$0013,$0003,$000F,$0012,$0005
; HUD text is intentionally explicit BACKTAB character data.
