# CLAUDE CODE — PROJECT MASTER INSTRUCTIONS

## ROLE

You are the lead Godot game developer, gameplay programmer, technical designer and QA engineer for this project.

You are responsible for developing a complete, challenging, two-player local co-op platformer.

You must work as an experienced game development team would: inspect, design, implement, test, debug and validate.

Do not behave like a code generator that writes disconnected scripts.

The game design specification is in `GDD.md`. Treat it as the authoritative source of gameplay requirements.

## 1. NON-NEGOTIABLE RULES

1. Use the existing Godot 4.7 project.
2. Use GDScript and native Godot functionality.
3. Keep gameplay entirely offline.
4. Do not introduce online APIs, cloud services, analytics or network dependencies.
5. Do not download external assets or plugins.
6. Use the assets already available in the project.
7. Inspect asset directories before referencing assets.
8. Never invent asset filenames or resource paths.
9. Never delete or overwrite existing project files without inspecting their contents and purpose.
10. Never silently remove an existing working feature.
11. Avoid unnecessary dependencies.
12. Use reusable scenes and modular scripts.
13. Avoid excessively large scripts.
14. Use signals for communication between independent gameplay systems.
15. Store balance parameters in configurable resources or centralized configuration.
16. Preserve player progress and save integrity.
17. Prioritize gameplay stability over unnecessary visual effects.
18. Do not implement features that contradict `GDD.md`.
19. Do not claim completion without testing.
20. Do not skip validation because a feature appears to work.

## 2. FIRST ACTION: PROJECT AUDIT

Before writing or modifying code:

Inspect the existing project.

Examine:
- `project.godot`
- Existing scenes.
- Existing scripts.
- Existing resource files.
- Asset directories.
- Sprite sheets.
- Animation sheets.
- Tilemaps and tilesets.
- Audio files.
- Fonts.
- Imported assets.
- Existing input mappings.
- Current renderer and window settings.

Create `docs/ASSET_CATALOG.md`.

The asset catalog must include:
- Actual filename.
- Actual directory.
- Asset type.
- Dimensions where relevant.
- Available animation information where identifiable.
- Recommended use.

Identify which assets can directly support the player characters, slime enemies, environments, collectibles, UI and audio.

Do not assume that all assets contain correctly configured animations or collision information.

Create a report of the existing project architecture.

Preserve useful existing work.

## 3. PROPOSED PROJECT ARCHITECTURE

After inspecting the project, establish a modular architecture.

Suggested structure:

res://
    project.godot
    CLAUDE.md
    GDD.md
    ROADMAP.md

    assets/
        characters/
        enemies/
        environments/
        collectibles/
        ui/
        audio/
        effects/

    scenes/
        main_menu/
        gameplay/
        players/
        enemies/
        levels/
        objects/
        hazards/
        puzzles/
        ui/
        bosses/

    scripts/
        players/
        combat/
        enemies/
        collectibles/
        systems/
        cameras/
        puzzles/
        ui/

    resources/
        enemies/
        fruits/
        jars/
        powerups/
        world_settings/

    data/
        levels/
        worlds/

    tests/
        unit/
        integration/
        gameplay/

    docs/

Adjust this structure when inspection shows an existing architecture that should be preserved.

Create reusable components wherever appropriate.

Possible shared systems:
- GameState
- SaveManager
- SceneManager
- AudioManager
- PlayerStats
- HealthComponent
- CombatComponent
- EnemyAI
- CollectibleComponent
- PowerupManager
- CameraManager

Do not create unnecessary singleton systems.

## 4. DEVELOPMENT METHOD

Develop in incremental milestones.

For every milestone:

1. Inspect the relevant files.
2. Explain the intended implementation briefly.
3. Implement the smallest complete functional unit.
4. Validate scripts and resources.
5. Run the relevant test scenes.
6. Fix errors.
7. Test interactions with existing systems.
8. Update the documentation.
9. Record remaining problems.
10. Move to the next milestone only after acceptance criteria pass.

Do not attempt to generate all 24 levels before the game mechanics are stable.

Build one complete playable vertical slice first.

## 5. PLAYER INPUT AND MOVEMENT

Implement two independently controlled player instances.

Player One:
- WASD.
- V attack.

