# Manual Puzzle Test (Phase 7)

Status: **pending**. To be performed by the project owner and a second player sharing the
keyboard (P1: WASD + V, P2: arrows + Alt). No extra buttons are used.

## Starting the puzzle test room

```
"C:/Users/Reaper/Downloads/Godot/Godot_v4.7.2-stable_win64.exe" --path "C:/Users/Reaper/Desktop/code/game" res://scenes/dev/puzzle_test_room.tscn
```

Or open `scenes/dev/puzzle_test_room.tscn` in the editor and press **F6**.

The room is one long corridor of ten sections, each closed by an iron portcullis. A signpost
with a short clue stands in every section; it becomes readable as you approach. Try to solve
each section from the clue alone before reading the solution below.

The overlay (top left) shows both knights, every lock's state, every gate's state and timer,
how many puzzle states the run has saved, and recent events.

| Key | Action (this room only) |
|---|---|
| F1 / F2 | Hurt P1 / P2 |
| F3 | Heal both by 1; revive a dead knight at its spawn |
| F4 | Move both knights to the start of the next section |
| F5 | **New run** and reload: every puzzle resets |
| F6 | Reload the room, keeping the run: completed locks and latched gates must stay open |
| F7 | Overlay on/off |
| F8 | Pause / resume (gate and lock timers must stop) |
| F9 | Debug drawing: puzzle ids and states over every element |

## Solutions (for the tester)

| # | Clue | Solution |
|---|---|---|
| 1 | "One stone remembers. Two stones awaken." | Each knight stands on one plate at the same time. The gate stays open for good |
| 2 | "Hold the light. Let the other pass." | One holds the plate; the other jumps the spikes and walks through, then strikes the "!" switch beyond the gate, which keeps it open for good |
| 3 | "Two blades. One heartbeat." | Each knight strikes a different target within 2 s |
| 4 | "The door counts. One strikes, one runs." | One climbs the ladder and strikes the ledge switch; the other runs through the 3 s gate. The far switch reopens it for the first |
| 5 | "Above and below. Two hands, one door." | One climbs to the upper route, the other takes the lower; each strikes the switch at its route's end (different knights). The upper knight drops down to rejoin |
| 6 | "The gate listens to both sides." | One stands on the left plate; the other passes and stands on the right plate so the first can pass |
| 7 | "The bridge walks only when watched." | A plate on either side extends the bridge: one holds, the other rides across, then holds the far plate while the first rides |
| 8 | "It hungers for one. The other works." | One approaches the purple slime and leads it left; the other strikes the switch behind it |
| 9 | "Warm stone, open door. One pays. Both pass." | One stands on the plate on hot ground (costs 1 HP) while the other passes and stands on the safe far plate |
| 10 | "Two knights. One way forward." | Both knights stand in the end area together |

## Tests

| # | Procedure | Pass when |
|---|---|---|
| 1 | Solve sections 1–10 together, in order | Every section is solvable with the clue and the five buttons each; nothing needs a third hand |
| 2 | Try each section alone (one knight) | Sections 1–9 cannot be completed by one knight (3 needs two knights; 4, 6 and 9 close before a lone knight arrives) |
| 3 | Section 1: one knight straddling both plates | Not enough; the second knight completes it |
| 4 | Section 2: the holder steps off while the other stands in the gateway | The gate waits (blinking) and never closes on the knight; walk out, it closes; strike the far switch to reopen |
| 5 | Section 3: strike one target, wait, strike the other | The attempt fails and resets; a correct attempt still works |
| 6 | Section 4: hit the switch, then F8 for a few seconds | The countdown stops while paused |
| 7 | Section 4: let the gate close with nobody passing | It closes; the switch opens it again |
| 8 | Section 5: separate onto the two routes | Both routes are walkable; both knights stay visible (the camera may stay shared: the routes fit one view) |
| 9 | Section 5: one knight strikes both switches | Not enough; the other knight striking either switch completes it |
| 10 | Section 7: ride the bridge with both knights in turn | No jitter; the bridge comes home when nobody holds a plate; falling off respawns you on the near side |
| 11 | Section 8: lure the slime | The slime follows the lurer; the slime itself never triggers the switch |
| 12 | Section 9 | The holder loses exactly 1 HP; nobody dies |
| 13 | Kill the holder (F1/F2 to 0) while the other is in a gateway | The plate releases, the gate waits for the doorway to clear; no one is trapped (team wipe arrives in Phase 8; F3 revives) |
| 14 | Complete sections 1–3, then F6 | Gates 1–3 are open right after the reload; held plates start released |
| 15 | F5 | Every gate is closed again |
| 16 | Separate the knights far apart (split screen) and use plates in both views | Plates, switches and gates work in both halves |
| 17 | Clues | Short, readable up close, faint from far away; none gives the whole solution |
| 18 | General | Feedback (sounds, lights, plate sinking, countdown bars) makes every state clear |
