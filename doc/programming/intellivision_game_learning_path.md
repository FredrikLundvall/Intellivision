# Learning to Make an Intellivision Game

This tutorial is a practical course in making an Intellivision game with the
AS1600 assembler. It starts with a title screen and ends with a small
gameplay framework containing a player, an enemy, input, collision detection,
sound, and a frame-driven update loop.

The source for every level is outside this document in:

```text
examples/learning_game/
```

Each level is a separate cartridge source file. Build and test one level
before moving to the next. The examples are intentionally small and repetitive
so that the new idea in each level is easy to identify.

## What you will learn

| Level | New idea | Source |
| --- | --- | --- |
| 1 | EXEC header, title, text, and a program entry point | `level01_title.asm` |
| 2 | BACKTAB background, VBLANK, and direct controller polling | `level02_input.asm` |
| 3 | GRAM artwork and one controllable MOB | `level03_player.asm` |
| 4 | Game state, frame timing, enemy movement, and collision | `level04_collision.asm` |
| 5 | A reusable mini-game loop with restart state | `level05_game.asm` |
| 6 | PSG sound effects, frame timing, and sound shutoff | `level06_sound.asm` |
| 7 | Decoded controller events with SCANHAND-style debouncing | `level07_scanhand.asm` |
| 8 | Double-buffered GRAM animation and MOB card selection | `level08_gram_animation.asm` |
| 9 | Tile-map lookup and solid-tile collision rules | `level09_tile_collision.asm` |
| 10 | Camera coordinates and coarse tile-map scrolling | `level10_scrolling.asm` |
| 11 | HUD text, score formatting, and screen layout | `level11_hud_text.asm` |
| 12 | Complete title/play/game-over state flow | `level12_state_flow.asm` |
| 13 | Deterministic random seeds and the SDK random routine | `level13_randomness.asm` |
| 14 | PSG channels, music ownership, and effect priorities | `level14_music_psg.asm` |
| 15 | VBLANK budgets, ROM banking, and production cartridge layout | `level15_production.asm` |

The examples deliberately use direct polling before introducing `SCANHAND`.
That makes the hardware model visible. Replace direct polling with
`examples/task/scanhand.asm` when building a larger production game.

Levels 7–15 deliberately revisit the earlier small programs rather than
pretending that one large engine is the only way to learn. They are
standalone checkpoints: assemble each one from its own directory and compare
the RAM shadows and frame boundary work with the preceding level.

## Before starting

You need:

* the SDK checkout;
* `bin/as1600.exe`;
* an Intellivision emulator such as jzIntv;
* a way to copy the generated `.bin` and `.cfg` files to the emulator's ROM
  directory.

From each level directory, use:

```text
as1600 -o level01_title.bin -l level01_title.lst level01_title.asm
```

The assembler should report zero errors. A listing is useful for inspecting
symbol addresses and confirming that RAM did not overlap; remove the generated
`.bin`, `.cfg`, and `.lst` files after the check so the example directories
remain source-only.

The examples use the SDK library through relative paths. Run AS1600 from the
level directory, or adjust the include path for your build system.

## Level 1: Put a title and message on the screen

Start with the smallest useful cartridge. The goal is not yet to make a game;
it is to prove that the assembler, ROM header, EXEC title screen, and library
include path work.

Read `examples/learning_game/level01_title.asm` alongside
`examples/hello/hello.asm`.

### Step 1: metadata and ROM width

`CFGVAR` adds descriptive cartridge metadata. `ROMW 16` selects the normal
16-bit example layout:

```asm
        CFGVAR  "name" = "Learning Game 1"
        ROMW    16
        INCLUDE "../../library/gimini.asm"
```

### Step 2: provide the EXEC header

The header points EXEC at `MAIN` and `TITLE`. `ZERO` supplies the initial
display mode and colors:

```asm
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
```

### Step 3: customize the title and enter the program

The title procedure returns to EXEC. `MAIN` writes a message and then returns.
At this level there is no game loop:

