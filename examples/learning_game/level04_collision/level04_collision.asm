; Star Dodger Level 4: two MOBs, frame timing, and meteor interaction.
        CFGVAR  "name" = "Star Dodger 4 - Meteor Collision"
        CFGVAR  "short_name" = "Star Dodger 4"
        CFGVAR  "description" = "Move a starship toward a patrolling meteor."
        ROMW    16
        INCLUDE "../../library/gimini.asm"

SCRATCH ORG     $100, $100, "-RWBN"
ISRVEC  RMB     2
INPUT   RMB     1
FRAME   RMB     1
HITS    RMB     1
SYSTEM  ORG     $2F0, $2F0, "-RWBN"
STACK   RMB     32
PLAYER_X RMB    1
PLAYER_Y RMB    1
ENEMY_X  RMB    1
ENEMY_Y  RMB    1
PLAYER_A RMB   1
ENEMY_A  RMB     1

        ORG     $5000
ROMHDR: BIDECLE ZERO
        BIDECLE ZERO
        BIDECLE MAIN
        BIDECLE ZERO
        BIDECLE ONES
        BIDECLE TITLE
        DECLE   $03C0
ZERO:   DECLE   0, 0
ONES:   DECLE   C_BLU, C_BLU, C_BLU, C_BLU, C_BLU
TITLE:  PROC
        BYTE    102, "STAR DODGER 4", 0
        BEGIN
        RETURN
        ENDP

MAIN:   PROC
        DIS
        MVII    #STACK, R6
        MVII    #VBLANK_ISR, R0
        MVO     R0, ISRVEC
        SWAP    R0
        MVO     R0, ISRVEC+1
        CALL    INIT
        EIS
@@loop:
        MVI     $01FF, R0
        XORI    #$00FF, R0
        ANDI    #$00FF, R0
        MVO     R0, INPUT
        MVI     INPUT, R0
        TSTR    R0
        BEQ     @@enemy
        MVI     PLAYER_X, R1
        INCR    R1
        MVO     R1, PLAYER_X
@@enemy:
        MVI     FRAME, R0
        ANDI    #3, R0
        BNEQ    @@check
        MVI     ENEMY_X, R1
        INCR    R1
        CMPI    #$0090, R1
        BNC     @@enemy_save
        MVII    #$0040, R1
@@enemy_save:
        MVO     R1, ENEMY_X
@@check:
        MVI     HITS, R0
        BEQ     @@loop
        CLRR    R0
        MVO     R0, HITS
        B       @@loop
        ENDP

INIT:   PROC
        MVII    #$0200, R4
        MVII    #$00F0, R1
        MVII    #$1352, R0
        CALL    FILLMEM
        CALL    MEMCPY
        DECLE   $3800, PLAYER_GFX, 8
        MVII    #STIC.mobx_visb + STIC.mobx_intr + 60, R0
        MVO     R0, PLAYER_X
        MVII    #STIC.mobx_visb + STIC.mobx_intr + 110, R0
        MVO     R0, ENEMY_X
        MVII    #STIC.moby_ysize2 + 50, R0
        MVO     R0, PLAYER_Y
        MVO     R0, ENEMY_Y
        MVII    #STIC.moba_gram + STIC.moba_fg2, R0
        MVO     R0, PLAYER_A
        MVII    #STIC.moba_gram + STIC.moba_fg1, R0
        MVO     R0, ENEMY_A
        JR      R5
        ENDP

VBLANK_ISR PROC
        MVO     R0, $0020
        MVI     PLAYER_X, R0
        MVO     R0, STIC.mob0_x
        MVI     ENEMY_X, R0
        MVO     R0, STIC.mob1_x
        MVI     PLAYER_Y, R0
        MVO     R0, STIC.mob0_y
        MVI     ENEMY_Y, R0
        MVO     R0, STIC.mob1_y
        MVI     PLAYER_A, R0
        MVO     R0, STIC.mob0_a
        MVI     ENEMY_A, R0
        MVO     R0, STIC.mob1_a
        MVI     STIC.mob0_c, R0
        MVO     R0, HITS
        MVI     FRAME, R0
        INCR    R0
        MVO     R0, FRAME
        JR      R5
        ENDP

PLAYER_GFX:
        DECLE   %00111100, %01111110, %11111111, %11011011
        DECLE   %11111111, %01100110, %00100100, %00000000
        INCLUDE "../../library/fillmem.asm"
        INCLUDE "../../library/memcpy.asm"