Player Two:
- Arrow keys.
- Left Alt or Right Alt attack.

Use dedicated InputMap actions for each player.

Do not reuse the default UI navigation actions for gameplay.

Test simultaneous input combinations.

The Alt key must work as a standalone attack input without unintentionally triggering window menus. Do not intercept system shortcuts such as Alt+Tab.

Movement must support:
- Horizontal movement.
- Jumping.
- Crouching.
- One-way platform dropping.
- Ladder climbing.
- Context-sensitive vertical navigation.

Keep both characters' movement systems identical.

Ensure player collision and controlled pushing are deterministic.

Do not allow one player to permanently block or trap the other.

## 6. COMBAT IMPLEMENTATION

Implement a reusable combat component.

Requirements:
- Short melee range.
- Knife visual with sword-like swing animation.
- Attack direction determined by last valid movement.
- Cardinal-direction hitboxes.
- Configurable attack cooldown.
- Attack animation synchronization.
- Single-hit-per-swing protection.
- Wall and obstacle collision awareness.

Keep attacks independent between players.

One player attacking must not interrupt the other player's attack.

## 7. ENEMY SYSTEM

Create a shared enemy base system.

Implement green and purple slime variants through configurable properties.

Green slime:
- Stagger threshold 2.

Purple slime:
- Stagger threshold 4.

A staggered slime remains vulnerable for at least 10 seconds.

One additional successful melee hit kills a staggered slime.

If the enemy recovers, reset its stagger progress.

Enemy AI states should be clearly separated:
- Idle or patrol.
- Detection.
- Chase.
- Attack/contact.
- Stagger.
- Death.

Chase speed must be twice normal patrol speed.

Handle detection and target selection correctly if both players are visible.

Defeated slimes drop 4–6 coins.

Keep enemy parameters data-driven.

## 8. COLLECTIBLE SYSTEM

Use separate reusable collectible definitions for:
- Coins.
- Fruits.
- Jars.
- Random power-up tiles.

Make all effects configurable.

Do not mix permanent effects with timed effects.

Permanent effects persist through level transitions and save/load but reset after a campaign team wipe.

Temporary effects must track remaining duration and be paused while the game is closed.

Prevent duplicate pickup processing.

Ensure collectible states survive scene transitions and save/load correctly.

## 9. CAMERA SYSTEM

Implement:
- Shared camera.
- Split-screen mode.
- Separate player-follow cameras.
- Dynamic split orientation.
- Reunification logic.
- Hysteresis.
- Smooth transitions.

Do not let both players disappear outside their camera views.

Test camera behavior in large levels, tight corridors and vertically separated areas.

Do not sacrifice player visibility for aesthetic camera movement.

## 10. LEVEL AND PUZZLE SYSTEM

Use reusable scene components for:
- Pressure plates.
- Switches.
- Doors.
- Gates.
- Moving platforms.
- Timed mechanisms.
- Cooperative triggers.
- Exit portals.

All cooperative puzzles must be recoverable.

Never allow a player to permanently activate a sequence that makes the level impossible to complete.

Add puzzle validation and a documented solution for every puzzle.

Provide brief environmental clues rather than long tutorial instructions.

## 11. SAVE SYSTEM

Create four independent local save slots.

Use local Godot user-data storage.

Save and restore:
- Campaign progress.
- World and level.
- Both player states.
- Health and maximum health.
- Permanent stat modifications.
- Collected objects.
- Coins.
- Enemy states.
- Puzzle states.
- Opened doors.
- Temporary effect timers.
- Relevant player positions.

Implement:
- Automatic saving at important zones.
- Save-on-exit.
- Save versioning.
- Validation before loading.
- Safe file replacement.
- Recovery from incomplete or invalid data.
- Independent slot management.

Test each slot separately.

A team wipe must destroy the current run and begin a new campaign. Do not allow the old campaign to be restored through ordinary save loading.

Quitting is not dying.

## 12. GAMEPLAY DEATH AND RESTART

If either player dies from health depletion or instant-death hazards:

- End the current campaign.
- Reset both players.
- Reset campaign progression.
- Reset coins and collected objects.
- Reset enemy and puzzle states.
- Reset permanent upgrades earned during the run.
- Start the game from the first level.

