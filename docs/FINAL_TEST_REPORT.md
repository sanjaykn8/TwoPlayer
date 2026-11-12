# Final Test Report (final pass, 2026-11-12)

What was tested after the final development pass, how, and with what result. Earlier phases
are in `docs/TEST_REPORT.md`; per-level results are in `docs/LEVEL_BY_LEVEL_QA.md` and
`docs/LEVEL_VALIDATION_MATRIX.md`.

## 1. Summary

| Item | Result |
|---|---|
| Automated tests | **516 passed, 0 failed**, in two consecutive full runs (48 test files, about 1 min 50 s each, headless, fixed 60 fps) |
| Errors, warnings, script errors in the full-run logs | 0 in both runs (the runner fails any test that logs one) |
| Leak or orphan lines after the summary | None in either run |
| Levels | All 24 pass every check that applies to them (see §3) |
| Real-window checks | Renders of six changed levels, three gameplay screenshots, the HUD with six effects, the Controls screen, and a performance run over all 24 levels |
| Manual play by people | **Not done.** Nothing in this report is a manual result |
| Export or release build | Not built and not tested (not requested) |

Before the pass the suite had 497 tests. The pass added 19: `test_final_range` (5),
`test_final_coop` (9), `test_optional_routes` (2), one HUD test, and two in the power-up
suites (others there were rewritten for the new rules).

