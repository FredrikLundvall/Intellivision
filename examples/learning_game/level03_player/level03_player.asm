; Star Dodger Level 3: custom GRAM starship art and one MOB.
        CFGVAR  "name" = "Star Dodger 3 - Starship"
        CFGVAR  "short_name" = "Star Dodger 3"
        CFGVAR  "description" = "Display and move the Star Dodger starship."
        ROMW    16
        INCLUDE "../../library/gimini.asm"

SCRATCH ORG     $100, $100, "-RWBN"
ISRVEC  RMB     2
INPUT   RMB     1
SYSTEM  ORG     $2F0, $2F0, "-RWBN"
STACK   RMB     32
PLAYER_X RMB    1
PLAYER_Y RMB    1
PLAYER_A RMB    1

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
        BYTE    102, "STAR DODGER 3", 0
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
        MVII    #$0200, R4
        MVII    #$00F0, R1
        MVII    #$1352, R0
        CALL    FILLMEM
        CALL    MEMCPY
        DECLE   $3800, PLAYER_GFX, 8
        MVII    #STIC.mobx_visb + STIC.mobx_intr + 76, R0
        MVO     R0, PLAYER_X
        MVII    #STIC.moby_ysize2 + 44, R0
        MVO     R0, PLAYER_Y
        MVII    #STIC.moba_gram + STIC.moba_fg2, R0
        MVO     R0, PLAYER_A
        EIS
@@loop:
        MVI     $01FF, R0
        XORI    #$00FF, R0
        ANDI    #$00FF, R0
        MVO     R0, INPUT
        TSTR    R0
        BEQ     @@loop
        MVI     PLAYER_X, R1
        ANDI    #STIC.mobx_xpos, R1
        INCR    R1
        CMPI    #$00F0, R1
        BNC     @@save_x
        MVII    #$00F0, R1
@@save_x:
        ADDI    #STIC.mobx_visb + STIC.mobx_intr, R1
        MVO     R1, PLAYER_X
        B       @@loop
        ENDP

VBLANK_ISR PROC
        MVO     R0, $0020
        MVI     PLAYER_X, R0
        MVO     R0, STIC.mob0_x
        MVI     PLAYER_Y, R0
        MVO     R0, STIC.mob0_y
        MVI     PLAYER_A, R0
        MVO     R0, STIC.mob0_a
        JR      R5
        ENDP

PLAYER_GFX:
        DECLE   %00111100, %01111110, %11111111, %11011011
        DECLE   %11111111, %01100110, %00100100, %00000000

        INCLUDE "../../library/fillmem.asm"
        INCLUDE "../../library/memcpy.asm"
