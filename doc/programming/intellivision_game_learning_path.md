# Learning to Make an Intellivision Game

This tutorial is a practical course in making an Intellivision game with the
AS1600 assembler. It starts with a title screen and ends with a small
gameplay framework containing a player, an enemy, input, collision detection,
sound, and a frame-driven update loop. Star Dodger is used only for the final
integration lesson; the earlier lessons teach reusable Intellivision
techniques without assuming a particular game.

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
| 1 | EXEC startup, ROM metadata, title, text, and entry point | `level01_title/level01_title.asm` |
| 2 | BACKTAB background, VBLANK, and direct controller polling | `level02_input/level02_input.asm` |
| 3 | GRAM artwork and one controllable MOB | `level03_player/level03_player.asm` |
| 4 | Game state, frame timing, enemy movement, and collision | `level04_collision/level04_collision.asm` |
| 5 | A reusable mini-game loop with restart state | `level05_game/level05_game.asm` |
| 6 | PSG sound effects, frame timing, and sound shutoff | `level06_sound/level06_sound.asm` |
| 7 | Decoded controller events with SCANHAND-style debouncing | `level07_scanhand/level07_scanhand.asm` |
| 8 | Double-buffered GRAM animation and MOB card selection | `level08_gram_animation/level08_gram_animation.asm` |
| 9 | Tile-map lookup and solid-tile collision rules | `level09_tile_collision/level09_tile_collision.asm` |
| 10 | Camera coordinates and coarse tile-map scrolling | `level10_scrolling/level10_scrolling.asm` |
| 11 | HUD text, score formatting, and screen layout | `level11_hud_text/level11_hud_text.asm` |
| 12 | Complete title/play/game-over state flow | `level12_state_flow/level12_state_flow.asm` |
| 13 | Deterministic random seeds and the SDK random routine | `level13_randomness/level13_randomness.asm` |
| 14 | PSG channels, music ownership, and effect priorities | `level14_music_psg/level14_music_psg.asm` |
| 15 | VBLANK budgets, ROM banking, and production cartridge layout | `level15_production/level15_production.asm` |

The examples deliberately use direct polling before introducing `SCANHAND`.
That makes the hardware model visible. Replace direct polling with
`examples/task/scanhand.asm` when building a larger production game.

Every level is a standalone checkpoint. Levels 7–15 deliberately revisit
earlier small programs rather than pretending that one large engine is the
only way to learn. The final Star Dodger lesson then composes selected
techniques and clearly lists what it still leaves out.

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

## The machine model used throughout

It helps to keep three kinds of memory separate. Cartridge ROM holds the EXEC
header, code, constants, and usually maps and music. General-purpose RAM holds
game state and *shadows* of values that will later be committed to hardware.
STIC memory-mapped registers expose BACKTAB, GRAM, MOBs, collision results, and
timing controls. A RAM variable is not automatically a safe STIC write: the
frame boundary determines when the write is legal.

Initialization happens once, with display-sensitive work disabled: install the
stack and interrupt vector, clear state, silence the PSG, upload GRAM cards,
fill BACKTAB, and initialize MOB shadows. The ordinary main loop then reads
input, updates rules, queues work, and dispatches the current state. The
VBLANK ISR is the short commit phase:

```text
EXEC -> TITLE/MAIN initialization
        main loop: input -> rules -> RAM shadows/requests
        VBLANK: handshake -> STIC shadows/collision -> frame clocks
```

The `$0020` display-enable handshake in the examples is part of the EXEC/STIC
timing contract. Keep the ISR bounded and deterministic. Do not put map
redrawing, number formatting, or a music decoder in it merely because those
operations are convenient to call there. This ownership model is the central
idea behind Levels 2–15.

The source tree mirrors the progression: each `levelNN_name` directory has a
same-named `.asm` file and can be assembled independently. Library examples
such as `examples/hello`, `examples/game_template`, and `examples/task` are
comparisons, not hidden prerequisites. Read the level source, its listing, and
the relevant SDK include together; a prose claim never substitutes for
running the cartridge.

## Level 1: Put a title and message on the screen

Start with the smallest useful cartridge. The goal is not yet to make a game;
it is to prove that the assembler, ROM header, EXEC title screen, and library
include path work.

Read `examples/learning_game/level01_title/level01_title.asm` alongside
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

