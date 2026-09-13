; Star Dodger integrated skeleton.
; This is deliberately a small, honest composition of levels 1-15:
; title/play/pause/game-over states, a starship and meteor, score/lives,
; direct input, GRAM cards, collision sampling, and frame-timed PSG sound.
        CFGVAR  "name" = "Star Dodger - integrated skeleton"
        CFGVAR  "short_name" = "Star Dodger"
        CFGVAR  "description" = "Integrated teaching skeleton for the Star Dodger course."
        ROMW    16
        INCLUDE "../../library/gimini.asm"

SCRATCH ORG     $100, $100, "-RWBN"
ISRVEC  RMB     2
INPUT   RMB     1
INPUT_OLD RMB  1
PRESSED RMB    1
FRAME   RMB     1
HITS    RMB     1
STATE   RMB     1
SCORE   RMB     1
LIVES   RMB     1
SFX_TIMER RMB   1
SYSTEM  ORG     $2F0, $2F0, "-RWBN"
STACK   RMB     32
STARSHIP_X RMB  1
STARSHIP_Y RMB  1
METEOR_X   RMB  1
METEOR_Y   RMB  1
METEOR_FRAME RMB 1
STARSHIP_A RMB  1
METEOR_A   RMB  1

STATE_TITLE EQU 0
STATE_PLAY  EQU 1
STATE_PAUSE EQU 2
STATE_OVER  EQU 3
INPUT_START EQU $0001
INPUT_PAUSE EQU $0002

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
        DIS
        MVII    #STACK, R6
        MVII    #VBLANK_ISR, R0
        MVO     R0, ISRVEC
        SWAP    R0
        MVO     R0, ISRVEC+1
        CALL    MEMCPY
        DECLE   $3800, STARSHIP_GFX, 8
        CALL    MEMCPY
        DECLE   $3808, METEOR_GFX, 8
        CALL    RESET_GAME
        MVII    #STATE_TITLE, R0
        MVO     R0, STATE
        EIS
@@loop:
        CALL    READ_INPUT
        MVI     STATE, R0
        CMPI    #STATE_TITLE, R0
        BEQ     @@title
        CMPI    #STATE_PLAY, R0
        BEQ     @@play
        CMPI    #STATE_PAUSE, R0
        BEQ     @@pause
        B       @@over
@@title:
        MVI     PRESSED, R0
        ANDI    #INPUT_START, R0
        BEQ     @@loop
        CALL    RESET_GAME
        MVII    #STATE_PLAY, R0
        MVO     R0, STATE
        B       @@loop
@@play:
        MVI     PRESSED, R0
        ANDI    #INPUT_PAUSE, R0
        BNEQ    @@set_pause
        MVI     INPUT, R0
        TSTR    R0
        BEQ     @@check_hit
        MVI     STARSHIP_X, R1
        INCR    R1
        MVO     R1, STARSHIP_X
@@check_hit:
        MVI     FRAME, R0
        MVI     METEOR_FRAME, R1
        XOR     FRAME, R1
        BEQ     @@check_hit_now
        MVI     FRAME, R0
        MVO     R0, METEOR_FRAME
        ANDI    #$0003, R0
        BNEQ    @@check_hit_now
        MVI     METEOR_X, R1
        DECR    R1
        CMPI    #$0040, R1
        BNC     @@save_meteor
        MVII    #$0090, R1
@@save_meteor:
        MVO     R1, METEOR_X
@@check_hit_now:
        MVI     HITS, R0
        BEQ     @@loop
        CLRR    R0
        MVO     R0, HITS
        MVI     LIVES, R0
        DECR    R0
        MVO     R0, LIVES
        MVII    #$0090, R0
        MVO     R0, METEOR_X
        MVII    #1, R0
        MVO     R0, SFX_TIMER
        MVII    #$40, R0
        MVO     R0, PSG0.chan_enable
        MVII    #$80, R0
        MVO     R0, PSG0.chn_a_lo
        CLRR    R0
        MVO     R0, PSG0.chn_a_hi
        MVII    #$0F, R0
        MVO     R0, PSG0.chn_a_vol
        MVI     SCORE, R0
        INCR    R0
        MVO     R0, SCORE
        MVI     LIVES, R0
        BNEQ    @@loop
        MVII    #STATE_OVER, R0
        MVO     R0, STATE
        B       @@loop