## 2. Commands

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . --import
Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 60 --script res://tests/run_tests.gd
```

The exit code is the number of failures (0 in both final runs). Add `-- <substring>` to run
some files only, for example `-- test_final`.

## 3. Levels: every level, every check

| Check | Suite | Levels | Result |
|---|---|---|---|
| 20 probe checks (load, spawns, movement, ladders, camera, enemies, combat, hazards, pickups, upgrades, effects, puzzles and arenas, optional areas, exit, progression, save and resume) | `test_level_validation` | 24 | PASS (every check PASS or N/A; no FAIL, no BLOCKED) |
| Main route walked by the real knight with base stats | `test_campaign_routes` | 24 | PASS (147 jumps made of 147, none banned; 65 steps onto or off moving platforms are skipped, see §8) |
| New optional routes walked by the real knight | `test_optional_routes` | 17 levels, 19 routes | PASS |
| Blinking chains crossable | `test_platform_timing` | 6 levels with chains | PASS (smallest slack 1.65 s, l24) |
| Exit, collectibles and inputs reachable; no impossible lock; no boss needed; **no trap** | `test_campaign_levels` | 24 | PASS |
| Safe spawns | `test_campaign_flow` | 24 | PASS |
| One knight alone at the exit, partner far away | `test_final_coop` | 24 | PASS |
| A knight's death restarts the campaign | `test_final_coop` | 24 | PASS |
| Quit (close request) and reopen with effects running | `test_final_coop` | 24 | PASS |

Found by these checks during the pass and fixed before the commit: KI-117 (l06's new wind did
not reach its shelf) and KI-118 (the probe did not know the refusal rule). Details in
`docs/KNOWN_ISSUES.md`.

## 4. Combat and reach

| Test | Result |
|---|---|
| Reach grew 1.33× in every direction; all directions equal | PASS |
| A real swing at each of the 14 enemy types: misses from 3 px beyond the reach, is blocked by a wall, hits exactly once from the edge of the new reach | PASS for all 14 (green and purple slime, grunt, brute, shieldbearer, archer, bat, ember slime, Warchief, Captain, Crowned Hollow, Brood Mother, Magma Heart, Citadel Warden) |
| Up-swing reaches as far as a side swing | PASS |
| No melee enemy can be poked from outside its own strike; wind-ups ≥ 0.2 s | PASS (6 enemies) |
| A grunt answers a knight standing at full reach | PASS |
| Existing combat, enemy, slime and boss suites with the new numbers | PASS (`test_combat` 25, `test_combat_expansion` 8, `test_combat_logic` 11, `test_enemies` 14, `test_slimes` 25, `test_boss` 4, `test_enemy_logic` 9) |

## 5. Power-ups

| Area | Suite | Result |
|---|---|---|
| Rules: ward, venom, caps, protection order, snapshot, legacy conversion | `test_progression_logic` (13) | PASS |
| Each item on real knights: effect, collector only, feast, refusals, capped jar left for the partner, tile cycle, exact durations, no duplicate pickup | `test_collectibles` (23) | PASS |
| HUD: indicator text and seconds, upgrades line, six effects wrap and stay clear of the coin panel | `test_hud` (10) | PASS |
| Every placed fruit, jar, stash and tile in all 24 levels | `test_level_validation` | PASS |
| Saved and restored through slots, relaunches and wipes | `test_release_saves` (5), `test_team_wipe` (13), `test_campaign_save` (10), `test_final_coop` | PASS |

## 6. Co-op edge cases

| Case | Where tested | Result |
|---|---|---|
| Player One reaches the exit first; Player Two reaches it first | Every level, alternating (`test_final_coop`) | PASS |
| The knights are far apart | Same test (partner > 400 px from the exit); camera split in the probe | PASS |
| One knight dies | Every level, alternating | PASS: one wipe, new run at l01 |
| Both knights die in the same frame | `test_team_wipe`, `test_release_saves` | PASS: exactly one wipe |
| A pickup while the partner is elsewhere | l04 venom, l11 feast, l05 ward | PASS: collector only; the feast heals the far partner 1 |
| Both knights take the same jar in the same frame | l03 | PASS: exactly one upgrade |
| Death while temporary effects are active | l13 (lava, with shield and ward) and every level's death test | PASS: nothing survives |
| Quit and reopen | Every level, with venom, haste and a recharging ward | PASS |
| Load a save | Every level (probe check 20), four slots (`test_release_saves`, `test_save_slots`) | PASS |
| Both knights use a mechanism together | l16 twin hearts in the same frame; sync and two-plate locks in the probe | PASS |
| A death during a level transition; the exit and a death in one frame | `test_team_wipe`, `test_campaign_flow` | PASS: the death wins |
| New co-op mechanisms in their levels | l05 jar door, l19 span, l16 summit gate | PASS |

## 7. Real-window checks (not headless)

| Check | Result |
|---|---|
| Whole-level renders of l01, l05, l06, l11, l13, l19 | New areas look as designed. One sign text sat beside another in l13; the sign was moved |
| Reach crescent on a side slash and an up slash (640×360 screenshot, zoomed) | On the far edge of the slash; purple with venom |
| Power tile label, refusal text ("FULL HEALTH"), HUD with 2, 3 and 6 effects | Readable. Found KI-116 (HUD panel over the coin panel) and fixed it |
| Controls screen with the new power-up line | Fits the 640×360 screen |
| Performance, all 24 levels, real time, vsync on a 144 Hz display | 144 fps average on every level (worst level average 142.6); 0 orphan nodes; 1 audio player; back on the menu the node count returns to 39. Two single long frames: 37 ms in l09 and 89 ms in l13 (KI-121) |
| Stress: l12 with 24 extra enemies and a Warchief | 144 fps, worst frame 7.8 ms |

Machine: Windows 11, i5-13450HX, RTX 4050 Laptop, 1280×720 window.

## 8. What was not tested, and why

| Not tested | Why | Risk | How to test it |
|---|---|---|---|
| The whole campaign played by two people | Needs people | Fun, clarity, fairness and length are unknown | Play from a new slot; `docs/FRIEND_PLAYTEST_CHECKLIST.md` |
| How the longer reach and the new power-ups feel | Needs people | A value may be a little too generous or too strict | `docs/COMBAT_AND_POWERUP_CHANGES.md` §3 (15 minutes) |
| Lantern and partner-boost routes (l01 secret room, l03 jar, l04 islet) | The route validator plans without them | An optional reward could be harder to reach than intended; never a blocker | Try them |
| Jumps onto and off moving platforms | Their position depends on time; the validator skips them | Covered by the probe solving each platform puzzle and by platform tests, but not jump by jump | Play l02, l04, l13, l15–l17 |
| Boss fights against real players | The probe wins arenas by script | Pattern difficulty unknown | Play l12, l20, l24 |
| Enemy and hazard pressure during puzzles | Checks remove enemies where they would add noise | A combination may be harsher than intended (l11 crypt plate, l12 gallery, l17 platforms) | Report deaths per level |
| Keyboard ghosting with six keys held | Hardware | Some keyboards drop keys | `docs/MANUAL_KEYBOARD_TEST.md` |
| Displays other than this laptop; sound balance | One machine | — | Listen and look |
| An exported build | Not requested | — | — |

## 9. Is the campaign ready for a full two-player playthrough?

Yes, as a playtest. Every level can be finished with base stats, nothing found can trap a
knight, saves, wipes and the four slots behave, and the suite is green twice with no error
lines. What is not known is everything only people can tell: whether it is fun, where it is
unclear, and whether any fight or jump feels unfair. Expect to find such things; write them
down with the level's name.
