# Level Validation Matrix

One row per level; every level has its own result. Updated 2026-11-08 after the gameplay
overhaul (levels rebuilt or remixed, new enemies and mechanisms), from the full regression run (the probe, route and timing results are written by the
tests to `user://level_validation_results.json`, `user://route_validation_results.json` and
`user://platform_timing_results.json`).

**Two kinds of evidence, kept apart:**

- **Automated (columns 1–20, Route, Timing):** run by the tests in the real game code, with
  real input and physics, headless. They prove that each mechanism works and that the level
  can be completed by the knights' real movement. They do **not** prove that a level is clear,
  fair or fun, that the camera reads well on a monitor, or how long it takes.
- **Manual:** two people playing. **No level has been played by people since the overhaul.**
  Levels 1–4 were passed on the first attempt by the user before the overhaul
  (`docs/PLAYTEST_FEEDBACK.md`), but they have been rebuilt since, so that report no longer
  applies to them.

Statuses: NOT TESTED / PASS / PASS WITH MINOR ISSUES / FAIL / BLOCKED, plus **N/A** where the
level has no such element (listed below the table). No automated check is FAIL or BLOCKED.

## Checks

| # | Check | How the automated test does it (`tests/framework/level_probe.gd`, `test_level_validation`) |
|---|---|---|
| 1 | Level scene loads | Loaded by the real `CampaignGame` from `LevelCatalog` |
| 2 | Player One spawns | Standing on the floor at the catalog spawn |
| 3 | Player Two spawns | As 2 |
| 4 | Both players move | Both run with real input, both move |
| 5 | Jumping | Both jump with real input and rise at least 24 px |
| 6 | Climbing | A knight grabs a ladder with real input and climbs at least 24 px (each ladder) |
| 7 | One-way platforms | A knight presses Down on a one-way tile with a safe landing below and drops through |
| 8 | Player collision | Knights walking into each other never overlap |
| 9 | Camera | Rig bounds equal the level's `CameraBounds`; knights half a screen apart split the view; together again it merges |
| 10 | Enemies | Slimes and every new enemy type released for 4 s: they move, none falls out of the level, no ground enemy hangs in the air (bats fly) |
| 11 | Combat | Player One's real attack lands on a ground enemy: a slime gains stagger progress, an orc or hollow soldier loses health, an ember slime lights its fuse (rules: `test_slimes`, `test_enemies`) |
| 12 | Hazards | A knight placed on every spike and hot-ground strip loses exactly one health; every lava pool is at least one tile deep (readable). Lava's instant death is never triggered by the probe (it would end the run); it is covered by `test_hazards` / `test_team_wipe` |
| 13 | Collectibles | A knight placed on every coin stash, fruit and jar collects it, its id is recorded and the coins are counted |
| 14 | Permanent upgrades | Every jar changes the collecting knight's `PlayerStats` and not the other knight's |
| 15 | Temporary effects | Every power tile gives the knight an active timed effect |
| 16 | Cooperative puzzles | Every non-boss gate and platform controller is solved the way knights would (plates by standing, switches and targets by real attacks, sync targets together, sequences in order) and opens; every arena lock closes with both knights inside and reopens once its enemies are defeated (defeated by script; fighting is checks 10–11 and `test_enemies`) |
| 17 | Optional areas | Static analyzer: every collectible, boss and reward is reachable (bosses may be required only for their own reward) |
| 18 | Main exit | A knight in the exit loads the correct next level (l24: the campaign completes) |
| 19 | Progression | The level is in `completed_levels`, has a level time, and the save names the next level |
| 20 | Save and resume | Save mid-level, load into a new game: level, coins, collected items and position match |
| Route | Physical route | `RouteValidator` (`test_campaign_routes`): the knight jumps every jump of the cheapest spawn→exit route with real input and base stats, no bosses, no upgrades. "6/6" = jumps made / jumps on the route; moving-platform rides are not counted |
| Timing | Timed chains | `test_platform_timing`: every blinking-stone chain recorded for 30 s and crossable with 0.55 s hops, a 0.3 s landing margin and at least 0.25 s on each stone; "slack" = the shortest time a knight can stand on a stone of that chain |

## Results

