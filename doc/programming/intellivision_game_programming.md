# Intellivision Game Programming with AS1600

This document collects the game-programming guidance in the SDK documentation
and the implementation patterns used by its examples. It is intended as a
practical starting point for writing cartridge games for the Intellivision
with the `as1600` assembler.

The examples use the SDK's `gimini.asm` definitions and library routines. They
are more useful than isolated hardware descriptions because they show how the
EXEC, STIC, RAM, controllers, sound, and game logic fit together in a running
program.

## 1. The machine from a game programmer's perspective

An Intellivision game is usually a 16-bit CP-1600 program running alongside
three important hardware blocks:

* **EXEC** provides cartridge startup, the title screen, interrupt dispatch,
  and common services.
* **STIC** generates the display. It provides a 20 by 12 background-card
  screen, eight movable objects (MOBs), color modes, collision information,
  scrolling delays, and the frame interrupt.
* **PSG** provides three tone channels, noise, envelopes, and the master hand
  controller input ports.

The display is a fixed-time system. NTSC hardware refreshes at approximately
59.92 frames per second; PAL hardware is approximately 50 Hz. A good game
therefore divides work into two cooperating parts:

1. The **main loop** reads input, updates rules, advances actors, performs
   collision and scoring logic, and queues changes.
2. The **VBLANK interrupt service routine (ISR)** performs time-sensitive
   display, GRAM, collision, and audio synchronization work.

This division is the central design pattern in `mazedemo`, `life`, `balls1`,
`bncpix`, and the reusable `examples/game_template`.

## 2. Cartridge startup and the EXEC contract

Most normal cartridges follow this source layout:

```asm
        CFGVAR  "name" = "My Game"
        ROMW    16
        INCLUDE "../library/gimini.asm"

; Scratch and system RAM declarations

        ORG     $5000
ROMHDR: ; EXEC-compatible header
TITLE:  ; title-screen procedure
MAIN:   ; game entry point

; game routines, graphics, and library includes
```

`ROMHDR` is not just metadata. The EXEC uses its pointers to find the MOB
list, process table, game entry point, background and GRAM data, and title
information. Keep the header format aligned with a known working example such
as `examples/hello/hello.asm` or `examples/mazedemo/mazedemo.asm`.

A typical header contains:

* a null or real MOB picture list;
* a null or real process table;
* `MAIN`, the code entered after the title screen;
* a background picture list;
* a GRAM picture list;
* `TITLE`, the title/date string or title procedure;
* the initial border, display mode, color stack, and border color.

The title procedure runs while the EXEC owns the screen. It may use routines
such as `PRINT.FLS` to customize the title, install a temporary ISR, or set
title-screen colors. It should return to the EXEC rather than falling through
into game code.

## 3. Memory organization

The standard memory map is deliberately split between 8-bit scratch RAM,
16-bit system RAM, hardware registers, and cartridge space.

| Address range | Game-programming use |
| --- | --- |
| `$0100-$0101` | EXEC VBLANK interrupt vector |
| `$0102-$01EF` | 8-bit scratch variables, task and controller state |
| `$01F0-$01FD` | Master PSG registers |
| `$01FE` | Right master controller input |
| `$01FF` | Left master controller input |
| `$0200-$02EF` | 240-word BACKTAB, 20 columns by 12 rows |
| `$02F0-$035F` | 16-bit system RAM, commonly stack and game state |
| `$3000-$37FF` | GROM, 256 built-in 8x8 cards |
| `$3800-$3AFF` | GRAM, 64 programmable 8x8 cards |
| `$5000-$6FFF` | Default cartridge code/data area |

Reserve RAM with explicit `ORG` ranges and `"-RWBN"` attributes, as in
`examples/balls1/balls1.asm` and `examples/life/life.asm`. Reserve a stack and
initialize `R6` before calling routines that use the stack:

```asm
SYSTEM  ORG     $2F0, $2F0, "-RWBN"
STACK   RMB     32
STATE   RMB     1

; During initialization:
        MVII    #STACK, R6
```

The interrupt vector is in scratch RAM and must be installed with interrupts
disabled. Writing both words of a 16-bit address is a non-interruptible setup
sequence:

```asm
        DIS
        MVII    #VBLANK_ISR, R0
        MVO     R0, ISRVEC
        SWAP    R0
        MVO     R0, ISRVEC+1
        EIS
```

## 4. Initialization and the frame loop

`MAIN` normally performs one-time setup with interrupts disabled:

1. initialize the stack and game variables;
2. seed the random-number state if needed;
3. install the VBLANK ISR;
4. initialize BACKTAB and the initial color mode;
5. load initial GRAM cards while the display is blanked or during VBLANK;
6. initialize MOB shadows, sound state, timers, and input state;
7. enable interrupts;
8. enter the main loop.

The main loop should be short, repeatable, and free of direct STIC/GRAM
access. A typical skeleton is:

```asm
MAIN:   PROC
        DIS
        MVII    #STACK, R6
        CALL    INIT_GAME
        EIS

@@loop:
        CALL    READ_INPUT
        CALL    UPDATE_GAME
        CALL    UPDATE_SOUND
        B       @@loop
        ENDP
```

