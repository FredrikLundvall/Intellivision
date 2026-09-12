; ============================================================================
;  Single red pixel
;
;  Build as a ROM:
;      as1600 -o red_pixel.rom -l red_pixel.lst red_pixel.asm
;
;  Build as BIN+CFG:
;      as1600 -o red_pixel.bin -l red_pixel.lst red_pixel.asm
; ============================================================================

        CFGVAR  "name" = "SDK-1600 Single Red Pixel"
        CFGVAR  "short_name" = "Red Pixel"
        CFGVAR  "author" = "SDK-1600 example"
        CFGVAR  "description" = "Displays one red pixel at the center of the screen."
        CFGVAR  "publisher" = "SDK-1600"

        ROMW    16
        INCLUDE "../library/gimini.asm"

; The EXEC uses this vector to call our routine during vertical blank.
SCRATCHRAM  ORG     $100, $100, "-RWBN"
ISRVEC      RMB     2

SYSTEMRAM   ORG     $2F0, $2F0, "-RWBN"
STACK       RMB     32
PIXEL_ON    RMB     1
LEFT_INIT   RMB     1
RIGHT_INIT  RMB     1

        ORG     $5000

; -----------------------------------------------------------------------------
; EXEC-friendly ROM header.
; -----------------------------------------------------------------------------
ROMHDR: BIDECLE ZERO
        BIDECLE ZERO
        BIDECLE MAIN
        BIDECLE ZERO
        BIDECLE ONES
        BIDECLE TITLE
        DECLE   $03C0

ZERO:   DECLE   $0000           ; black border
        DECLE   $0000           ; color-stack mode
ONES:   DECLE   C_BLK, C_BLK
        DECLE   C_BLK, C_BLK
        DECLE   C_BLK

TITLE:  BYTE    102, "Single Red Pixel", 0

; -----------------------------------------------------------------------------
; MAIN -- Install the ISR and wait.  STIC and GRAM are touched only by ISR.
; -----------------------------------------------------------------------------
MAIN:   PROC
        DIS
        MVII    #STACK, R6
        MVII    #1, R0
        MVO     R0, PIXEL_ON
        MVI     $1FE, R0
        MVO     R0, LEFT_INIT
        MVI     $1FF, R0
        MVO     R0, RIGHT_INIT

        MVII    #DRAW, R0
        MVO     R0, ISRVEC
        SWAP    R0
        MVO     R0, ISRVEC+1

        EIS
@@wait: DECR    PC
        ENDP

; -----------------------------------------------------------------------------
; DRAW -- Runs during vertical blank and initializes the display.
;
; The visible display is 159x96 pixels.  The object field begins eight pixels
; above and to the left of it, so x=84, y=52 and the fourth bitmap pixel place
; the set bit at the center (approximately x=88, y=56).
; -----------------------------------------------------------------------------
DRAW:   PROC
        PSHR    R5

        ; Keep the border and color stack black on every frame.  The EXEC
        ; title screen can leave its green border values in the STIC.
        CLRR    R0
        MVO     R0, STIC.cs0
        MVO     R0, STIC.cs1
        MVO     R0, STIC.cs2
        MVO     R0, STIC.cs3
        MVO     R0, STIC.bord

        ; Any change on either controller removes the pixel.  Compare against
        ; the startup readings so the controller's idle encoding is harmless.
        MVI     $1FE, R0
        XOR     LEFT_INIT, R0
        BNEQ    @@remove
        MVI     $1FF, R0
        XOR     RIGHT_INIT, R0
        BNEQ    @@remove
        BEQ     @@button_done
@@remove:
        CLRR    R0
        MVO     R0, PIXEL_ON
@@button_done:

        ; Hide all MOBs and clear their collision state.
        CLRR    R0
        MVII    #$0000, R4
        MVII    #32, R1
@@clear:
        MVO@    R0, R4
        DECR    R1
        BNEQ    @@clear

        ; Copy the one-bit bitmap into GRAM card 0.
        CALL    MEMCPY
        DECLE   $3800, PIXEL, 8

        ; MOB 0: visible, normal size, GRAM card 0, red foreground.
        MVI     PIXEL_ON, R0
        BEQ     @@display
        MVII    #STIC.mobx_visb + 84, R0
        MVO     R0, STIC.mob0_x
        MVII    #STIC.moby_ysize2 + 52, R0
        MVO     R0, STIC.mob0_y
        MVII    #STIC.moba_gram + STIC.moba_fg7, R0
        MVO     R0, STIC.mob0_a

@@display:
        ; Color-stack mode and display enabled.  Turn the border green after
        ; the controller removes the test pixel.
        MVI     PIXEL_ON, R0
        BNEQ    @@black_border
        MVII    #C_GRN, R0
        B       @@set_border
@@black_border:
        CLRR    R0
@@set_border:
        MVO     R0, STIC.bord
        MVI     STIC.mode, R0
        MVO     R0, STIC.viden

        PULR    PC
        ENDP

; The set bit is row 3, column 3 of the 8x8 MOB bitmap.
PIXEL:  DECLE   $0000
        DECLE   $0000
        DECLE   $0000
        DECLE   %00001000
        DECLE   $0000
        DECLE   $0000
        DECLE   $0000
        DECLE   $0000

        INCLUDE "../library/memcpy.asm"
