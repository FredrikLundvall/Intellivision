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
DISPLAY_INIT RMB    1

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
        CLRR    R0
        MVO     R0, DISPLAY_INIT

        MVII    #DRAW, R0
        MVO     R0, ISRVEC
        SWAP    R0
        MVO     R0, ISRVEC+1

        EIS
@@wait:
        ; Left controller Enter is keypad code $0B, encoded as $48 after
        ; inverting the active-low controller port.
        MVI     $1FE, R0
        XORI    #$00FF, R0
        ANDI    #$00FF, R0
        CMPI    #$0048, R0
        BNEQ    @@wait
        CLRR    R0
        MVO     R0, PIXEL_ON
        B       @@wait
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

        ; Keep the color stack black on every frame.  The EXEC title screen
        ; can leave its color-stack values in the STIC.
        CLRR    R0
        MVO     R0, STIC.cs0
        MVO     R0, STIC.cs1
        MVO     R0, STIC.cs2
        MVO     R0, STIC.cs3
        MVI     DISPLAY_INIT, R0
        BNEQ    @@display

        ; GRAM and MOB registers are accessible here during vertical blank.
        CALL    MEMCPY
        DECLE   $3800, PIXEL, 8

        ; MOB 0: visible, normal size, GRAM card 0, white foreground.
        MVII    #STIC.mobx_visb + 80, R0
        MVO     R0, STIC.mob0_x
        MVII    #STIC.moby_ysize2 + 48, R0
        MVO     R0, STIC.mob0_y
        MVII    #STIC.moba_gram + STIC.moba_fg7, R0
        MVO     R0, STIC.mob0_a
        MVII    #1, R0
        MVO     R0, DISPLAY_INIT

@@display:
        ; Update visibility without touching GRAM again.
        MVI     PIXEL_ON, R0
        BEQ     @@hidden
        MVII    #STIC.mobx_visb + 80, R0
        B       @@visibility_done
@@hidden:
        MVII    #80, R0
@@visibility_done:
        MVO     R0, STIC.mob0_x

        ; Color-stack mode and display enabled.  Turn the border green after
        ; the main loop detects left-controller Enter.
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

; Full card used during bring-up so the MOB is unmistakable.
PIXEL:  DECLE   $FFFF, $FFFF, $FFFF, $FFFF
        DECLE   $FFFF, $FFFF, $FFFF, $FFFF

        INCLUDE "../library/memcpy.asm"
