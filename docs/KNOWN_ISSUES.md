# Known Issues

Updated 2026-11-04 (Phase 11).

## Severity scheme (Phase 11)

| Severity | Meaning | Examples | Rule |
|---|---|---|---|
| **P0 Critical** | Destroys saves or the campaign, or stops the game | Saves lost; old campaign restored after a team wipe; crash on start; campaign cannot be completed; both players permanently uncontrollable; slots overwrite each other; progression corrupted | Fix immediately |
| **P1 Major** | Blocks progress or breaks a core rule | Trapped in a required section; required puzzle unsolvable; camera makes required platforming impossible; combat fails to register; exits fail; progress lost on normal transitions | Fix before release |
| **P2 Moderate** | Wrong but not blocking | Animation sync errors; wrong non-critical feedback; minor sound or UI layout problems; occasional non-blocking inconsistencies | Fix where practical |
| **P3 Cosmetic** | Polish | Texture inconsistencies; decorative alignment; non-essential polish | Not before P0–P2 work |

Every defect has: ID, description, severity, reproduction, expected, actual, root cause, fix,
regression-test result. Two other kinds of entries are kept separately because those fields
do not apply to them: **verification gaps** (something not yet tested by people) and
**design notes** (deliberate behaviour or accepted limits). An issue is never removed because
a workaround exists; resolved issues move to the Resolved section with their fix.

**Current count: P0 open 0 · P1 open 1 (KI-5, release environment, not a game defect) · P2
open 3 · P3 open 18.** No known open P0 or P1 game defect. Manual testing is still pending
(see Verification gaps), so this is a statement about what is known, not a guarantee.

## Found and fixed in Phase 11

### KI-97 — L20 coin vault had no way out (P1, fixed)

| Field | Detail |
|---|---|
| Description | The optional coin vault under the cracked floor of The Black Bastion (l20) could be entered through a one-way tile but not left |
| Reproduction | l20: walk onto the one-way tile at tile x 140–141 on the ground (row 42) and press Down; try to get out |
| Expected | Every place a knight can enter has a way back (CLAUDE.md design rule) |
| Actual | The vault floor is four rows below the one-way tile; a knight jumps at most three. The knight was stuck for good. Saving there (autosave on quit) kept it stuck; the only escape was restarting the whole run |
| Root cause | Level spec `tools/campaign/world_5.gd` l20: the vault was cleared without an exit. The Phase 10 analyzer proved every collectible reachable, but never checked that every reachable place can still reach the exit |
| Fix | A ladder from the vault floor up through the tile at x 135 (`["clear",135,42,135,42], ["ladder",135,42,47]`). New analyzer search `trap_cells()` (reverse reachability from the exit) and test `test_no_level_can_trap_a_knight` |
| Regression test | `test_no_level_can_trap_a_knight`: PASS (all 24 levels, gates open and closed); l20 row of the validation matrix: PASS; route l20: PASS |

### KI-98 — L22 spire floor east of the spike bed was a trap (P1, fixed)

| Field | Detail |
|---|---|
| Description | In Spire of Silence (l22) a knight falling onto the spire floor east of the nine-tile spike bed (x 38–46) could not get back to the start of the climb |
| Reproduction | l22: fall from the crumbling stones or the first landing onto the floor right of the spikes |
| Expected | Falls land on the spire floor "to climb again" (level design note) |
| Actual | The only way back was across nine tiles of spikes, longer than any jump: the knight had to walk the bed and take a hit each time its invulnerability ran out. With little health left that is a death, which ends the run; the trap scan treats the bed as impassable |
| Root cause | Level spec `tools/campaign/world_6.gd` l22: one long spike bed with no safe tile |
| Fix | Split into two three-tile beds (`spikes 38–40` and `44–46`) with a three-tile safe island between; each bed can be jumped |
| Regression test | `test_no_level_can_trap_a_knight`: PASS; l22 matrix row: PASS (hazard check still finds both beds); route l22: PASS |