Do not assume that one pass through the main loop equals one video frame. If
an action must happen at a fixed rate, count frames in the ISR and consume the
counter in the main loop.

## 5. VBLANK and the STIC timing budget

The STIC is the only regular interrupt source. During VBLANK the CPU can
access STIC registers for roughly the first 2,000 CPU cycles and GROM/GRAM for
roughly 3,780 cycles on NTSC hardware. During active display, reads and writes
to these resources do not behave normally.

The first operation in a display-preserving ISR must be the display-enable
handshake:

```asm
VBLANK_ISR:
        MVO     R0, $0020
```

The value written is ignored; the write itself tells the STIC to keep the
display enabled. It must happen every frame. Missing it causes the display to
blank even though interrupts continue to arrive.

A normal ISR performs work in this order:

1. preserve any registers required by the chosen EXEC return convention;
2. write `$0020` to enable the display;
3. update STIC registers from shadow state;
4. read collision results if required;
5. copy only the GRAM data that fits in the remaining VBLANK budget;
6. update frame counters, timers, and audio timing;
7. return through the EXEC dispatcher.

Keep the ISR bounded. Full-screen clears, decompression, random generation,
and general rule processing belong outside the ISR. `examples/handdemo` uses
an initialization ISR for work that must wait until VBLANK, while
`examples/balls1` uses a compact recurring ISR to copy its MOB shadow and
animate objects.

If a program needs a large initial STIC or GRAM update, blank the display
during startup or spread the work across multiple frames. Do not repeatedly
copy a full screen or full GRAM image every frame unless timing has been
measured.

## 6. Background graphics

BACKTAB is 240 words in raster order:

```text
$0200 + row * 20 + column
```

Each word selects a GROM/GRAM card and its display attributes. The STIC
supports Color Stack mode, Colored Squares mode, and
Foreground/Background mode. Color Stack mode is a useful default for maps and
menus; `mazedemo` uses it for a maze, while `life` and `bncpix` demonstrate
colored-square rendering.

For a simple full-screen initialization, the SDK examples use `FILLMEM`:

```asm
        MVII    #$00F0, R1      ; 240 BACKTAB words
        MVII    #$0200, R4      ; BACKTAB
        MVII    #$1352, R0      ; example colored-square pattern
        CALL    FILLMEM
```

The exact card and color word depends on the selected STIC mode. Start with a
known-good mode and word from `examples/life/life.asm` or
`examples/bncpix/bncpix.asm`, then change one field at a time.

Use the SDK screen routines for text and simple maps:

* `CLRSCR` clears the screen;
* `PRINT.FLS` writes a color and string to BACKTAB;
* `PUTPIXELS` and related colored-square routines draw individual cells;
* `MEMCPY` and `FILLMEM` initialize larger regions.

## 7. GROM, GRAM, and custom artwork

GROM contains 256 built-in 8x8 cards. GRAM contains 64 programmable 8x8
cards. A card is eight words high, with bit 7 as the leftmost pixel and bit 0
as the rightmost pixel:

```asm
PLAYER_GFX:
        DECLE   %00111000
        DECLE   %01111100
        DECLE   %11111110
        DECLE   %11011011
        DECLE   %11111110
        DECLE   %01111100
        DECLE   %00111000
        DECLE   %00010000
```

The first GRAM card begins at `$3800`; each additional card uses eight words.
GRAM writes are valid while the display is disabled or during its VBLANK access
window. A common startup operation is:

```asm
        CALL    MEMCPY
        DECLE   $3800, PLAYER_GFX, 8
```

For animated artwork, keep a shadow or queue of pending card updates and copy
only the changed cards in the ISR. `examples/bncpix`, `examples/balls1`, and
`examples/mob_test` are useful references for custom graphics and MOB setup.

## 8. MOBs and collision handling

The STIC has eight MOBs. Their registers are arranged in four groups:

| Registers | Meaning |
| --- | --- |
| `$0000-$0007` | X position, visibility, interaction, and X size |
| `$0008-$000F` | Y position, flips, Y size, and resolution |
| `$0010-$0017` | card number, GRAM/GROM selection, priority, and color |
| `$0018-$001F` | collision/interaction results |

Keep the 24 display words in RAM as a **MOB shadow**:

```text
MOB shadow = X[8], Y[8], Attribute[8]
```

The main loop changes the shadow from game state. The ISR writes the shadow
to the STIC during VBLANK. This prevents partially updated objects from
appearing on screen and keeps all STIC access in the legal timing window.

Important details:

* MOB coordinates are relative to the object field, not the visible
  background-card area.
* An X coordinate of zero disables a MOB; a Y coordinate of zero does not.
* Single-resolution MOBs use one 8x8 card.
* Double-resolution MOBs use two consecutive cards and start on an even card
  number.
* Interaction must be enabled in the MOB attribute word if collision results
  are required.
* Read collision registers in VBLANK, then clear or consume the result in
  game logic.

`examples/balls1/balls1.asm` is the primary reference for eight moving MOBs,
shadow registers, velocities, collision interaction, and a frame-driven
animation loop.

