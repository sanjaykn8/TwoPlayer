# Release Readiness Report

Phase 11, 2026-11-04. Godot 4.7.2, Windows. This report says what is known, how it is known,
and what is still missing before the game can be called a release candidate.

**Evidence labels used throughout:** **Implemented** (in the code) · **Auto-tested** (an
automated test in `tests/` passed) · **Measured** (a real run on this machine) ·
**User-reported** (the user said so) · **Pending** (needs people to test it) · **Not
implemented**.

## 1. Summary and recommendation

**Not yet a validated release candidate.** No known P0 issue and no known P1 game defect is
open, and the automated validation of all 24 levels passes. But the campaign has only been
played by people through level 4, the two-player session has not happened, playtime is
unmeasured, and no export build exists. The game is **ready for the final manual playtest**,
which is the remaining gate.

| Release-candidate criterion (Phase 11 Part L) | Status | Evidence |
|---|---|---|
| 1. No P0 bugs | Met (known) | None found; `docs/KNOWN_ISSUES.md` |
| 2. No known P1 progression blockers | Met (known) | Five P1-class level defects found and fixed (KI-97, KI-98, KI-101 ×3 levels); KI-5 is the export environment, not gameplay |
| 3. No known critical save corruption | Met | `test_release_saves`, `test_save_slots`, `test_team_wipe` (Auto-tested) |
| 4. No permanent puzzle softlocks in validated scenarios | Met | Probe check 16 on 24 levels; `test_no_level_can_trap_a_knight`; Phase 7 recoverability tests (Auto-tested) |
| 5. All 24 level scenes load | Met | Matrix check 1 (Auto-tested) |
| 6. All 24 exits work | Met | Matrix check 18 (Auto-tested) |
| 7. Save and resume across the campaign | Met (auto) / Pending (manual) | Matrix check 20; four slots in four worlds |
| 8. Team wipe resets correctly | Met (auto) / Pending (manual) | `test_team_wipe` (13), `test_release_saves` |
| 9. Optional bosses are optional | Met | RouteValidator walked every level with bosses removed; `test_main_route_never_needs_a_boss` |
| 10. Final victory works | Met (auto) / Pending (manual) | `test_final_level_completes_the_campaign` |
| 11. UI works | Auto-tested / Pending (manual, KI-75) | Phase 9 UI tests |
| 12. Audio works | Auto-tested / Pending (by ear, KI-75) | `test_audio_system`, `test_ui_audio` |
| 13. Offline execution | Auto-tested for code (`test_game_code_is_offline`); export **not possible yet** (KI-5) | — |
| 14. Real Windows hardware tested | Partly: performance measured in a real window on this PC; the user played levels 1–4 on their machine | §8 |

## 2. P0 issues

None found. The P0 areas were stress-tested (§7): saves lost, old campaign restored after a
wipe, slots overwriting each other, progression corrupted, campaign impossible.

## 3. P1 issues

| ID | Issue | State |
|---|---|---|
| KI-97 | L20 coin vault could be entered but not left (stuck for good; quitting saved the knight inside) | **Fixed**: ladder out; trap test |
| KI-98 | L22 spire floor east of a nine-tile spike bed: the only way back was walking the spikes | **Fixed**: bed split with a safe island |
| KI-101 | Blinking chains on L14 and L16 (over lava) and L22 vanished ahead of the knights: no timing crossed them | **Fixed**: phase order reversed |
| KI-5 | Export templates not installed (release environment) | **Open**, user action, Phase 12 |

All three level defects were invisible to the Phase 10 checks. They were found by the new
Phase 11 tools: the reverse "trap" search and the platform timing test.

## 4. P2 and P3 issues

Fixed in Phase 11: KI-99 (teleport kept the ladder regrab delay), KI-100 (analyzer allowed a
jump through solid terrain), KI-102 (L06 bridge window 0.5 s), KI-83 (runner passed tests
with script errors), KI-104 (route validator leaked level copies).