### KI-101 — Blinking-stone chains on L14, L16 and L22 vanished ahead of the knights (P1, fixed)

| Field | Detail |
|---|---|
| Description | In Cinder Bridges (l14, over the lava sea), Heart of the Mountain (l16, over lava) and Spire of Silence (l22, a staircase) the blinking stones' phases ran the wrong way: the stone ahead disappeared before the one the knight stood on |
| Reproduction | `test_platform_timing` before the fix; in play: try to cross the chain without stopping |
| Expected | A chain is hard but crossable with real hop times and a reaction margin |
| Actual | No timing crossed the whole chain (slack −1: impossible) with 0.55 s hops, a 0.3 s landing margin and 0.25 s reaction. Over lava, a forced death ends the run |
| Root cause | `TimedPlatform.start_offset` advances the phase (a higher offset vanishes **sooner**). The specs gave the offsets increasing in the direction of travel, which makes the wave run against the knights |
| Fix | Offsets reversed so they decrease along the route (l14: 1.8 → 0 in 0.3 s steps; l16: 1.8, 1.2, 0.6, 0 then 0.8, 0; l22: 1.8, 1.2, 0.6, 0). Timing, stone count, spacing and lava unchanged |
| Regression test | `test_every_timed_chain_can_be_crossed`: PASS. Shortest stay on a stone: l14 1.92 s, l16 2.05 s, l22 3.4 s. Routes l14/l16/l22: PASS |

### KI-102 — L06 blinking bridge had a 0.5 s window (P2, fixed)

| Field | Detail |
|---|---|
| Description | The blinking bridge in Echoing Shafts (l06) had the same reversed phase order as KI-101 |
| Reproduction | `test_platform_timing` |
| Expected | A normal reaction margin on each stone |
| Actual | Crossable, but the best timing left only 0.5 s on a stone, and only by waiting for the wave to come round |
| Root cause | As KI-101 (offsets 0, 0.8, 1.6 along the route) |
| Fix | Offsets 1.2, 0.6, 0 |
| Regression test | `test_every_timed_chain_can_be_crossed`: PASS (shortest stay 3.2 s) |

### KI-99 — A teleport kept the ladder regrab delay (P2, fixed)

| Field | Detail |
|---|---|
| Description | `Knight.teleport_to()` called on a climbing knight left the 0.25 s "do not regrab" delay of leaving a ladder running at the new place |
| Reproduction | Teleport a knight from one ladder to another and press Up at once (found by the level probe at l18 Ladder3 → Ladder2). In play: loading a save made while a knight was on a ladder, or a fall respawn next to a ladder |
| Expected | A teleport is a fresh placement; Up next to a ladder grabs it |
| Actual | For 0.25 s Up jumped instead of grabbing |
| Root cause | `teleport_to()` calls `_leave_climb()`, which starts `_regrab_timer` (meant only for jumping off a ladder) |
| Fix | `teleport_to()` resets `_regrab_timer` (`scenes/players/knight.gd`) |
| Regression test | `test_teleport_clears_the_ladder_regrab_delay`: PASS; `test_knight_movement` (26): PASS |

### KI-100 — Level analyzer let a jump pass through a solid slab (P2, tooling, fixed)

| Field | Detail |
|---|---|
| Description | The static analyzer accepted a downward jump on l04 from (107,23) to (113,27) that passes through solid terrain |
| Reproduction | `test_analyzer_never_jumps_through_solid` before the fix |
| Expected | The analyzer only accepts jumps whose arc is clear |
| Actual | It checked headroom at take-off and landing only, so it could report impossible routes as possible (hiding a P1) |
| Root cause | `tools/level_analyzer.gd` `_jump_clear` did not check the arc in between |
| Fix | Whole-arc check along the lowest playable arc (hump 1 tile up, 0.75 down; body rows at each column) |
| Regression test | `test_analyzer_never_jumps_through_solid`: PASS; `test_every_level_is_playable`: PASS; physical routes (RouteValidator): PASS on all 24 |