Read `examples/learning_game/level02_input/level02_input.asm`.

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

Read `examples/learning_game/level03_player/level03_player.asm`.

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

Read `examples/learning_game/level04_collision/level04_collision.asm`.

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

Read `examples/learning_game/level05_game/level05_game.asm`.

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

Raw controller ports are useful for learning but awkward for game rules. The
bits are active-low, the disc and keypad share a scan interface, and a held
button is not the same event as a newly pressed button. Read the complete
hardware result in one place, convert it to a small action word, and let the
rest of the program consume that word.

Read `examples/learning_game/level07_scanhand/level07_scanhand.asm` with
`examples/task/scanhand.asm`. The lesson initializes `SCANHAND` and `RUNQ` and
records an event; it intentionally does not move an actor. `SCANHAND` is a
background routine, not an interrupt routine: call it regularly and keep its
handlers short.

A useful ownership boundary is:

```text
controller hardware -> SCANHAND -> held/pressed action bits -> game rules
```

Keep `held` for continuous movement and `pressed` for one-shot actions such
as pause or fire. If an action repeats unexpectedly, inspect the edge
calculation before changing the game state machine.

**Exercise:** add a `pressed` value beside `LAST_EVENT`, then make a test
handler fire only on the transition from zero to nonzero. Compare the result
with direct polling from Level 2.

## Level 8: Animate GRAM

GRAM is writable character memory. Uploading an eight-word bitmap creates an
art asset, while a MOB attribute selects which card to display. Upload cards
when display access is disabled; during VBLANK, change only the MOB's card
selection and other small shadows. Rewriting bitmap words during active display
can produce tearing or corrupt the visible card.

`examples/learning_game/level08_gram_animation/level08_gram_animation.asm`
uploads two cards and alternates them from a frame counter. The important
pattern is `animation_frame` in ordinary RAM and `MOB_A_SHADOW` as the value
committed at the frame boundary. The example is not a complete player and has
no controller or collision rules.

Start with two visibly different cards. Confirm one static card, then switch
cards every 8 or 16 frames (the exact divider is a teaching constant). Add a
third card only after the upload and VBLANK commit are stable.

**Exercise:** make animation stop while a state is paused, and ensure that
changing the frame counter cannot write GRAM from the main loop.

## Level 9: Collide with a tile map

A tile map is ordinary ROM or RAM data; it is not the same thing as BACKTAB.
Store compact tile IDs, calculate `row * map_width + column`, and inspect the
destination tile before committing a movement. Reserve one convention (for
example, zero is floor and nonzero is solid) and document exceptions such as
hazards and doors.

`examples/learning_game/level09_tile_collision/level09_tile_collision.asm`
contains a small `TILE_MAP`, a bounded lookup, and a solid/non-solid branch.
It does not render a map or perform pixel-perfect MOB collision. Keeping map
coordinates separate from screen coordinates is what makes this rule survive
camera movement.

```asm
; candidate_x/candidate_y are map coordinates, not STIC pixels
        ; index = candidate_y * MAP_WIDTH + candidate_x
        ; reject the move when TILE_MAP[index] is SOLID
```

**Exercise:** add an out-of-bounds wall and test all four edges. Then add a
hazard tile that is passable but raises a gameplay event instead of blocking.

## Level 10: Scroll the camera

A camera changes which part of a world is shown; it does not move the player
through the world. Keep world coordinates, camera origin, and screen
coordinates as separate values. A first implementation scrolls by whole
BACKTAB columns or rows: calculate the newly exposed strip and redraw it.
Smooth pixel scrolling can come later, after the VBLANK work fits.

`examples/learning_game/level10_scrolling/level10_scrolling.asm` stores a
camera and coarse-X value and shows the legal STIC delay write in a separate
`VBLANK_ISR_CAMERA`. The checkpoint does not install a complete scrolling
renderer. That limitation is intentional: a counter is not a map engine.

Reserve HUD rows outside the map viewport. Never let a camera redraw overwrite
those BACKTAB cells, and do not confuse BACKTAB cell coordinates with MOB
pixel/object coordinates.

**Exercise:** clamp the camera to both world edges and redraw one exposed
column. Log the camera origin in RAM while testing so an off-by-one can be
seen in the listing/emulator.

## Level 11: Draw a HUD