Open P2: KI-85 placeholder title, KI-27 slash art vs range, KI-106 gates without a nearby
clue (playtest decides). Open P3: 18 cosmetic or polish items (placeholder art and frames,
camera merge cosmetics, menu W/S, no focus pause, one 32 ms frame in l03). Full list in
`docs/KNOWN_ISSUES.md`.

## 5. Campaign validation

| Check | Result | Label |
|---|---|---|
| 20 runtime checks on each of the 24 levels (real input, real physics) | 24 × PASS (N/A where the level has no such element; no FAIL, no BLOCKED) | Auto-tested |
| Physical main route, base knight, no bosses, no upgrades | 24 / 24: every jump made with real input, 0 banned edges | Auto-tested |
| Blinking chains crossable with 0.55 s hops, 0.3 s landing margin, 0.25 s reaction | 6 levels, all PASS; shortest stays l24 1.65 s, l14 1.92 s, l16 2.05 s | Auto-tested |
| No place a knight can be trapped forever | 24 / 24 | Auto-tested |
| Transitions l01 → l24 and victory | PASS | Auto-tested |
| Played by people | l01–l04: reached and passed on the first attempt; l05–l24: not played | User-reported / Pending |

Details per level: `docs/LEVEL_VALIDATION_MATRIX.md`.

## 6. Difficulty findings

**Baseline (User-reported):** "The game felt difficult." "The difficulty appeared manageable."
Levels 1–4 passed on the first attempt. Read together: World 1 is challenging but fair, the
intended feel. **No general difficulty reduction was made.** Enemy rules (green 2 hits, purple 4
hits, stagger ≥ 10 s, one more hit kills, chase = 2 × patrol, no contact damage while
staggered), damage rules (lava instant death; spikes, hot ground and falls 1 health) and the
team-wide permadeath are untouched.

**What the levels ask, counted from the built scenes** (`tools/difficulty_report.gd`; route =
the cheapest spawn→exit route with gates open; "lethal below" = a miss lands in lava or on
spikes; "at limit" = a jump at the maximum of the movement envelope):

| Level | Diff. | Route jumps | At limit | Lava below | Spikes below | Platform hops | Lava-crossing stones | Slimes near route (green/purple) | Two-knight locks |
|---|---|---|---|---|---|---|---|---|---|
| l01 | 1 | 6 | 1 | 0 | 0 | 0 | 0 | 4/0 | 0 |
| l02 | 2 | 7 | 0 | 0 | 0 | 2 | 0 | 4/0 | 1 |
| l03 | 2 | 11 | 2 | 0 | 1 | 7 | 0 | 4/0 | 0 |
| l04 | 3 | 5 | 0 | 0 | 0 | 2 | 0 | 4/0 | 1 |
| l05 | 3 | 10 | 0 | 0 | 6 | 3 | 0 | 2/2 | 0 |
| l06 | 4 | 3 | 0 | 0 | 3 | 3 | 0 | 1/2 | 0 |
| l07 | 4 | 2 | 0 | 0 | 0 | 1 | 0 | 3/4 | 0 |
| l08 | 5 | 17 | 0 | 0 | 0 | 17 | 0 | 1/3 | 0 |
| l09 | 5 | 1 | 0 | 0 | 0 | 0 | 0 | 3/2 | 2 |
| l10 | 6 | 3 | 0 | 0 | 0 | 1 | 0 | 2/3 | 0 |
| l11 | 6 | 2 | 0 | 0 | 0 | 0 | 0 | 1/2 | 0 |
| l12 | 7 | 1 | 0 | 0 | 0 | 0 | 0 | 1/3 | 2 |
| l13 | 6 | 10 | 0 | 9 | 0 | 8 | 3 | 2/2 | 0 |
| l14 | 7 | 10 | 2 | 10 | 0 | 8 | 7 | 2/3 | 0 |
| l15 | 7 | 9 | 0 | 7 | 0 | 7 | 3 | 2/4 | 0 |
| l16 | 8 | 22 | 0 | 14 | 0 | 21 | 9 | 2/4 | 0 |
| l17 | 7 | 2 | 0 | 0 | 1 | 1 | 0 | 3/3 | 1 |
| l18 | 8 | 4 | 2 | 0 | 3 | 3 | 0 | 2/3 | 0 |
| l19 | 8 | 11 | 0 | 0 | 11 | 11 | 0 | 2/3 | 0 |
| l20 | 9 | 14 | 0 | 0 | 5 | 13 | 0 | 2/4 | 2 |
| l21 | 8 | 17 | 2 | 6 | 11 | 15 | 5 | 1/4 | 0 |
| l22 | 9 | 19 | 9 | 0 | 4 | 17 | 0 | 1/2 | 1 |
| l23 | 9 | 5 | 0 | 5 | 0 | 5 | 4 | 3/4 | 0 |
| l24 | 10 | 10 | 0 | 6 | 0 | 6 | 3 | 1/3 | 2 |