### KI-83 — Test runner passed tests that hit a SCRIPT ERROR (P2, tooling, fixed)

| Field | Detail |
|---|---|
| Description | A test whose code raised an engine or script error still counted as passed if no assertion failed |
| Reproduction | Any test that calls a method on a freed object |
| Expected | Any logged error fails the test |
| Actual | Reported PASS; full-run logs had to be searched by hand |
| Root cause | `tests/run_tests.gd` only counted assertion failures |
| Fix | A Godot `Logger` (`OS.add_logger`) collects every error and warning logged during a test and adds it to that test's failures |
| Regression test | Final full regression ×2: 461 passed, 0 failed, no logged errors |

### KI-104 — Route validator leaked a copy of every level (P3, tooling, fixed)

| Field | Detail |
|---|---|
| Description | The first Phase 11 full run ended with engine leak reports (5456 objects, physics and canvas RIDs) |
| Reproduction | `run_tests.gd -- test_campaign_routes` |
| Expected | No leaks at exit |
| Actual | Leaks reported after the summary line (tests themselves passed) |
| Root cause | `RouteValidator` instantiated a second, never-added copy of each level for the analyzer and never freed it |
| Fix | Free `analyzer.level` at the end of `validate()` |
| Regression test | `test_campaign_routes` alone and the full regression: no leak lines |

## Open defects

