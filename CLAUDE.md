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
