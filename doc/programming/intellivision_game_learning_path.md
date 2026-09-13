# Learning to Make Star Dodger for Intellivision

This course uses one project vocabulary from the first title card through an
integrated skeleton: the player is a **starship**, the moving obstacle is a
**meteor**, and the eventual HUD tracks **score** and **lives**. The source
files remain small, standalone teaching checkpoints; a checkpoint may expose a
data structure or hardware boundary without implementing the complete feature.
Do not infer a feature from its lesson title—run the source and read its loop.

Sources are in `examples/learning_game/`. Build from each source's directory:

```text
D:\source\Repos\Intellivision\jzintvSDK\bin\as1600.exe ^
  -o level01_title.bin -l level01_title.lst level01_title.asm
```

Remove generated `.bin`, `.cfg`, and `.lst` files after testing. The final
composition is `examples/learning_game/star_dodger/star_dodger.asm`.

## The progression

| Level | Star Dodger focus | What the source actually demonstrates |
| --- | --- | --- |
| 1 | Title | EXEC header, title callback, and one message |
| 2 | Starship input | A BACKTAB marker, VBLANK handshake, and raw active-low polling |
| 3 | Starship art | One GRAM card and one movable starship MOB |
| 4 | Meteor contact | Starship and meteor MOB shadows, patrol timing, and STIC collision sampling |
| 5 | Play-loop foundation | PLAY/GAME_OVER dispatch, restart, collision-triggered effect request |
| 6 | Meteor alert sound | A standalone frame-timed PSG effect triggered by new input |
| 7 | Control decoding | SCANHAND/task-queue wiring; handlers only record an event |
| 8 | Starship animation | Two GRAM cards and VBLANK card switching |
| 9 | Asteroid-field tiles | One-dimensional tile lookup and a solid/non-solid decision |
| 10 | Camera groundwork | Camera/coarse-scroll state and a separate camera ISR example |
| 11 | Score HUD groundwork | A score counter and explicit BACKTAB character data (not formatting) |
| 12 | State model | A scaffold that cycles TITLE, PLAY, PAUSE, and GAME_OVER |
| 13 | Meteor variation | A deterministic local RAND routine and a stored random value |
| 14 | Music/effect ownership | Two-note PSG sequencing and an effect-priority branch |
| 15 | Production discipline | A bounded-work counter and fixed-bank cartridge layout markers |

Levels 7–15 are deliberately focused checkpoints, not successive builds of one
complete executable. The integrated file is where the systems are composed.

## Build and study rhythm

1. Assemble the level with `as1600.exe`.
2. Inspect the listing and run the cartridge in an emulator.
3. Change one constant or mask.
4. Identify which state belongs in ordinary RAM and which writes belong in
   VBLANK.
5. Delete generated artifacts before moving on.

The examples use relative SDK includes, so run AS1600 from the level directory.
The source is intentionally repetitive: comparing adjacent files makes the
new idea visible.

## Levels 1–6: from title to playable foundation

### 1. Title

`level01_title.asm` proves the ROM header, `TITLE`, `MAIN`, `CLRSCR`, and
`PRINT.FLS`. Its visible result is the `STAR DODGER` title and the
`DODGE THE METEORS` message. It has no input or game loop yet.

### 2. Raw starship input

`level02_input.asm` inverts the active-low left-controller byte and advances a
colored BACKTAB cell when any input is present. This is a deliberately crude
starship marker, not directional movement or decoded events. The ISR's only
display job is the `$0020` handshake.

### 3. Starship MOB

`level03_player.asm` copies an eight-word GRAM bitmap and commits one MOB from
RAM shadows during VBLANK. Its input still advances only X; it does not draw a
meteor or score.

### 4. Meteor collision boundary

`level04_collision.asm` adds a second MOB named as the meteor, moves it on a
frame divider, enables interaction bits, and copies `STIC.mob0_c` to `HITS`.
The source demonstrates collision sampling; it does not award points or remove
lives. Keep rules in the main loop and hardware access in the ISR.

### 5. Play-loop foundation

