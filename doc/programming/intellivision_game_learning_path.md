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
| 8 | Two-frame GRAM animation and MOB card selection | `level08_gram_animation/level08_gram_animation.asm` |
| 9 | Tile-map lookup and solid-tile collision rules | `level09_tile_collision/level09_tile_collision.asm` |
| 10 | Camera coordinates and a coarse STIC scroll value | `level10_scrolling/level10_scrolling.asm` |
| 11 | HUD layout, explicit character data, and screen ownership | `level11_hud_text/level11_hud_text.asm` |
| 12 | Complete title/play/game-over state flow | `level12_state_flow/level12_state_flow.asm` |
| 13 | Deterministic random seeds and bounded random values | `level13_randomness/level13_randomness.asm` |
| 14 | PSG channels, music ownership, and effect priorities | `level14_music_psg/level14_music_psg.asm` |
| 15 | VBLANK budget markers and production cartridge layout | `level15_production/level15_production.asm` |

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
* `as1600.exe` available on your `PATH`;
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

## Common pitfalls, errors, and misunderstandings

Keep this section open while working through the lessons. Most early failures
are recurring mistakes rather than mysterious hardware faults. When a symptom
matches one of these entries, fix the underlying assumption before adding more
code.

### Build and source problems

* **“The assembler is not recognized.”** The command is `as1600.exe`, not a
  repository-specific absolute path. Put the SDK `bin` directory on `PATH`, or
  use a shell where that directory has already been added.
* **“The include file cannot be opened.”** Run AS1600 from the example's own
  directory. The learning sources use relative includes such as
  `../../library/gimini.asm`; running from the repository root changes what
  those paths mean.
* **“It assembled, so the game must be correct.”** Assembly proves syntax,
  symbols, and output generation only. It does not prove a valid ROM header,
  legal STIC timing, visible coordinates, correct input polarity, or correct
  game rules. Always run the binary and inspect the listing.
* **“The emulator cannot find the cartridge.”** Copy both the `.bin` and its
  matching `.cfg` file to the emulator's ROM directory. Keep their base names
  matching; a `.lst` file is not required at runtime.
* **“Old behavior remains after a rebuild.”** The emulator may be loading a
  copy from another directory. Check the file timestamp and ROM path, and
  remove stale copies before diagnosing source code.

### Startup and memory mistakes