## 9. Controller input

The master controller ports are active-low. The SDK maps the right controller
to `$01FE` and the left controller to `$01FF`. If polling directly, invert and
mask the value before interpreting it:

```asm
        MVI     $01FF, R0       ; left controller
        XORI    #$00FF, R0      ; pressed inputs become one bits
        ANDI    #$00FF, R0
```

Direct polling is appropriate for a small diagnostic or a tightly controlled
game. It still needs edge detection and debouncing:

```asm
        MOVR    R0, R1
        XOR     INPUT_OLD, R1
        ANDR    R0, R1          ; newly pressed inputs
        MVO     R0, INPUT_OLD
```

For a normal game, prefer the SDK's `SCANHAND` and task routines in
`examples/task/scanhand.asm`. They provide:

* keypad, action-button, and disc decoding;
* left/right controller identification;
* press and release events;
* debouncing over repeated scans;
* optional ECS controller support.

`SCANHAND` uses a dispatch table for keypad, action-button, and disc events.
Keypad Enter is input number 11 (`$0B`); release events have the high bit set.
Call the scanner regularly at a reasonably even rate. The debounce setting
must match the call rate: the default is intended for frequent background
calls, while ISR-driven scanning should use a smaller value.

`examples/handdemo/handdemo.asm` shows a complete controller status display
and is the best input reference in this SDK.

## 10. Sound with the PSG

The master PSG is mapped at `$01F0-$01FD`:

| Address | Function |
| --- | --- |
| `$01F0/$01F4` | Channel A period low/high |
| `$01F1/$01F5` | Channel B period low/high |
| `$01F2/$01F6` | Channel C period low/high |
| `$01F8` | Tone/noise enable |
| `$01F9` | Noise period |
| `$01FB-$01FD` | Channel A/B/C volume |

The period is a divisor: smaller period values produce higher tones. A sound
effect normally writes a channel period, enables the desired tone or noise,
sets volume, and uses a frame timer to turn the channel off or advance the
effect.

Keep sound requests in game state and update the PSG from a predictable
timing path. The ISR is useful for fixed-rate music and effect envelopes; the
main loop is suitable for queuing events. Do not bury long sound-generation
loops in either path. `doc/programming/psg.txt` contains the register details,
while `examples/game_template/game_template.asm` provides a small sound-effect
framework.

## 11. Game-state architecture

Separate persistent game state from hardware shadows:

```text
Game state:     player coordinates, velocities, lives, score, timers
Input state:    current/previous buttons, queued events
Display state:  BACKTAB map, MOB shadow, pending GRAM cards
Sound state:    active channels, effect timers, music position
Hardware ISR:   commits display and timing state during VBLANK
```

For each frame, a conventional sequence is:

1. scan or consume controller events;
2. update player and enemy state;
3. resolve map and MOB collisions;
4. update score, lives, timers, and animation phases;
5. write new values into BACKTAB/MOB/sound shadows;
6. let the ISR commit the hardware-visible portion.

Use fixed-point values for smooth movement when appropriate. `balls1` keeps
fractional positions and velocities, then converts them to STIC coordinates
when updating its shadow. A grid-based game such as `mazedemo` can instead
keep card and pixel coordinates separately.

## 12. A recommended source-file organization

Small programs can remain in one `.asm` file. Larger games should divide
responsibilities into include files:

```text
game.asm             cartridge metadata, header, title, main loop
memory.inc           RAM layout and constants
display.inc          BACKTAB, MOB shadows, STIC commit code
input.inc            SCANHAND/task integration
sound.inc            PSG drivers and music/effects
levels.inc           maps, card tables, level data
art.inc              GRAM bitmaps and animation frames
```

Within the main source, this order is easy to audit:

```text
CFGVAR / ROMW / includes
scratch-RAM declarations
system-RAM declarations
constants and build options
ORG $5000
ROMHDR, ZERO, and ONES
TITLE
MAIN and initialization
VBLANK ISR
input, rules, collision, and sound routines
graphics and level data
library includes
```

## 13. Building and testing with AS1600

From the example directory, build BIN+CFG or ROM output:

```text
as1600 -o mygame.bin -l mygame.lst mygame.asm
as1600 -o mygame.rom -l mygame.lst mygame.asm
```

BIN+CFG is convenient for emulator and Intellicart-style testing. ROM output
is useful when a single ROM image is required, especially for bank-switched
layouts. Bank-switched examples such as `bankdemo`, `banktest`, and
`bankworld` are not ordinary single BIN+CFG programs.

A practical test order is:

1. assemble with zero errors and inspect the listing;
2. verify the EXEC title screen and return to `MAIN`;
3. verify display enable and background mode;
4. test one controller event at a time;
5. add one MOB or GRAM card before adding animation;
6. test collision results;
7. add sound and frame timers;
8. test reset, title restart, long-running play, and PAL/NTSC assumptions.

When graphics are missing or the screen becomes scrambled, first reduce the
program to a known-good background and a single MOB. The most common causes
are excessive VBLANK work, writing STIC/GRAM during active display, an invalid
MOB X coordinate, an incorrect GRAM card number, or failure to write the
display-enable handshake every frame.