| ID | Sev. | Description | Reproduction | Expected | Actual | Root cause | Fix / plan | Regression test |
|---|---|---|---|---|---|---|---|---|
| KI-5 | P1 (release environment) | Windows export templates for 4.7.2 are not installed (`%APPDATA%/Godot/export_templates/` is empty) | Project → Export → Windows Desktop | A release build can be exported and run offline | Export impossible | Editor environment, not game code | User installs via Editor → Manage Export Templates (Phase 12) | Pending (Phase 12 export test) |
| KI-85 | P2 | Window title from `ui_config.tres` is "UNTITLED"; `application/config/name` is "2p" (task bar, exports) | Launch the game | The real title | Placeholder names | No title chosen (the user must choose it) | Set when the title is chosen (Phase 12) | — |
| KI-27 | P2 | The knife slash art does not grow with the red-fruit range bonus | Eat red fruit, attack | The drawn arc shows the reach | Hits land beyond the drawn arc | Pixel art cannot scale by 1.1–1.3 cleanly | Longer arc variant or range indicator (art polish) | — |
| KI-106 | P2 (pending playtest) | Gates with no clue within 24 tiles: l06 1, l09 2, l10 1, l11 4, l12 1, l18 1, l19 1, l20 1, l24 3 (boss reward gates excluded) | `tools/difficulty_report.gd` | Puzzle solvable by reasoning from the level (GDD) | Unknown: these gates may be clear from their switches, or not | Clues are placed per area, not per gate | Decide from the manual playtest; add clues only where players get stuck | — |
| KI-103 | P3 | One 32.3 ms frame in l03 during the 24-level performance run (every other frame of all levels ≤ 23.2 ms) | Windowed run, all 24 levels in a row | No frame above ~25 ms | One isolated spike, not reproduced | Unknown (single event; possibly first use of a shader or sound) | Watch in the manual playtest; profile if it recurs | Performance run: average 60.0 fps on every level |
| KI-17 | P3 | While two nearby knights wait out a merge (0.25 s + 0.3 s), both appear in both halves | Separate, then rejoin | Clean merge | Both knights briefly in both views | One world seen by two cameras | Tune `merge_hold_time` / `transition_duration` after manual tests | `test_camera_rig`: PASS |
| KI-19 | P3 | When P1 is right of or below P2, split and merge cut instead of sliding | Swap sides, separate | Slide | Cut | Fixed view identity per player | By design; revisit after manual tests | `test_camera_rig`: PASS |
| KI-79 | P3 | W/S do not move through menus | Main menu, press W/S | Optional | Only arrows, Enter/Space, Esc | Gameplay mappings kept separate | Revisit after manual keyboard test | — |
| KI-84 | P3 | No automatic pause on focus loss | Alt+Tab during play | Optional pause | Game keeps running | Not implemented | Consider after manual tests | — |
| KI-86 | P3 | Main-menu backdrop repeats its cloud band | Main menu | Seamless | Visible repetition | Bundle sky strip tiled | Art polish | — |
| KI-92 | P3 | Level art limits: flat banded skies, no terrain edge or corner tiles, thin wall columns above gates read as poles, mostly rectangular rooms | Any level | Polished art | Functional placeholder look | Asset bundle limits | Art polish | — |
| KI-58 | P3 | Gate, plate and target visuals are drawn by code; switches reuse "!" blocks | Any puzzle | Dedicated art | Placeholder | No bundle art | Art polish | — |
| KI-49 | P3 | Spike art is generated placeholder; hot ground reuses the red-earth tile with a glow | Any hazard | Dedicated art | Placeholder | No bundle art | Art polish | — |
| KI-50 | P3 | Platforms wider than two tiles show a seam every two tiles | Wide platform | Seamless | Seams | `platforms.png` has no middle piece | Draw a middle piece | — |
| KI-51 | P3 | Under the hazard test-room lava pit the next row is grass-topped | Dev room only | Lava bed | Grass top | Auto-tiling | Dev room only | — |
| KI-39 | P3 | The red jar is the magenta bottle tinted red | Pick up red jar | Own art | Tinted | No red bottle in bundle | Art polish | — |
| KI-33 | P3 | Slimes have no death or attack animation (squash-and-fade placeholder, briefly non-integer scale) | Kill a slime | Death frames | Placeholder | Bundle lacks frames | Art polish | — |
| KI-26 | P3 | No knight attack body animation; the generated slash overlays idle/run frames | Attack | Attack pose | Overlay only | Bundle lacks frames | Art polish | — |
| KI-10 | P3 | Jump, fall, crouch and climb use placeholder frames | Move | Dedicated frames | Closest existing frames | Bundle lacks frames | Art polish | — |
| KI-12 | P3 | A rider overlaps the lower knight's plume by a few pixels | Stand on partner | No overlap | Small overlap | Sprite bounds | Cosmetic | — |
| KI-41 | P3 | The red-jar route in the collectible test room is tight | Dev room only | — | Tight | Dev room design | Dev room only | — |
| KI-4 | P3 | Loading WAVs from source at runtime warns (odd data chunks) | Dev only | — | Warning | Bundle files | Never load WAVs from source at runtime; imported resources are fine | Full run: no warnings |

## Verification gaps (manual testing still required)

