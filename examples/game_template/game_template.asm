; ============================================================================
;  Intellivision game template
;
;  This is a small, working framework for new AS1600 games.  Replace the
;  example game state and graphics, but keep the startup, ISR, and memory
;  organization patterns unless the game has a specific reason not to.
;
;  Build from this directory:
;      as1600 -o game_template.bin -l game_template.lst game_template.asm
;      as1600 -o game_template.rom -l game_template.lst game_template.asm
; ============================================================================

        CFGVAR  "name" = "SDK-1600 Game Template"
        CFGVAR  "short_name" = "Game Template"
        CFGVAR  "author" = "SDK-1600"
        CFGVAR  "description" = "Framework skeleton for an Intellivision game."
        CFGVAR  "publisher" = "SDK-1600"

        ROMW    16
        INCLUDE "../library/gimini.asm"

; -----------------------------------------------------------------------------
; Scratch RAM: 8-bit values and the EXEC interrupt vector.
; -----------------------------------------------------------------------------
SCRATCHRAM  ORG     $100, $100, "-RWBN"
ISRVEC      RMB     2               ; EXEC VBLANK vector ($100/$101)
INPUT       RMB     1               ; Inverted left-controller input
INPUT_OLD   RMB     1               ; Previous input, for edge detection
FRAME       RMB     1               ; Incremented once per video frame
SFX         RMB     1               ; Non-zero while the example sound plays
_EOSCRATCH  EQU     $

; -----------------------------------------------------------------------------
; System RAM: stack, game state, and a 24-word MOB shadow.
; -----------------------------------------------------------------------------
SYSTEMRAM   ORG     $2F0, $2F0, "-RWBN"
STACK       RMB     32
PLAYER_X    RMB     1               ; MOB 0 X register shadow
PLAYER_Y    RMB     1               ; MOB 0 Y register shadow
PLAYER_A    RMB     1               ; MOB 0 attribute register shadow
PLAYER_C    RMB     1               ; MOB 0 collision register shadow
MOB_SHADOW  RMB     24              ; X[8], Y[8], A[8], C[8]
_EOSYSTEM   EQU     $

; -----------------------------------------------------------------------------
; Cartridge header and title.
; -----------------------------------------------------------------------------
        ORG     $5000

ROMHDR: BIDECLE ZERO                ; MOB picture list
        BIDECLE ZERO                ; EXEC process list
        BIDECLE MAIN                ; game entry point
        BIDECLE ZERO                ; background picture list
        BIDECLE ONES                ; GRAM picture list
        BIDECLE TITLE               ; title/date string
        DECLE   $03C0               ; run code after title

ZERO:   DECLE   $0000               ; border control
        DECLE   $0000               ; color-stack mode
ONES:   DECLE   C_BLU, C_BLU        ; color stack 0/1
        DECLE   C_BLU, C_BLU        ; color stack 2/3
        DECLE   C_BLU                ; border

TITLE:  PROC
        BYTE    102, "Game Template", 0
        BEGIN
        CALL    PRINT.FLS
        DECLE   C_WHT, $23D
        STRING  "=SDK-1600="
        BYTE    0
        CALL    PRINT.FLS
        DECLE   C_WHT, $2D0
        STRING  "Game Template"
        BYTE    0
        RETURN
        ENDP

; -----------------------------------------------------------------------------
; MAIN: one-time initialization followed by the game loop.
; -----------------------------------------------------------------------------
MAIN:   PROC
        DIS
        MVII    #STACK, R6

        CLRR    R0
        MVO     R0, FRAME
        MVO     R0, SFX
        MVO     R0, INPUT_OLD

        ; Install the ISR used by the EXEC interrupt dispatcher.
        MVII    #VBLANK_ISR, R0
        MVO     R0, ISRVEC
        SWAP    R0
        MVO     R0, ISRVEC+1

        CALL    INIT_GAME
        EIS

; Main-loop responsibilities: input, rules, timers, and sound requests.
@@loop:
        CALL    READ_INPUT
        CALL    UPDATE_GAME
        CALL    UPDATE_SOUND
        B       @@loop
        ENDP

; -----------------------------------------------------------------------------
; INIT_GAME: initialize background, GRAM, MOB shadow state, and PSG.
; -----------------------------------------------------------------------------
INIT_GAME PROC
        CALL    INIT_BACKGROUND

        ; GRAM is safe to write while display is disabled during startup.
        CALL    MEMCPY
        DECLE   $3800, PLAYER_GFX, 8

        ; Initialize one visible player MOB at the screen center.
        MVII    #STIC.mobx_visb + 76, R0
        MVO     R0, PLAYER_X
        MVII    #STIC.moby_ysize2 + 44, R0
        MVO     R0, PLAYER_Y
        MVII    #STIC.moba_gram + STIC.moba_fg2, R0
        MVO     R0, PLAYER_A
        CLRR    R0
        MVO     R0, PLAYER_C

        ; Silence all PSG channels.  Sound effects are enabled by UPDATE_SOUND.
        MVII    #PSG.tone_a_off + PSG.tone_b_off + PSG.tone_c_off, R0
        MVO     R0, PSG0.chan_enable
        CLRR    R0
        MVO     R0, PSG0.chn_a_lo
        MVO     R0, PSG0.chn_a_hi
        MVO     R0, PSG0.chn_a_vol
        JR      R5
        ENDP