## 14. SDK example index

| Example | Main lesson |
| --- | --- |
| `examples/hello` | Minimal EXEC-compatible cartridge and title flow |
| `examples/mazedemo` | Color Stack background, title customization, map logic |
| `examples/life` | Large scratch-RAM state and colored-square simulation |
| `examples/bncpix` | Colored-square drawing and frame-driven animation |
| `examples/balls1` | MOB shadows, GRAM/MOB animation, collisions, sound timing |
| `examples/mob_test` | Focused MOB register and display behavior |
| `examples/handdemo` | Controller scanning and decoded display of input |
| `examples/task/scanhand.asm` | Reusable debounced controller/task routines |
| `examples/game_template` | Starting framework combining startup, input, MOBs, GRAM, and PSG |
| `examples/spacepat` | Larger multi-file project and generated-asset workflow |

## 15. Primary SDK references

The following files are the authoritative low-level references behind this
guide:

* `doc/programming/memory_map.txt` — hardware addresses and access windows;
* `doc/programming/interrupts.txt` — VBLANK dispatch and timing;
* `doc/programming/stic.txt` — STIC modes, registers, MOBs, and scrolling;
* `doc/programming/graphics_mem.txt` — GROM/GRAM layout and bitmap encoding;
* `doc/programming/psg.txt` — PSG registers, tones, noise, and envelopes;
* `doc/programming/intro_to_cp1600.txt` — CP-1600 assembly fundamentals;
* `doc/programming/game_structure.md` — shorter structural overview;
* `examples/library/gimini.asm` — SDK symbols and hardware definitions;
* `examples/task/scanhand.asm` — controller scanning implementation.

When this overview conflicts with a hardware detail, use the programming
reference files and the working examples as the final authority.

---

# Expanded Programming Notes and Examples

The following notes expand every section above with the decisions that usually
matter while turning a demo into a game. The code is intentionally small. It
shows the shape of a solution; game-specific constants, register masks, and
library requirements must still be checked against `gimini.asm` and the
relevant example.

## 1. Machine model: one frame, two execution contexts

The CP-1600 does not have a separate graphics processor that can safely accept
updates at any time. The STIC owns the display bus during active display, so a
game should treat the frame as two regions:

```text
active display  -> run game logic, read normal RAM, queue changes
VBLANK          -> commit STIC/GRAM changes, sample collisions, tick clocks
```

This is why a game can calculate a new position in the main loop but should
not write `$0000` directly there. Instead, update a shadow:

```asm
; Main-loop code: ordinary RAM is safe here.
        MVI     PLAYER_X, R0
        ADDI    #1, R0
        MVO     R0, PLAYER_X
        MVO     R0, MOB_SHADOW       ; committed later by the ISR
```

For a slow game, the main loop may run several times per frame. For a busy
game, it may run less than once per frame. A `FRAME` counter maintained by the
ISR gives game code a stable clock:

```asm
VBLANK_ISR:
        MVO     R0, $20
        MVI     FRAME, R0
        INCR    R0
        MVO     R0, FRAME
```

Use a separate accumulator when a rule must run exactly once per frame. This
avoids tying gameplay speed to the number of iterations through the main loop.

## 2. Startup: a minimal working cartridge

The header fields are pointers, not inline objects. A useful minimal cartridge
looks like this:

```asm
        CFGVAR  "name" = "Example Game"
        CFGVAR  "short_name" = "Example"
        ROMW    16
        INCLUDE "../library/gimini.asm"

        ORG     $5000
ROMHDR: BIDECLE ZERO
        BIDECLE ZERO
        BIDECLE MAIN
        BIDECLE ZERO
        BIDECLE ONES
        BIDECLE TITLE
        DECLE   $03C0

ZERO:   DECLE   $0000              ; border control
        DECLE   $0000              ; Color Stack mode
        DECLE   C_BLU, C_BLU
        DECLE   C_BLU, C_BLU
        DECLE   C_BLU              ; border color
ONES:   DECLE   1

TITLE:  PROC
        BYTE    102, "Example Game", 0
        BEGIN
        RETURN
        ENDP

MAIN:   PROC
        DIS
        MVII    #STACK, R6
        ; Install variables and the ISR here.
        EIS
@@loop:
        B       @@loop
        ENDP
```

`hello.asm` is the best first comparison when startup fails. If the title
screen works but the game never begins, inspect the title return path and the
`MAIN` pointer before investigating graphics. If the title is garbled, check
the title length byte, the ROM width, and the `ROMHDR` layout.

A title patch is normally data-driven:

```asm
        CALL    PRINT.FLS
        DECLE   C_WHT, $23D
        STRING  "My Studio Presents", 0
```

The destination is a BACKTAB address. Avoid patching title text after the EXEC
has returned control to the game unless the title screen is deliberately part
of the game.

## 3. Memory organization: avoid overlap before debugging code

Memory bugs often look like graphics bugs. Record the start and end of every
RAM block and leave room for the stack:

```asm
SCRATCH ORG     $100, $100, "-RWBN"
ISRVEC  RMB     2
INPUT   RMB     1
FRAME   RMB     1

SYSTEM  ORG     $2F0, $2F0, "-RWBN"
STACK   RMB     32
STATE   RMB     8
STICSH  RMB     24
```