| Level | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 | Route | Timing | Manual |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| l01 The Mossy Path | PASS | PASS | PASS | PASS | PASS | N/A | PASS | PASS | PASS | PASS | PASS | N/A | PASS | N/A | PASS | PASS | PASS | PASS | PASS | PASS | PASS (6/6 jumps) | N/A | NOT TESTED |
| l02 Rootway Hollows | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | N/A | N/A | PASS | PASS | PASS | PASS | PASS | PASS (2/2 jumps) | N/A | NOT TESTED |
| l03 Old Watchtrees | PASS | PASS | PASS | PASS | PASS | N/A | PASS | PASS | PASS | PASS | PASS | N/A | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS (9/9 jumps) | N/A | NOT TESTED |
| l04 Heart of the Grove | PASS | PASS | PASS | PASS | PASS | PASS | N/A | PASS | PASS | PASS | PASS | PASS | PASS | N/A | PASS | PASS | PASS | PASS | PASS | PASS | PASS (2/2 jumps) | N/A | NOT TESTED |
| l05 Crystal Descent | PASS | PASS | PASS | PASS | PASS | N/A | N/A | PASS | PASS | PASS | PASS | PASS | PASS | PASS | N/A | N/A | PASS | PASS | PASS | PASS | PASS (7/7 jumps) | N/A | NOT TESTED |
| l06 Echoing Shafts | PASS | PASS | PASS | PASS | PASS | N/A | PASS | PASS | PASS | PASS | PASS | N/A | PASS | N/A | PASS | N/A | PASS | PASS | PASS | PASS | PASS (8/8 jumps) | PASS (min slack 3.20 s) | NOT TESTED |
| l07 Brood Caverns | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | N/A | PASS | PASS | PASS | PASS | PASS | PASS (1/1 jumps) | N/A | NOT TESTED |
| l08 The Sunless Lift | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | N/A | PASS | N/A | N/A | PASS | PASS | PASS | PASS | PASS | PASS (0/0 jumps) | N/A | NOT TESTED |
| l09 Sunken Gatehouse | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | N/A | PASS | N/A | N/A | PASS | PASS | PASS | PASS | PASS | PASS (2/2 jumps) | N/A | NOT TESTED |
| l10 Hall of Echoes | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | N/A | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS (2/2 jumps) | N/A | NOT TESTED |
| l11 Twin Sanctums | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | N/A | PASS | PASS | PASS | PASS | PASS | PASS | PASS (2/2 jumps) | N/A | NOT TESTED |
| l12 The Gilded Seal | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | N/A | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS (1/1 jumps) | N/A | NOT TESTED |
| l13 Ashen Steps | PASS | PASS | PASS | PASS | PASS | N/A | N/A | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS (6/6 jumps) | N/A | NOT TESTED |
| l14 Cinder Bridges | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | N/A | N/A | PASS | PASS | PASS | PASS | PASS | PASS (10/10 jumps) | PASS (min slack 1.92 s) | NOT TESTED |
| l15 Forge of Embers | PASS | PASS | PASS | PASS | PASS | PASS | N/A | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS (6/6 jumps) | N/A | NOT TESTED |
| l16 Heart of the Mountain | PASS | PASS | PASS | PASS | PASS | N/A | PASS | PASS | PASS | PASS | PASS | PASS | PASS | N/A | PASS | PASS | PASS | PASS | PASS | PASS | PASS (13/13 jumps) | PASS (min slack 2.05 s) | NOT TESTED |
| l17 Iron Gate Keep | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | N/A | PASS | PASS | PASS | PASS | PASS | PASS (1/1 jumps) | N/A | NOT TESTED |
| l18 Clockwork Halls | PASS | PASS | PASS | PASS | PASS | PASS | N/A | PASS | PASS | PASS | PASS | PASS | PASS | N/A | PASS | PASS | PASS | PASS | PASS | PASS | PASS (4/4 jumps) | N/A | NOT TESTED |
| l19 Broken Towers | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | N/A | PASS | PASS | PASS | PASS | PASS | PASS (10/10 jumps) | N/A | NOT TESTED |
| l20 The Black Bastion | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | N/A | N/A | PASS | PASS | PASS | PASS | PASS | PASS (6/6 jumps) | N/A | NOT TESTED |
| l21 Frost Causeway | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | N/A | PASS | PASS | PASS | PASS | PASS | PASS (17/17 jumps) | PASS (min slack 3.22 s) | NOT TESTED |
| l22 Spire of Silence | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS (11/11 jumps) | PASS (min slack 3.40 s) | NOT TESTED |
| l23 Warden's Vault | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | N/A | PASS | PASS | PASS | PASS | PASS | PASS (5/5 jumps) | N/A | NOT TESTED |
| l24 Crown of Dawn | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | N/A | PASS | PASS | PASS | PASS | PASS | PASS | PASS (7/7 jumps) | PASS (min slack 1.65 s) | NOT TESTED |