| ID | What is not yet verified by people | Where |
|---|---|---|
| KI-88 | **Campaign playtest.** Levels 1–4: user-reported first-attempt pass (no per-check results or times). Levels 5–24: not played by people. Clarity of clues and routes, fairness of jumps and timings, difficulty curve, camera in each level | `docs/CAMPAIGN_PLAYTEST.md`, `docs/FINAL_MANUAL_TEST_PLAN.md` |
| KI-89 | **Campaign length unmeasured** (release-candidate blocker for validation, not a defect). Design estimates total 124 min; the analyzer's pure-movement floor is 9.5 min; target 90–120 min | Time the manual playtest (M-T1) |
| KI-107 | **Two-player session** with the 20 tests of `docs/TWO_PLAYER_PLAYTEST.md` | User (two players) |
| KI-9 | Physical keyboard: **user-reported pass**; model not supplied, so not tied to hardware; rollover with six keys held not separately reported | `docs/MANUAL_KEYBOARD_TEST.md`, T-04 |
| KI-18 | Phase 2 manual camera tests | `docs/MANUAL_CAMERA_TEST.md` |
| KI-20 | Camera smoothness on monitors above 60 Hz | Manual test 10 |
| KI-21 | `Parallax2D` in the second view (no parallax layers exist yet) | When backgrounds are added |
| KI-25 | Phase 3 manual combat tests | `docs/MANUAL_COMBAT_TEST.md` |
| KI-32 | Phase 4 manual enemy tests | `docs/MANUAL_ENEMY_TEST.md` |
| KI-38 | Phase 5 manual collectible tests | `docs/MANUAL_COLLECTIBLE_TEST.md` |
| KI-46 | Phase 6 manual hazard tests | `docs/MANUAL_HAZARD_TEST.md` |
| KI-55 | Phase 7 manual puzzle tests (clue clarity, solo-proof timings) | `docs/MANUAL_PUZZLE_TEST.md` |
| KI-65 | Phase 8 manual save tests, including the real window X button and Alt+F4 | `docs/MANUAL_SAVE_TEST.md` |
| KI-75 | Phase 9 manual UI tests: menus with the real keyboard, audio mix by ear, fullscreen on the real monitor, settings after a real restart, HUD readability | `docs/MANUAL_UI_TEST.md` |

## Design notes and accepted limitations (not defects)

| ID | Note | Decision |
|---|---|---|
| KI-96 | Collapsing and blinking platforms over lava: a miss ends the run (lava kills; a death resets the campaign). Phase 11 verified every such crossing physically (RouteValidator) and every blinking chain's timing (`test_platform_timing`); whether they **feel** fair is a playtest question | Keep (core rule); playtest |
| KI-91 | The level analyzer is a tile model (no timing, no enemies). Phase 11 added physical route checks with the real knight and a timing test for blinking chains; enemy pressure and moving-platform phase are still only covered by play | Playtest |
| KI-76 | One music track in the bundle; menu, worlds and victory use it at different pitch and volume; game over is silent | Add tracks when available |
| KI-77 | New sound cues reuse the six bundle sounds | Accepted (asset bundle) |
| KI-78 | Display options: whole-multiple windows and borderless fullscreen; no exclusive fullscreen, monitor choice or vsync option | Revisit in Phase 12 if needed |
| KI-81 | In the stacked split, Player Two's panel stays top-right | By design |
| KI-82 | No tutorial screen (GDD §14); the Controls screen and in-level clues cover the basics | Accepted; levels 1–4 passed first try by the user |
| KI-87 | Victory statistics do not count enemy defeats or deaths | Accepted |
| KI-90 | Boss fights are not saved mid-fight (a loaded boss is back at full health); defeat itself is saved | By design |
| KI-93 | Saves from the Phase 8–9 development builds (levels `w1_l1`/`w1_l2`) cannot be loaded by the production campaign; the slot says so | Accepted |
| KI-94 | Coins dropped by boss minions get generated save ids | Accepted |
| KI-95 | Either-knight exit rule: one knight can reach the exit while the other holds a plate; both move on | By design (GDD) |
| KI-68 | Save on exit covers a normal close (window X, Alt+F4). A killed process or power loss keeps the last completed save (atomic writes protect it) but loses progress since the last autosave. No claim of protection against every disk failure or power cut | By design |
| KI-69 | If the team-wipe marker cannot be written, the game halts (fail-closed) and offers only Quit | Inherent; reported to the player |
| KI-70 | A copy of an old save restored by hand from outside the game would load again | Out of scope |
| KI-71 | After loading: slime AI restarts in IDLE, poison keeps its remaining time but not the current tick fraction, held plates and partial SYNC/SEQUENCE attempts restart | By design (safe restore) |
| KI-73 | Dropped coins from slimes without a `save_id` (dev rooms) get generated ids | Campaign slimes always have ids |
| KI-56 | No pushable or carryable objects | Not needed by the levels |
| KI-59 | A closing gate bounces open when a knight reaches its doorway; partner-only crossings must take longer than the close delay + 0.3 s | Level-design rule |
| KI-60 | Only completed locks, latched gates/plates and toggled/latched switches are saved | By design |
| KI-61 | Puzzle test room's separate-route section keeps the shared camera | By design |
| KI-62 | Puzzle feedback sounds reuse `tap.wav` and `power_up.wav` | Accepted (asset bundle) |
| KI-63 | A plate spot can become a knight's safe respawn position | Harmless |
| KI-52 | Older dev rooms apply 1 FALL damage on falling out | Expected since Phase 6 |
| KI-54 | Hazard sounds reuse `hurt.wav` and `explosion.wav` | Accepted (asset bundle) |
| KI-42 | Collectible sounds reuse `coin.wav` and `power_up.wav` | Accepted (asset bundle) |
| KI-44 | Climbing speed is not affected by speed upgrades | By design |
| KI-45 | `RunState` is a static holder, not an autoload | By design (ARCHITECTURE §16) |
| KI-34 | Slimes cannot jump or path-find | By design (GDD §18) |
| KI-36 | Two distinct attacks in one tick can stagger and then kill a slime | Follows the rule |
| KI-28 | On solid ground Up also jumps, so an up attack from the ground is a jump attack | By design (GDD §18) |
| KI-29 | A dead knight stays dead until `revive()` (dev rooms) | By design |
| KI-30 | Line of sight uses two rays per target | Accepted |
| KI-23 | The Phase 1 room keeps its fixed view | By design |
| KI-13 | `knight.tscn` defaults to the P1 profile | By design |
| KI-14 | No crouching on one-way platforms (Down drops) | By design (GDD §18) |
| KI-15 | Ladder tops must be one-way tiles | Level-design rule |
| KI-16 | A release and re-press within one 16 ms tick is not a new press | Accepted |
| KI-24 | Godot 4.7.2: a static function returning its own class's enum must spell `ClassName.Enum` | Convention in CLAUDE.md |