```asm
TITLE:  PROC
        BYTE    102, "Learning 1", 0
        BEGIN
        RETURN
        ENDP

MAIN:   PROC
        BEGIN
        CALL    CLRSCR
        CALL    PRINT.FLS
        DECLE   C_YEL, $200 + 5*20 + 4
        STRING  "PRESS RESET FOR LEVEL 2", 0
        RETURN
        ENDP
```

### Checkpoint

You have learned how a cartridge starts, where screen text goes, and how
library routines are called. If this level fails, do not add game logic yet.
Compare it with `hello.asm` and fix the header or build command first.

## Level 2: Read a controller and move a background cell

Level 2 introduces the two-part game architecture:

* the main loop reads input and changes game state;
* the VBLANK ISR performs the display-enable handshake.

The player is represented by one colored BACKTAB cell. This is less visually
interesting than a sprite, but it teaches address calculation and makes input
bugs easy to see.

### Step 1: reserve state and install the ISR

```asm
SCRATCH ORG     $100, $100, "-RWBN"
ISRVEC  RMB     2
INPUT   RMB     1

SYSTEM  ORG     $2F0, $2F0, "-RWBN"
STACK   RMB     32
PLAYER  RMB     1
```

Initialize the vector with interrupts disabled:

```asm
        DIS
        MVII    #STACK, R6
        MVII    #VBLANK_ISR, R0
        MVO     R0, ISRVEC
        SWAP    R0
        MVO     R0, ISRVEC+1
        EIS
```

### Step 2: fill a background

`FILLMEM` writes 240 words beginning at `$0200`. The exact word is interpreted
by the selected STIC mode; start with the known-good colored-square pattern in
the example:

```asm
        MVII    #$0200, R4
        MVII    #$00F0, R1
        MVII    #$1352, R0
        CALL    FILLMEM
```

### Step 3: invert active-low input

The example reads the left controller and moves the cell when a direction bit
is present:

```asm
        MVI     $01FF, R0
        XORI    #$00FF, R0
        ANDI    #$00FF, R0
        MVO     R0, INPUT
```

This is raw hardware input, not a decoded keypad event. The bit masks are
kept visible in the source so they can be replaced after testing on the
target emulator or console.

### Step 4: update a BACKTAB address

The example keeps a current cell address in `PLAYER`. For a production game,
keep row and column separately and calculate `$0200 + row*20 + column`.
Writing the cell during active display is unsafe, so the example changes the
RAM state in the main loop and commits it in the ISR.

### Checkpoint

Hold a direction and confirm the colored cell changes. If it moves constantly,
your code is treating a held input as an edge event. If it moves in the wrong
direction, inspect the active-low inversion and mask. If the screen blanks,
check that the ISR writes `$0020` every frame.

## Level 3: Replace the cell with a GRAM MOB

Level 3 adds custom artwork. The player is now an 8x8 GRAM bitmap displayed by
MOB 0.

### Step 1: define an 8x8 bitmap

Bit 7 is the leftmost pixel:

```asm
PLAYER_GFX:
        DECLE   %00111100
        DECLE   %01111110
        DECLE   %11111111
        DECLE   %11011011
        DECLE   %11111111
        DECLE   %01100110
        DECLE   %00100100
        DECLE   %00000000
```

Copy eight words to `$3800` while the display is disabled during startup:

```asm
        CALL    MEMCPY
        DECLE   $3800, PLAYER_GFX, 8
```

### Step 2: create a MOB shadow

The main loop changes `PLAYER_X` and `PLAYER_Y`. The ISR writes those values
to STIC registers:

```asm
SYSTEM  ORG     $2F0, $2F0, "-RWBN"
STACK   RMB     32
PLAYER_X RMB    1
PLAYER_Y RMB    1
PLAYER_A RMB    1
```

The attribute word selects GRAM and a foreground color. Use the symbolic
fields from `gimini.asm`:

