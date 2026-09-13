# Intellivision

Starting point for Intellivision projects. The progressive, standalone
Star Dodger assembler curriculum covers startup, input, GRAM and tile maps,
scrolling, HUD text, state flow, randomness, PSG music/effects, VBLANK
budgeting, and production cartridge layout:

* Tutorial: `doc/programming/intellivision_game_learning_path.md`
* Sources: `examples/learning_game/`
* Integrated skeleton: `examples/learning_game/star_dodger/star_dodger.asm`

Build each level from its directory with the SDK `bin/as1600.exe`. Generated
`.bin`, `.cfg`, and `.lst` files are temporary build artifacts and are not
part of the source tree.
