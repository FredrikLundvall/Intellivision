Intellivision progressive game-learning examples

Build each level from its own directory with AS1600:

  as1600 -o level01_title.bin -l level01_title.lst level01_title.asm
  as1600 -o level02_input.bin -l level02_input.lst level02_input.asm
  as1600 -o level03_player.bin -l level03_player.lst level03_player.asm
  as1600 -o level04_collision.bin -l level04_collision.lst level04_collision.asm
  as1600 -o level05_game.bin -l level05_game.lst level05_game.asm
  as1600 -o level06_sound.bin -l level06_sound.lst level06_sound.asm
  as1600 -o level07_scanhand.bin -l level07_scanhand.lst level07_scanhand.asm
  as1600 -o level08_gram_animation.bin -l level08_gram_animation.lst level08_gram_animation.asm
  as1600 -o level09_tile_collision.bin -l level09_tile_collision.lst level09_tile_collision.asm
  as1600 -o level10_scrolling.bin -l level10_scrolling.lst level10_scrolling.asm
  as1600 -o level11_hud_text.bin -l level11_hud_text.lst level11_hud_text.asm
  as1600 -o level12_state_flow.bin -l level12_state_flow.lst level12_state_flow.asm
  as1600 -o level13_randomness.bin -l level13_randomness.lst level13_randomness.asm
  as1600 -o level14_music_psg.bin -l level14_music_psg.lst level14_music_psg.asm
  as1600 -o level15_production.bin -l level15_production.lst level15_production.asm

The source files are deliberately standalone and repeat some initialization
code. Compare one level with the previous level to see exactly what changed.
Generated BIN, CFG, and LST files are build artifacts and are not source.

Read doc/programming/intellivision_game_learning_path.md for the lesson
sequence, explanations, checkpoints, and suggested exercises.
