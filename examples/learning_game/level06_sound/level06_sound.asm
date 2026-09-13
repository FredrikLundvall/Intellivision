; Learning Game Level 6: a frame-timed PSG sound effect.
; Press any newly detected controller input to start the tone.
        CFGVAR  "name" = "Learning Game 6 - Sound"
        CFGVAR  "short_name" = "Learning 6"
        CFGVAR  "description" = "Frame-timed PSG sound effect."
        ROMW    16
        INCLUDE "../../library/gimini.asm"

SCRATCH ORG     $100, $100, "-RWBN"
ISRVEC  RMB     2
INPUT   RMB     1
INPUT_OLD RMB   1
SFX_PENDING RMB 1
SFX_TIMER RMB   1
SYSTEM  ORG     $2F0, $2F0, "-RWBN"
STACK   RMB     32

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
        BYTE    102, "Learning Game 6", 0
        BEGIN
        RETURN
        ENDP

MAIN:   PROC
        DIS
        MVII    #STACK, R6
        CLRR    R0
        MVO     R0, INPUT_OLD
        MVO     R0, SFX_PENDING
        MVO     R0, SFX_TIMER

        ; Start silent, then install the frame ISR.
        MVII    #PSG.tone_a_off + PSG.tone_b_off + PSG.tone_c_off, R0
        MVO     R0, PSG0.chan_enable
        MVO     R0, PSG0.chn_a_vol
        MVII    #VBLANK_ISR, R0
        MVO     R0, ISRVEC
        SWAP    R0
        MVO     R0, ISRVEC+1
        EIS

@@loop:
        ; Controller ports are active-low.  Detect a newly pressed input.
        MVI     $01FF, R0
        XORI    #$00FF, R0
        ANDI    #$00FF, R0
        MVO     R0, INPUT
        MOVR    R0, R1
        XOR     INPUT_OLD, R1
        ANDR    R0, R1
        BEQ     @@save_input
        MVII    #1, R1
        MVO     R1, SFX_PENDING
        MVII    #12, R1
        MVO     R1, SFX_TIMER
@@save_input:
        MVO     R0, INPUT_OLD

        ; Start pending effects in the main loop; the ISR only times them.
        MVI     SFX_PENDING, R0
        BEQ     @@loop
        CLRR    R0
        MVO     R0, SFX_PENDING
        MVII    #$40, R0
        MVO     R0, PSG0.chan_enable
        MVII    #$80, R0
        MVO     R0, PSG0.chn_a_lo
        CLRR    R0
        MVO     R0, PSG0.chn_a_hi
        MVII    #$0F, R0
        MVO     R0, PSG0.chn_a_vol
        B       @@loop
        ENDP

VBLANK_ISR PROC
        ; Keep the display enabled and use the frame as the sound clock.
        MVO     R0, $0020
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