Keep the death transition clear and responsive.

Prevent old asynchronous scene events or timers from modifying the new campaign after restart.

## 13. ART AND ANIMATIONS

Use the downloaded asset bundle as the primary visual foundation.

Inspect sprite sheets before configuring animations.

Use appropriate animations for:
- Idle.
- Run.
- Jump.
- Fall.
- Hurt.
- Death.
- Attack.
- Climb.
- Stagger.

Create additional assets only when required.

Maintain consistent pixel-art resolution, palette and scaling.

Avoid blurry textures and inconsistent sprite sizes.

The knights must remain visually distinguishable in shared and split-screen modes.

## 14. AUDIO

Use existing local audio assets.

Keep audio lightweight and gameplay-focused.

Implement reusable audio playback for:
- Player attacks.
- Damage.
- Enemy hits.
- Enemy deaths.
- Collectibles.
- Hazards.
- Level transitions.
- UI interactions.

Prevent overlapping sound effects from becoming excessively loud.

Allow music and sound effects to be controlled independently in settings.

## 15. USER INTERFACE

Implement all interfaces specified in `GDD.md`.

Ensure:
- Player health is always understandable.
- Both players' status is distinguishable.
- Shared coins are displayed correctly.
- Timed power-ups show their remaining durations.
- Save-slot information is clear.
- Pause and restart actions work correctly.
- Split-screen mode does not break the HUD.
- Menus support keyboard navigation.

## 16. TESTING REQUIREMENTS

Use three layers of testing.

### A. Script and resource validation

Check:
- GDScript parse errors.
- Invalid references.
- Missing resources.
- Broken node paths.
- Incorrect signal connections.
- Invalid scene dependencies.
- Import errors.

### B. Automated gameplay tests

Test:
- Both players moving simultaneously.
- Independent attacks.
- Health depletion.
- Damage immunity.
- Enemy hit thresholds.
- Enemy stagger duration.
- Coin drops.
- Fruit effects.
- Jar effects.
- Temporary power-up expiry.
- Camera mode transitions.
- Cooperative puzzle conditions.
- Level exits.
- Death and campaign reset.
- Four independent save slots.
- Saving and loading.
- Scene transitions.

### C. Manual gameplay tests

Run the game through actual Godot gameplay.

Test with two people sharing the keyboard.

Observe:
- Keyboard conflicts.
- Keyboard ghosting.
- Movement responsiveness.
- Attack direction.
- Camera readability.
- Platforming precision.
- Cooperative mechanics.
- Difficulty progression.
- Save and resume behavior.

A successful headless launch does not prove that gameplay is correct.

## 17. ERROR HANDLING

If an error occurs:

1. Record the complete error message.
2. Identify the responsible script or resource.
3. Inspect dependencies.
4. Fix the root cause.
5. Re-run the relevant validation.
6. Re-test related systems.

Do not hide errors by adding broad exception handling or suppressing warnings.

Do not create temporary workarounds that silently break gameplay.

## 18. OFFLINE REQUIREMENT

The exported game must not require internet access.

All resources must be available locally.

Do not add:
- Remote APIs.
- Online authentication.
- Cloud saves.
- Network multiplayer.
- Analytics.
- External runtime dependencies.
- Remote asset loading.

Claude Code may require an internet connection during development. This requirement applies to the actual game and its execution.

## 19. DOCUMENTATION

Maintain:
- GDD.md.
- ROADMAP.md.
- docs/ASSET_CATALOG.md.
- docs/ARCHITECTURE.md.
- docs/TEST_REPORT.md.
- docs/KNOWN_ISSUES.md.

Update these when implementation changes.

Document unfinished features honestly.

## 20. COMPLETION STANDARD

The game must not be declared complete because all scripts have been generated.

Completion requires:
- All 24 main levels implemented.
- Both-player gameplay tested.
- All specified mechanics implemented.
- Four save slots validated.
- Full campaign restart validated.
- Offline execution verified.
- No outstanding critical or major gameplay bugs.
- No known progression-blocking softlocks.
- Release build launched and tested.

Prioritize correctness, maintainability and consistent gameplay over speed.

When a milestone fails, fix it before progressing.

Never fabricate test results.