Do not place frequently changing 16-bit values in scratch RAM merely because
it is convenient. Scratch RAM is byte-wide in the standard configuration;
system RAM is the natural home for stack frames, MOB shadows, positions, and
other word-sized state.

A useful convention is to give each block an end symbol:

```asm
_EOSCR  EQU     $
        ; Later, inspect the listing and verify _EOSCR is before $2F0.
```

The controller and PSG addresses overlap conceptually because the AY-3-8914
exposes both functions through the same device. Do not treat `$01FE` and
`$01FF` as general RAM. Likewise, `$0200-$02EF` is not free state while the
background is displayed: it is the live BACKTAB.

## 4. Initialization and frame scheduling

Separate one-time setup from repeatable frame work. For example:

```asm
INIT_GAME PROC
        CALL    INIT_BACKGROUND
        CALL    INIT_PLAYER
        CALL    INIT_SOUND
        CLRR    R0
        MVO     R0, FRAME
        MVO     R0, INPUT_OLD
        JR      R5
        ENDP
```

Keep initialization idempotent where practical. A restart path can then call
`INIT_GAME` again without leaving old MOBs, sounds, or timers active.

A simple frame scheduler can turn the ISR counter into several rates:

```asm
        MVI     FRAME, R0
        ANDI    #$0003, R0        ; every four frames
        BNEQ    @@not_due
        CALL    UPDATE_ENEMIES
@@not_due:
```

For more complex games, use a `TICK` flag set by the ISR and cleared by the
main loop. This prevents a fast main loop from processing the same frame event
multiple times:

```asm
VBLANK_ISR:
        MVO     R0, $20
        MVII    #1, R0
        MVO     R0, TICK
```

The main loop must clear `TICK` before waiting for the next event. Never wait
for a flag while interrupts are disabled.

## 5. VBLANK: writing a bounded ISR

A compact ISR can copy a 24-word MOB shadow with a library routine or an
unrolled loop, then return:

```asm
VBLANK_ISR PROC
        MVO     R0, $20           ; display-enable handshake first

        MVII    #MOB_SHADOW, R4
        MVII    #$0000, R5        ; first STIC X register
        MVII    #8, R2
@@x:
        MVI@    R4, R0
        MVO@    R0, R5
        INCR    R5
        DECR    R2
        BNEQ    @@x

        ; Repeat for Y and attribute words as required by the game.
        MVI     FRAME, R0
        INCR    R0
        MVO     R0, FRAME
        JR      R5
        ENDP
```

The exact return instruction depends on whether the handler is written as an
EXEC-dispatched function or a custom interrupt replacement. Follow the
pattern in `balls1`, `bncpix`, or `handdemo`; do not copy only the first and
last lines of an ISR without matching its register-saving convention.

Measure the expensive parts. A full 240-word BACKTAB fill and a full GRAM
copy may assemble correctly but still overrun the VBLANK access window. Split
large work into jobs:

```text
GRAM queue: card address, source address, word count
ISR:        copy one queued card, advance queue, return
```

If the display is intentionally disabled, initialization has a much larger
access window. Re-enable it only after the initial STIC and GRAM state is
complete.

## 6. Backgrounds: choosing a display mode

Choose the background mode based on the game rather than trying to force every
map into one format:

| Mode | Good use |
| --- | --- |
| Color Stack | maps with a small repeating palette and text |
| Colored Squares | fast multicolor cellular or tile effects |
| Foreground/Background | cards needing independent foreground/background colors |

The 20-column stride is easy to get wrong. A helper for a map cell can compute:

```text
BACKTAB address = $0200 + (row * 20) + column
```

For a map stored in ROM, copy one row at a time:

```asm
        MVII    #LEVEL_MAP, R4
        MVII    #$0200, R5
        MVII    #12, R2
@@row:
        MVII    #20, R1
@@col:
        MVI@    R4, R0
        MVO@    R0, R5
        DECR    R1
        BNEQ    @@col
        DECR    R2
        BNEQ    @@row
```

This code belongs outside the recurring ISR when the map is initialized only
once. For scrolling or animated maps, update a small dirty rectangle instead
of rewriting all 240 words.

`mazedemo` is a useful example of changing individual BACKTAB cells as the
maze is generated. `life` demonstrates the opposite approach: a compact
simulation buffer is calculated in RAM and then rendered as a screen-wide
colored-square field.

## 7. Artwork: card numbering and animation

The STIC card number determines both the source memory and the bitmap. GROM
cards occupy numbers `0..255`; GRAM cards are commonly referred to as
`256..319`, or as GRAM cards `0..63` in source comments. A MOB attribute must
select GRAM when its card is programmable.

For an 8x8 frame, keep the data aligned as eight words:

```asm
FRAME_IDLE:
        DECLE   %00011000
        DECLE   %00111100
        DECLE   %01111110
        DECLE   %11011011
        DECLE   %00111000
        DECLE   %00111000
        DECLE   %01101100
        DECLE   %11000110
```