A HUD is a small, stable BACKTAB layout owned by the game state, while a map
renderer owns the remaining cells. Reserve rows for score, lives, prompts, or
a pause label. Update only changed fields; repeatedly formatting every field
inside the frame boundary wastes time.

`examples/learning_game/level11_hud_text/level11_hud_text.asm` increments a
score and supplies explicit BACKTAB character data. It is deliberately honest:
it does not provide a general number formatter or a complete production HUD.
Use `PRINT.FLS` for fixed labels and the SDK numeric routines (or a small
fixed-width conversion routine) for changing values. Define whether scores
wrap, saturate, or use BCD before writing the renderer.

**Exercise:** display a two-digit counter with leading zeroes, then update it
only when the value changes. Verify that camera redraw leaves the HUD intact.

## Level 12: Model the state flow

State is the answer to “which rules own this frame?” Use explicit constants
and a single dispatch point instead of scattered flags:

```text
TITLE -> PLAY -> PAUSE -> PLAY
                 \-> GAME_OVER -> TITLE
```

`examples/learning_game/level12_state_flow/level12_state_flow.asm` cycles
through `STATE_TITLE`, `STATE_PLAY`, `STATE_PAUSE`, and `STATE_GAMEOVER` so the
dispatch shape can be observed. It does not pretend that each state already
has a finished renderer or input policy.

Each state should own its entry work, allowed input, drawing requests, and
transition conditions. A single `RESET_GAME` routine should restore player,
enemy, score, lives, sound requests, collision results, and MOB visibility.
Do not partially reset these values from several button branches.

**Exercise:** add a debounced pause transition using Level 7's `pressed` bit,
then make GAME_OVER ignore movement while accepting restart.

## Level 13: Add controlled randomness

Randomness is useful for spawn positions and variation, but unbounded random
words are not valid pointers or map indices. Seed `RAND` once, reduce its
result to the desired range, and keep a fixed seed while debugging so a bug
reproduces.

`examples/learning_game/level13_randomness/level13_randomness.asm`
demonstrates a deterministic local routine and stores its output. It does not
spawn an actor. A release build may mix reset RAM, controller timing, and a
counter for a less predictable seed, but reproducible tests are more valuable
than novelty during development.

**Exercise:** map a random value into columns `0..MAP_WIDTH-1` without modulo
bias concerns being hidden, then reject a solid tile using Level 9's lookup.
Record the seed when reporting a bug.

## Level 14: Share PSG voices

The PSG has three tone channels and noise controls. Decide who owns each
channel. A simple design reserves channel A for effects and B/C for music; a
more advanced mixer temporarily steals a voice and restores its period,
volume, and enable state afterward. Always provide a silence path on reset and
game-over.

`examples/learning_game/level14_music_psg/level14_music_psg.asm` sequences
two notes and gives an effect-priority branch. It is not a tracker and does
not restore a stolen voice. A music driver should advance one short pattern
step per frame, not decode an entire song inside VBLANK.

The PSG writes are frame-timed just like movement. A request (`SFX_PENDING`,
priority, and duration) belongs to game state; the audio routine translates it
to PSG registers. This keeps collision code independent of hardware details.

**Exercise:** let an effect interrupt one music note, save the displaced
register values, and restore them when the effect timer reaches zero.

## Level 15: Budget the frame and the cartridge

The VBLANK ISR has a bounded job: perform the display-enable handshake, copy a
small set of MOB shadows, sample/clear collision, and advance short frame
clocks. Queue expensive map, AI, formatting, and music work for the main loop.
The main loop may spin at a different rate; gameplay timers must therefore be
based on VBLANK frames, not loop iterations.

`examples/learning_game/level15_production/level15_production.asm` marks a
fixed-bank layout and counts bounded work. It does not implement bank
switching, so the markers are a review aid rather than a performance claim.
For a real cartridge, keep EXEC entry points and the fixed header reachable,
put large maps/music in documented banked regions, and specify the bank
switch protocol. `CFGVAR`, a repeatable build command, an emulator smoke test,
and source control for generated listings turn a demo into a maintainable
cartridge.

**Exercise:** list every ISR write and its maximum count per frame. Move one
nonessential operation to the main loop, then compare the behavior rather than
assuming the optimization is safe.

## Let’s put it all together: Star Dodger