## Resolved (earlier phases)

| ID | Issue | Resolution |
|---|---|---|
| KI-80 | After victory the finished campaign stays in its slot | Phase 10: the slot shows CAMPAIGN COMPLETE; Continue opens the victory screen; starting over asks first |
| KI-67 | Only two development levels existed | Phase 10: six worlds, 24 levels |
| KI-57 | No level exits or transitions | Phase 8 (`LevelExit`, `CampaignGame.complete_level`) |
| KI-66 | No main menu, slot selection, confirmations or game-over screen | Phase 9 |
| KI-72 | The wipe delay froze the dying knight | Phase 9: covered by the "RUN LOST" screen |
| KI-74 | Main scene was the Phase 1 room | Phase 9: `scenes/app/game_app.tscn` |
| KI-40 | No HUD for effects | Phase 9 HUD |
| KI-31 | No combat sounds | Phase 9 |
| KI-22 | Split-screen audio listener undecided | Phase 9: all sounds non-positional |
| KI-7 | Main scene was a dev room | Phase 9 |
| KI-64 | Live puzzle elements kept an old registry after a reset | Phase 8: wipes and new runs rebuild the level |
| KI-53 | Timed platforms could only cycle on their own | Phase 7 `PlatformController` TRIGGER |
| KI-47 | No campaign-wide team wipe | Phase 8 |
| KI-43 | Dropped coins not saved | Phase 8 |
| KI-37 | Defeated slimes not saved | Phase 8 |
| KI-48 | Platform states and safe positions not saved | Phase 8 |
| KI-35 | Dropped coins could not be collected | Phase 5 |
| KI-11 | No camera system | Phase 2 |
| KI-1 | Blurry texture filtering | Phase 1–2 |
| KI-2 | Font antialiasing | Phase 1 |
| KI-3 | Music did not loop | Phase 1 |
| KI-6 | Save folder tied to project name | Phase 1 (`TwoKnightCoop`) |
| KI-8 | No version control | Git |