Animation does not require rewriting the MOB position. It can change the
attribute card number while the main loop continues to update position:

```asm
        MVI     ANIM_FRAME, R0
        ANDI    #$0003, R0
        ADDI    #GRAM_CARD_BASE, R0
        XORI    #STIC.moba_gram, R0
        MVO     R0, PLAYER_A
```

The actual card-base constants depend on the SDK definitions. Verify them in
`gimini.asm` and compare with `balls1` or `bncpix`.

When a GRAM frame is changed, use double buffering or update only during a
known VBLANK slot. Otherwise the STIC may display half of the old bitmap and
half of the new one for a frame.

## 8. MOBs: positions, attributes, and interactions

Treat an object as three independent decisions:

```text
where      -> X and Y registers
what       -> card, GRAM/GROM source, color, flips, size
how        -> visibility, interaction, priority, resolution
```

A single visible MOB setup typically contains:

```asm
        MVII    #STIC.mobx_visb + 76, R0
        MVO     R0, MOB_SHADOW + 0
        MVII    #STIC.moby_ysize2 + 44, R0
        MVO     R0, MOB_SHADOW + 8
        MVII    #STIC.moba_gram + STIC.moba_fg2, R0
        MVO     R0, MOB_SHADOW + 16
```

The symbolic fields are preferable to unexplained hexadecimal masks. The
object field is larger than the visible background area, so center positions
must be chosen using the STIC coordinate system, not simply column 10 and row
6 multiplied by eight.

Collision results are bitfields, not a single boolean. Save them in the ISR
before the next frame overwrites them:

```asm
        MVI     $0018, R0         ; MOB 0 interaction result
        MVO     R0, PLAYER_HITS
```

Then decode `PLAYER_HITS` in the main loop and apply damage, scoring, or
bounce rules there. This keeps collision consequences deterministic and avoids
long rule code in VBLANK.

## 9. Input: raw ports versus decoded events

Raw input is useful for continuous movement. A disc direction can be held,
converted to velocity, and applied every game tick:

```asm
        MVI     INPUT, R0
        ANDI    #DISC_MASK, R0
        BEQ     @@no_disc
        CALL    MOVE_PLAYER
@@no_disc:
```

Keypad and action buttons are better represented as events. A press event
should generally happen once, while a held disc direction may repeat. This is
the distinction that `SCANHAND` and the task queue make explicit.

When debugging a controller, display the raw and inverted values on screen
before adding game behavior. `handdemo` does this and is a better diagnostic
than guessing at one bit. Remember that controller input is active-low at the
hardware port and that the left/right port naming follows the SDK's memory-map
convention.

For a direct Enter test, use a decoded keypad event when possible:

```asm
; SCANHAND event payload:
; low byte = input number, bit 7 = release
        ANDI    #$007F, R0
        CMPI    #$000B, R0        ; keypad Enter
        BNEQ    @@not_enter
        CALL    START_GAME
@@not_enter:
```

Do not compare an unmasked raw port value to `$0B`; raw values include active-
low encoding and other controller lines.

## 10. Sound: make effects data-driven

A compact sound-effect record can keep the game code independent from PSG
register details:

```text
effect: tone-period, duration-in-frames, volume, enable-mask
```

The main loop requests an effect:

```asm
        MVII    #SFX_JUMP, R0
        MVO     R0, SFX_PENDING
```

The ISR or a frame-synchronized sound routine consumes it:

```asm
        MVI     SFX_TIMER, R0
        BEQ     @@sound_off
        DECR    R0
        MVO     R0, SFX_TIMER
        B       @@sound_done
@@sound_off:
        MVII    #PSG.tone_a_off, R0
        MVO     R0, PSG0.chan_enable
@@sound_done:
```

The exact SDK field names vary by include definitions, so use the symbolic
`PSG0` names from `gimini.asm`. Keep the audio mixer state in RAM if music and
effects share channels. A common policy is to reserve channel C for effects
and leave channels A/B to music.

Noise is useful for explosions, engines, and percussion. Tone period and
volume changes should be bounded just like display updates; a long music
decoder should prepare its next event in the main loop and only commit PSG
writes on the frame boundary.

## 11. Game state: from input to visible result

A useful update pipeline is:

```text
read input -> decide intent -> move -> collide -> resolve -> animate
          -> update score/timers -> publish display and sound shadows
```

For example, a tile-based player can keep both a precise position and a map
cell:

```text
player_x_fp / player_y_fp  fixed-point movement position
player_col / player_row    collision-map cell
player_mob_x / player_mob_y rendered STIC coordinates
```

Do not use the rendered MOB coordinate as the only game position when smooth
movement or subpixel velocity is needed. `balls1` demonstrates fractional
positions and velocities; `mazedemo` demonstrates a card/pixel model suited
to a maze.

Use explicit state transitions for screens:

```text
STATE_TITLE -> STATE_PLAY -> STATE_PAUSE -> STATE_GAME_OVER
```

Each state owns input rules, drawing work, and allowed transitions. This is
safer than leaving title-screen code, game code, and restart code active at
the same time.

## 12. Source organization: interfaces between files

