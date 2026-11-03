# Manual Save and Team-Wipe Test (Phase 8)

Status: **pending**. To be performed by the project owner (with a second player for the
co-op parts).

The harness uses its **own** folder, `%APPDATA%\TwoKnightCoop\saves_dev\`
(`user://saves_dev/`). It never touches `%APPDATA%\TwoKnightCoop\saves\`, where real campaigns
live. You can open that folder in Explorer while testing: each slot is `slot_N.save` (plus
`.bak`, and briefly `.tmp`; `.dead` during a team wipe; `.corrupt` after a recovery).

## Starting the harness

```
"C:/Users/Reaper/Downloads/Godot/Godot_v4.7.2-stable_win64.exe" --path "C:/Users/Reaper/Desktop/code/game" res://scenes/dev/save_test_room.tscn
```

It continues slot 1 (or starts it if empty) in the development campaign: level `w1_l1`
(slime, fruit and jars, save point flag, two-plate gate, moving platform over a pit, timed and
collapsing platforms, purple slime, spikes, a small lava pit, second save point, exit portal)
then `w1_l2` (slime, timed gate with two switches, disappearing platform, blue jar, save point,
exit). The overlay shows the slot, phase, level, campaign id, play time, coins, both knights,
the last save and the state of all four slots.

| Key | Action (harness only) |
|---|---|
| 1–4 | Save this slot, then switch to slot 1–4 (continue, or start it if empty) |
| F1 / F2 | Hurt P1 / P2 by 1 |
| F3 | Kill P1 (team wipe) |
| F4 | Start a NEW campaign in this slot (explicit overwrite) |
| F5 | Save now |
| F6 | Delete this slot and start fresh |
| F7 | Damage this slot's primary file and reload it (backup recovery) |
| F8 | Damage primary AND backup and try to reload (corrupted slot) |
| F9 | Overlay on/off |
| F10 | Close the window (same path as the window's X button) |
| F11 | Complete the level (as if the exit was reached) |

## Tests

| # | Procedure | Pass when |
|---|---|---|
| 1 | Play slot 1: collect the jar and fruit, open the plate gate, defeat the green slime (leave its coins), stagger the purple slime, stand somewhere specific. Close the window with the **X button** | The window closes after a short moment |
| 2 | Start the harness again | Same position (both knights), health, max health, coins, collected items gone, defeated slime gone, its coins still on the ground, gate open, purple slime still staggered with its remaining time, platforms where they were |
| 3 | Before closing, pick up a power tile effect or yellow fruit (watch its seconds), close, wait a minute, start again | The effect has the same seconds left as when you closed |
| 4 | Press 2, play a little, press 3, play, press 4, play; then 1, 2, 3, 4 again | Each slot resumes its own campaign; the overlay shows four independent entries |
| 5 | In slot 2 press F6 | Slot 2 starts fresh; slots 1, 3, 4 unchanged |
| 6 | In slot 3 press F7 | Slot 3 reloads from its backup (a message says so); a `slot_3.corrupt` file appears |
| 7 | In slot 4 press F8 | Slot 4 is reported corrupted and is not loaded; F4 starts a new campaign there |
| 8 | Make progress in slot 1 (coins, jar), then F3 (or walk into lava) | The world freezes, "The run is lost for both" appears, then both knights are back at the start of `w1_l1` with 3/3 health, power 1, no coins, every item, slime and gate reset |
| 9 | After 8, close and restart | Slot 1 holds the fresh run, never the lost one; other slots unchanged |
| 10 | Make progress, F3, and close the window **during** the frozen moment | On restart slot 1 is either the fresh run or reported as lost (start a new campaign); the lost campaign never comes back |
| 11 | Both knights take lethal damage at the same moment (e.g. F3 while P2 stands in lava) | One team wipe only |
| 12 | Reach the exit (or F11) in `w1_l1`, then close and restart | Resumes in `w1_l2` with upgrades kept |
| 13 | Walk past a save-point flag | The flag turns gold and the overlay shows "save_point:..." as the last save |
| 14 | Quit with Alt+F4 | Same as closing with X: progress is saved |