```asm
        MVII    #STIC.mobx_visb + 76, R0
        MVO     R0, PLAYER_X
        MVII    #STIC.moby_ysize2 + 44, R0
        MVO     R0, PLAYER_Y
        MVII    #STIC.moba_gram + STIC.moba_fg2, R0
        MVO     R0, PLAYER_A
```

### Step 3: commit the MOB during VBLANK

```asm
        MVI     PLAYER_X, R0
        MVO     R0, STIC.mob0_x
        MVI     PLAYER_Y, R0
        MVO     R0, STIC.mob0_y
        MVI     PLAYER_A, R0
        MVO     R0, STIC.mob0_a
```

An X coordinate of zero disables a MOB. Coordinates are in the STIC object
field, so the visible center is not simply BACKTAB column 10, row 6.

### Checkpoint

First show the player without input. Then add the Level 2 movement code.
Debug in this order: GRAM copy, attribute source/card, nonzero X coordinate,
Y coordinate, and finally movement. `bncpix`, `mob_test`, and `balls1` are
useful comparisons.

## Level 4: Add an enemy, frame timing, and collision

Level 4 changes the display into a game scene. It adds:

* a second MOB;
* an enemy that moves once per video frame;
* a collision result copied from the STIC;
* a score or hit state in ordinary RAM.

### Step 1: keep game state separate from hardware state

```asm
PLAYER_X RMB 1
PLAYER_Y RMB 1
ENEMY_X  RMB 1
ENEMY_Y  RMB 1
HITS     RMB 1
FRAME    RMB 1
```

The main loop owns movement and rules. The ISR owns STIC register access and
copies `STIC.mob0_c` into `HITS`.

### Step 2: use a frame counter

```asm
        MVI     FRAME, R0
        ANDI    #$0003, R0
        BNEQ    @@not_due
        CALL    MOVE_ENEMY
@@not_due:
```

This makes the enemy move every four VBLANKs regardless of how quickly the
main loop spins.

### Step 3: enable interaction

Set the interaction bit in the MOB attribute words. During VBLANK, read the
collision register:

```asm
        MVI     STIC.mob0_c, R0
        MVO     R0, HITS
        CLRR    R0
        MVO     R0, STIC.mob0_c
```

Decode the saved result in the main loop. Do not run score, life, or restart
logic inside the ISR.

### Checkpoint

Make the enemy move predictably before enabling collision. Then deliberately
place the two MOBs on top of each other and verify that the hit state changes.
If collision is always zero, check interaction bits, MOB visibility, and the
order in which the ISR reads and clears the register.

## Level 5: Turn the prototype into a small game

This example combines the previous levels into a tiny game loop:

```text
TITLE -> PLAY -> GAME_OVER
```

The player moves, the enemy patrols, a collision triggers a sound effect, and
the action button restarts the game.

### Step 1: define states

```asm
STATE_PLAY EQU 0
STATE_OVER EQU 1
```

State-specific code keeps title, gameplay, and restart behavior from
interfering with each other:

```asm
        MVI     STATE, R0
        TSTR    R0
        BNEQ    GAME_OVER
        CALL    UPDATE_PLAY
        B       @@loop
GAME_OVER:
        CALL    UPDATE_GAME_OVER
        B       @@loop
```

### Step 2: queue sound instead of mixing it into collision code

The collision rule writes `SFX_PENDING`. A sound routine consumes the request
and programs the PSG:

```asm
        MVII    #1, R0
        MVO     R0, SFX_PENDING
```

This keeps the gameplay routine independent of PSG register details and makes
it possible to replace a one-shot sound with a music/effects driver later.

### Step 3: use a restart path

`RESET_GAME` restores player, enemy, score, state, and sound state. It should
also clear any stale collision result and restore the MOB visibility bits.
Restarting through one routine is safer than partially reinitializing values
from several input branches.

### Step 4: compare with production examples

After completing Level 5, study:

* `examples/mazedemo` for map and rule logic;
* `examples/balls1` for fractional motion and multiple MOBs;
* `examples/handdemo` and `examples/task/scanhand.asm` for decoded events;
* `examples/life` for a larger RAM-backed simulation;
* `examples/game_template` for a framework layout.