`examples/learning_game/star_dodger/star_dodger.asm` is the final integrated
lesson, not the framing story for the preceding levels. Read it only after
building the checkpoints above. It combines the reusable patterns as a small
working composition:

* EXEC startup, title entry, initialization, and a frame-driven main loop;
* raw controller sampling and explicit TITLE, PLAY, PAUSE, and GAME_OVER
  dispatch;
* GRAM starship/meteor artwork, MOB RAM shadows, VBLANK commits, and STIC
  collision sampling;
* score and three lives in ordinary RAM, collision rules in the main loop;
* a queued, short PSG alert whose lifetime is measured in VBLANK frames.

It intentionally omits a complete formatted HUD renderer, SCANHAND event
integration, a scrolling tile-map renderer, sophisticated meteor spawning,
music restoration/mixing, pixel-perfect collision, and production bank
switching. Those omissions are honest next steps, not hidden features. The
source is a scaffold for inspection and extension rather than a finished
commercial game.

Build from its own directory:

```text
D:\source\Repos\Intellivision\jzintvSDK\bin\as1600.exe ^
  -o star_dodger.bin -l star_dodger.lst star_dodger.asm
```

Compare its ISR and RAM ownership with Levels 2–6, then make one change at a
time. Do not copy generated `.bin`, `.cfg`, or `.lst` files into the source
tree.

## Debugging checklist

When a cartridge fails, return to the smallest visible result:

1. assemble and inspect errors and the listing;
2. verify the ROM header, `TITLE`, `MAIN`, and stack initialization;
3. verify the `$0020` VBLANK handshake and that interrupts are installed;
4. verify one BACKTAB cell before adding GRAM or MOBs;
5. verify GRAM upload, MOB attribute, visibility, and coordinates separately;
6. verify active-low polarity and held-versus-pressed input;
7. verify collision interaction bits before adding score or lives;
8. verify PSG enable, period, volume, and timer independently;
9. add camera, HUD, and bank work only after the small loop is stable.

An assembled binary proves syntax and symbol resolution, not correct STIC
timing or game rules. Change one subsystem at a time, keep a known-good copy,
and test on the emulator as well as hardware when available.

## Exercises and extensions

* Replace the Level 2 colored cell with a bounded cursor and a second input.
* Add two animation frames to a Level 3 MOB without moving GRAM writes into
  the frame ISR.
* Give Level 5 separate lives and score, then reset both through one routine.
* Add a pause state and a fixed-width HUD to the Level 12 scaffold.
* Make Level 13 spawn only on non-solid tiles and record the seed.
* Add a music voice to Level 14 while preserving effect priority and silence.
* Measure the Level 15 ISR's worst-case work and document the result beside the
  source layout.

## Glossary

* **BACKTAB:** the STIC background name/color table, normally 20 columns by 12
  rows; it selects cards and display attributes for background cells.
* **GRAM:** writable graphics memory used for custom 8x8 cards.
* **MOB:** a movable object described by STIC position, card, color, and
  interaction attributes.
* **STIC:** the Standard Television Interface Chip, responsible for display,
  BACKTAB, GRAM, MOBs, timing, and collision reporting.
* **EXEC:** the Intellivision executive ROM that calls the cartridge title,
  initializes the machine, and enters the cartridge's main entry point.
* **VBLANK:** the vertical blank interval and the safe frame boundary used by
  these examples for the display handshake and small STIC updates.
* **PSG:** the programmable sound generator with three tone channels and noise
  control.
* **ISR:** interrupt service routine; here it must remain short and bounded.
* **RAM shadow:** ordinary RAM copy of a hardware/display value that gameplay
  can update before the ISR commits it.
* **SCANHAND:** SDK controller scanning/dispatch support that turns raw scans
  into debounced action events.

## Appendix: source and build map

Each lesson's assembly file lives in a same-named directory under
`examples/learning_game/`, so relative includes resolve when AS1600 is run
there. For example, Level 10 is
`examples/learning_game/level10_scrolling/level10_scrolling.asm`, and the
integrated lesson is
`examples/learning_game/star_dodger/star_dodger.asm`.

Build one lesson, inspect its `.lst`, run the resulting cartridge in an
Intellivision emulator, and remove generated artifacts. The examples are
teaching checkpoints: they may expose a hardware boundary without implementing
the entire feature named by the lesson. Read the source and test the binary
before generalizing from a label or table entry.