Includes should expose data and small contracts, not hidden hardware side
effects. For example:

```asm
; display.inc contract
; Input:  MOB_SHADOW contains 24 words
; Clobbers: R0, R1, R2, R4, R5
; Output:  STIC registers updated during VBLANK
```

Keep constants that describe the same format together. A level-map include
should define width, height, and map data in one place:

```asm
LEVEL_WIDTH  EQU 20
LEVEL_HEIGHT EQU 12
LEVEL_MAP:
        DECLE  ; 20 card words per row
```

For large projects, generated assets should be reproducible. `spacepat` is
the SDK example to study for a multi-file/generated-data build, while the
small examples are easier to copy when starting a new game.

## 13. Build and test: isolate failures

Use the smallest test ROM that proves the current subsystem:

| Test ROM | Proves |
| --- | --- |
| title-only program | header, title, and EXEC return |
| filled BACKTAB | display mode and color words |
| one GRAM card | GRAM access and card numbering |
| one MOB | coordinates, visibility, color, and card source |
| input diagnostic | port polarity and controller mapping |
| sound diagnostic | PSG period, enable, and volume |

Keep the listing file. It reveals the final addresses of RAM symbols, ISR
code, graphics, and generated tables. When a failure appears after adding a
feature, compare the listing and the last known-good ROM rather than changing
several timing-sensitive sections at once.

For BIN output, retain the generated configuration file beside the binary
when using an emulator or cartridge tool. Use ROM output only when the target
expects a single ROM image. Banked examples require the appropriate banking
layout; changing only the file extension does not make a normal image
bank-switched.

## 14. Example index: how to study the SDK

Read examples in increasing complexity:

1. `hello` for header and title flow;
2. `mazedemo` for BACKTAB and a complete rule loop;
3. `bncpix` for colored-square drawing and an ISR;
4. `handdemo` and `task/scanhand.asm` for controller events;
5. `balls1` for MOB shadows, movement, interaction, and timing;
6. `life` for a larger RAM-backed simulation;
7. `game_template` for a deliberately organized starting point;
8. `spacepat` for generated assets and a multi-file build.

When borrowing code, copy the surrounding memory declarations and timing
assumptions too. A routine that works in `balls1` may depend on its stack,
shadow layout, ROM width, or ISR convention.

## 15. References: how to use the documentation

Use the references in this order while developing:

1. `memory_map.txt` to identify the address and access restriction;
2. `stic.txt` or `graphics_mem.txt` to interpret a register/card word;
3. `interrupts.txt` to determine when the access is legal;
4. a working example to copy the calling and return convention;
5. `gimini.asm` to use the SDK's actual symbolic names;
6. the listing and emulator output to verify the result.

The documentation uses hardware terminology consistently, but old examples
may use local names such as `STICSH`, `ISRVEC`, `RNDLO`, or `WTIMER`.
Understand what a symbol represents before reusing its name in a new module.

---

# Appendix A: Glossary of Terms

## Address and CPU terms

**AS1600** — The SDK assembler used to translate CP-1600 assembly source into
BIN+CFG or ROM output.

**CP-1600** — The 16-bit processor used by the Intellivision. Its registers,
instruction timing, and interrupt behavior are documented in
`intro_to_cp1600.txt` and the CP-1600 reference files.

**R0-R7** — The CP-1600 registers. `R6` is conventionally used as the stack
pointer by SDK routines; `R7` is the program counter.

**`DECLE`** — An AS1600 directive that emits one or more 16-bit words.

**`BYTE`** — An AS1600 directive that emits byte-oriented data, commonly used
for title strings and scratch-RAM data.

**`RMB`** — Reserve memory bytes/words according to the active memory width.
Use it in RAM declarations rather than putting writable state in ROM.

**`ORG`** — Selects the address at which subsequent code or data is assembled.
The SDK uses separate `ORG` blocks for scratch RAM, system RAM, and cartridge
ROM.

**`ROMW`** — Selects the ROM word width expected by the assembler and target
layout. Match the working example being used as a base.

**`CFGVAR`** — Adds cartridge metadata such as name, author, year, and
description to the build.

**EXEC** — The Intellivision Executive ROM. It starts cartridges, displays
the title screen, dispatches interrupts, and supplies common routines.

**ROM header** — The table at the start of a cartridge that tells EXEC where
to find the game entry point, title, picture lists, and initial display state.

**BIN+CFG** — A two-file assembler output format useful for emulator and
Intellicart-style loading. The binary and its configuration describe the
memory mapping together.

**ROM output** — A single ROM image. It is useful for targets that expect a
complete image and for layouts such as bank-switched cartridges.

## Display terms

**STIC** — Standard Television Interface Circuit. It generates the display,
manages background cards and MOBs, and produces the VBLANK interrupt.

**VBLANK** — Vertical blanking interval between active display regions. The
CPU temporarily gains access to STIC registers and graphics memory.

**Display-enable handshake** — A write to STIC address `$0020` during each
VBLANK. The written value is not important; omitting the write eventually
blanks the display.

**BACKTAB** — The 240-word background-card table at `$0200-$02EF`, arranged
as 20 columns by 12 rows.