; -----------------------------------------------------------------------------
; INIT_BACKGROUND: fill BACKTAB with blue colored-square test tiles.
; Replace this with a map loader or card layout for a real game.
; -----------------------------------------------------------------------------
INIT_BACKGROUND PROC
        MVII    #$0200, R4
        MVII    #$00F0, R1
        MVII    #$1249, R0          ; four blue colored squares
        CALL    FILLMEM
        JR      R5
        ENDP

; -----------------------------------------------------------------------------
; READ_INPUT: active-low left controller, with simple press edge detection.
; The low byte uses the standard controller bit layout.  Bit 0 is disc down;
; keypad/action decoding can be added here or replaced with SCANHAND.
; -----------------------------------------------------------------------------
READ_INPUT PROC
        MVI     $1FE, R0            ; left master controller
        XORI    #$00FF, R0          ; pressed inputs become 1 bits
        ANDI    #$00FF, R0
        MVO     R0, INPUT

        ; Example: any newly pressed input requests a short sound effect.
        MOVR    R0, R1
        XOR     INPUT_OLD, R1
        ANDR    R0, R1
        BEQ     @@save
        MVII    #1, R1
        MVO     R1, SFX
@@save:
        MVO     R0, INPUT_OLD
        JR      R5
        ENDP

; -----------------------------------------------------------------------------
; UPDATE_GAME: example rules update.  The disc moves the player one pixel.
; Keep expensive game logic here, not in VBLANK_ISR.
; -----------------------------------------------------------------------------
UPDATE_GAME PROC
        MVI     INPUT, R0
        ANDI    #$000F, R0
        BEQ     @@done

        MVI     PLAYER_X, R1
        ADDI    #1, R1
        MVO     R1, PLAYER_X
@@done:
        JR      R5
        ENDP

; -----------------------------------------------------------------------------
; UPDATE_SOUND: simple one-shot PSG effect.  Replace with a music/SFX driver.
; -----------------------------------------------------------------------------
UPDATE_SOUND PROC
        MVI     SFX, R0
        BEQ     @@done
        CLRR    R0
        MVO     R0, SFX

        MVII    #$40, R0            ; enable channel A tone
        MVO     R0, PSG0.chan_enable
        MVII    #$80, R0            ; example tone period
        MVO     R0, PSG0.chn_a_lo
        CLRR    R0
        MVO     R0, PSG0.chn_a_hi
        MVII    #$0F, R0            ; volume
        MVO     R0, PSG0.chn_a_vol
@@done:
        JR      R5
        ENDP

; -----------------------------------------------------------------------------
; VBLANK_ISR: runs once per frame.  Only touch STIC/GRAM during VBLANK.
; The EXEC dispatcher saves registers and returns after JR R5/PULR PC style
; handlers.  This handler uses a normal subroutine return.
; -----------------------------------------------------------------------------
VBLANK_ISR PROC
        PSHR    R5

        ; Display-enable handshake is required every frame.
        MVI     STIC.mode, R0
        MVO     R0, STIC.viden

        ; Set the background and border colors for this frame.
        MVII    #C_BLU, R0
        MVO     R0, STIC.cs0
        MVO     R0, STIC.cs1
        MVO     R0, STIC.cs2
        MVO     R0, STIC.cs3
        MVO     R0, STIC.bord

        ; Commit the player MOB shadow to the STIC.
        MVI     PLAYER_X, R0
        MVO     R0, STIC.mob0_x
        MVI     PLAYER_Y, R0
        MVO     R0, STIC.mob0_y
        MVI     PLAYER_A, R0
        MVO     R0, STIC.mob0_a
        MVI     PLAYER_C, R0
        MVO     R0, STIC.mob0_c

        ; Clear sticky MOB collisions after the game has consumed them.
        CLRR    R0
        MVO     R0, STIC.mob0_c

        MVI     FRAME, R0
        INCR    R0
        MVO     R0, FRAME
        PULR    PC
        ENDP

; -----------------------------------------------------------------------------
; Example graphics: a simple 8x8 player sprite.  Bit 7 is the left pixel.
; -----------------------------------------------------------------------------
PLAYER_GFX:
        DECLE   %00111100
        DECLE   %01111110
        DECLE   %11111111
        DECLE   %11011011
        DECLE   %11111111
        DECLE   %01100110
        DECLE   %00100100
        DECLE   %00000000

; -----------------------------------------------------------------------------
; Library routines.  Add or remove includes as the game grows.
; -----------------------------------------------------------------------------
        INCLUDE "../library/fillmem.asm"
        INCLUDE "../library/memcpy.asm"
        INCLUDE "../library/print.asm"
