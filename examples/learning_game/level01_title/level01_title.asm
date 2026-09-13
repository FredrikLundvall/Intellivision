; Star Dodger Level 1: EXEC startup, title, and text.
        CFGVAR  "name" = "Star Dodger 1 - Title"
        CFGVAR  "short_name" = "Star Dodger 1"
        CFGVAR  "description" = "Star Dodger title-card and text foundation."
        ROMW    16
        INCLUDE "../../library/gimini.asm"
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
        BYTE    102, "STAR DODGER", 0
        BEGIN
        RETURN
        ENDP

MAIN:   PROC
        BEGIN
        CALL    CLRSCR
        CALL    PRINT.FLS
        DECLE   C_YEL, $200 + 5*20 + 3
        STRING  "DODGE THE METEORS", 0
        RETURN
        ENDP

        INCLUDE "../../library/print.asm"
        INCLUDE "../../library/fillmem.asm"