This learning example is intentionally not a full commercial engine. Its
purpose is to give each subsystem a visible home that can be expanded.

## Level 6: Add a proper frame-timed sound effect

Level 5 requests a sound when a collision occurs, but it does not yet teach
how to manage the lifetime of that sound. Level 6 isolates the PSG so the
effect can be tested independently, then applies the same pattern to a game.

Read `examples/learning_game/level06_sound/level06_sound.asm` alongside
`doc/programming/psg.txt` and the `UPDATE_SOUND` routine in
`examples/game_template/game_template.asm`.

### Step 1: understand the PSG registers

The master PSG uses these important addresses:

```text
$01F0  channel A period, low byte
$01F4  channel A period, high bits
$01F8  tone/noise enable
$01FB  channel A volume
```

The SDK symbols are preferable to hard-coded addresses:

```asm
        MVO     R0, PSG0.chan_enable
        MVO     R0, PSG0.chn_a_lo
        MVO     R0, PSG0.chn_a_hi
        MVO     R0, PSG0.chn_a_vol
```

The period is a divisor. A smaller period produces a higher tone. The enable
register controls which tone and noise generators are active; the volume
register controls the channel amplitude.

### Step 2: initialize silence

Always silence channels during startup and restart:

```asm
        MVII    #PSG.tone_a_off + PSG.tone_b_off + PSG.tone_c_off, R0
        MVO     R0, PSG0.chan_enable
        CLRR    R0
        MVO     R0, PSG0.chn_a_vol
```

This prevents a previous program or reset state from leaving an unwanted tone
running.

### Step 3: request an effect from game code

Game logic should not contain all PSG register writes. It raises a request:

```asm
        MVII    #1, R0
        MVO     R0, SFX_PENDING
        MVII    #12, R0
        MVO     R0, SFX_TIMER
```

`SFX_TIMER` is measured in frames, not main-loop iterations.

### Step 4: start the tone

The sound routine consumes the request and initializes channel A:

```asm
        MVII    #$40, R0
        MVO     R0, PSG0.chan_enable
        MVII    #$80, R0
        MVO     R0, PSG0.chn_a_lo
        CLRR    R0
        MVO     R0, PSG0.chn_a_hi
        MVII    #$0F, R0
        MVO     R0, PSG0.chn_a_vol
```

The example starts the effect when any new controller input is detected. In a
real game, call the same routine after a jump, shot, collision, or menu
selection.

### Step 5: stop the tone at a predictable time

The VBLANK ISR decrements the timer. When it reaches zero, it disables channel
A and clears its volume:

```asm
        MVI     SFX_TIMER, R0
        BEQ     @@sound_done
        DECR    R0
        MVO     R0, SFX_TIMER
        BNEQ    @@sound_done
        MVII    #PSG.tone_a_off, R0
        MVO     R0, PSG0.chan_enable
        CLRR    R0
        MVO     R0, PSG0.chn_a_vol
@@sound_done:
```

This keeps the effect duration stable even when the main loop does different
amounts of work. Keep the PSG writes short and never put a long music decoder
inside the ISR.

### Checkpoint

Build `level06_sound.asm`, press a controller input, and verify that the tone
starts and stops by itself. Then change the period, volume, and timer one at a
time. If there is no sound, check the channel enable mask, volume, and that the
effect request is actually set. If the sound never stops, check the timer
decrement and the zero transition.

### Exercises

* Give the effect two notes by changing the period halfway through the timer.
* Use the noise generator for an explosion-like effect.
* Reserve channel A for sound effects and add a music driver on channels B/C.
* Add a `SFX_PRIORITY` value so an important effect can interrupt a weaker one.

## A disciplined debugging method

When a new level fails, return to the last working level and add one subsystem:

1. assemble and inspect errors;
2. run the title screen;
3. verify `MAIN` is entered;
4. verify a stable background;
5. verify the ISR display handshake;
6. verify one input bit;
7. verify one GRAM card;
8. verify one MOB;
9. verify collision;
10. verify sound;
11. only then add more actors or map logic.

