# Manual Combat Test (Phase 3)

Status: **pending**. To be performed by the project owner and a second player.

## Starting the combat test room

```
"C:/Users/Reaper/Downloads/Godot/Godot_v4.7.2-stable_win64.exe" --path "C:/Users/Reaper/Desktop/code/game" res://scenes/dev/combat_test_room.tscn
```

Or open `scenes/dev/combat_test_room.tscn` in the editor and press **F6**. The room uses the
Phase 2 camera, so it splits when the knights separate.

Attack keys: **P1 = V**, **P2 = Left Alt or Right Alt**. The direction is set when the attack begins:
- Up held: up.
- Down held: down. On the ground this is a **low forward slash** (D-2); in the air or on a ladder it is a real downward slash.
- Otherwise: the way the knight last walked.

On solid ground, Up also jumps, so an up attack from the ground is a jump attack.

The overlay (top left) shows for each knight: health, alive/dead, movement state,
invulnerability time left, attack state, direction, cooldown left, attack power, range
multiplier and hits landed. Red boxes show the active hitboxes (F9 toggles them). Each
target shows its health and flashes when hit, then shows `X` when broken and repairs itself
after 3 s.

Development keys (this room only, never in release builds):

| Key | Action |
|---|---|
| F1 / F2 | Hurt P1 / P2 by 1 (respects invulnerability) |
| F3 | Heal both by 1 |
| F4 / F5 | Kill P1 / P2 (lava damage) |
| F6 | Revive and reset everyone and every target |
| F7 | Overlay on/off |
| F9 | Hitbox drawing on/off |

## Targets in the room (left to right)

| Label | Purpose |
|---|---|
| LEFT / RIGHT | Basic left and right attacks near the start |
| STAND → EDGE | Stand on the first blue tick: the EDGE target is just inside reach |
| STAND → TOO FAR | Stand on the second blue tick: the TOO FAR target is 1 px out of reach |
| ON PLATFORM | Target standing on a one-way platform |
| UP | Hanging target: jump under it with Up + attack |
| LADDER DOWN | Climb the ladder a little, then Down + attack the target at its foot |
| JUMP + DOWN | Jump over it and press Down + attack in the air |
| WALL | Thin wall with a target right behind it: the wall must block every attack |
| PILLAR | Target behind a solid pillar |
| CORRIDOR | Target inside a low corridor |
| TWO AT ONCE | Two targets close together: one swing can hit both |

## Tests

| # | Procedure | Pass when |
|---|---|---|
| 1 | P1 attacks LEFT and RIGHT targets; P2 does nothing | Only P1 swings; each swing removes 1 health |
| 2 | P2 attacks with Left Alt, then Right Alt | Both Alt keys attack |
| 3 | Both attack at the same moment, again and again | Neither attack interrupts the other |
| 4 | Try all four directions (and the low slash) | The knife arc points the right way each time |
| 5 | Mash the attack key | At most about 3 attacks per second. A press just before the cooldown ends still fires |
| 6 | Hold a target in front of you and attack once (watch its health) | Exactly 1 damage per swing |
| 7 | TWO AT ONCE | One swing damages both |
| 8 | WALL and PILLAR targets | Never damaged from the far side |
| 9 | EDGE vs TOO FAR | EDGE is hit from its tick; TOO FAR is not |
| 10 | F1 several times quickly on P1 | Only one point lost per second; the knight blinks while invulnerable |
| 11 | F4 (kill P1), then try to move and attack with P1; press F3 | P1 lies in the death pose; it cannot move or attack, and healing does nothing |
| 12 | F6 | Both knights and all targets are back to full |
| 13 | Separate the knights to split the screen, then attack and get hurt in both views | Combat behaves the same in split-screen; the camera is unaffected by attacks |
| 14 | Attack while running, jumping, crouching and on ladders | Responsive; the hitbox follows the knight |

## Record your results

```
Test | Result (pass/fail) | Notes
1-14 |                    |
Did the attack feel responsive?  Was the range too short or too long?
Was it always clear which way the attack went and when it could hit?
```
