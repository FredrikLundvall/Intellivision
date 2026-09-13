; Standalone AS1600 checkpoint: tile-map lookup and solid collision
        CFGVAR  "name" = "Learning Game - tile-map lookup and solid collision"
        CFGVAR  "short_name" = "level09_tile_collision"
        CFGVAR  "description" = "Focused tile-map lookup and solid collision checkpoint."
        ROMW 16
        INCLUDE "../../library/gimini.asm"
SCRATCH ORG $100, $100,"-RWBN"
ISRVEC RMB 2
PLAYER_X RMB 1
PLAYER_Y RMB 1
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
        BYTE 102,"tile-map lookup and solid collision",0
        BEGIN
        RETURN
        ENDP
MAIN: PROC
        DIS
        MVII #STACK,R6
        MVII #1,R0
 MVO R0,PLAYER_X
 MVO R0,PLAYER_Y
 MVI PLAYER_X,R0
 INCR R0
 CALL TILE_AT
 BNEQ @@blocked
 MVO R0,PLAYER_X
@@blocked: NOP
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
TILE_AT: MOVR R0,R1
 ANDI #$0F,R1
 ADDI #TILE_MAP,R1
 MVI@ R1,R0
 JR R5
TILE_MAP: DECLE 0,0,0,1,1,1,0,0,0,0,1,1,0,0,0,0