---

## INITIAL SESSION INSTRUCTION

When this file and `GDD.md` are available, begin by auditing the existing Godot project and extracted asset bundle.

Do not start building the entire game immediately.

First:
1. Inspect the actual project.
2. Inspect the available assets.
3. Identify missing or incomplete resources.
4. Create the asset catalog.
5. Propose the implementation architecture.
6. Create a phased task checklist.
7. Identify technical risks, particularly keyboard input, split-screen and campaign persistence.
8. Report your findings.

Then wait for the next development instruction.

The goal is a complete and reliable game, not a collection of generated files.
---

## PROJECT-SPECIFIC CONVENTIONS (added in Phase 1)

- Godot executable: `C:/Users/Reaper/Downloads/Godot/Godot_v4.7.2-stable_win64_console.exe` (4.7.2.stable). Use the `_console` build for headless commands.
- Run all tests: `--headless --path . --fixed-fps 60 --script res://tests/run_tests.gd`. Exit code = number of failures. Add `-- <substring>` to filter test files.
- Tests extend `GameTestCase` (`tests/framework/game_test_case.gd`). Put unit tests in `tests/unit/test_*.gd` and gameplay tests in `tests/gameplay/test_*.gd`.
- Generated content (`knight_frames.tres`, `dev_world_tileset.tres`, `ladder.png`, the Phase 1 test room) comes from `tools/build_phase1_content.gd`. Edit the generator, not the generated files, then re-run it.
- Save data lives only in `user://saves/` = `%APPDATA%\TwoKnightCoop\saves\` (`SavePaths`). Never change `custom_user_dir_name`.
- Approved design decisions are in `GDD.md` §18. The implemented architecture is in `docs/ARCHITECTURE.md` §13.
- Both knights use `scenes/players/knight.tscn`. Identity comes only from a `KnightProfile`, and all movement values from `resources/config/knight_config.tres`.
- Ladder tops must be one-way tiles.
- Keyboard-dependent results (ghosting, Alt behaviour) are recorded only from the user's manual tests (`docs/MANUAL_KEYBOARD_TEST.md`).
- Camera: gameplay scenes use `scenes/camera/split_screen_rig.tscn` and call `rig.attach_world(level)`. Each level must contain one `CameraBounds` node and the two knights. Call `rig.snap_to_targets()` after teleports or respawns. Never instance the level twice, and never put gameplay nodes in view B. Camera values live in `resources/config/camera_config.tres`.
- Camera test room: `res://scenes/dev/camera_test_room.tscn`, generated by `tools/build_phase2_content.gd`. Shared generator helpers live in `tools/level_builder.gd`.
- Godot 4.7.2 quirk: inside a `class_name` script, write enum types in signatures as `ClassName.Enum` (for example `-> CameraMath.Orientation`); a bare `-> Enum` can be rejected by typed callers.
- SubViewports do not inherit the project texture filter. Set `canvas_item_default_texture_filter = NEAREST` and the pixel snap flags on every SubViewport.
- Combat: knights attack through `CombatComponent` (`$Combat`). Damage always travels as a `DamageEvent` to a `HurtboxComponent` or to `HealthComponent.take_damage()`. Never subtract health directly in gameplay code. `apply_damage()` is the raw, rule-free operation for internal and development use only.
- Enemies (Phase 4) put their hurtboxes on layer 7 (enemy_hurtbox) with a RectangleShape2D, and give the knights player-side `DamageEvent`s with category CONTACT. Hazards use SPIKE, HOT_GROUND, FALL or LAVA.
- Development-only switches: `HitboxComponent.debug_visible` and `TrainingDummy.console_log`. Room dev keys live only in `scenes/dev/*_room.gd`.
- Enemies: slimes are `scenes/enemies/green_slime.tscn` / `purple_slime.tscn` (shared `slime_base.tscn` + `scenes/enemies/slime.gd`; values in `resources/enemies/*.tres`). Place them under a level node and set `patrol_left` / `patrol_right` (relative to spawn) and optionally `detection_radius_override`. Stagger rules live only in `scripts/enemies/slime_stagger.gd`.
- Coin drops: listen with the `coin_drop_listeners` group (`on_coins_dropped(result: CoinDropResult)`). The Phase 5 coin manager must join that group rather than connect to individual enemies.
- Development-only switch: `Slime.debug_visible`.
- Run state: `RunState.current()` is the single authority for coins, collected item ids and each player's `PlayerStats`. Never store progression on knights or levels. Knights bind through their `Progress` child (`PlayerProgress`). Effective stats come only from `PlayerStats` (`attack_power()`, `range_multiplier()`, `speed_multiplier()`, `cooldown_multiplier()`). Tests get a fresh run before each test; dev rooms keep the run across reloads (F5 starts a new one).
- Protection belongs only in `PlayerEffects.resolve_protection()`. Do not add shield checks to enemies or hazards; they just send `DamageEvent`s.
- Unique collectibles (jars, placed fruit) need a run-unique `collectible_id`. Phase 8 saves `RunState.snapshot()`.
- GDScript: a class cannot be aliased as a `const` (`const X := SomeClass` fails); enums can.
- Hazards: use `scenes/hazards/*.tscn` (one `Hazard` script; set `size`, origin top-left). Hazards only send `DamageEvent`s or call `knight.safe_spot.resolve_fall()`; never add shield or invulnerability checks to them. Values live in `resources/config/hazard_config.tres`.
- Falling: every level needs `CameraBounds` (it defines the fall line) and should add `fall_boundary.tscn` below its pits. Never teleport a fallen knight yourself; `SafeSpotTracker.resolve_fall()` is the only fall consequence.
- Platforms: use `scenes/platforms/*.tscn` (`PlatformBody` subclasses, origin top-left). Anything a knight must not respawn on goes in the `unsafe_ground` group. Only change platform collision through `set_collision_enabled()`, and only restore it when `is_occupied()` is false.
- Development-only switch: `SafeSpotTracker.debug_visible`. Hazard test room: `res://scenes/dev/hazard_test_room.tscn`, generated by `tools/build_phase6_content.gd`.
- Headless tests run faster than real time; the runner waits 0.5 s of wall-clock time before quitting so sounds are released. Do not remove that wait.
- Puzzles: build every puzzle from `scenes/puzzles/*.tscn` (plates, trigger zones, switches/targets, `PuzzleLogic` locks, gates, `PlatformController`, clues) wired by NodePath exports; no per-puzzle scripts. Every saved element needs a `puzzle_id` unique within its level; set `level_id` metadata on each level root. Puzzle state lives only in `RunState.current().puzzles` (`PuzzleRegistry`).
- Puzzle targets must be `PuzzleSource`s with an ordinary `HurtboxComponent` on layer 7; never add a separate puzzle attack system. Gates are solid only when fully closed and must never close on an occupant.
- Design rule: a crossing that must require a partner needs travel time > gate close delay + 0.3 s slide (closing gates reopen when someone reaches the doorway). Every one-way crossing needs a way back.
- Development-only switch: `PuzzleSource.debug_visible`. Puzzle test room: `res://scenes/dev/puzzle_test_room.tscn`, generated by `tools/build_phase7_content.gd`.
- Saving: all slot I/O goes through `SaveManager` (`scripts/save/`); never write slot files directly. Save data contains ids, never paths: add every new level to `LevelCatalog` and every re-creatable entity type to `LevelCatalog.ENTITY_SCENES`. Give every persistent enemy and platform a `save_id` (unique per level; `SaveIds.find_duplicates` checks) and set `level_id` metadata on level roots.
- New saveable state goes through `RunState.snapshot()` (run-wide) or `capture_live()` / `apply_live()` / `save_state()` (level-live) and must be validated before it is applied. Never serialise nodes, resources or callables.
- Gameplay never saves directly: call `CampaignGame.request_autosave(reason)`. Only `CampaignGame` runs team wipes; a knight's `died` signal is the only trigger.
- Tests and dev rooms use their own save folders (`user://test_saves*/`, `user://saves_dev/`), never `user://saves/`.
- Main scene: `scenes/app/game_app.tscn` (`GameApp`). It owns the one `SaveManager` (injected into `CampaignGame`), `SettingsManager`, `AudioManager` and the `UiStack`. Only `GameApp` pauses the game (`get_tree().paused`). No autoloads.
- Menu screens extend `MenuScreen`: widgets in `build()`, first focus in `first_focus()`, Escape in `back()`. Every action goes through `GameApp`, and UI scripts never read save files. Use `UiButton`, `ConfirmDialog` (destructive questions focus Cancel) and `UiTheme`. Use only Pixel Operator 8 at 8, 16 or 32 px.
- HUD: `GameHud` is a CanvasLayer child of `campaign_game.tscn`. It updates from signals and must never be placed inside a SubViewport.
- Sounds: play through `Sfx.play` / `Sfx.cue` (SFX bus; pass `ui = true` for menu sounds). Music goes only through `AudioManager`. Every file and cue lives in `resources/config/audio_config.tres`.
- Settings live in `user://settings.cfg` (`SettingsManager`), never in a save slot. Tests use `user://test_settings_ui.cfg` and `user://test_saves_ui/` (`UiTestUtil`), with `touch_window = false` and a `quit_handler`.
- Every quit goes through `GameApp.shutdown()` or `CampaignGame.quit_handler`. These stop audio before exiting.
- Phase 9 harness: `scenes/dev/ui_test_room.tscn` (its own save folder and settings file; dev keys in its script).
- Test runner: any error or warning logged during a test (engine or `SCRIPT ERROR`, `push_error`, `push_warning`) fails that test (`ErrorCatcher` in `run_tests.gd`). Expected fault reports use `printerr`. Still check full-run logs for leak lines after the summary.
- Campaign: `LevelCatalog` is the registry (production campaign by default; `use_development()` gives the two Phase 8 test levels for older tests). Never hard-code level ids or scene paths elsewhere; use `first_level()`, `next_level()`, `level()`, `world_ids()`.
- Levels are generated. Edit the specs in `tools/campaign/world_*.gd` (op format in `tools/campaign/campaign_builder.gd`), then run `--script res://tools/build_phase10_content.gd` and `--script res://tools/campaign_report.gd`. Never edit `scenes/worlds/**` or `resources/campaign/*.tres` by hand.
- Level design limits (checked by `tools/level_analyzer.gd` and calibrated in `test_campaign_physics.gd`): jump up 3 tiles within 2 columns, up 2 within 3, up 1 or level within 4; gaps of 3 tiles at most. Clear a cell before putting a ladder top in solid terrain. Lifts start flush in a cleared floor cell. Every lava crossing needs a route within those limits; every pit a knight can fall into needs a way out.
- Optional bosses: `scenes/enemies/boss/boss_slime.tscn` with `BossStats`, plus a `BossSeal` that opens the reward gate (LATCH). A boss must never be needed for the exit.
- Placed coins use `scenes/collectibles/coin_stash.tscn` with a `collectible_id`, never dropped coins.
- Campaign validation (Phase 11): `test_level_validation` (LevelProbe, 20 checks per level), `test_campaign_routes` (RouteValidator, physical main route with base stats and no bosses), `test_platform_timing` (blinking chains) and `test_no_level_can_trap_a_knight` must pass after every level change. They are slow (the full suite takes about two minutes). Results go to `user://*_results.json`; `docs/LEVEL_VALIDATION_MATRIX.md` is written from them.
- Blinking stones: `TimedPlatform.start_offset` advances the phase (higher = vanishes sooner), so offsets must decrease in the direction of travel. A chain must leave at least 0.25 s on every stone with 0.55 s hops.
- Every reachable place must lead back to the exit: vaults and pits need a ladder or steps; spike beds wider than a jump need a safe tile (`trap_cells`).
- Test tools that instance a level copy outside the tree (analyzer copies) must free it.
- Severity: P0 critical, P1 major (blocks progress), P2 moderate, P3 cosmetic; every defect in `docs/KNOWN_ISSUES.md` lists reproduction, expected, actual, root cause, fix and regression result.
- Manual results come only from the user. Levels the user has reported go in `USER_REPORTS` in `tools/campaign_report.gd` and in `docs/PLAYTEST_FEEDBACK.md`; never mark other levels as manually tested.
- `tools/difficulty_report.gd` gives the per-level difficulty evidence (`user://difficulty_report.md`). Balance changes need evidence (impossible, trap, luck-based), never just "it feels hard".
