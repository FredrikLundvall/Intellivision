; Standalone AS1600 checkpoint: two-note PSG music sequencing and effect priority
        CFGVAR  "name" = "Learning Game - two-note PSG music sequencing and effect priority"
        CFGVAR  "short_name" = "level14_music_psg"
        CFGVAR  "description" = "Focused two-note PSG music sequencing and effect priority checkpoint."
        ROMW 16
        INCLUDE "../../library/gimini.asm"
SCRATCH ORG $100, $100,"-RWBN"
ISRVEC RMB 2
NOTE_INDEX RMB 1
NOTE_TIMER RMB 1
EFFECT_PRIORITY RMB 1
SYSTEM ORG $2F0, $2F0,"-RWBN"
STACK RMB 32
        ORG $5000
ROMHDR: BIDECLE ZERO
        BIDECLE ZERO
        BIDECLE MAIN
        BIDECLE ZERO
        BIDECLE ONES
        BIDECLE TITLE
        DECLE $03C0
ZERO: DECLE 0,0
        DECLE C_BLU,C_BLU,C_BLU,C_BLU,C_BLU
ONES: DECLE 1
TITLE: PROC
        BYTE 102,"two-note PSG music sequencing and effect priority",0
        BEGIN
        RETURN
        ENDP
MAIN: PROC
        DIS
        MVII #STACK,R6
        CLRR R0
 MVO R0,NOTE_INDEX
        MVII #30,R0
        MVO R0,NOTE_TIMER
        MVO R0,EFFECT_PRIORITY
               ; Install the frame ISR before entering the music loop.
               MVII #VBLANK_ISR,R0
               MVO R0,ISRVEC
               SWAP R0
               MVO R0,ISRVEC+1
               EIS
@@music: MVI EFFECT_PRIORITY,R0
        BNEQ @@sfx
        MVI NOTE_INDEX,R0
        ANDI #1,R0
        ADDI #NOTE_TABLE,R0
        MOVR R0,R4
        MVI@ R4,R1
        MVO R1,PSG0.chn_a_lo
        CLRR R1
        MVO R1,PSG0.chn_a_hi
        MVII #$0F,R1
        MVO R1,PSG0.chn_a_vol
        ; Enable tone A while leaving tone B and C disabled (bits 1 and 2).
        MVII #6,R1
        MVO R1,PSG0.chan_enable
        B @@music
@@sfx: MVI NOTE_INDEX,R0
        MVII #SFX_NOTE,R4
        MVI@ R4,R1
        MVO R1,PSG0.chn_a_lo
        CLRR R1
        MVO R1,PSG0.chn_a_hi
        MVII #$0F,R1
        MVO R1,PSG0.chn_a_vol
        MVII #6,R1
        MVO R1,PSG0.chan_enable
        B @@music
@@loop:
               B @@loop
               ENDP
VBLANK_ISR: PROC
               MVO R0, $20
               ; Advance the note only after a frame-based timer expires.
               MVI NOTE_TIMER,R0
               DECR R0
               MVO R0,NOTE_TIMER
               BNEQ @@done
               MVII #30,R0
               MVO R0,NOTE_TIMER
               MVI NOTE_INDEX,R0
               INCR R0
               ANDI #1,R0
               MVO R0,NOTE_INDEX
@@done:
               JR R5
               ENDP
NOTE_TABLE: DECLE $0080,$00A0
SFX_NOTE: DECLE $0040
; SFX path wins whenever EFFECT_PRIORITY is nonzero.
