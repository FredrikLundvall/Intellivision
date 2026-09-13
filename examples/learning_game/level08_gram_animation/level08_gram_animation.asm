; Star Dodger Level 8: two starship GRAM frames and card switching
        CFGVAR  "name" = "Star Dodger 8 - Starship Animation"
        CFGVAR  "short_name" = "Star Dodger 8"
        CFGVAR  "description" = "Animate the Star Dodger starship with GRAM cards."
        ROMW 16
        INCLUDE "../../library/gimini.asm"
SCRATCH ORG $100, $100,"-RWBN"
ISRVEC RMB 2
FRAME RMB 1
CARD RMB 1
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
        BYTE 102,"STAR DODGER 8",0
        BEGIN
        RETURN
        ENDP
MAIN: PROC
        DIS
        MVII #STACK,R6
        CLRR R0
 MVO R0,FRAME
 ; Put MOB 0 on screen before the ISR starts changing its card.
 MVII #STIC.mobx_visb + 76,R0
 MVO R0,STIC.mob0_x
 MVII #STIC.moby_ysize2 + 44,R0
 MVO R0,STIC.mob0_y
 MVII #STIC.moba_gram + STIC.moba_fg2,R0
 MVO R0,STIC.mob0_a
 MVII #GRAM_FRAME0,R4
 MVII #$3800,R5
 MVII #8,R2
 CALL MEMCPY
 MVII #GRAM_FRAME1,R4
 MVII #$3808,R5
 MVII #8,R2
 CALL MEMCPY
        MVII #VBLANK_ISR,R0
        MVO R0,ISRVEC
        SWAP R0
        MVO R0,ISRVEC+1
        EIS
@@loop:
        B @@loop
        ENDP
VBLANK_ISR: PROC
        MVO R0, $20
        ; The active ISR alternates the visible MOB between the two cards.
        MVI FRAME,R0
        INCR R0
        ANDI #1,R0
        MVO R0,FRAME
        BEQ @@frame0
        MVII #STIC.moba_gram + STIC.moba_fg2 + 8,R0
        B @@set_card
@@frame0:
        MVII #STIC.moba_gram + STIC.moba_fg2,R0
@@set_card:
        MVO R0,STIC.mob0_a
        JR R5
        ENDP
GRAM_FRAME0: DECLE $3C3C,$7E7E,$FFFF,$DBDB,$FFFF,$6666,$2424,0
GRAM_FRAME1: DECLE $1818,$3C3C,$7E7E,$FFFF,$FFFF,$7E7E,$3C3C,$1818
        INCLUDE "../../library/memcpy.asm"