@@set_pause:
        MVII    #STATE_PAUSE, R0
        MVO     R0, STATE
        B       @@loop
@@pause:
        MVI     PRESSED, R0
        ANDI    #INPUT_PAUSE, R0
        BEQ     @@loop
        MVII    #STATE_PLAY, R0
        MVO     R0, STATE
        B       @@loop
@@over:
        MVI     PRESSED, R0
        ANDI    #INPUT_START, R0
        BEQ     @@loop
        CALL    RESET_GAME
        MVII    #STATE_PLAY, R0
        MVO     R0, STATE
        B       @@loop
        ENDP

READ_INPUT: PROC
        MVI     $01FF, R0
        XORI    #$00FF, R0
        ANDI    #$00FF, R0
        MVO     R0, INPUT
        MVI     INPUT_OLD, R1
        XOR     INPUT, R1
        AND     INPUT, R1
        MVO     R1, PRESSED
        MVI     INPUT, R1
        MVO     R1, INPUT_OLD
        JR      R5
        ENDP

RESET_GAME: PROC
        MVII    #3, R0
        MVO     R0, LIVES
        CLRR    R0
        MVO     R0, SCORE
        MVO     R0, INPUT_OLD
        MVO     R0, PRESSED
        MVO     R0, FRAME
        MVO     R0, HITS
        MVO     R0, METEOR_FRAME
        MVO     R0, SFX_TIMER
        MVII    #PSG.tone_a_off, R0
        MVO     R0, PSG0.chan_enable
        CLRR    R0
        MVO     R0, PSG0.chn_a_vol
        MVII    #STIC.mobx_visb + STIC.mobx_intr + 56, R0
        MVO     R0, STARSHIP_X
        MVII    #STIC.mobx_visb + STIC.mobx_intr + 116, R0
        MVO     R0, METEOR_X
        MVII    #STIC.moby_ysize2 + 52, R0
        MVO     R0, STARSHIP_Y
        MVO     R0, METEOR_Y
        MVII    #STIC.moba_gram + STIC.moba_fg2, R0
        MVO     R0, STARSHIP_A
        MVII    #STIC.moba_gram + STIC.moba_fg1 + 8, R0
        MVO     R0, METEOR_A
        JR      R5
        ENDP

VBLANK_ISR: PROC
        MVO     R0, $0020
        MVI     STARSHIP_X, R0
        MVO     R0, STIC.mob0_x
        MVI     METEOR_X, R0
        MVO     R0, STIC.mob1_x
        MVI     STARSHIP_Y, R0
        MVO     R0, STIC.mob0_y
        MVI     METEOR_Y, R0
        MVO     R0, STIC.mob1_y
        MVI     STARSHIP_A, R0
        MVO     R0, STIC.mob0_a
        MVI     METEOR_A, R0
        MVO     R0, STIC.mob1_a
        MVI     STIC.mob0_c, R0
        MVO     R0, HITS
        MVI     FRAME, R0
        INCR    R0
        MVO     R0, FRAME
        MVI     SFX_TIMER, R0
        BEQ     @@done
        DECR    R0
        MVO     R0, SFX_TIMER
        BNEQ    @@done
        MVII    #PSG.tone_a_off, R0
        MVO     R0, PSG0.chan_enable
        CLRR    R0
        MVO     R0, PSG0.chn_a_vol
@@done:
        JR      R5
        ENDP

STARSHIP_GFX:
        DECLE   %00111100, %01111110, %11111111, %11011011
        DECLE   %11111111, %01100110, %00100100, %00000000
METEOR_GFX:
        DECLE   %00111100, %01111110, %11111111, %11111111
        DECLE   %11111111, %11111111, %01111110, %00111100

        INCLUDE "../../library/memcpy.asm"
