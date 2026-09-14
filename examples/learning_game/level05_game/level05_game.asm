; Star Dodger Level 5: starship, meteor, collision, state, and PSG effect.
        CFGVAR  "name" = "Star Dodger 5 - Play Loop"
        CFGVAR  "short_name" = "Star Dodger 5"
        CFGVAR  "description" = "A small frame-driven Star Dodger play loop."
        ROMW    16
        INCLUDE "../../library/gimini.asm"

SCRATCH ORG     $100, $100, "-RWBN"
ISRVEC  RMB     2
INPUT   RMB     1
FRAME   RMB     1
HITS    RMB     1
STATE   RMB     1
SFX     RMB     1
SYSTEM  ORG     $2F0, $2F0, "-RWBN"
STACK   RMB     32
PLAYER_X RMB    1
PLAYER_Y RMB    1
ENEMY_X  RMB    1
ENEMY_Y  RMB    1
PLAYER_A RMB    1
ENEMY_A  RMB    1

STATE_PLAY EQU 0
STATE_OVER EQU 1

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
        BYTE    102, "STAR DODGER 5", 0
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
        CALL    RESET_GAME
        EIS
@@loop:
        CALL    READ_INPUT
        MVI     STATE, R0
        TSTR    R0
        BNEQ    @@over
        CALL    UPDATE_PLAY
        CALL    UPDATE_SOUND
        B       @@loop
@@over:
        MVI     INPUT, R0
        ANDI    #$0001, R0
        BEQ     @@loop
        CALL    RESET_GAME
        B       @@loop
        ENDP

RESET_GAME PROC
        MVII    #STATE_PLAY, R0
        MVO     R0, STATE
        CLRR    R0
        MVO     R0, FRAME
        MVO     R0, HITS
        MVO     R0, SFX
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

READ_INPUT PROC
        MVI     $01FF, R0
        XORI    #$00FF, R0
        ANDI    #$00FF, R0
        MVO     R0, INPUT
        JR      R5
        ENDP

UPDATE_PLAY PROC
        MVI     INPUT, R0
        ANDI    #$000F, R0
        BEQ     @@enemy
        MVI     PLAYER_X, R1
        INCR    R1
        MVO     R1, PLAYER_X
@@enemy:
        MVI     FRAME, R0
        ANDI    #3, R0
        BNEQ    @@hit
        MVI     ENEMY_X, R1
        INCR    R1
        CMPI    #$0090, R1
        BNC     @@save
        MVII    #$0040, R1
@@save: MVO     R1, ENEMY_X
@@hit:
        MVI     HITS, R0
        BEQ     @@done
        MVII    #STATE_OVER, R0
        MVO     R0, STATE
        MVII    #1, R0
        MVO     R0, SFX
@@done:
        JR      R5
        ENDP

UPDATE_SOUND PROC
        MVI     SFX, R0
        BEQ     @@done
        CLRR    R0
        MVO     R0, SFX
        MVII    #$40, R0
        MVO     R0, PSG0.chan_enable
        MVII    #$80, R0
        MVO     R0, PSG0.chn_a_lo
        MVII    #$0F, R0
        MVO     R0, PSG0.chn_a_vol
@@done: JR      R5
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
        CLRR    R0
        MVO     R0, STIC.mob0_c
        MVI     FRAME, R0
        INCR    R0
        MVO     R0, FRAME
        JR      R5
        ENDP

PLAYER_GFX:
        DECLE   %00111100, %01111110, %11111111, %11011011
        DECLE   %11111111, %01100110, %00100100, %00000000
        INCLUDE "../../library/memcpy.asm"
