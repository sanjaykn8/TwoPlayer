# Phase 9 Implementation Summary: Main Menu, Save Slot UI, HUD, Settings and Audio

Date: 2026-11-03. Engine: Godot 4.7.2.stable. Starts from Phase 8 commit `3e6f8cc`.

Status key: **Implemented** · **Auto-tested** · **Manually tested** · **Pending user test** · **Not implemented**.

## 1. Status

| Item | Implemented | Auto-tested | Manually tested |
|---|---|---|---|
| Main menu (New Game, Continue, Save Slots, Settings, Controls, Exit), configurable "UNTITLED" title, backdrop from bundle art, menu music | Yes | Yes | **Pending user test** |
| Four-slot screen: NEW_GAME / CONTINUE / MANAGE; EMPTY, ACTIVE, RECOVERED, CORRUPTED, INVALIDATED | Yes | Yes | **Pending user test** |
| Overwrite and delete confirmations; repair through `recover_backup`; one slot at a time | Yes | Yes | **Pending user test** |
| HUD: both knights (any maximum health, death state), shared coins, timed effects with seconds and charges, upgrades, world/level | Yes | Yes | **Pending user test** |
| One HUD in shared, side-by-side, stacked and merging camera modes | Yes | Yes | **Pending user test** |
| Pause menu: Resume, Settings, Restart Campaign (confirmed, not a death), Save and Quit, Return to Main Menu (only after a verified save) | Yes | Yes | **Pending user test** |
| Everything stops while paused (knights, slimes, physics, platforms, puzzle timers, effects, play time) | Yes | Yes | **Pending user test** |
| Game-over screen on the team wipe (after durable invalidation), Begin Again / Main Menu; storage error offers only Quit | Yes | Yes | **Pending user test** |
| Victory screen with real statistics; development preview | Yes | Yes | **Pending user test** |
| Settings in `user://settings.cfg`: Master/Music/Effects buses, fullscreen, window size; per-value fallback | Yes | Yes | **Pending user test** |
| Real window switching (fullscreen, sizes) | Yes | Windowed run (not headless) | **Pending user test** |
| Audio buses Master / Music / SFX; `AudioManager` music; `Sfx` on the SFX bus with limits; new cues | Yes | Yes | **Pending user test** (no one has listened yet) |
| Controls screen | Yes | Yes (against the InputMap) | **Pending user test** |
| Keyboard navigation, focus display, modal dialogs, no gameplay input in menus | Yes | Yes (real key events) | **Pending user test** |
| Main scene set to the game (`scenes/app/game_app.tscn`) | Yes | Yes | — |
| Initial tutorial screen (GDD §14) | **Not implemented** (KI-82) | — | — |
| Production campaign (24 levels) | **Not implemented** (Phase 10) | — | — |

## 2. New files

| Path | Purpose |
|---|---|
| `scenes/app/game_app.gd/.tscn` | `GameApp`: the main scene and application flow |
| `scenes/ui/menus/*.gd/.tscn` | `MainMenu`, `SaveSlotScreen`, `SettingsScreen`, `ControlsScreen`, `PauseMenu`, `GameOverScreen`, `VictoryScreen` |
| `scenes/ui/hud/game_hud.gd/.tscn`, `player_status_panel.gd`, `health_display.gd`, `effect_indicator.gd` | HUD |
| `scenes/ui/components/confirm_dialog.gd`, `save_slot_card.gd`, `settings_slider.gd`, `option_stepper.gd`, `menu_backdrop.gd` | Reusable UI components |
| `scripts/ui/ui_theme.gd`, `ui_button.gd`, `menu_screen.gd`, `ui_stack.gd`, `ui_config.gd` | Theme, button, screen base, navigation stack, title config |
| `scripts/systems/settings_manager.gd` | `SettingsManager` |
| `scripts/audio/audio_manager.gd`, `audio_config.gd` | `AudioManager`, `AudioConfig` |
| `default_bus_layout.tres` | Master, Music, SFX buses |
| `resources/config/audio_config.tres`, `ui_config.tres` | Audio and UI configuration |
| `assets/created/ui_icons.png`, `tools/build_phase9_content.gd` | Hearts, slider grabber, pointer arrow (generated) |
| `scenes/dev/ui_test_room.gd/.tscn` | UI test harness (own save folder and settings file) |
| `tests/framework/ui_test_util.gd` and 8 test files (67 tests) | Automated tests |
| `docs/MANUAL_UI_TEST.md`, `docs/PHASE_9_SUMMARY.md` | Documentation |

## 3. Modified files

| Path | Change |
|---|---|
| `scenes/campaign/campaign_game.gd/.tscn` | Injected `SaveManager`. New signals `team_wipe_failed` and `campaign_completed`. New `restart_run()`, `save_before_leaving()` and `quit_handler`. The level-transition sound. A named recovered handler. The HUD as a child |
| `scripts/audio/sfx.gd` | SFX bus, separate menu pool that works while paused, same-stream-per-frame limit, named cues, test counters |
| `components/combat/combat_component.gd`, `scenes/enemies/slime.gd`, `scenes/players/knight.gd` | Attack, enemy hit / stagger / death, player damage / death and jump cues (one line each) |
| `scripts/campaign/level_catalog.gd` | World and level display titles; `DEVELOPMENT_CAMPAIGN` flag |
| `project.godot` | Main scene is the game; `pause` action (Esc) |

## 4. Key decisions

1. **No autoloads.** `GameApp` owns the session-wide objects; tests and development rooms create
   their own on separate folders.
2. **One SaveManager.** The menus and the campaign share the instance, so the menus show exactly
   what the campaign writes.
3. **Leaving needs a verified save.** Main Menu and Save and Quit go through
   `save_before_leaving()`. A failure keeps the game paused and explains why.
4. **Restart is not a death.** It replaces the campaign through `start_new_run(slot, true)`:
   no invalidation marker and no game-over screen.
5. **The game-over choices come only after the Phase 8 wipe has finished.** The lost run is
   unloadable from the moment the screen opens.
6. **The HUD is drawn once.** It sits outside the camera SubViewports, in fixed corners.
7. **Settings are read without engine errors.** A quiet line parser replaces
   `ConfigFile.load()`, and each bad value falls back on its own.
8. **Quitting stops audio first.** This avoids exit leak reports of playing streams.

## 5. Tests

**412 tests in total**, all passing in two consecutive runs with no `ERROR`, `WARNING` or
`SCRIPT ERROR` lines. That is 345 Phase 1–8 tests plus 67 Phase 9 tests:

| Area | Tests |
|---|---|
| Settings | 8 |
| Audio | 7 |
| Main menu and navigation | 9 |
| Save-slot UI | 12 |
| HUD | 9 |
| Pause | 9 |
| Game over and victory | 6 |
| Application audio and controls | 7 |

Details are in `docs/TEST_REPORT.md`.

## 6. Manual tests

`docs/MANUAL_UI_TEST.md` is **pending user test**.
