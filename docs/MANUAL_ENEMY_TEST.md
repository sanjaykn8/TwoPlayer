# Manual Enemy Test (Phase 4)

Status: **pending**. To be performed by the project owner and a second player.

## Starting the enemy test room

```
"C:/Users/Reaper/Downloads/Godot/Godot_v4.7.2-stable_win64.exe" --path "C:/Users/Reaper/Desktop/code/game" res://scenes/dev/enemy_test_room.tscn
```

Or open `scenes/dev/enemy_test_room.tscn` in the editor and press **F6**.

Slimes from left to right:
- **ONE GREEN** and **ONE PURPLE** on open floor.
- **BEHIND PILLAR**: hidden behind a pillar that blocks sight.
- **LEDGE EDGES**: a green slime whose patrol is wider than its ledge.
- **HIGH PLATFORM**: a purple slime on a one-way platform.
- **CORRIDOR**: a green slime in a low passage.
- **CROWD**: two green and two purple slimes.

In this development build the room shows:
- every slime's detection circle (yellow), patrol limits (blue line), line of sight to its
  target (green when visible, red during the grace period) and edge probe (orange);
- a label with its type, state, stagger progress and timer;
- the overlay (top left), with one line per slime and the coins dropped so far.

| Key | Action (this room only, never in release builds) |
|---|---|
| F1 / F2 | Hurt P1 / P2 by 1 |
| F3 | Heal both |
| F4 | Protected mode: slimes cannot hurt the knights (for practising stagger and kills) |
| F6 | Reload the room (every slime returns) |
| F7 | Overlay on/off |
| F9 | Slime debug drawing and hitboxes on/off |

What to look for on a slime:

| Look | Meaning |
|---|---|
| Slow bob, walking back and forth | Patrolling |
| Yellow **!** above it | It has just noticed a knight |
| Fast bob, moving twice as fast | Chasing |
| White flash | It was hit (stagger progress went up) |
| Flattened puddle, pulsing light, two small circling stars | Staggered: harmless, and one more hit kills it |
| Pulse speeds up | Less than 2 s until it recovers |
| Rises back up | It recovered; progress starts again from 0 |
| Flash, squash and fade, coins pop out | Defeated |

## Tests

| # | Procedure | Pass when |
|---|---|---|
| 1 | Watch ONE GREEN and ONE PURPLE without approaching | They wait about 1 s, then walk back and forth within their patrol area |
| 2 | Watch LEDGE EDGES | The slime turns at the ledge edges and never falls |
| 3 | Walk toward a slime | It shows **!** and then chases at double speed |
| 4 | Stand behind the PILLAR (left side), then walk round it | It ignores you behind the pillar and chases once it can see you |
| 5 | Both knights near one slime, at different distances | It chases the nearer knight and does not keep switching between you |
| 6 | Run away out of its circle | It keeps chasing for about 1 s, then returns to patrol |
| 7 | Let a slime touch you (F4 off) | You lose 1 health, blink, and lose no more until the blinking stops |
| 8 | Green: hit twice | Staggered after the 2nd hit and still alive. The 3rd hit kills it |
| 9 | Purple: hit four times | Staggered after the 4th hit. The 5th hit kills it |
| 10 | Stagger a slime and wait without hitting it | After 10 s it recovers. It needs the full number of hits again |
| 11 | Stand inside a staggered slime (F4 off) | No damage |
| 12 | Defeat several slimes | Each drops 4–6 coins that settle on the ground (they cannot be collected yet: Phase 5). The overlay total rises by the same amount |
| 13 | Both knights fight slimes at the same time, in split-screen too | Attacks, slimes and the camera all behave normally |
| 14 | HIGH PLATFORM: stand on the platform above a slime on the floor | It walks under you, waits, and gives up after about 3 s (slimes cannot jump) |

## Record your results

```
Test | Result (pass/fail) | Notes
1-14 |                    |
Was each slime state easy to recognise?  Was chasing too fast or too slow?
Did the 10 s stagger window feel right?
```