**Background card** — An 8x8 picture selected by a BACKTAB word. It normally
comes from GROM or GRAM.

**GROM** — Graphics ROM containing 256 built-in cards, including the standard
character set.

**GRAM** — Graphics RAM containing 64 programmable cards. It is the normal
place for player, enemy, item, and special-effect artwork.

**Card number** — The index of an 8x8 picture. GROM uses cards 0 through 255;
GRAM cards are often described as cards 256 through 319 in combined numbering.

**Color Stack mode** — A STIC mode where background colors are selected from
the four color-stack registers and card attributes.

**Colored Squares mode** — A mode where BACKTAB words directly produce
colored-square patterns. It is useful for cellular simulations and simple
abstract graphics.

**Foreground/Background mode** — A mode that gives a card independent
foreground and background color information, subject to card availability
restrictions.

**MOB** — Movable Object. One of eight hardware sprites controlled through
STIC registers.

**MOB shadow** — A RAM copy of the MOB X, Y, and attribute words. Game logic
updates the shadow; the ISR commits it to the STIC.

**Object field** — The larger coordinate field used by MOBs. It extends beyond
the visible 20-by-12 background-card area, which allows objects to move partly
off-screen.

**Interaction** — The STIC's term for MOB collision and overlap detection.
Results are reported in the MOB collision registers.

**Horizontal/vertical delay** — STIC registers that shift the object field
relative to the visible display. They are useful for scrolling.

## Input and sound terms

**Active-low** — A signal convention where zero means asserted or pressed.
The master controller ports use this convention and normally need inversion
before game logic interprets them.

**SCANHAND** — SDK controller-scanning code that decodes keypad, action
buttons, and disc directions, performs debouncing, and schedules events.

**Edge detection** — Comparing current input with the previous input to find a
new press or release instead of treating a held button as many presses.

**Debouncing** — Filtering rapid electrical transitions so one physical press
becomes one stable game event.

**PSG** — Programmable Sound Generator. The AY-3-8914-compatible sound chip
with three tone channels, noise, envelopes, and controller I/O.

**Tone period** — A divisor written to a PSG channel. Smaller periods produce
higher tone frequencies.

**Envelope** — A programmable volume progression used to shape tones.

**Noise generator** — The PSG source for pseudo-random noise effects such as
explosions, engines, and percussion.

## Game-architecture terms

**Main loop** — Repeating game-code path for input, rules, physics, map
collisions, scoring, and preparation of hardware shadows.

**ISR** — Interrupt service routine. On the Intellivision this normally means
the VBLANK handler installed at `$0100/$0101`.

**Frame counter** — A variable incremented by the ISR to provide a stable
video-rate clock.

**Fixed-point value** — An integer that reserves some low bits for a
fractional part. It allows smooth movement while the STIC still receives
integer pixel coordinates.

**Dirty rectangle** — A small changed region of the BACKTAB or graphics
surface. Updating only dirty regions saves CPU and VBLANK time.

**State machine** — A set of named game modes, such as title, play, pause,
and game over, with explicit transitions between them.

**Task queue** — A queue of deferred work or input events used by SDK task
routines. It lets scanning code report events without executing all game
logic inside the scanner.

**Bank switching** — Hardware or cartridge logic that changes which ROM region
is visible at an address range. Banked games need a matching ROM layout and
build process; they cannot be made banked by changing an output filename.

# Appendix B: Quick-reference tables

## Common hardware addresses

| Symbolic purpose | Address | Access note |
| --- | ---: | --- |
| STIC display enable | `$0020` | VBLANK |
| STIC mode | `$0021` | VBLANK |
| color stack | `$0028-$002B` | VBLANK |
| border color | `$002C` | VBLANK |
| VBLANK vector | `$0100-$0101` | normal scratch RAM |
| master PSG | `$01F0-$01FD` | normal writes |
| right controller | `$01FE` | active-low input |
| left controller | `$01FF` | active-low input |
| BACKTAB | `$0200-$02EF` | live display memory |
| GROM | `$3000-$37FF` | VBLANK or blank display |
| GRAM | `$3800-$3AFF` | VBLANK or blank display |

## A practical debugging checklist

1. Does the assembler report zero errors and warnings?
2. Does the title screen appear and return to `MAIN`?
3. Is the stack initialized before any `CALL`?
4. Is the ISR vector written with interrupts disabled?
5. Does the ISR write `$0020` every frame?
6. Is the background mode consistent with the BACKTAB word format?
7. Is GRAM loaded before the MOB references its card?
8. Is the MOB X coordinate nonzero and in the object-field coordinate system?
9. Are controller values inverted, masked, and debounced?
10. Are collision results copied before the next frame?
11. Are sound and graphics updates bounded?
12. Does the program still work after a reset and after several minutes?

## A minimal development progression

```text
title only
  -> solid background
  -> one GROM character
  -> one GRAM card
  -> one visible MOB
  -> controller diagnostic
  -> player movement
  -> collision result
  -> sound effect
  -> enemies, map rules, scoring, and animation
```

This progression is intentionally conservative. It makes timing, addressing,
and polarity errors visible before they are hidden inside a full game.
