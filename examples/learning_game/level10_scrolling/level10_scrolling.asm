; Star Dodger Level 10: camera coarse scrolling and STIC delay
        CFGVAR  "name" = "Star Dodger 10 - Camera"
        CFGVAR  "short_name" = "Star Dodger 10"
        CFGVAR  "description" = "Scroll the Star Dodger asteroid-field camera."
        ROMW 16
        INCLUDE "../../library/gimini.asm"
SCRATCH ORG $100, $100,"-RWBN"
ISRVEC RMB 2
CAMERA_X RMB 1
COARSE_X RMB 1
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
ONES:   DECLE   C_BLU, C_BLU, C_BLU, C_BLU, C_BLU
TITLE: PROC
        BYTE 102,"STAR DODGER 10",0
        BEGIN
        RETURN
        ENDP
MAIN: PROC
        DIS
        MVII #STACK,R6
        CLRR R0
 MVO R0,CAMERA_X
 MVO R0,COARSE_X
        MVII #VBLANK_ISR_CAMERA,R0
        MVO R0,ISRVEC
        SWAP R0
        MVO R0,ISRVEC+1
        EIS
@@move: MVI CAMERA_X,R0
 INCR R0
 MVO R0,CAMERA_X
 ANDI #7,R0
 MVO R0,COARSE_X
 B @@move
@@loop:
        B @@loop
        ENDP
VBLANK_ISR: PROC
        MVO R0, $20
        JR R5
        ENDP
VBLANK_ISR_CAMERA: PROC
 MVO R0,$20
 MVI CAMERA_X,R0
 MVO R0,STIC.h_delay
 JR R5
 ENDP
WORLD_MAP: DECLE 0,1,2,3,4,5,6,7
