# Manual Collectible Test (Phase 5)

Status: **pending**. To be performed by the project owner and a second player.

## Starting the collectible test room

```
"C:/Users/Reaper/Downloads/Godot/Godot_v4.7.2-stable_win64.exe" --path "C:/Users/Reaper/Desktop/code/game" res://scenes/dev/collectible_test_room.tscn
```

Or open `scenes/dev/collectible_test_room.tscn` in the editor and press **F6**.

Layout, from left to right:
- **Fruit gallery:** HEAL (green), SHIELD (yellow), RANGE (red), POISON (purple). In each
  column, tier 1 (apple) is on the floor, tier 2 (pear) needs a small hop, and tier 3
  (grapes) needs a full jump.
- **JARS:** green, yellow and blue.
- **RED JAR:** on top of the pillar, reached only by precise jumps across three single-tile
  steps.
- **? TILES:** three power tiles.
- **SPEED LANE:** distance ticks every 32 px.
- **SHIELD TEST:** a pen with a green slime.
- **POISON TEST:** a pen with a purple slime.
- **COIN DROPS:** two green slimes.

The overlay (top left) shows, per knight: health, power, range, speed and cooldown
multipliers, poison seconds and active effects with time left and charges. It also shows the
shared coin total and the last six collections, with who collected them. Small coloured pips
above a knight show its active timed effects, with a bar for the time left.

| Key | Action (this room only) |
|---|---|
| F1 / F2 | Hurt P1 / P2 (contact damage: shields and the yellow jar can block it) |
| F3 | Heal both |
| F4 | Drop 5 coins next to P1 |
| F5 | **New run** and reload (everything resets) |
| F6 | Reload the room keeping the run (progression must survive) |
| F7 | Overlay on/off |
| F8 | Pause / resume (effect timers must stop) |
| F9 | Debug drawing on/off |

## Tests

| # | Procedure | Pass when |
|---|---|---|
| 1 | Defeat a COIN DROPS slime (2 + 1 hits), then let both knights pick up coins | 4–6 coins pop out and settle. Each one adds 1 to the shared total, whoever takes it |
| 2 | F4 several times and collect many coins while hurt (F1/F2 first) | Sometimes "+1 HP" appears over both knights (about 1 coin in 10). Health never goes above the maximum |
| 3 | Kill P2 (F2 three times) and collect coins with P1 | P2 is never revived by a coin |
| 4 | Green fruits of each tier while hurt | Tier 1/2/3 heal 1/2/3 points; only the collector heals |
| 5 | Yellow fruit, then walk into the SHIELD TEST slime | "BLOCKED" for as many hits as the tier, then damage resumes. The shield ends after 5/10/20 s if unused |
| 6 | Red fruit, then attack a slime from slightly further away | The range multiplier in the overlay rises (1.1/1.2/1.3); attacks reach a little further |
| 7 | Purple fruit, then hit the POISON TEST slime once and watch | It tints green with bubbles; its stagger count rises by one per second of poison; poison alone can stagger but never kill it |
| 8 | Each jar | Green: max HP +1, filled. Red: power 2 (a green slime staggers in one hit). Yellow: "LUCK" for 60 s, about half of hits show "LUCKY!". Blue: speed ×1.05 |
| 9 | The red jar | Reachable only with careful jumps |
| 10 | Each ? tile | One random effect (speed, fast attack or shield) for 5 s. Standing still does not repeat it; stepping off and on again does. Both knights can use one tile at the same moment |
| 11 | F8 during an effect | Its time stops while paused |
| 12 | Collect some upgrades, then F6 | After the reload the upgrades, coins and running effect timers are kept, and collected fruit and jars do not reappear |
| 13 | F5 | Everything is back to the start |
| 14 | Split the screen and collect items with both knights | Works in both views; the camera is unaffected |

## Record your results

```
Test | Result (pass/fail) | Notes
1-14 |                    |
Was each effect clear when it started and ended?  Was the red jar route fair?
```