* **Skipping `DIS` while installing the vector.** Disable interrupts before
  changing the stack or ISR vector, then enable them only after initialization
  is complete. See [the startup sequence in Level 2](#step-1-reserve-state-and-install-the-isr).
* **Putting state in the wrong memory region.** Keep ordinary variables in
  RAM `ORG` regions and code/assets in cartridge ROM. A label's name does not
  make a location writable.
* **Forgetting the stack.** `CALL`, `RETURN`, and many SDK routines depend on
  a valid stack in `R6`. Initialize it before calling library procedures.
* **Confusing `DECLE` data with executable code.** A table of words or bitmap
  rows is data; it becomes useful only when a routine reads it or copies it to
  the appropriate hardware address.
* **Changing a ROM pointer without checking byte order.** Cartridge header
  pointers use the SDK's `BIDECLE` convention. Copy the established header
  pattern before inventing a new one.

### Display, GRAM, and MOB mistakes

* **Forgetting the `$0020` handshake.** The VBLANK ISR must perform the
  display-enable write every frame. A missing or misplaced handshake can make
  a correct program appear blank.
* **Writing every display value directly from the main loop.** Keep positions
  and attributes in RAM shadows, then commit the small set of STIC writes in
  VBLANK. This prevents partially updated objects and makes timing ownership
  visible.
* **Treating BACKTAB coordinates as MOB coordinates.** BACKTAB uses a
  20-by-12 character grid; MOB positions use STIC object fields. Screen cell
  `(10,6)` is not automatically the visual center of a MOB.
* **Using X zero for a visible MOB.** In these examples an X value of zero
  disables the MOB. Set visibility and interaction bits in the attribute word
  as well as choosing a nonzero position.
* **Selecting the wrong GRAM card.** Uploading artwork to `$3800` does not
  guarantee that the MOB selects card zero with the expected color. Check the
  card offset, GRAM bit, foreground color, visibility, and the listing.
* **Uploading GRAM every frame.** For animation, upload cards once and change
  the MOB card selection at the frame boundary unless measured timing proves
  that repeated bitmap writes are safe.
* **Assuming a collision is a game rule.** STIC reports an interaction fact.
  The main loop must decide whether it means damage, a score, a bounce, or
  nothing. Read and clear the collision result in a predictable place.

### Input, timing, and sound mistakes

* **Forgetting active-low input.** A pressed control is commonly represented
  by zero at the hardware port. Normalize and mask the input before comparing
  it with game constants.
* **Confusing held with pressed.** Held input is appropriate for movement;
  pressed/edge input is appropriate for start, pause, and fire. Use `SCANHAND`
  or an explicit previous/current comparison for one-shot actions. See
  [Level 7](#level-7-decode-controller-input).
* **Using main-loop iterations as time.** The main loop can run many times per
  video frame or stall while doing work. Use a VBLANK frame counter for
  movement cadence, animation, sound duration, and delays.
* **Making the ISR do game logic.** The ISR should handshake, commit shadows,
  sample hardware facts, and advance short clocks. Keep collision consequences,
  map rendering, formatting, AI, and long PSG/music work in the main loop.
  See [the frame-budget lesson](#level-15-budget-the-frame-and-the-cartridge).
* **Treating PSG period as frequency.** The PSG period is a divisor: smaller
  values produce higher tones. A tone also needs the correct enable mask and
  nonzero volume, plus an explicit silence path.
* **Sharing a PSG channel accidentally.** Music and sound effects must agree
  on channel ownership, or one routine silently overwrites another's state.
  See [Level 14](#level-14-share-psg-voices).

### Coordinates, maps, and game rules

* **Mixing coordinate systems.** Keep world/map coordinates, camera
  coordinates, BACKTAB row/column coordinates, and MOB object fields in
  separate variables. Convert between them deliberately.
* **Moving before checking the destination tile.** Compute the candidate
  position, inspect its tile, and commit the move only when the tile is
  allowed. Define out-of-bounds behavior explicitly.
* **Assuming a tile map is automatically rendered.** A tile map is data.
  Rendering it requires a separate BACKTAB update and camera policy. See
  [Level 9](#level-9-collide-with-a-tile-map) and
  [Level 10](#level-10-scroll-the-camera).
* **Using an unbounded random value as an index.** Reduce a random word to a
  documented range, reject invalid or solid positions, and use a fixed seed
  while debugging so failures can be reproduced.
* **Resetting only visible values.** A restart must clear score, lives, timers,
  collision results, pending sounds, animation counters, and visibility—not
  only the positions currently on screen.

When in doubt, return to the
[disciplined debugging method](#a-disciplined-debugging-method) and test one
ownership boundary at a time.

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
If the screen is blank or input moves in the wrong direction, start with
[Common pitfalls](#common-pitfalls-errors-and-misunderstandings), especially
the handshake, active-low input, and coordinate notes.

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
For an invisible or incorrectly colored object, use the
[GRAM and MOB pitfalls](#display-gram-and-mob-mistakes) before changing the
movement code.

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
If the effect is silent or never ends, check the
[input, timing, and sound pitfalls](#input-timing-and-sound-mistakes).

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
The [common pitfalls](#common-pitfalls-errors-and-misunderstandings) section
maps these symptoms to the most likely incorrect assumptions.

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
uploads two cards and alternates them from a frame counter. This is two-frame
card animation, not a complete double-buffered renderer. The important
pattern is `FRAME` in ordinary RAM and the selected card value committed at the
frame boundary. The example is not a complete player and has
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
score and supplies explicit BACKTAB character data while the corrected ISR
keeps the display handshake active. It is deliberately honest:
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
as1600.exe ^
  -o star_dodger.bin -l star_dodger.lst star_dodger.asm
```

### Why this example is organized this way

The integrated game is deliberately split into three layers:

```text
MAIN loop       reads input, selects the state, applies rules, requests sound
RAM variables   hold score, lives, positions, state, and pending work
VBLANK ISR      commits MOB shadows, samples collision, advances frame time
```

The main loop never assumes that it is running once per video frame. The ISR
increments `FRAME`, so frame-based work has a stable clock. The main loop owns
the meaning of a collision; the ISR only copies the STIC result into `HITS`.
This is the most important design lesson in the final example:

> Hardware-facing code reports facts; game code decides what those facts mean.

### Step 1: identify the cartridge entry path

Start at `ROMHDR`, then follow the pointers:

```text
ROMHDR -> TITLE -> MAIN -> RESET_GAME -> main loop
                                  \-> VBLANK_ISR through ISRVEC
```

`MAIN` disables interrupts while it installs the stack, interrupt vector, and
initial GRAM cards. It then calls `RESET_GAME`, which gives the game a known
score, life count, sound state, and pair of MOB positions before interrupts
are enabled. This prevents a reset from inheriting stale gameplay state.

### Step 2: understand the game state machine

`STATE` selects one of four paths. `READ_INPUT` derives `PRESSED` from the
current and previous raw input, so holding a start or pause control does not
toggle a state repeatedly:

| State | What it does | How it leaves |
| --- | --- | --- |
| `STATE_TITLE` | waits for the start input | start input enters play |
| `STATE_PLAY` | moves objects, handles collisions, awards score | lives reaching zero enters game over |
| `STATE_PAUSE` | leaves gameplay values unchanged | pause input returns to play |
| `STATE_OVER` | waits without advancing the game | start input calls `RESET_GAME` |

The state value is data, not a collection of scattered jumps. To add a
countdown or an attract mode, add a state and define its input, update, and
transition rules separately.

### Step 3: follow one frame of play

During a normal play iteration:

1. `READ_INPUT` reads the active-low left controller and stores a normalized
   value in `INPUT`.
2. The play branch changes the starship position when input is present.
3. Every fourth frame, the main loop moves the meteor left and wraps it to the
   right edge. The VBLANK-driven `FRAME` value provides the timing source.
4. `VBLANK_ISR` writes the RAM positions and attributes into MOB 0 and MOB 1.
5. The ISR copies MOB 0's collision result into `HITS`.
6. The next main-loop pass sees `HITS`, decrements `LIVES`, increments `SCORE`,
   and starts the alert tone.

Notice the one-frame boundary: the main loop does not read a half-updated STIC
register set, and the ISR does not perform score or life logic.

### Step 4: understand the two GRAM cards

The source copies `STARSHIP_GFX` to GRAM card 0 and `METEOR_GFX` to GRAM card 1.
The MOB attribute words select GRAM and the appropriate card. The artwork is
loaded once while the display is disabled; the ISR only writes the small MOB
attribute and position values afterward.

To add animation, upload a second starship card during initialization and
change the starship attribute in the ISR from a RAM animation value. Do not
copy eight bitmap words every frame unless the VBLANK budget has been measured.

### Step 5: understand collision and scoring

`STIC.mob0_c` is a hardware report, not a game rule. The example saves it as
`HITS`, clears the saved value in the main-loop path, and then applies rules:

```text
collision -> lives = lives - 1
          -> score = score + 1
          -> start alert sound
          -> game over when lives == 0
```

The scoring rule is intentionally simple so the data flow is visible. A real
game might respawn the meteor, add invulnerability frames, flash the border,
or subtract score instead.

### Step 6: understand the sound request

The collision path starts a short PSG channel-A tone and stores a frame timer.
The ISR decrements the timer and silences the channel when it expires. This
keeps the sound duration independent of main-loop speed. A production game
would replace this direct write with the Level 14 music/effect ownership
scheme, but the small version is easier to trace.

### Build, run, and inspect in stages

Do not begin by changing the whole file. Use this order:

1. Build and run it unchanged; verify the title and start path.
2. Change only the title text.
3. Change the starship X start position.
4. Change the meteor X start position until a collision is easy to observe.
5. Change `LIVES` from three to one and confirm game over.
6. Change the tone period and timer.
7. Add one animation frame.

After every change, ask which layer owns it: main-loop rules, RAM state, or
VBLANK hardware commit. That question is more valuable than memorizing the
instruction sequence.

### What this final lesson does not do

The integrated source is a teaching skeleton, not a finished game. It does
not yet provide:

* directional decoded input through `SCANHAND`;
* a scrolling tile map or tile-based collision;
* formatted score/lives HUD text;
* robust edge clamping or meteor respawning;
* invulnerability, animation timing, or multiple enemies;
* music restoration after a sound effect;
* fixed-point movement or pixel-perfect collision;
* ROM bank switching, save data, or a production asset pipeline.

Each omission points back to a preceding lesson. Add one feature at a time and
keep the integrated source buildable after each change. A sensible next order
is `SCANHAND`, edge clamping, HUD, meteor respawn, animation, music, and only
then scrolling or bank switching.

Do not copy generated `.bin`, `.cfg`, or `.lst` files into the source tree.

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

* **AS1600:** the assembler used by these examples; it converts source
  mnemonics, directives, symbols, and data into an Intellivision cartridge
  image and listing.
* **BACKTAB:** the STIC background name/color table, normally 20 columns by 12
  rows; it selects cards and display attributes for background cells.
* **BIDECLE:** an SDK assembler directive that emits a pointer in the byte
  order expected by the EXEC cartridge header.
* **CFGVAR:** an AS1600/SDK build directive that stores cartridge metadata in
  the generated CFG file.
* **Color Stack:** a STIC display mode in which background cells select colors
  from a small rotating stack rather than carrying an independent full color
  value.
* **DECLE:** an AS1600 directive that emits one or more 16-bit words.
* **EXEC:** the Intellivision executive ROM that calls the cartridge title,
  initializes the machine, and enters the cartridge's main entry point.
* **ROMHDR:** the cartridge header data structure containing the EXEC entry
  pointers, title pointer, display initialization data, and other metadata.
* **TITLE:** the cartridge procedure called by EXEC to show or identify the
  cartridge before `MAIN` is entered.
* **MAIN:** the cartridge's normal initialization and game-loop entry point.
* **Fixed-point value:** an integer whose bits are deliberately divided into
  whole-unit and fractional parts, allowing smooth motion without floating
  point.
* **GROM:** read-only graphics memory containing the built-in 8x8 character
  cards.
* **GRAM:** writable graphics memory used for custom 8x8 cards.
* **MOB:** a movable object described by STIC position, card, color, and
  interaction attributes.
* **Interaction bits:** MOB attribute flags that enable STIC collision reports
  between selected objects.
* **MOB shadow:** a RAM copy of a MOB's position or attribute word; the main
  loop changes the shadow and the ISR commits it to STIC.
* **Collision register:** a STIC read/clear register containing hardware
  interaction results; it reports overlap facts, not score or damage rules.
* **ISR vector:** the RAM address pair through which the CPU reaches the
  installed interrupt service routine.
* **ROMW:** an AS1600 directive selecting the cartridge word width/layout.
* **STIC:** the Standard Television Interface Chip, responsible for display,
  BACKTAB, GRAM, MOBs, timing, and collision reporting.
* **Task queue:** a small FIFO of deferred controller or system events; its
  handlers should do little work and leave game rules to the main loop.
* **Debouncing:** converting a held physical control into a single press event
  plus a separate held state, so menus do not toggle repeatedly.
* **Tile map:** compact world data whose tile IDs are interpreted by collision
  and rendering rules; it is separate from the STIC BACKTAB.
* **Camera:** the world-to-screen offset used to choose which map region is
  visible; moving the camera is not the same as moving the player.
* **HUD:** a stable screen region reserved for score, lives, prompts, or
  status text rather than map cells.
* **Bank switching:** changing which ROM region is visible at a selected
  address, allowing a cartridge to hold more code or assets than one fixed
  mapping can expose.
* **Active-low:** a digital signal convention in which zero means asserted
  or pressed and one means inactive.
* **BCD:** binary-coded decimal, a representation that stores each decimal
  digit separately; it is useful for scores only when the display and arithmetic
  rules require it.
* **VBLANK:** the vertical blank interval and the safe frame boundary used by
  these examples for the display handshake and small STIC updates.
* **PSG:** the programmable sound generator with three tone channels and noise
  control.
* **ISR:** interrupt service routine; here it must remain short and bounded.
* **RAM shadow:** ordinary RAM copy of a hardware/display value that gameplay
  can update before the ISR commits it.
* **SCANHAND:** SDK controller scanning/dispatch support that turns raw scans
  into debounced action events.
* **PROC / ENDP:** AS1600 directives marking a procedure's source range; they
  do not automatically create a callable stack frame.
* **Stack:** RAM used by `CALL`, `RETURN`, and temporary register-saving
  conventions; it must be initialized before library calls.

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