`level05_game.asm` adds `STATE_PLAY` and `STATE_OVER`, a reset path, a
collision-to-`SFX` request, and a one-shot PSG write. It still has no score or
lives counter and its restart input is a simple bit test. Those systems are
composed in the final skeleton rather than being retroactively claimed here.

### 6. Frame-timed alert

`level06_sound.asm` isolates PSG setup and uses `SFX_TIMER` as a frame clock.
New raw input starts a short channel-A tone; the ISR silences it. This is the
pattern later used for a meteor-impact alert, not a music player.

## Levels 7–15: focused Star Dodger systems

### 7. Decode controls

`level07_scanhand.asm` initializes `SCANHAND` and `RUNQ`. Its three handlers
only store `LAST_EVENT`; it does not move the starship. Replace those handlers
with gameplay actions in a larger program.

### 8. Animate the starship

`level08_gram_animation.asm` uploads two eight-word cards and alternates the
visible MOB card in VBLANK. It does not include input or a meteor.

### 9. Check asteroid tiles

`level09_tile_collision.asm` looks up a 16-entry `TILE_MAP` and branches when
the candidate value is nonzero. It is a collision-rule checkpoint, not a map
renderer and not a scrolling playfield.

### 10. Move the camera

`level10_scrolling.asm` stores camera and coarse-X values. `MAIN` demonstrates
the counter; `VBLANK_ISR_CAMERA` shows the separate `STIC.h_delay` write but is
not installed by this checkpoint. Full world-coordinate scrolling is an
exercise for the integrated project.

### 11. Show score data

`level11_hud_text.asm` increments a one-word `SCORE` and provides explicit
BACKTAB character data. It does not call a number formatter or display a
complete `SCORE 0000 / LIVES` HUD. Those ownership rules are design guidance.

### 12. Model states

`level12_state_flow.asm` cycles through `STATE_TITLE`, `STATE_PLAY`,
`STATE_PAUSE`, and `STATE_GAMEOVER` in a tight scaffold. It does not read
buttons or draw each state. Add real transitions only after the dispatch shape
is understood.

### 13. Vary meteors

`level13_randomness.asm` demonstrates a deterministic `RAND` routine and stores
its output. It does not spawn or position a meteor. Always reduce a random
value before using it as a map index or screen coordinate.

### 14. Share PSG voices

`level14_music_psg.asm` alternates two periods and gives an effect branch
priority when `EFFECT_PRIORITY` is nonzero. It is a sequencing checkpoint; it
does not restore a stolen voice or implement a complete song.

### 15. Budget the cartridge

`level15_production.asm` marks fixed-bank header data and demonstrates a
bounded work counter. It does not implement bank switching. Treat its
VBLANK budget as a review checklist, not as a performance measurement.

## Integrated skeleton

`star_dodger/star_dodger.asm` is a reasonable working composition, not a
finished game. It uses shared Star Dodger constants and the starship/meteor
GRAM assets, initializes score and three lives, samples raw input, and
dispatches TITLE, PLAY, PAUSE, and GAME_OVER. A collision decrements lives,
increments score, and starts a short PSG alert. MOB shadows and collision
sampling remain in VBLANK. It intentionally omits a full HUD renderer,
direction decoding, scrolling map renderer, music restoration, and production
bank switching; those are the next engineering steps, not features to claim
from this skeleton.

Build it from its directory:

```text
D:\source\Repos\Intellivision\jzintvSDK\bin\as1600.exe ^
  -o star_dodger.bin -l star_dodger.lst star_dodger.asm
```

## Debugging checklist

When a cartridge fails, return to the smallest visible result:

1. assemble and inspect errors;
2. verify `TITLE` and `MAIN`;
3. verify the `$0020` VBLANK handshake;
4. verify one RAM shadow and one MOB;
5. verify input polarity;
6. verify collision bits before adding rules;
7. verify PSG enable, period, volume, and timer independently.

An assembled binary proves syntax and symbol resolution, not correct STIC
timing. Keep each experiment in a copy and remove build artifacts from the
source tree.
