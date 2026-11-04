# Two-Player Playtest

A local two-player game has to be tested by two real people sharing one keyboard. This file
is the checklist for that session. **Every test below is pending** until the user plays it and
writes the result into the Actual and Status columns. The automated tests that already cover
the same mechanics are listed for reference only. They drive the game through the input
system, which is not the same as two people on one keyboard.

Statuses: NOT TESTED / PASS / PASS WITH MINOR ISSUES / FAIL / BLOCKED.

## Existing user-reported result

| Item | Result | Source |
|---|---|---|
| Physical keyboard: both players' controls, simultaneous input, Alt attack | **User-reported: works correctly** (reported before Phase 11; recorded in `docs/MANUAL_KEYBOARD_TEST.md`) | User |
| Levels 1–4 | **User-reported: reached and passed on the first attempt** | `docs/PLAYTEST_FEEDBACK.md` F-3 |

Phase 11 made no fresh, independent keyboard check. The keyboard model was not given (KI-9),
so the report applies to the user's own keyboard only.

## Keyboard rollover

Cheap keyboards often register only two or three keys at once in some combinations
("ghosting"). Player One uses WASD + V and Player Two the arrow keys + Alt. The worst moment is
both knights running, jumping and attacking together: up to six keys held at once. When a
test below fails only in such a moment (a jump or attack is ignored while both players hold
keys), write **which keys were held** in Notes and mark the test PASS WITH MINOR ISSUES
(hardware), not a game bug. Repeat it with fewer keys to confirm. Tests T-01, T-02, T-03 and
T-04 are the rollover checks; play them on the keyboard that will actually be used.

## Setup

Main menu → New Game in an empty slot. Levels named below are the easiest places to try each
item. Player One: WASD, V attack. Player Two: arrow keys, Alt (left or right) attack.

## Results

| ID | Test | How | Expected | Automated reference | Actual | Status | Notes |
|---|---|---|---|---|---|---|---|
| T-01 | Simultaneous movement | l01: both run left and right at the same time, then in opposite directions | Both knights respond at once, same speed, no dropped keys | `test_knight_movement` (raw key events drive both knights) | | NOT TESTED | |
| T-02 | Simultaneous jumping | l01: both jump in the same moment while running | Both jump, same height | `test_both_jump_in_same_frame` | | NOT TESTED | |
| T-03 | Independent directional attacks | l01 slimes: P1 attacks left while P2 attacks right/up/down | Each slash goes the way that knight last moved; one never cancels the other | `test_player_two_attacks_independently`, `test_combat` | | NOT TESTED | |
| T-04 | Keyboard combinations | Both hold run + jump + attack together; P2 presses Alt alone and with arrows | No ignored keys; Alt never opens a window menu; Alt+Tab still works | Not automatable (hardware) | | NOT TESTED | Rollover check |
| T-05 | Player collision | l01: walk into each other; stand on the other's head | Knights block each other and can stand on each other, no jitter | `test_knight_movement` (push tests) | | NOT TESTED | |
| T-06 | Pushing | Push the partner along the ground and against a wall | Controlled push; never trapped in a wall or pushed off-screen | `test_knight_movement` (push tests) | | NOT TESTED | |
| T-07 | Shared and split-screen cameras | l03: walk apart sideways, then one climbs high | Splits side by side, then stacked; merges smoothly when back together; no flicker at the threshold | `test_camera_rig` (21 tests) | | NOT TESTED | |
| T-08 | Separate routes | l09 / l11: each knight takes a different branch | Both views stay readable; nobody is lost off-screen | `test_split_screen_does_not_affect_puzzles` | | NOT TESTED | |
| T-09 | Enemy targeting with both visible | l05: both near one purple slime | It chases one knight (the nearer), switches when that one leaves | `test_slimes` | | NOT TESTED | |
| T-10 | Independent health | Let one knight take a spike hit | Only that knight's hearts drop; the HUD shows which | `test_both_players_health_is_shown_independently` | | NOT TESTED | |
| T-11 | Collectible ownership | One knight picks up fruit / a jar | Only that knight gets the effect | `test_collectibles` | | NOT TESTED | |
| T-12 | Shared coins | Both pick up coins | One shared total goes up for both | `test_collectibles` | | NOT TESTED | |
| T-13 | Player-specific upgrades | One knight eats a red fruit (range) | Only that knight's attack reaches further; kept on the next level | `test_red_fruit_range_reaches_further_targets`, `test_release_saves` (upgrades restored) | | NOT TESTED | |
| T-14 | Temporary protection | Pick up a shield jar, then touch spikes | That knight takes no damage until the timer runs out; the HUD shows the seconds | `test_collectibles` | | NOT TESTED | |
| T-15 | Moving-platform cooperation | l02 / l08: both ride one lift; l15: one stands on the island plate while the other rides | Both carried; the plate-held platform runs only while held | `test_moving_platform_carries_both_knights` | | NOT TESTED | |
| T-16 | Puzzle coordination | l02 two-plate lock; l09 / l12 two-knight locks; l17 sync targets | Solvable only together; a mistake can be undone (no softlock) | `test_puzzle_room` (S1–S9), `test_level_validation` | | NOT TESTED | |
| T-17 | Exit while separated | l02: one knight holds a plate, the other reaches the exit | Both move to the next level together with their progress | `test_one_knight_at_the_exit_moves_both_and_keeps_progress` | | NOT TESTED | |
| T-18 | Player death | Let one knight die (spikes to zero, or lava in World 4) | Clear "RUN LOST" screen | `test_team_wipe` | | NOT TESTED | Use a throwaway slot |
| T-19 | Campaign-wide reset | After T-18: choose to start again | Level 1, 0 coins, no upgrades, both knights full health; Continue shows only the new run | `test_team_wipe`, `test_release_saves` | | NOT TESTED | |
| T-20 | Save and resume | Mid-level: close the window (X), relaunch, Continue | Same level, positions, health, coins, upgrades, opened gates | `test_exit_save`, `test_release_saves` | | NOT TESTED | |

## Session summary (to fill in)

| Item | Value |
|---|---|
| Date | |
| Players | |
| Keyboard (make / model) | |
| Levels played | |
| Problems found (IDs in KNOWN_ISSUES) | |