Do not debug input, GRAM timing, collisions, and sound simultaneously. A
successful assembly only proves that the syntax and symbols are valid; it
does not prove that a STIC access happened during its legal timing window.

## Exercises

After each level, make one small change:

* Level 1: change the title and message colors.
* Level 2: add screen-edge clamping.
* Level 3: draw a second animation frame.
* Level 4: make the enemy reverse at two boundaries.
* Level 5: add a score and a limited number of lives.
* Level 6: add two sound effects with different periods and durations.

## Level 7: Decode controller input

Raw controller ports are active-low and contain keypad, disc, and button
bits. A game should not spread those hardware masks through its rules. Decode
the scan result once, retain held and newly-pressed values, and pass a small
action word to gameplay. `examples/task/scanhand.asm` supplies the production
debounce and dispatch implementation; `level07_scanhand.asm` is the small
standalone bridge that makes the decode boundary visible. `SCANHAND` is a
background routine, not an ISR: call it regularly and keep its dispatch
handlers short.

## Level 8: Animate GRAM

Upload GRAM cards while display access is disabled, then animate by changing a
MOB's card number during VBLANK. Keep the current frame in RAM and commit it
from the ISR; never rewrite an eight-word bitmap in the middle of active
display. The example uses two eight-row frames and a frame counter. Add a
third card only after the two-frame timing is stable.

## Level 9: Collide with a tile map

Store the map as compact tile IDs, calculate `row * map_width + column`, and
look up the destination tile before committing a movement. Zero can represent
floor while nonzero IDs represent walls, hazards, or doors. Keep map
coordinates separate from MOB pixel coordinates so the same rule works while
the camera scrolls.

## Level 10: Scroll the camera

A scrolling game moves the camera, not the player sprite. Track a world
coordinate and a tile-aligned camera origin, redraw only the newly exposed
column or row, and leave HUD cells outside the map viewport. Coarse tile
scrolling is the reliable first milestone; smooth pixel scrolling can be
added after the BACKTAB update fits the VBLANK budget.

## Level 11: Draw a HUD

Reserve the top or bottom BACKTAB rows for score, lives, and prompts. Update
only changed fields and format numbers with `PRINT.FLS` or the numeric
library routines. A HUD is ordinary display memory, but it has a different
ownership rule from the scrolling map: camera redraws must never overwrite
its cells.

## Level 12: Finish the state flow

Use explicit `TITLE`, `PLAY`, and `GAME_OVER` states. Each state owns its
input, drawing, and transition conditions; a single reset routine restores
player, score, sound, and collision state. The example intentionally cycles
the states so the dispatch structure can be observed without requiring a
complete game.

## Level 13: Add randomness

Seed `RAND` once from a non-repeatable value when possible (or combine reset
RAM, controller timing, and a counter), then use bounded results for spawn
positions and variations. Do not use a random value directly as a pointer or
tile index without range reduction. Reproducible fixed seeds are valuable
while debugging; change the seed only for the release build.

## Level 14: Music and advanced PSG

Treat channels B/C as music voices and reserve channel A for effects, or
implement a priority mixer that can temporarily steal a voice. A tracker
advances one short pattern step per frame; it must not decode an entire song
inside VBLANK. Save/restore channel enable, period, and volume when an effect
interrupts music, and always provide a silence path on restart.

## Level 15: VBLANK and production layout

The ISR should do a bounded display handshake, copy a small set of MOB
shadows, sample collision, and advance frame clocks. Queue expensive work for
the main loop. For a cartridge build, keep the EXEC header and fixed entry
points in the fixed bank, put large maps/music in banked ROM, and document
the bank switch protocol. `CFGVAR` metadata, a repeatable build script, and
an emulator smoke test turn an assembled demo into a shippable cartridge.

Keep each exercise in a separate copy until it works. This creates a sequence
of known-good checkpoints that is invaluable when a later optimization breaks
the display.