Findings:

- **The curve rises by world, by different means.** World 1 is movement and green slimes;
  World 2 brings purple slimes, spike-lined routes and the 17-hop lift shaft (l08); World 3
  replaces platforming with puzzles and two-knight locks (l09–l12 have 1–3 jumps); World 4
  makes misses lethal (6–14 lava-over jumps per level; l16 is the peak, 14); World 5 moves the
  risk to spikes and towers (l19: 11 spike-over jumps); World 6 combines everything (l21 lava
  and spikes, l22 nine jumps at the limit, l24 lava plus two locks).
- **World 3 (l09–l12) has very few jumps.** Its challenge is puzzles and enemies, which this
  table cannot weigh. It may play easier than its difficulty numbers (5–7) say. **Not
  changed**: whether it feels like a lull needs the playtest; record times and wipes there.
- **l13 (difficulty 6) has more lethal jumps than l12 (7).** Expected: l13 opens the lava
  world, so lethal misses are new there, but none of its jumps is at the movement limit and
  its wide crossings use crumbling stones and moving platforms. No change.
- **l22 has 9 jumps at the movement limit**, the most of any level, plus a blinking
  staircase. It is a deliberate finale-world climb; falls land on the spire floor (no lava).
  Kept, now that the trap (KI-98) and the chain timing (KI-101) are fixed.
- **No mandatory route needs an upgrade, a boss or a lucky coin heal** (RouteValidator: base
  stats, bosses removed; coin heal never assumed).
- **Lethal hazards are visible**: every lava pool is at least one tile deep (probe check 12)
  and drawn with the lava theme; spikes and hot ground cost exactly one health (probe).
  Readability on a real monitor is a playtest item.

**Changes to the original difficulty** (all evidence-based; nothing was made easier because
the game felt hard):

| Change | Why | Effect on difficulty |
|---|---|---|
| L14, L16, L22 blinking-stone order reversed (KI-101) | Impossible: no timing crossed the chain | Was impossible, now hard. Same timing, stones and lava |
| L06 blinking-bridge order reversed (KI-102) | 0.5 s best window: luck rather than skill | Fair window (3.2 s); same timing and gaps |
| L20 ladder out of the coin vault (KI-97) | Permanent trap | None on the main route (optional vault) |
| L22 spike bed split by a three-tile safe island (KI-98) | Trap after a fall | Falls still hurt; the way back is jumpable |

## 7. Save integrity and team wipe

All Auto-tested in the production campaign (`test_release_saves`, plus Phase 8–9 suites
`test_save_slots` 18, `test_campaign_save` 10, `test_team_wipe` 13, `test_exit_save` 2,
`test_save_slot_ui` 12):

