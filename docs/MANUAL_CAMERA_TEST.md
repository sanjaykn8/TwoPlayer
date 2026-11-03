# Manual Camera Test (Phase 2)

Status: **pending**. To be performed by the project owner and a second player.

## Starting the camera test room

Run it in its own window:

```
"C:/Users/Reaper/Downloads/Godot/Godot_v4.7.2-stable_win64.exe" --path "C:/Users/Reaper/Desktop/code/game" res://scenes/dev/camera_test_room.tscn
```

Or, in the Godot editor: open `scenes/dev/camera_test_room.tscn` and press **F6** (Run Current Scene).
The main scene (F5) is still the Phase 1 movement room.

The level is 1920 × 960 px (three screens wide, almost three tall). It contains:
- **TOGETHER:** the start area, where both knights stand close.
- **Threshold lane:** floor markers `P1 HERE`, `MERGE` and `SPLIT`. With P1 at the blue post,
  P2 merges left of the green tick and splits right of the red tick.
- **Ladder by the start, with MERGE HEIGHT / SPLIT HEIGHT ticks:** vertical thresholds while P1
  waits at the foot of the ladder.
- **MID LEDGE / UPPER LEDGE:** two more ladders and higher elevations.
- **CORRIDOR and CRAWL:** a 32 px passage with a 16 px crawl section.
- **TOWER:** a 768 px tall ladder plus a zig-zag of one-way platforms, with the WALKWAY above.
- **OPEN AREA / FAR RIGHT:** floating platforms at several heights.

The top-left overlay shows:
- the camera mode (SHARED / SPLIT / MERGING) and the orientation;
- the separation ratios against the split and merge thresholds;
- view sizes, and whether view B is rendering;
- a count of layout changes;
- fps, object and node counts.

Development keys (this room only):

| Key | Action |
|---|---|
| F1 | Send P2 to the tower top |
| F2 | Send P2 to the far right |
| F3 | Bring P2 next to P1 |
| F6 | Reset both knights |
| F7 | Hide or show the overlay |

## Tests

| # | Procedure | Pass when |
|---|---|---|
| 1 | Shared camera: both knights stand together at TOGETHER and walk around a little | One full-screen view. The camera moves calmly, without twitching on tiny steps. Both knights visible |
| 2 | Horizontal separation: in the threshold lane, P1 walks left and P2 walks right | The view splits with a vertical divider. **P1 is in the left view, P2 in the right view.** The moment of splitting shows no jump (the picture is identical, then each half eases toward its knight) |
| 3 | Vertical separation: P1 waits at the foot of the start ladder, P2 climbs past SPLIT HEIGHT. Also try the tower (F1 or climbing) | The view splits with a horizontal divider. **P1 is in the top view, P2 in the bottom view** (this is fixed even when P1 is the lower knight) |
| 4 | Independent tracking: while split, P1 moves and P2 stands still; then swap | Only the moving knight's view moves. The other view stays perfectly still |
| 5 | Reunification: walk the knights together, with each player taking a turn as the one who walks | After a short moment the halves line up and become one shared view with no visible jump. The divider disappears |
| 6 | Threshold stability: P1 at `P1 HERE`. P2 walks slowly back and forth between `MERGE` and `SPLIT`, then hovers right at the `SPLIT` tick | No flickering. Between the ticks the mode never changes. At the SPLIT tick it splits once and stays split until P2 comes back past MERGE |
| 7 | Interaction during transitions: push each other, jump, and use ladders while the view is splitting or merging | Movement and collisions behave exactly as in Phase 1 |
| 8 | Window resizing: drag the window edges larger and smaller, and maximise or restore it | The picture scales in whole-pixel steps with black bars. Nothing is stretched or blurred. Neither knight disappears, and the split layout stays correct |
| 9 | Level boundaries: walk each knight into every corner and wall, including the top of the tower and the far right | The cameras never show anything outside the level (no grey void beyond the walls) |
| 10 | Performance: both players run around, repeatedly splitting and merging, for 2–3 minutes | Smooth frame rate. The `nodes` and `objects` counters in the overlay do not keep growing |

## Known behaviour (not failures)

- Just before a merge completes (about half a second), two nearby knights can appear in **both**
  halves. This is one world seen through two cameras, not duplicated knights.
- If the knights have swapped sides (P1 right of P2, or P1 below P2), the split and the merge
  **cut** instead of sliding, because each view always belongs to the same player.
- An orientation change (side-by-side ↔ stacked) is an instant re-layout. It only happens when
  the other direction clearly dominates for a moment (hysteresis 1.35×, 0.35 s).
- The camera does not zoom (decision D-8).

## Record your results

```
Test | Result (pass/fail) | Notes
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
Monitor resolution / refresh rate:
Anything that felt jumpy, slow or confusing:
```
