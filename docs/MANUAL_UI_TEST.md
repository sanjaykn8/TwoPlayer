# Manual Interface, Settings and Audio Test (Phase 9)

Status: **pending**. To be performed by the project owner, with a second player for the HUD
and pause parts, with speakers or headphones on.

There are two ways to run the game.

**The real game** is the project's main scene. It uses your real campaigns in
`%APPDATA%\TwoKnightCoop\saves\` and your real `%APPDATA%\TwoKnightCoop\settings.cfg`:

```
"C:/Users/Reaper/Downloads/Godot/Godot_v4.7.2-stable_win64.exe" --path "C:/Users/Reaper/Desktop/code/game"
```

**The UI test harness** is the same game, but it uses its **own** folder (`saves_ui_dev\`) and
its own `settings_ui_dev.cfg`, so it cannot touch real campaigns or settings:

```
"C:/Users/Reaper/Downloads/Godot/Godot_v4.7.2-stable_win64.exe" --path "C:/Users/Reaper/Desktop/code/game" res://scenes/dev/ui_test_room.tscn
```

Harness keys:

| Key | Where | Action |
|---|---|---|
| F1 | Main menu | Fill the four slots with controlled states: 1 ACTIVE (level 2, 23 coins), 2 INVALIDATED, 3 CORRUPTED, 4 RECOVERED |
| F2 | Main menu | Empty all four slots |
| F3 | Playing | P1 +1 maximum health (repeat for more than 3 hearts) |
| F4 | Playing | Timed effects on both knights |
| F5 | Playing | +1 coin |
| F6 | Playing | Kill P1 (team wipe → game-over screen) |
| F7 | Playing | Victory screen (development preview) |
| F8 / F9 / F10 | Playing | Hold the knights apart sideways / vertically / release them |

Menus use the arrow keys, Enter (or Space) and Esc; the mouse also works.

## Tests (use the harness unless stated)

| # | Procedure | Pass when |
|---|---|---|
| 1 | Start the harness. Use only the keyboard to move through the main menu | A gold frame and a pointer arrow show the selected button. With no saves, Continue is greyed out and skipped, and a hint says to choose New Game. Up from New Game wraps to Exit. Menu music plays |
| 2 | Press F1, then open Save Slots | Four slots: ACTIVE (World 1 - Level 2, 23 coins, P1 4/4, P2 2/3, play time, save time), INVALIDATED, CORRUPTED, RECOVERED, each with a short explanation |
| 3 | In Save Slots select slot 1 → Delete → Cancel, then Delete → Delete | Cancel keeps it. Delete empties only slot 1; slots 2–4 are unchanged |
| 4 | Select slot 4 (RECOVERED) → Repair | "restored from its backup"; slot 4 becomes ACTIVE |
| 5 | Back on the main menu, open Continue | Only ACTIVE / RECOVERED slots can be selected; the lost and damaged ones are skipped |
| 6 | New Game → an occupied slot | "Overwrite slot N?" with its level and coins; Cancel is selected first; Esc cancels. Overwrite starts a fresh campaign there |
| 7 | Play (two people). Watch the HUD while you take damage, collect a coin, a fruit and a jar, and press F3 several times and F4 | P1 info top-left, P2 top-right. Hearts change at once and the maximum grows past 3. One shared coin total. Effects show under the right knight, with sprite, name, charges and seconds counting down, and disappear when they end. "World 1 - Level 1" under the coins |
| 8 | Walk apart sideways, then F9, then come back together | Exactly one HUD in all modes, never doubled in the second view; the panels do not move or cover the knights badly |
| 9 | Press Esc during play, hold movement keys, wait, then Esc again | Everything stops (knights, slimes, moving platform, effect seconds, a timed gate); the music gets quieter but continues; Esc resumes |
| 10 | Pause → Settings → change Music and Effects → Esc | Changes are heard at once; you return to the pause menu with Settings selected; the game is still paused |
| 11 | Pause → Restart Campaign → Cancel, then again → Restart | The warning says the progress in this slot will be erased; Cancel keeps everything; Restart puts both knights back at the start of level 1 with nothing (no game-over screen; it is not a death) |
| 12 | Make progress, Pause → Return to Main Menu → Continue the same slot | You resume exactly where you left, with coins, effects and upgrades |
| 13 | Pause → Save and Quit, then start the harness again | The window closes after a short moment; on restart Continue resumes that state |
| 14 | Press F6 (or walk into lava) | "RUN LOST" fades in over the frozen world. After a moment Begin Again and Main Menu appear. Begin Again starts level 1 fresh. Main Menu → Continue shows only the fresh run (0 coins, level 1) |
| 15 | Reach the exit of level 2 (or use the dev campaign to finish both levels) | Victory screen with your real coins and play time and a note that only test levels exist; Main Menu returns |
| 16 | F7 during play | The victory screen says DEVELOPMENT PREVIEW and that the campaign is not finished |
| 17 | Settings → Mode: Fullscreen, then Windowed, then each window size | Fullscreen fills the screen with sharp pixels (black bars where needed); window sizes are 640x360, 1280x720 and so on, always sharp; the HUD stays correct |
| 18 | Change settings, close the game with the window X, start again | Settings kept. Delete a slot or lose a run: the settings are still kept |
| 19 | Controls screen | Matches the keys you actually use (W A S D V / arrows and Left or Right Alt) |
| 20 | Listen throughout | Menu clicks, attack swings, hits, slime deaths, damage, coins, level change and victory are audible but not harsh; many coins at once are not loud; no music restarts or doubles after changing screens; nothing keeps playing on the main menu |

Also check whether menu keys clash with gameplay keys on a shared keyboard: arrows are also
Player Two's movement, and Esc pauses.