| Area | Result |
|---|---|
| Four slots in four worlds (l03, l10, l17, l23) | Each restores exactly: level, coins, upgrades, health, poison and shield time, position, defeated slime, completed levels |
| Save on exit (window close) | The process saves before exit (real child process) |
| Normal save, resume, transitions, dropped coins, collected items, puzzles, platforms | PASS (Phase 8 suites; matrix check 20 on all 24 levels) |
| Player One death / Player Two death / lava death / both in one frame | One wipe, fresh run at l01 |
| Death during a level transition with a pending save | One wipe; the transition does not win |
| Close request during the wipe | The dead run is never saved or restored |
| After a wipe | Coins 0, upgrades removed, all six worlds' progress reset, no backup of the dead run, loading never returns it |
| Other three slots after a wipe in a world 5 slot | Byte-identical |
| Corruption | Refused: tampered checksum, invalid JSON, future format, missing players, health above max, negative upgrade, unknown level `l99`, a scene path as level, duplicate coin ids. Damaged primary with valid backup → recovered and reported; damaged backup alone detected; both damaged → reported, never silently replaced |

Not claimed: protection against every disk failure or power cut (KI-68). Manual save tests
(real window X, Alt+F4) are pending (KI-65).

## 8. Camera and performance

**Camera, Auto-tested:** `test_camera_rig` (21: shared, side-by-side and stacked split,
merge hold, hysteresis, jitter at the threshold, bounds), probe check 9 on every level (rig
bounds equal the level bounds; split at half a screen; merge on return), one HUD in every
camera mode. **Pending:** readability on a real monitor, window resizing by hand (KI-18,
KI-20, M-C1…M-C4).

**Performance, Measured** in a real window (not headless) during Phase 11: all 24 levels in a
row, then back to the menu.

| Item | Value |
|---|---|
| Machine | Windows 11, Intel Core i5-13450HX, NVIDIA GeForce RTX 4050 Laptop GPU |
| Window | 1280×720 (2× the 640×360 game), vsync on |
| Average | 60.0 fps on the menu and on every level (16.66–16.67 ms) |
| 99th percentile frame | 17.1–18.1 ms on every level |
| Worst frame | 32.3 ms once in l03 (the only frame above 25 ms in the whole run, KI-103); otherwise ≤ 23.2 ms |
| Scene size | 192–324 nodes per level, 35–56 draw calls |
| Leaks | 0 orphan nodes per level; 1 audio player throughout; after 24 levels the menu has 39 nodes and 0 orphans; static memory 83 MB |

Limits: vsync caps the frame rate at 60, so headroom above 60 fps was not measured; one
machine only; the release export (KI-5) has not been measured.

## 9. Playtime

**Not measured.** No level time has been recorded by a person (the user's slot held a fresh
run with 1.2 s of play). Known numbers, not measurements:

| Measure | Value | Label |
|---|---|---|
| Design estimates, sum of 24 levels | 124 min | Estimate |
| Pure movement along the routes (analyzer) | 9.5 min | Lower bound |
| Target | 90–120 min first completion | GDD |

The gap between 9.5 and 124 minutes is filled by combat, puzzles, waiting on platforms,
exploration and coordination, which only play can measure. KI-89 stays open; M-T1 in the
manual plan records it. If the playtest shows the campaign is short, the planned levers are
optional rooms and cooperative sections, not padding.

## 10. Manual testing still required

1. Two-player session: `docs/TWO_PLAYER_PLAYTEST.md` (20 tests, including keyboard rollover).
2. Levels 5–24 played in order with times: `docs/CAMPAIGN_PLAYTEST.md`.
3. Final manual plan: `docs/FINAL_MANUAL_TEST_PLAN.md` (bosses, camera, saves with X and
   Alt+F4, menus, audio by ear, settings after a restart, victory).
4. Older focused checklists still open: KI-18, 25, 32, 38, 46, 55, 65, 75.

## 11. Release blockers

| Blocker | Owner |
|---|---|
| Manual campaign and two-player playtest (levels 5–24 never played by people) | User |
| Playtime measured (KI-89) | User (during the playtest) |
| Export templates installed (KI-5), then an offline export build tested | User, then Phase 12 |
| Game title chosen (KI-85) | User |

Any P0 or P1 found in the playtest is also a blocker until fixed.
