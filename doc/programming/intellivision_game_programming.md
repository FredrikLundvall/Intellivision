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
