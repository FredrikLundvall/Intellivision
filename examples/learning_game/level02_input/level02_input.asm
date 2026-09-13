; Star Dodger Level 2: background, VBLANK, and raw active-low input.
        CFGVAR  "name" = "Star Dodger 2 - Input"
        CFGVAR  "short_name" = "Star Dodger 2"
        CFGVAR  "description" = "Move the starship marker with raw controller input."
        ROMW    16
        INCLUDE "../../library/gimini.asm"

SCRATCH ORG     $100, $100, "-RWBN"
ISRVEC  RMB     2
INPUT   RMB     1
SYSTEM  ORG     $2F0, $2F0, "-RWBN"
STACK   RMB     32
PLAYER  RMB     1

        ORG     $5000
ROMHDR: BIDECLE ZERO
        BIDECLE ZERO
        BIDECLE MAIN
        BIDECLE ZERO
        BIDECLE ONES
        BIDECLE TITLE
        DECLE   $03C0
ZERO:   DECLE   0, 0
        DECLE   C_BLU, C_BLU, C_BLU, C_BLU, C_BLU
ONES:   DECLE   1

TITLE:  PROC
        BYTE    102, "STAR DODGER 2", 0
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
        MVII    #$0200 + 5*20 + 9, R0
        MVO     R0, PLAYER
        EIS
@@loop:
        MVI     $01FF, R0
        XORI    #$00FF, R0
        ANDI    #$00FF, R0
        MVO     R0, INPUT
        ; Any pressed input advances the starship marker so polarity is easy to test.
        TSTR    R0
        BEQ     @@loop
        MVI     PLAYER, R1
        INCR    R1
        CMPI    #$02EF, R1
        BNC     @@save
        MVII    #$0200, R1
@@save:
        MVO     R1, PLAYER
        MVII    #$0200, R4
        MVII    #$00F0, R1
        MVII    #$1352, R0
        CALL    FILLMEM
        MVI     PLAYER, R4
        MVII    #$0007, R0
        MVO@    R0, R4
        B       @@loop
        ENDP

VBLANK_ISR PROC
        MVO     R0, $0020
        JR      R5
        ENDP

        INCLUDE "../../library/fillmem.asm"
