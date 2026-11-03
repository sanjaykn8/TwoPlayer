# Phase 8 Implementation Summary: Campaign Death, Full Run Reset and Four-Slot Saves

Date: 2026-11-03. Engine: Godot 4.7.2.stable. Starts from Phase 7 commit `95f9766`.

Status key: **Implemented** · **Auto-tested** · **Manually tested** · **Pending user test** · **Not implemented**.

## 1. Status

| Item | Implemented | Auto-tested | Manually tested |
|---|---|---|---|
| Four independent slots (`slot_1.save` … `slot_4.save`) in `user://saves/` | Yes | Yes | **Pending user test** |
| Slot metadata without loading the world | Yes | Yes | — |
| Versioned, checksummed JSON save format; validation; migration hook | Yes | Yes | — |
| Players (position, facing, safe position, health, upgrades, poison tier, effects with remaining time and charges) | Yes | Yes | **Pending user test** |
| Enemies (defeated stay defeated; living: position, home, stagger progress/timer, poison) | Yes | Yes | **Pending user test** |
| Collectibles and dropped coins (stable ids, positions, pickup delay) | Yes | Yes | **Pending user test** |
| Puzzles (completed locks, latched gates/switches, timed gates/switches/plates with remaining time) | Yes | Yes | **Pending user test** |
| Platforms (moving progress/direction/pause, timed and collapsing states and timers; safe restore) | Yes | Yes | **Pending user test** |
| Timed effects paused while the game is closed | Yes | Yes | **Pending user test** |
| Autosave: save points, level start after a transition, latched puzzle completion, campaign completion; coalesced requests | Yes | Yes | **Pending user test** |
| Save on normal window close (X / Alt+F4), verified before the process exits | Yes | Yes (real child process) | **Pending user test** |
| Atomic writes, backup, rollback, recovery, corruption detection | Yes | Yes (fault injection) | **Pending user test** |
| Team wipe: either knight's death resets both, only the active slot, starts at `w1_l1`, fresh run saved and verified | Yes | Yes | **Pending user test** |
| Old campaign unloadable after a wipe (primary, backup, temp, delayed save, exit, transition) | Yes | Yes | **Pending user test** |
| Race conditions (simultaneous deaths, death during transition / pending save, duplicate signals, close during wipe) | Yes | Yes | — |
| Restoration guard (nothing interacts while a level is restored) | Yes | Yes | — |
| Save test harness (`scenes/dev/save_test_room.tscn`, own folder `saves_dev/`) | Yes | — | **Pending user test** |
| Main menu, slot-selection screen, overwrite confirmation, game-over screen | **Not implemented** (Phase 9; APIs ready) | — | — |
| Production campaign levels (only two development levels exist) | **Not implemented** (Phase 10) | — | — |
| Recovery after power loss or a killed process beyond the last completed save | **Not implemented** (not claimed) | — | — |

## 2. New files

| Path | Purpose |
|---|---|
| `scripts/save/save_manager.gd` | `SaveManager`: the single slot API |
| `scripts/save/slot_store.gd` | `SlotStore`: all slot file I/O, atomic writes, marker, diagnostics |
| `scripts/save/save_schema.gd` | `SaveSchema`: build, encode, decode, validate, migrate |
| `scripts/save/world_snapshot.gd` | `WorldSnapshot`: capture/restore of the current level |
| `scripts/save/save_ids.gd` | `SaveIds`: level keys, id validation, duplicate detection |
| `scripts/campaign/level_catalog.gd` | `LevelCatalog`: the only id → scene map |
| `scripts/campaign/campaign_state.gd` | `CampaignState`: campaign id, world/level, completed levels, play time, flags |
| `scenes/campaign/campaign_game.gd/.tscn` | `CampaignGame`: plays a campaign in a slot (load, transitions, autosave, exit save, team wipe) |
| `scenes/campaign/save_point.gd/.tscn`, `level_exit.gd/.tscn` | `SavePoint`, `LevelExit` |
| `scenes/levels/w1/w1_l1.tscn`, `w1_l2.tscn` | Development campaign levels |
| `scenes/dev/save_test_room.gd/.tscn`, `save_debug_hud.gd/.tscn` | Save test harness |
| `tools/build_phase8_content.gd` | Generator for the levels and the harness |
| `tests/framework/save_test_util.gd`, `tests/integration/exit_save_child.gd` | Test helpers; the child process for exit tests |
| `tests/unit/test_save_schema.gd`, `tests/gameplay/test_save_slots.gd`, `test_campaign_save.gd`, `test_team_wipe.gd`, `test_exit_save.gd` | 49 tests |
| `docs/MANUAL_SAVE_TEST.md`, `docs/PHASE_8_SUMMARY.md` | Documentation |

## 3. Modified files (minimal integrations)

| Path | Change |
|---|---|
| `scripts/progression/run_state.gd` | Owns `campaign: CampaignState`; snapshot version 3 (versions 1–2 still restore) |
| `scripts/systems/save_paths.gd`, `tests/unit/test_project_setup.gd` | Slot file name `slot_N.save` (was the Phase 0 placeholder `slot_N.json`) |
| `scenes/enemies/slime.gd` | `save_id`; records its defeat in the run and removes itself on load if defeated; `save_state()` / `restore_state()` |
| `components/loot/coin_dropper.gd`, `scenes/objects/dropped_coin.gd` | Stable coin ids from the dropping enemy; coin save/restore |
| `scenes/platforms/platform_body.gd`, `moving_platform.gd`, `timed_platform.gd`, `collapsing_platform.gd` | `save_id`; `capture_live()` / `apply_live()`; `interior_rect()`, `fade_in_safely()` |
| `scenes/puzzles/puzzle_source.gd` and subclasses | `capture_live()` / `apply_live()` for timers; level key moved to `SaveIds` |
| `.gitignore` | Slot helper files and test save folders |

## 4. Key decisions

1. **No autoload.** `CampaignGame` exists only while a campaign is played, so the
   close-request handling and the team wipe cannot affect menus, dev rooms or the test runner.
2. **Ids, never paths.** Saves store catalog level ids and entity type ids; paths come only
   from `LevelCatalog`. Unknown ids or path-like ids are rejected.
3. **Checksum over the exact text.** JSON numbers come back as floats, so the SHA-256 covers
   the stored body text rather than re-serialised data.
4. **Save strategy for transitions:** the new level is saved after it has been fully built;
   a close request during a pending transition saves the valid pre-transition level.
5. **Restoration in one frame:** positions before the level enters the tree, entity states
   right after its `_ready()`, with processing disabled until done.
6. **Geometric safety checks after restore.** Physics queries do not see a level added in
   the same frame (found by a test), so knight/wall and knight/platform overlap checks use tile
   cells, closed gates and solid platform rectangles.
7. **The wipe's physics freeze is deferred to the end of the frame.** The logical lock,
   on-disk invalidation and attack cancel are immediate. A death can arrive inside a physics
   callback (falls, lava), where disabling collision objects is not allowed (found by a test).

## 5. Tests

345 tests in total, all passing in two consecutive runs with no `ERROR`/`WARNING` lines:
296 Phase 1–7 tests plus 49 new (6 schema unit, 18 slot, 10 campaign save, 13 team wipe,
2 real-process exit). Details in `docs/TEST_REPORT.md`.

## 6. Manual tests

`docs/MANUAL_SAVE_TEST.md`: **pending user test** (including closing with the real window X
button, which the automated test simulates with the same notification).