**N/A details** (the level has no such element):

- **l01**: climb (no ladders); hazards (no hazards); upgrades (no jars; fruit upgrades are checked under 13)
- **l02**: upgrades (no jars; fruit upgrades are checked under 13); effects (no power tiles)
- **l03**: climb (no ladders); hazards (no hazards)
- **l04**: one_way (no one-way tile with a safe landing below; drops into lava or onto spikes are not tried); upgrades (no jars; fruit upgrades are checked under 13)
- **l05**: climb (no ladders); one_way (no one-way tile with a safe landing below; drops into lava or onto spikes are not tried); effects (no power tiles); puzzles (no mechanisms)
- **l06**: climb (no ladders); hazards (no hazards); upgrades (no jars; fruit upgrades are checked under 13); puzzles (no mechanisms)
- **l07**: effects (no power tiles)
- **l08**: hazards (no hazards); upgrades (no jars; fruit upgrades are checked under 13); effects (no power tiles)
- **l09**: hazards (no hazards); upgrades (no jars; fruit upgrades are checked under 13); effects (no power tiles)
- **l10**: hazards (no hazards)
- **l11**: upgrades (no jars; fruit upgrades are checked under 13)
- **l12**: hazards (no hazards)
- **l13**: climb (no ladders); one_way (no one-way tile with a safe landing below; drops into lava or onto spikes are not tried)
- **l14**: upgrades (no jars; fruit upgrades are checked under 13); effects (no power tiles)
- **l15**: one_way (no one-way tile with a safe landing below; drops into lava or onto spikes are not tried)
- **l16**: climb (no ladders); upgrades (no jars; fruit upgrades are checked under 13)
- **l17**: effects (no power tiles)
- **l18**: one_way (no one-way tile with a safe landing below; drops into lava or onto spikes are not tried); upgrades (no jars; fruit upgrades are checked under 13)
- **l19**: effects (no power tiles)
- **l20**: upgrades (no jars; fruit upgrades are checked under 13); effects (no power tiles)
- **l21**: effects (no power tiles)
- **l23**: effects (no power tiles)
- **l24**: upgrades (no jars; fruit upgrades are checked under 13)

## Campaign-wide checks

| Check | Result | Evidence |
|---|---|---|
| Every transition loads the correct next level (l01→…→l24) | PASS (automated) | Check 18 on each level; `test_registry_is_linear_and_trusted` |
| World order (Worlds 1–6, four levels each) | PASS (automated) | `test_six_worlds_of_four_levels` |
| Main campaign completable without optional bosses | PASS (automated) | Route column (bosses removed); `test_main_route_never_needs_a_boss` |
| Main campaign completable with base stats (no upgrades) | PASS (automated) | Route column |
| No place where a knight can be trapped forever | PASS (automated) | `test_no_level_can_trap_a_knight` (two traps found and fixed in Phase 11: KI-97, KI-98) |
| Final level completes the campaign; victory kept | PASS (automated) | `test_final_level_completes_the_campaign`, `test_victory_result_is_kept_and_replay_needs_confirmation` |
| Save and resume in every world | PASS (automated) | Check 20; `test_save_and_resume_in_every_world`; `test_release_saves` |
| Whole campaign played by people from l01 to the victory | NOT TESTED | `docs/FINAL_MANUAL_TEST_PLAN.md` |

## Manual results

| Level | Status | Source |
|---|---|---|
| l01–l24 | NOT TESTED since the overhaul (l01–l04 were passed before it, on their old layouts) | `docs/PLAYTEST_FEEDBACK.md` |

Per-check manual results go into `docs/CAMPAIGN_PLAYTEST.md` and are summarised here when
they exist. A level counts as manually validated only when two people have played it and
recorded its checklist.
