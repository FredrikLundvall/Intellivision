# Typical Intellivision Game Structure

This is a practical outline for an AS1600 game in this SDK. It describes the
structure used by examples such as `examples/mazedemo`, `examples/life`,
`examples/balls1`, and `examples/hello`.

## 1. Cartridge layout and startup

Most programs begin with:

1. `CFGVAR` metadata and `ROMW`.
2. `INCLUDE "../library/gimini.asm"` for memory-map symbols, STIC fields, and
   color constants.
3. Scratch-RAM and system-RAM allocations.
4. Code assembled at `$5000`, the default cartridge address.
5. An EXEC-compatible ROM header containing pointers to the MOB list, process
   table, entry point, background data, GRAM data, and title.
6. A `TITLE` procedure that optionally customizes the EXEC title screen.
7. A `MAIN` procedure that takes over the game.

The header is not optional for a normal EXEC-launched cartridge. Keep the
header pointers and title format consistent with the working examples.

## 2. RAM organization

Use the hardware-defined regions deliberately:

| Region | Typical use |
|---|---|
| `$0100-$01EF` | 8-bit scratch RAM, including the VBLANK vector at `$0100/$0101` |
| `$0200-$02EF` | BACKTAB display memory, 20 columns by 12 rows |
| `$02F0-$035F` | 16-bit system RAM, commonly including the stack |
| `$01F0-$01FF` | Master PSG and controller ports |

Declare program variables with `ORG` ranges and `"-RWBN"` attributes when
building BIN+CFG output. Reserve a stack explicitly, usually in system RAM,
and initialize `R6` before calling routines that use the stack.

## 3. Initialization and the main loop

`MAIN` normally disables interrupts while it performs critical setup:

- initialize `R6`;
- initialize game state and random seeds;
- install the VBLANK ISR at `$0100/$0101`;
- initialize BACKTAB, MOB state, sound state, and timers;
- copy required graphics into GRAM when the display is blanked or during
  VBLANK;
- enable interrupts with `EIS`.

After initialization, the main loop performs game logic that does not require
STIC or GRAM access:

- read and debounce controller input;
- update player and enemy state;
- run collision and rules logic;
- update timers and animation state;
- queue or update sound requests;
- prepare shadow copies of display state.

Keep the loop deterministic and bounded. A game should not depend on a slow
operation completing at an arbitrary point in the frame.

## 4. The VBLANK interrupt

The STIC generates the only regular interrupt, approximately 60 Hz on NTSC
systems and 50 Hz on PAL systems. The EXEC dispatcher calls the function
whose address is stored at `$0100/$0101`.

A normal ISR should:

1. preserve any registers it uses beyond the dispatcher contract;
2. write the STIC display-enable handshake at `$0020` every frame;
3. update STIC registers from shadow state;
4. perform only the GRAM work that fits in the available VBLANK time;
5. update frame counters, timers, and audio timing;
6. return through the EXEC dispatcher, normally with `RETURN` or `PULR PC`
   according to the chosen calling pattern.

STIC registers are available only during VBLANK. GRAM and GROM are also
restricted while the display is enabled. Do not perform large screen clears,
long decompression jobs, or general game logic in every ISR unless the timing
has been measured. A common design is to do one-time initialization in the
first ISR, then keep later ISRs short.

The display-enable write is a handshake, not a normal on/off setting: if it is
not written each frame, the display eventually blanks.

## 5. Graphics

### BACKTAB and background cards

BACKTAB starts at `$0200` and contains 240 words in raster order. Each word
selects a GROM/GRAM card and its display attributes. Color Stack mode is the
usual starting point for backgrounds; `examples/life` uses it extensively.

### GRAM

GRAM occupies `$3800-$39FF` and stores 64 programmable 8x8 cards. Each card is
eight words, with bit 7 representing the leftmost pixel of a row. Copy graphics
with routines such as `MEMCPY` or `MEMUNPK`, but only when GRAM is accessible.

### MOBs

The eight MOBs are controlled through STIC registers:

- `$0000-$0007`: X position and visibility attributes;
- `$0008-$000F`: Y position and size attributes;
- `$0010-$0017`: card, GRAM/GROM selection, priority, and foreground color;
- `$0018-$001F`: collision results.

Games commonly keep a 24-word MOB shadow in RAM and copy or write it during
VBLANK. `examples/balls1` and `examples/sky` demonstrate this approach.

## 6. Input, sound, and timing

The master-controller ports are at `$01FE` and `$01FF`. Inputs are active-low
and encode disc, action buttons, and keypad switches as bit patterns. For a
real game, use the SDK's `SCANHAND` and task/event routines when possible;
they provide debouncing and decoded press/release events. Simple programs can
poll the ports directly, but should mask and debounce the values.

The PSG occupies `$01F0-$01FF` (with the controller ports sharing the upper
addresses). Sound code should update PSG registers from the main loop or the
VBLANK timing path, not from unbounded game logic.

Use VBLANK as the frame heartbeat. Frame counters and timers belong in the ISR;
game decisions and expensive calculations generally belong in the main loop.

## 7. A useful source-file order

```asm
CFGVAR / ROMW / includes
SCRATCH-RAM variables
SYSTEM-RAM variables
constants and build options
ORG $5000
ROMHDR, ZERO, ONES
TITLE
MAIN
ISR
game routines
graphics and tables
library includes
```

This is a convention rather than a requirement, but it makes symbol ownership,
memory use, and initialization order easy to audit.

## 8. Build and test

From an example directory:

```text
as1600 -o game.bin -l game.lst game.asm
as1600 -o game.rom -l game.lst game.asm
```

Use BIN+CFG output for emulator and Intellicart-style testing; use ROM output
when a single ROM image is required. Always inspect the assembler listing,
check for zero errors and warnings, and test startup, title return, controller
input, display timing, sound, and reset behavior separately.

For additional working patterns, compare:

- `examples/hello/hello.asm`: minimal EXEC-compatible program;
- `examples/mazedemo/mazedemo.asm`: title customization, color-stack display,
  timing, and a complete main loop;
- `examples/life/life.asm`: larger RAM state and colored-square rendering;
- `examples/balls1/balls1.asm`: MOB shadowing, GRAM graphics, collisions, and
  an ISR-driven animation loop;
- `examples/handdemo/handdemo.asm`: controller scanning and display of input.
