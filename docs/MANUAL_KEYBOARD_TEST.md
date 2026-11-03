# Manual Keyboard Test (Phase 1)

Status: **pending**. To be performed by the project owner and a second player on the real keyboard.
Automated tests cannot prove these results; they only cover Godot's handling of key events.

## Before you start

1. Write down the keyboard **manufacturer and model**, whether it is a **laptop or external**
   keyboard, and the Windows **keyboard layout** (Settings → Time & language → Language & region,
   for example "English (United States) – US").
2. Launch the game **in its own window**, not inside the editor's embedded Game tab. The embedded
   view handles Alt and focus differently and invalidates the Alt results. Use either:
   - a terminal:
     ```
     "C:/Users/Reaper/Downloads/Godot/Godot_v4.7.2-stable_win64.exe" --path "C:/Users/Reaper/Desktop/code/game"
     ```
   - or the editor, after turning off **Embed Game on Next Play** in the Game tab, then F5.
3. The Phase 1 test room opens. The debug HUD shows:
   - **Top-left / top-right panels:** each knight's health, state, floor type, live keys
     (`L R U D ATK`; dots mean not held), facing, attack count and resolved attack direction.
   - **Top-centre panel:** `P1 V:n` counts V attacks. `P2 Alt L:n R:n ?:n` counts Alt presses
     by the side Windows reported (LEFT, RIGHT, or unspecified). Below that are the last six raw key
     events with their physical key and `loc=` value.
   - **Dev keys** (test room only): F1/F2 hurt P1/P2, F3/F4 heal, F6 reset positions, F7 hide HUD.

Player One: W A S D + V. Player Two: arrow keys + Left Alt or Right Alt.

## Tests

For each test, hold the keys for about 2 seconds and watch the HUD key indicators and the knights.
A combination **registers** when every held key shows in the HUD and the knights respond.

| # | Procedure | Pass when |
|---|---|---|
| 1 | P1 walks left and right (A, D). P2 touches nothing | P1 moves. P2 panel shows no keys and P2 does not move |
| 2 | P2 walks left and right (←, →). P1 touches nothing | P2 moves. P1 does not |
| 3 | P1 holds A while P2 holds → (opposite directions), then swap to D and ← | Both move at the same time |
| 4 | Both press Up together (W and ↑), repeat 10 times | Both jump on the same press every time |
| 5 | P2 stands at the ladder and holds ↑ to climb. Meanwhile P1 runs and jumps (A/D + W) | P2 climbs smoothly while P1 moves and jumps |
| 6 | Both stand on the left one-way platforms. Both press Down (S and ↓) to drop. Then on solid floor, both hold Down to crouch | Both drop through one platform at a time, and both crouch on solid floor |
| 7 | P1 holds D and presses V repeatedly. P2 holds ← and presses **Left Alt** repeatedly | `P1 V` and `P2 Alt L` counters rise with every press. Both knights keep moving |
| 8 | Repeat test 7 using **Right Alt** | `P2 Alt R` rises with every press. Note if `?` rises instead, or if Right Alt also shows a Ctrl event |
| 9 | P1 holds D + W + V while P2 holds → + ↑ + Alt. Then A + S + V with ← + ↓ + Alt. Then D + S + V with → + ↓ + Alt | All held keys appear in both panels at once |
| 10 | Push each other in the CORRIDOR (walk into each other, then reverse). Then on the ledge near EDGE, P1 pushes P2 off | No knight gets stuck. Both can always walk away or jump. The pushed knight falls and lands safely |

Additional Alt and Windows checks (do these during test 7 or 8):

- **A.** Tap Left Alt alone 10 times, each time immediately pressing an arrow key afterwards.
  The arrow key must move P2 every time. If a key is swallowed, or a window menu or system
  menu appears, Windows menu mode is interfering.
- **B.** Tap Right Alt alone 10 times the same way.
- **C.** Alt+Tab away from the game and back. The game must not keep any key stuck "held" in
  the HUD. Alt+Tab must still work normally; the game does not block it.
- **D.** While P2 holds Alt, P1 plays normally for 30 seconds. Nothing unexpected should happen
  (no window menu, no minimising, no focus loss).

## Record your results

Copy this table into your reply (or into `docs/TEST_REPORT.md`):

```
Keyboard: <manufacturer / model>   Type: laptop | external   Layout: <Windows layout>

Test | Result (pass/fail) | Notes (which keys failed, ghosting, menus, etc.)
1    |                    |
2    |                    |
3    |                    |
4    |                    |
5    |                    |
6    |                    |
7    |                    |
8    |                    |
9    |                    |
10   |                    |
A    |                    |
B    |                    |
C    |                    |
D    |                    |

Left Alt and Right Alt distinguishable (HUD shows loc=LEFT vs loc=RIGHT)?  yes / no
Any Windows shortcut triggered by the game keys?  yes / no (which)
Any key combination that failed to register (ghosting)?  list them
```

## Interpreting failures

- **A key does not appear in the HUD while others are held:** keyboard ghosting or rollover.
  This is hardware and cannot be fixed in software. Note the exact combination. Levels will be
  designed to avoid it, and key remapping (D-14) will be reconsidered.
- **`?:n` rises instead of L/R:** Windows did not report which Alt was pressed. The game
  still accepts it as an attack (a location-independent fallback binding exists).
- **Right Alt also logs a Ctrl key:** your layout treats Right Alt as AltGr. It still attacks.
  Ctrl is not bound to anything.
- **A window or system menu appears after tapping Alt:** report it with the Windows version.
  This would need an engine-level fix that keeps Alt+Tab working.
