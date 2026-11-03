# Test Report

Only tests that were actually run are recorded here.

## Phase 0: 2026-11-03

| Check | Command / method | Result |
|---|---|---|
| Godot version | `Godot_v4.7.2-stable_win64_console.exe --version` | `4.7.2.stable.official.ed1daf0bf` |
| Project import | `godot --headless --path . --import` | Completed, no errors or warnings |
| Launch | `godot --headless --path . --quit-after 2` | `Error: Can't run project: no main scene defined` (expected; no scenes exist) |
| Sprite sheets readable | Headless `Image.load_from_file` on all 7 PNGs | All load; dimensions and per-cell rects recorded in ASSET_CATALOG |
| Audio readable | Headless `AudioStreamMP3/WAV.load_from_file` | All load. WAV runtime loader prints `Condition "p_position > length"` for coin, explosion, jump, tap (odd-length data chunk, no pad byte). The editor importer is unaffected |
| Asset paths in docs | Script checking every `res://` path in `docs/*.md` exists | 17/17 existing-asset paths found. The only miss is `res://tests/run_tests.gd`, which is a proposed future file, labelled as such |
| No project files modified | `find . -newer GDD.md -not -path ./.godot/*` | Only `CLAUDE.md`, `ROADMAP.md` (edited by the user before this session) |

Gameplay tests: none yet (no gameplay exists).
Manual keyboard tests: none yet (scheduled for Phase 1.4).

## Phase 1: 2026-11-03

Engine: `Godot_v4.7.2-stable_win64_console.exe` (`4.7.2.stable.official.ed1daf0bf`), at
`C:/Users/Reaper/Downloads/Godot/`.

### A. Script and resource validation

| Check | Method | Result |
|---|---|---|
| Resource import | `godot --headless --path . --import` | No errors or warnings |
| Editor opens project | `godot --headless --path . --editor --quit` | Scan, class update and layout load OK; exit 0 |
| GDScript parsing | `test_all_scripts_parse`: every `.gd` loads and `can_instantiate()` | Pass (all scripts) |
| Scenes and resources load, dependencies exist | `test_all_resources_and_scenes_load` | Pass |
| Scene instantiation, NodePaths, signal connections, collision shapes | `test_scenes_instantiate_with_valid_paths_signals_and_shapes` (every scene under `res://scenes`) | Pass |
| InputMap definitions | `test_gameplay_actions_exist_with_correct_keys`, `test_actions_are_exclusive_per_player`, `test_alt_variants_and_modifier_independence` | Pass |
| Offline guard (no network APIs or URLs in game code) | `test_game_code_is_offline` | Pass |
| Animation frames never use the sheet's text-label cells | `test_knight_sprite_frames` | Pass |
| Renderer actually loads | Windowed run with a capture script | `gl_compatibility`, OpenGL 3.3.0 NVIDIA 610.47, RTX 4050 Laptop GPU. Window 1280×720, viewport 640×360 |
| Save directory | `test_save_directory_identity` + room startup log | `user://` = `C:/Users/Reaper/AppData/Roaming/TwoKnightCoop/`; `saves/` created; outside the project |

### B. Automated tests

Command: `godot --headless --path . --fixed-fps 60 --script res://tests/run_tests.gd`

Result: **42 passed, 0 failed**, exit code 0, no `ERROR`/`WARNING` lines. Repeated 3 times
with identical results (about 2 s per run). Gameplay tests run in a fresh copy of the real test
room and drive the real InputMap actions. One test injects raw `InputEventKey` events, including
Left/Right Alt with `location`, through `Input.parse_input_event`.

```
res://tests/gameplay/test_knight_movement.gd
PASS test_knights_spawn_independent
PASS test_players_move_independently_and_simultaneously
PASS test_left_and_right_together_cancel
PASS test_full_jump_height_and_landing
PASS test_variable_jump_height
PASS test_no_double_jump_and_no_hold_bunny_hop
PASS test_jump_buffer_before_landing
PASS test_both_jump_in_same_frame
PASS test_crouch_under_low_ceiling
PASS test_down_on_solid_floor_does_not_drop
PASS test_drop_through_one_way_and_jump_back_up
PASS test_drop_passes_only_one_platform
PASS test_other_knight_unaffected_by_drop
PASS test_ladder_climb_up_hold_and_exit_top
PASS test_ladder_climb_down_from_top
PASS test_ladder_side_release
PASS test_passage_allows_free_movement
PASS test_attack_inputs_are_independent
PASS test_attack_direction_from_input
PASS test_push_moves_the_other_knight
PASS test_push_against_wall_does_not_trap
PASS test_corridor_mutual_push_never_locks
PASS test_push_off_platform_edge
PASS test_standing_on_knight_carry_and_lift
PASS test_spawn_overlap_resolves_without_impulse
PASS test_raw_key_events_drive_both_knights
res://tests/unit/test_logic.gd
PASS test_attack_direction_table
PASS test_vertical_intent_priority_table
PASS test_input_frame_edges_and_axes
PASS test_health_limits
PASS test_health_max_changes
res://tests/unit/test_project_setup.gd
PASS test_rendering_and_window_settings
PASS test_save_directory_identity
PASS test_gameplay_actions_exist_with_correct_keys
PASS test_actions_are_exclusive_per_player
PASS test_alt_variants_and_modifier_independence
PASS test_profiles_reference_valid_actions
res://tests/unit/test_resource_validation.gd
PASS test_all_scripts_parse
PASS test_all_resources_and_scenes_load
PASS test_scenes_instantiate_with_valid_paths_signals_and_shapes
PASS test_game_code_is_offline
PASS test_knight_sprite_frames
```

Defects found and fixed during Phase 1 testing:

1. `HealthComponent`: a property setter with a defaulted second parameter is a GDScript parse
   error. Split into a plain setter plus `set_max_health(value, fill_added)`.
2. Knights left a ladder 9 px below the top. The body *centre* left the area before the
   feet reached the top exit, causing a release/regrab loop. The same bug affected the passage.
   Fixed with `Climbable.holds()`, which ignores the top edge while climbing.
3. One attack press was counted twice when the engine's `just_pressed` and the held-state edge
   fell on different ticks. Presses now count only if the action was not already held.
4. The test validator crashed Godot by calling `GDScript.reload()` on scripts in use. It now
   validates with `load()` + `can_instantiate()`.
5. The generated test room stored every inherited property as an override, which would hide
   future `knight.tscn` changes. Instances are now created with `GEN_EDIT_STATE_INSTANCE`.

### C. Manual tests

| Test | Status |
|---|---|
| Visual check of rendered frames (crisp pixels, P1 green/red vs P2 blue/cyan, HUD, crouch, climb, stacking, hurt) | Done by Claude from captured frames, **not** interactive play |
| Physical keyboard tests 1–10 and Alt checks A–D (`docs/MANUAL_KEYBOARD_TEST.md`) | **USER-REPORTED PASS** (reported by the project owner before Phase 2; see the Phase 2 section) |
| Keyboard model and layout | **Not supplied** |
| Movement feel, responsiveness, readability with two people | **Pending user test** |
| Running the test room from the editor (F5) by the user | **Pending user test** |

## Phase 1 physical keyboard test: user report

- **Result: USER-REPORTED PASS.** Before Phase 2 began, the project owner reported that the
  physical keyboard test was performed and that the keyboard works correctly for both players.
- **Not supplied:** keyboard manufacturer, model and layout, and the per-test results table.
- This is a user report. Claude did not, and cannot, independently verify the hardware.
  Ghosting and Alt behaviour on other keyboards remain untested.

## Phase 2: 2026-11-03

### A. Validation

| Check | Method | Result |
|---|---|---|
| Import | `godot --headless --path . --import` | No errors |
| Editor opens project | `godot --headless --path . --editor --quit` | No errors |
| Camera room launches standalone | `godot --headless --path . res://scenes/dev/camera_test_room.tscn --quit-after 120` | Exit 0, no errors |
| Phase 1 generator refactor | Regenerated the Phase 1 room with `tools/level_builder.gd` and diffed it against the committed file (ignoring generated IDs) | Identical; committed file kept |
| Renderer in rendered run | Windowed capture script | `gl_compatibility` on RTX 4050 |
| Seamless split (rendered) | Froze both knights, captured the last shared frame and the frame produced by the single camera update that split | Left half: **0** differing pixels. Right half: 460, all from P2's own 15 px move |
| Window resize (rendered) | `DisplayServer.window_set_size` to 1920×1080, 1000×620, 800×450 | Root visible rect and rig stay 640×360. Views 320×360 + 320×360 in each case. Captures sharp and undistorted |
| Long-run counters | Rendered run with 7 layout changes | 61 nodes throughout |

### B. Automated tests

Command: `godot --headless --path . --fixed-fps 60 --script res://tests/run_tests.gd`

Result: **74 passed, 0 failed**, exit code 0, no `ERROR`/`WARNING` lines. That is 42 Phase 1
tests (unchanged), 11 camera unit tests and 21 camera gameplay tests.

```
res://tests/gameplay/test_camera_rig.gd
PASS test_shared_mode_at_start
PASS test_world_is_simulated_once
PASS test_pixel_art_settings
PASS test_horizontal_separation_splits_side_by_side
PASS test_vertical_separation_splits_stacked
PASS test_assignment_is_fixed_even_when_knights_cross
PASS test_split_triggers_at_threshold_while_walking
PASS test_independent_tracking
PASS test_reunification_by_walking
PASS test_reunification_initiated_by_either_player
PASS test_no_flicker_inside_hysteresis_band
PASS test_jitter_at_split_threshold_switches_once
PASS test_merge_requires_hold_time
PASS test_orientation_hysteresis_and_hold
PASS test_cameras_respect_level_bounds
PASS test_tall_section_tracking
PASS test_layout_follows_rig_size
PASS test_camera_does_not_affect_simulation
PASS test_camera_updates_never_move_knights
PASS test_repeated_switching_does_not_accumulate_resources
PASS test_phase1_mechanics_inside_the_rig
res://tests/gameplay/test_knight_movement.gd
PASS test_knights_spawn_independent
PASS test_players_move_independently_and_simultaneously
PASS test_left_and_right_together_cancel
PASS test_full_jump_height_and_landing
PASS test_variable_jump_height
PASS test_no_double_jump_and_no_hold_bunny_hop
PASS test_jump_buffer_before_landing
PASS test_both_jump_in_same_frame
PASS test_crouch_under_low_ceiling
PASS test_down_on_solid_floor_does_not_drop
PASS test_drop_through_one_way_and_jump_back_up
PASS test_drop_passes_only_one_platform
PASS test_other_knight_unaffected_by_drop
PASS test_ladder_climb_up_hold_and_exit_top
PASS test_ladder_climb_down_from_top
PASS test_ladder_side_release
PASS test_passage_allows_free_movement
PASS test_attack_inputs_are_independent
PASS test_attack_direction_from_input
PASS test_push_moves_the_other_knight
PASS test_push_against_wall_does_not_trap
PASS test_corridor_mutual_push_never_locks
PASS test_push_off_platform_edge
PASS test_standing_on_knight_carry_and_lift
PASS test_spawn_overlap_resolves_without_impulse
PASS test_raw_key_events_drive_both_knights
res://tests/unit/test_camera_math.gd
PASS test_midpoint
PASS test_separation_ratio_axes
PASS test_split_and_merge_thresholds_with_hysteresis
PASS test_orientation_selection_and_hysteresis
PASS test_layout_rectangles
PASS test_sub_view_center_is_seamless
PASS test_clamp_center_to_bounds
PASS test_deadzone
PASS test_smoothing_is_frame_rate_independent
PASS test_camera_config_validation
PASS test_camera_bounds_rect_and_tilemap_fit
res://tests/unit/test_logic.gd
PASS test_attack_direction_table
PASS test_vertical_intent_priority_table
PASS test_input_frame_edges_and_axes
PASS test_health_limits
PASS test_health_max_changes
res://tests/unit/test_project_setup.gd
PASS test_rendering_and_window_settings
PASS test_save_directory_identity
PASS test_gameplay_actions_exist_with_correct_keys
PASS test_actions_are_exclusive_per_player
PASS test_alt_variants_and_modifier_independence
PASS test_profiles_reference_valid_actions
res://tests/unit/test_resource_validation.gd
PASS test_all_scripts_parse
PASS test_all_resources_and_scenes_load
PASS test_scenes_instantiate_with_valid_paths_signals_and_shapes
PASS test_game_code_is_offline
PASS test_knight_sprite_frames
```

Requirement coverage:
- midpoint: `test_midpoint`
- horizontal and vertical separation: `test_separation_ratio_axes`
- split and merge thresholds plus hysteresis: `test_split_and_merge_thresholds_with_hysteresis`, `test_split_triggers_at_threshold_while_walking`, `test_merge_requires_hold_time`, `test_no_flicker_inside_hysteresis_band`, `test_jitter_at_split_threshold_switches_once`
- orientation: `test_orientation_selection_and_hysteresis`, `test_orientation_hysteresis_and_hold`, `test_horizontal_separation_splits_side_by_side`, `test_vertical_separation_splits_stacked`
- assignment: `test_assignment_is_fixed_even_when_knights_cross`
- target updates: `test_independent_tracking`, `test_tall_section_tracking`
- viewport sizes: `test_layout_rectangles`, `test_layout_follows_rig_size`
- bounds: `test_clamp_center_to_bounds`, `test_cameras_respect_level_bounds`, `test_camera_bounds_rect_and_tilemap_fit`
- mode changes during movement: `test_reunification_by_walking` (checks every frame that each knight stays visible in its own view), `test_reunification_initiated_by_either_player`
- one simulation: `test_world_is_simulated_once`
- no physics side effects: `test_camera_does_not_affect_simulation` (P1's trajectory is identical with the camera on and off, while the camera switches modes), `test_camera_updates_never_move_knights`
- resources: `test_repeated_switching_does_not_accumulate_resources`

### C. Phase 1 regression

- All 42 Phase 1 tests pass unchanged, in the Phase 1 room.
- `test_phase1_mechanics_inside_the_rig` repeats the following inside the camera room, where
  physics now runs in a SubViewport's World2D: jump height, one-way drop, crawl, push, and
  simultaneous attacks. All pass.
- No Phase 1 movement, input or knight file was modified.

### Defects found and fixed during Phase 2

1. **Enum type mismatch in Godot 4.7.2.** A static function on a `class_name` script declared
   as `-> Orientation` produced a type that typed callers rejected as not `CameraMath.Orientation`
   (reproduced in isolation). Fixed by fully qualifying the enum in `camera_math.gd`.
   Phase 1's `AttackDirection` was probed with typed callers and is unaffected.
2. **Physics interpolation warning.** It forced the cameras into physics-process mode. They now
   declare `CAMERA2D_PROCESS_PHYSICS` explicitly.
3. **Test-only issues:**
   - placements inside the crawl section, where a standing knight is wedged;
   - unrealistically fast scripted movement, at six times knight speed;
   - a float32 boundary comparison;
   - a capture taken one tick after the split, which first suggested a 10 px seam;
     the exact split frame shows none.

### D. Manual tests

| Test | Status |
|---|---|
| Camera tests 1–10 (`docs/MANUAL_CAMERA_TEST.md`) | **Pending user test** |
| Visual inspection of captured frames (shared, side-by-side, stacked, merging, three window sizes) | Done by Claude from captures, **not** interactive play |

## Phase 3: 2026-11-03

### A. Validation

| Check | Result |
|---|---|
| Import / editor open (`--import`, `--editor --quit`) | No errors |
| Combat room launches standalone (`res://scenes/dev/combat_test_room.tscn --quit-after 120`) | Exit 0, no errors |
| Rendered run (windowed, Compatibility) | Right slash captured on its first hit frame: weapon frame 1, hitbox open, target flashes and drops to 2/3. Up slash shown. P1 death pose and P2 invulnerability blink visible. Both knights attacking in split-screen. Pixel art sharp |
| Room targets driven by a script | Jump + up attack hits "Above". One swing hits both "TWO AT ONCE" targets (same attack id). The EDGE target is hit from its stand tick; TOO FAR is not |

### B. Automated tests

Command: `godot --headless --path . --fixed-fps 60 --script res://tests/run_tests.gd`

Result: **110 passed, 0 failed**, exit code 0, no `ERROR`/`WARNING` lines, identical over
repeated runs. That is 42 Phase 1, 32 Phase 2 and 36 Phase 3 tests.

```
res://tests/gameplay/test_camera_rig.gd
PASS test_shared_mode_at_start
PASS test_world_is_simulated_once
PASS test_pixel_art_settings
PASS test_horizontal_separation_splits_side_by_side
PASS test_vertical_separation_splits_stacked
PASS test_assignment_is_fixed_even_when_knights_cross
PASS test_split_triggers_at_threshold_while_walking
PASS test_independent_tracking
PASS test_reunification_by_walking
PASS test_reunification_initiated_by_either_player
PASS test_no_flicker_inside_hysteresis_band
PASS test_jitter_at_split_threshold_switches_once
PASS test_merge_requires_hold_time
PASS test_orientation_hysteresis_and_hold
PASS test_cameras_respect_level_bounds
PASS test_tall_section_tracking
PASS test_layout_follows_rig_size
PASS test_camera_does_not_affect_simulation
PASS test_camera_updates_never_move_knights
PASS test_repeated_switching_does_not_accumulate_resources
PASS test_phase1_mechanics_inside_the_rig
res://tests/gameplay/test_combat.gd
PASS test_player_one_attacks_independently
PASS test_player_two_attacks_independently
PASS test_simultaneous_attacks
PASS test_attack_does_not_interrupt_other_player
PASS test_knights_cannot_hit_each_other
PASS test_four_directions_and_animation_selection
PASS test_down_attack_from_ladder_hits_target_below
PASS test_hit_frames_and_animation_are_synchronised
PASS test_cooldown_and_input_buffer
PASS test_one_hit_per_target_per_attack
PASS test_one_swing_hits_several_targets
PASS test_attack_power_sets_damage
PASS test_range_edge
PASS test_walls_block_attacks
PASS test_low_obstacle_and_corner
PASS test_one_way_platform_does_not_block
PASS test_room_thin_wall_target_is_protected
PASS test_knights_have_independent_health
PASS test_contact_damage_with_invulnerability_on_knight
PASS test_death_state
PASS test_dead_knight_while_climbing
PASS test_attack_while_running
PASS test_attacks_during_camera_transitions
PASS test_combat_never_changes_camera_state
PASS test_no_nodes_created_per_attack
res://tests/gameplay/test_knight_movement.gd
PASS test_knights_spawn_independent
PASS test_players_move_independently_and_simultaneously
PASS test_left_and_right_together_cancel
PASS test_full_jump_height_and_landing
PASS test_variable_jump_height
PASS test_no_double_jump_and_no_hold_bunny_hop
PASS test_jump_buffer_before_landing
PASS test_both_jump_in_same_frame
PASS test_crouch_under_low_ceiling
PASS test_down_on_solid_floor_does_not_drop
PASS test_drop_through_one_way_and_jump_back_up
PASS test_drop_passes_only_one_platform
PASS test_other_knight_unaffected_by_drop
PASS test_ladder_climb_up_hold_and_exit_top
PASS test_ladder_climb_down_from_top
PASS test_ladder_side_release
PASS test_passage_allows_free_movement
PASS test_attack_inputs_are_independent
PASS test_attack_direction_from_input
PASS test_push_moves_the_other_knight
PASS test_push_against_wall_does_not_trap
PASS test_corridor_mutual_push_never_locks
PASS test_push_off_platform_edge
PASS test_standing_on_knight_carry_and_lift
PASS test_spawn_overlap_resolves_without_impulse
PASS test_raw_key_events_drive_both_knights
res://tests/unit/test_camera_math.gd
PASS test_midpoint
PASS test_separation_ratio_axes
PASS test_split_and_merge_thresholds_with_hysteresis
PASS test_orientation_selection_and_hysteresis
PASS test_layout_rectangles
PASS test_sub_view_center_is_seamless
PASS test_clamp_center_to_bounds
PASS test_deadzone
PASS test_smoothing_is_frame_rate_independent
PASS test_camera_config_validation
PASS test_camera_bounds_rect_and_tilemap_fit
res://tests/unit/test_combat_logic.gd
PASS test_direction_rules
PASS test_new_knight_default_facing
PASS test_profiles
PASS test_hitbox_rectangles
PASS test_range_is_short_and_scales_separately_from_power
PASS test_combat_config_valid
PASS test_damage_category_rules
PASS test_health_operations
PASS test_invulnerability_blocks_then_expires
PASS test_fall_lava_and_protection_filters
PASS test_death_emitted_once_and_no_silent_revival
res://tests/unit/test_logic.gd
PASS test_attack_direction_table
PASS test_vertical_intent_priority_table
PASS test_input_frame_edges_and_axes
PASS test_health_limits
PASS test_health_max_changes
res://tests/unit/test_project_setup.gd
PASS test_rendering_and_window_settings
PASS test_save_directory_identity
PASS test_gameplay_actions_exist_with_correct_keys
PASS test_actions_are_exclusive_per_player
PASS test_alt_variants_and_modifier_independence
PASS test_profiles_reference_valid_actions
res://tests/unit/test_resource_validation.gd
PASS test_all_scripts_parse
PASS test_all_resources_and_scenes_load
PASS test_scenes_instantiate_with_valid_paths_signals_and_shapes
PASS test_game_code_is_offline
PASS test_knight_sprite_frames
```

Coverage of the requested Phase 3 checks:

| Requested check | Test |
|---|---|
| Up selects UP | `test_direction_rules` |
| Down selects DOWN | `test_direction_rules` |
| No vertical input or both held: last facing | `test_direction_rules` |
| Facing unchanged by Up/Down | `test_four_directions_and_animation_selection`, Phase 1 `test_attack_direction_from_input` |
| Default facing | `test_new_knight_default_facing` |
| P1 / P2 attack independently | `test_player_one_attacks_independently`, `test_player_two_attacks_independently` |
| Simultaneous attacks, no interruption | `test_simultaneous_attacks`, `test_attack_does_not_interrupt_other_player` |
| Animation selection | `test_four_directions_and_animation_selection`, `test_down_attack_from_ladder_hits_target_below` |
| Hitbox only on hit frames, synchronised | `test_hit_frames_and_animation_are_synchronised` |
| Cooldown | `test_cooldown_and_input_buffer` |
| One hit per target per attack | `test_one_hit_per_target_per_attack` |
| Several targets per swing | `test_one_swing_hits_several_targets` |
| Walls block | `test_walls_block_attacks`, `test_low_obstacle_and_corner`, `test_room_thin_wall_target_is_protected` |
| One-way platforms do not block | `test_one_way_platform_does_not_block` |
| Out of range | `test_range_edge` (1 px beyond the reach is not hit; ×1.3 range reaches it) |
| Dead players cannot attack | `test_death_state` |
| Health starts at 3, damage, heal, cap, max upgrade, never negative | `test_health_operations`, `test_knights_have_independent_health` |
| Invulnerability blocks, then expires | `test_invulnerability_blocks_then_expires`, `test_contact_damage_with_invulnerability_on_knight` |
| Death once, dead cannot play | `test_death_emitted_once_and_no_silent_revival`, `test_death_state`, `test_dead_knight_while_climbing` |
| Categories | `test_damage_category_rules`, `test_fall_lava_and_protection_filters` |
| No friendly fire | `test_knights_cannot_hit_each_other` |
| Attacks during camera transitions | `test_attacks_during_camera_transitions` (6 attacks across split and merge, each hit exactly once) |
| Combat never changes the camera | `test_combat_never_changes_camera_state` |
| No node churn | `test_no_nodes_created_per_attack` |

### C. Regression

- **Phase 1:** all 42 tests pass. Phase 1 movement code was not modified. The only knight
  changes are additive (combat, hurtbox, death); every Phase 1 test exercises the updated knight.
- **Phase 2:** all 32 tests pass, including the Phase 1 mechanics run inside the rig.

### Defects found and fixed during Phase 3

1. **Cooldown off by one tick.** The start tick counted as 1/60 s elapsed, so attacks could start
   17 ticks apart (0.283 s) instead of 18 (0.30 s). The start tick is now elapsed time 0.
2. **Weapon frame lagged a hit.** Within the hit tick, hits were applied before the weapon frame
   was updated. The visual is now updated first.
3. **Test and room placements:**
   - a running-attack target was beyond the actual swing position;
   - a "hold" check pressed outside the buffer window;
   - the camera test did not wait long enough for a merge;
   - the room's "Above" target hung so low that the jump of an up attack carried the knight past it.

### D. Manual tests

| Test | Status |
|---|---|
| Combat tests 1–14 (`docs/MANUAL_COMBAT_TEST.md`) | **Pending user test** |
| Phase 2 manual camera tests | **Still pending** (not reported by the user) |
| Visual inspection of captured frames | Done by Claude from captures, **not** interactive play |

## Phase 4: 2026-11-03

### A. Validation

| Check | Result |
|---|---|
| Import / editor open | No errors |
| Enemy room launches standalone (`res://scenes/dev/enemy_test_room.tscn --quit-after 300`) | Exit 0, no errors |
| Resource validation (every scene, including slimes and coins, instantiated) | Pass. It found that `slime_base.tscn` had no stats when instanced alone; fixed by defaulting it to the green stats |
| Rendered run (windowed) | "!" alert on detection; chase; staggered green slime as a pulsing puddle with circling stars; death; 5 coins (`coin.png`) settling on the floor; listener total = 5; overlay and debug drawing (detection circles, line of sight, patrol limits, edge probes) |

### B. Automated tests

Command: `godot --headless --path . --fixed-fps 60 --script res://tests/run_tests.gd`

Result: **144 passed, 0 failed**, exit code 0, no `ERROR`/`WARNING` lines. Identical over two
runs. That is 42 Phase 1, 32 Phase 2, 36 Phase 3 and 34 Phase 4 tests.

```
res://tests/gameplay/test_camera_rig.gd
PASS test_shared_mode_at_start
PASS test_world_is_simulated_once
PASS test_pixel_art_settings
PASS test_horizontal_separation_splits_side_by_side
PASS test_vertical_separation_splits_stacked
PASS test_assignment_is_fixed_even_when_knights_cross
PASS test_split_triggers_at_threshold_while_walking
PASS test_independent_tracking
PASS test_reunification_by_walking
PASS test_reunification_initiated_by_either_player
PASS test_no_flicker_inside_hysteresis_band
PASS test_jitter_at_split_threshold_switches_once
PASS test_merge_requires_hold_time
PASS test_orientation_hysteresis_and_hold
PASS test_cameras_respect_level_bounds
PASS test_tall_section_tracking
PASS test_layout_follows_rig_size
PASS test_camera_does_not_affect_simulation
PASS test_camera_updates_never_move_knights
PASS test_repeated_switching_does_not_accumulate_resources
PASS test_phase1_mechanics_inside_the_rig
res://tests/gameplay/test_combat.gd
PASS test_player_one_attacks_independently
PASS test_player_two_attacks_independently
PASS test_simultaneous_attacks
PASS test_attack_does_not_interrupt_other_player
PASS test_knights_cannot_hit_each_other
PASS test_four_directions_and_animation_selection
PASS test_down_attack_from_ladder_hits_target_below
PASS test_hit_frames_and_animation_are_synchronised
PASS test_cooldown_and_input_buffer
PASS test_one_hit_per_target_per_attack
PASS test_one_swing_hits_several_targets
PASS test_attack_power_sets_damage
PASS test_range_edge
PASS test_walls_block_attacks
PASS test_low_obstacle_and_corner
PASS test_one_way_platform_does_not_block
PASS test_room_thin_wall_target_is_protected
PASS test_knights_have_independent_health
PASS test_contact_damage_with_invulnerability_on_knight
PASS test_death_state
PASS test_dead_knight_while_climbing
PASS test_attack_while_running
PASS test_attacks_during_camera_transitions
PASS test_combat_never_changes_camera_state
PASS test_no_nodes_created_per_attack
res://tests/gameplay/test_knight_movement.gd
PASS test_knights_spawn_independent
PASS test_players_move_independently_and_simultaneously
PASS test_left_and_right_together_cancel
PASS test_full_jump_height_and_landing
PASS test_variable_jump_height
PASS test_no_double_jump_and_no_hold_bunny_hop
PASS test_jump_buffer_before_landing
PASS test_both_jump_in_same_frame
PASS test_crouch_under_low_ceiling
PASS test_down_on_solid_floor_does_not_drop
PASS test_drop_through_one_way_and_jump_back_up
PASS test_drop_passes_only_one_platform
PASS test_other_knight_unaffected_by_drop
PASS test_ladder_climb_up_hold_and_exit_top
PASS test_ladder_climb_down_from_top
PASS test_ladder_side_release
PASS test_passage_allows_free_movement
PASS test_attack_inputs_are_independent
PASS test_attack_direction_from_input
PASS test_push_moves_the_other_knight
PASS test_push_against_wall_does_not_trap
PASS test_corridor_mutual_push_never_locks
PASS test_push_off_platform_edge
PASS test_standing_on_knight_carry_and_lift
PASS test_spawn_overlap_resolves_without_impulse
PASS test_raw_key_events_drive_both_knights
res://tests/gameplay/test_slimes.gd
PASS test_patrol_stays_within_bounds
PASS test_patrol_turns_at_platform_edges
PASS test_patrol_turns_at_walls
PASS test_patrol_and_chase_speeds
PASS test_detects_visible_player_and_chases
PASS test_wall_blocks_detection
PASS test_detects_knight_on_ladder_or_platform_through_one_way
PASS test_nearest_player_selected
PASS test_target_selection_does_not_flicker
PASS test_dead_target_is_abandoned
PASS test_returns_to_patrol_after_grace_period
PASS test_unreachable_target_gives_up
PASS test_green_stagger_and_kill
PASS test_green_recovers_and_can_be_staggered_again
PASS test_purple_stagger_and_kill
PASS test_upgraded_attack_power
PASS test_staggered_slime_does_not_move
PASS test_real_knight_attacks_green_then_purple
PASS test_contact_damage_respects_invulnerability
PASS test_staggered_and_dead_slimes_are_harmless
PASS test_contact_stops_after_slime_is_removed
PASS test_death_and_coin_drop_happen_once
PASS test_every_slime_rolls_its_own_drop
PASS test_both_knights_fight_several_slimes_simultaneously
PASS test_recovered_slime_reacquires_visible_knight
res://tests/unit/test_camera_math.gd
PASS test_midpoint
PASS test_separation_ratio_axes
PASS test_split_and_merge_thresholds_with_hysteresis
PASS test_orientation_selection_and_hysteresis
PASS test_layout_rectangles
PASS test_sub_view_center_is_seamless
PASS test_clamp_center_to_bounds
PASS test_deadzone
PASS test_smoothing_is_frame_rate_independent
PASS test_camera_config_validation
PASS test_camera_bounds_rect_and_tilemap_fit
res://tests/unit/test_combat_logic.gd
PASS test_direction_rules
PASS test_new_knight_default_facing
PASS test_profiles
PASS test_hitbox_rectangles
PASS test_range_is_short_and_scales_separately_from_power
PASS test_combat_config_valid
PASS test_damage_category_rules
PASS test_health_operations
PASS test_invulnerability_blocks_then_expires
PASS test_fall_lava_and_protection_filters
PASS test_death_emitted_once_and_no_silent_revival
res://tests/unit/test_enemy_logic.gd
PASS test_green_stagger_sequence
PASS test_purple_stagger_sequence
PASS test_upgraded_attack_power
PASS test_duration_minimum_and_recovery
PASS test_hits_do_not_restart_the_timer
PASS test_non_melee_progress_cannot_kill
PASS test_target_selector
PASS test_coin_roll_range_and_reproducibility
PASS test_slime_stats
res://tests/unit/test_logic.gd
PASS test_attack_direction_table
PASS test_vertical_intent_priority_table
PASS test_input_frame_edges_and_axes
PASS test_health_limits
PASS test_health_max_changes
res://tests/unit/test_project_setup.gd
PASS test_rendering_and_window_settings
PASS test_save_directory_identity
PASS test_gameplay_actions_exist_with_correct_keys
PASS test_actions_are_exclusive_per_player
PASS test_alt_variants_and_modifier_independence
PASS test_profiles_reference_valid_actions
res://tests/unit/test_resource_validation.gd
PASS test_all_scripts_parse
PASS test_all_resources_and_scenes_load
PASS test_scenes_instantiate_with_valid_paths_signals_and_shapes
PASS test_game_code_is_offline
PASS test_knight_sprite_frames
```

Coverage of the requested Phase 4 checks:

| Requested check | Test |
|---|---|
| Enters patrol; stays within bounds | `test_patrol_stays_within_bounds` |
| Walls and platform edges | `test_patrol_turns_at_walls`, `test_patrol_turns_at_platform_edges` |
| Detects a visible player, enters chase | `test_detects_visible_player_and_chases` |
| Wall blocks detection | `test_wall_blocks_detection` (one-way platforms do not: `test_detects_knight_on_ladder_or_platform_through_one_way`) |
| Chase = exactly 2 × patrol | `test_patrol_and_chase_speeds` (velocities exactly 30 and 60; 20-tick distance), `test_slime_stats` |
| Nearest player; no flicker | `test_nearest_player_selected`, `test_target_selection_does_not_flicker`, `test_target_selector` |
| Dead target abandoned | `test_dead_target_is_abandoned` |
| Returns to patrol when the target is lost | `test_returns_to_patrol_after_grace_period`, `test_unreachable_target_gives_up` |
| Staggered slime does not move | `test_staggered_slime_does_not_move` |
| Green: 0 → 1 → stagger; the trigger does not kill; ≥ 10 s; next distinct attack kills; recovers; resets; staggers again; harmless | `test_green_stagger_and_kill`, `test_green_recovers_and_can_be_staggered_again`, `test_green_stagger_sequence`, `test_duration_minimum_and_recovery` |
| Purple: 1, 2, 3, stagger on 4; the trigger does not kill; ≥ 10 s; distinct attack kills; resets; harmless | `test_purple_stagger_and_kill`, `test_purple_stagger_sequence` |
| Attack power 2 | `test_upgraded_attack_power` (gameplay and unit) |
| Real knight attacks end to end | `test_real_knight_attacks_green_then_purple` (2+1 and 4+1 real swings) |
| Contact damage 1, invulnerability, staggered/dead harmless, stops after removal | `test_contact_damage_respects_invulnerability`, `test_staggered_and_dead_slimes_are_harmless`, `test_contact_stops_after_slime_is_removed` |
| Drop once, integer, 4–6, valid position, independent per enemy | `test_death_and_coin_drop_happen_once` (includes 2 simultaneous killing hits), `test_every_slime_rolls_its_own_drop` (12 seeded slimes), `test_coin_roll_range_and_reproducibility` (1 000 rolls) |
| Multiple enemies, both knights, camera undisturbed | `test_both_knights_fight_several_slimes_simultaneously` |

### C. Regression

All 42 Phase 1, 32 Phase 2 and 36 Phase 3 tests pass unchanged. No Phase 1–3 script or
scene was modified in Phase 4.

### Defects found during Phase 4

1. **`slime_base.tscn` instanced alone had no stats** (found by the scene validator). It now
   defaults to the green stats; the variants override them.
2. **Test-only issues:**
   - a jitter test let the chase carry a knight's position inside the pillar, so line of sight
     was genuinely blocked;
   - a fight test teleported both knights without re-centring the camera, so the visibility
     guard split the screen as designed.

### D. Manual tests

| Test | Status |
|---|---|
| Enemy tests 1–14 (`docs/MANUAL_ENEMY_TEST.md`) | **Pending user test** |
| Phase 2 camera and Phase 3 combat manual tests | **Still pending** |
| Visual inspection of captured frames | Done by Claude from captures, **not** interactive play |

## Phase 5: 2026-11-03

### A. Validation

| Check | Result |
|---|---|
| Import / compile of every new and changed script | All compile |
| Collectible room launches standalone (`--quit-after 240`) | Exit 0, no errors |
| Rendered run (windowed) | Fruit gallery (12 fruits, three tier heights), jars, power tiles (pressed state, "FAST ATTACK!"), red jar on the stepped pillar, effect pips, coin burst collected, overlay with per-player stats, effects and collection log |

### B. Automated tests

Command: `godot --headless --path . --fixed-fps 60 --script res://tests/run_tests.gd`

Result: **178 passed, 0 failed**, exit code 0, **no `ERROR`/`WARNING` lines**. Identical over
three runs. That is 42 Phase 1, 32 Phase 2, 36 Phase 3, 34 Phase 4 and 34 Phase 5 tests.

```
res://tests/gameplay/test_camera_rig.gd
PASS test_shared_mode_at_start
PASS test_world_is_simulated_once
PASS test_pixel_art_settings
PASS test_horizontal_separation_splits_side_by_side
PASS test_vertical_separation_splits_stacked
PASS test_assignment_is_fixed_even_when_knights_cross
PASS test_split_triggers_at_threshold_while_walking
PASS test_independent_tracking
PASS test_reunification_by_walking
PASS test_reunification_initiated_by_either_player
PASS test_no_flicker_inside_hysteresis_band
PASS test_jitter_at_split_threshold_switches_once
PASS test_merge_requires_hold_time
PASS test_orientation_hysteresis_and_hold
PASS test_cameras_respect_level_bounds
PASS test_tall_section_tracking
PASS test_layout_follows_rig_size
PASS test_camera_does_not_affect_simulation
PASS test_camera_updates_never_move_knights
PASS test_repeated_switching_does_not_accumulate_resources
PASS test_phase1_mechanics_inside_the_rig
res://tests/gameplay/test_collectibles.gd
PASS test_slime_drop_coins_are_collected_into_the_shared_total
PASS test_either_knight_collects_into_one_total
PASS test_two_knights_on_one_coin_collect_it_once
PASS test_coin_heal_roll_heals_both_living_knights
PASS test_green_fruit_tiers_heal_only_the_collector
PASS test_yellow_fruit_shield_blocks_slime_contact
PASS test_shields_do_not_stop_falling_or_lava
PASS test_red_fruit_range_reaches_further_targets
PASS test_purple_fruit_poison_staggers_but_never_kills
PASS test_poison_points_and_reapplication_on_purple
PASS test_green_jar_and_unique_ids
PASS test_red_jar_power_staggers_green_in_one_real_hit
PASS test_yellow_jar_rolls_on_contact
PASS test_blue_jar_speed_only_for_collector
PASS test_power_tile_fires_once_per_visit
PASS test_both_knights_activate_independently
PASS test_tile_effects_values_and_duration
PASS test_pause_stops_effect_timers
PASS test_progress_survives_scene_change
PASS test_snapshot_restore_updates_live_knights
PASS test_two_knights_collect_different_items_at_once
PASS test_speed_upgrade_during_camera_split
res://tests/gameplay/test_combat.gd
PASS test_player_one_attacks_independently
PASS test_player_two_attacks_independently
PASS test_simultaneous_attacks
PASS test_attack_does_not_interrupt_other_player
PASS test_knights_cannot_hit_each_other
PASS test_four_directions_and_animation_selection
PASS test_down_attack_from_ladder_hits_target_below
PASS test_hit_frames_and_animation_are_synchronised
PASS test_cooldown_and_input_buffer
PASS test_one_hit_per_target_per_attack
PASS test_one_swing_hits_several_targets
PASS test_attack_power_sets_damage
PASS test_range_edge
PASS test_walls_block_attacks
PASS test_low_obstacle_and_corner
PASS test_one_way_platform_does_not_block
PASS test_room_thin_wall_target_is_protected
PASS test_knights_have_independent_health
PASS test_contact_damage_with_invulnerability_on_knight
PASS test_death_state
PASS test_dead_knight_while_climbing
PASS test_attack_while_running
PASS test_attacks_during_camera_transitions
PASS test_combat_never_changes_camera_state
PASS test_no_nodes_created_per_attack
res://tests/gameplay/test_knight_movement.gd
PASS test_knights_spawn_independent
PASS test_players_move_independently_and_simultaneously
PASS test_left_and_right_together_cancel
PASS test_full_jump_height_and_landing
PASS test_variable_jump_height
PASS test_no_double_jump_and_no_hold_bunny_hop
PASS test_jump_buffer_before_landing
PASS test_both_jump_in_same_frame
PASS test_crouch_under_low_ceiling
PASS test_down_on_solid_floor_does_not_drop
PASS test_drop_through_one_way_and_jump_back_up
PASS test_drop_passes_only_one_platform
PASS test_other_knight_unaffected_by_drop
PASS test_ladder_climb_up_hold_and_exit_top
PASS test_ladder_climb_down_from_top
PASS test_ladder_side_release
PASS test_passage_allows_free_movement
PASS test_attack_inputs_are_independent
PASS test_attack_direction_from_input
PASS test_push_moves_the_other_knight
PASS test_push_against_wall_does_not_trap
PASS test_corridor_mutual_push_never_locks
PASS test_push_off_platform_edge
PASS test_standing_on_knight_carry_and_lift
PASS test_spawn_overlap_resolves_without_impulse
PASS test_raw_key_events_drive_both_knights
res://tests/gameplay/test_slimes.gd
PASS test_patrol_stays_within_bounds
PASS test_patrol_turns_at_platform_edges
PASS test_patrol_turns_at_walls
PASS test_patrol_and_chase_speeds
PASS test_detects_visible_player_and_chases
PASS test_wall_blocks_detection
PASS test_detects_knight_on_ladder_or_platform_through_one_way
PASS test_nearest_player_selected
PASS test_target_selection_does_not_flicker
PASS test_dead_target_is_abandoned
PASS test_returns_to_patrol_after_grace_period
PASS test_unreachable_target_gives_up
PASS test_green_stagger_and_kill
PASS test_green_recovers_and_can_be_staggered_again
PASS test_purple_stagger_and_kill
PASS test_upgraded_attack_power
PASS test_staggered_slime_does_not_move
PASS test_real_knight_attacks_green_then_purple
PASS test_contact_damage_respects_invulnerability
PASS test_staggered_and_dead_slimes_are_harmless
PASS test_contact_stops_after_slime_is_removed
PASS test_death_and_coin_drop_happen_once
PASS test_every_slime_rolls_its_own_drop
PASS test_both_knights_fight_several_slimes_simultaneously
PASS test_recovered_slime_reacquires_visible_knight
res://tests/unit/test_camera_math.gd
PASS test_midpoint
PASS test_separation_ratio_axes
PASS test_split_and_merge_thresholds_with_hysteresis
PASS test_orientation_selection_and_hysteresis
PASS test_layout_rectangles
PASS test_sub_view_center_is_seamless
PASS test_clamp_center_to_bounds
PASS test_deadzone
PASS test_smoothing_is_frame_rate_independent
PASS test_camera_config_validation
PASS test_camera_bounds_rect_and_tilemap_fit
res://tests/unit/test_combat_logic.gd
PASS test_direction_rules
PASS test_new_knight_default_facing
PASS test_profiles
PASS test_hitbox_rectangles
PASS test_range_is_short_and_scales_separately_from_power
PASS test_combat_config_valid
PASS test_damage_category_rules
PASS test_health_operations
PASS test_invulnerability_blocks_then_expires
PASS test_fall_lava_and_protection_filters
PASS test_death_emitted_once_and_no_silent_revival
res://tests/unit/test_enemy_logic.gd
PASS test_green_stagger_sequence
PASS test_purple_stagger_sequence
PASS test_upgraded_attack_power
PASS test_duration_minimum_and_recovery
PASS test_hits_do_not_restart_the_timer
PASS test_non_melee_progress_cannot_kill
PASS test_target_selector
PASS test_coin_roll_range_and_reproducibility
PASS test_slime_stats
res://tests/unit/test_logic.gd
PASS test_attack_direction_table
PASS test_vertical_intent_priority_table
PASS test_input_frame_edges_and_axes
PASS test_health_limits
PASS test_health_max_changes
res://tests/unit/test_progression_logic.gd
PASS test_percent_rolls_are_exact
PASS test_tile_effects_last_five_seconds_and_refresh
PASS test_fruit_shield_tiers_and_policy
PASS test_protection_order_and_bypass
PASS test_yellow_jar_duration_chance_and_refresh
PASS test_effects_snapshot_round_trip
PASS test_fruit_effects
PASS test_jar_effects_and_stat_calculation
PASS test_player_stats_snapshot_round_trip
PASS test_coin_collection_and_healing_without_knights
PASS test_collected_ids_and_run_snapshot
PASS test_poison_points_per_tier
res://tests/unit/test_project_setup.gd
PASS test_rendering_and_window_settings
PASS test_save_directory_identity
PASS test_gameplay_actions_exist_with_correct_keys
PASS test_actions_are_exclusive_per_player
PASS test_alt_variants_and_modifier_independence
PASS test_profiles_reference_valid_actions
res://tests/unit/test_resource_validation.gd
PASS test_all_scripts_parse
PASS test_all_resources_and_scenes_load
PASS test_scenes_instantiate_with_valid_paths_signals_and_shapes
PASS test_game_code_is_offline
PASS test_knight_sprite_frames
```

Coverage of the requested Phase 5 checks:

| Area | Tests |
|---|---|
| Coins: 4–6 objects, one increment each, either player, shared, one roll per coin, exact 10 %, heals both living, cap, no revival, no double pickup | `test_slime_drop_coins_are_collected_into_the_shared_total`, `test_either_knight_collects_into_one_total`, `test_two_knights_on_one_coin_collect_it_once`, `test_coin_heal_roll_heals_both_living_knights`, `test_percent_rolls_are_exact`, `test_coin_collection_and_healing_without_knights` |
| Green fruit tiers, cap, collector only | `test_green_fruit_tiers_heal_only_the_collector`, `test_fruit_effects` |
| Yellow fruit tiers, charges, expiry, FALL/LAVA bypass, no stacking | `test_fruit_shield_tiers_and_policy`, `test_yellow_fruit_shield_blocks_slime_contact`, `test_shields_do_not_stop_falling_or_lava`, `test_protection_order_and_bypass` |
| Red fruit ×1.10/1.20/1.30, collector only, survives scene change | `test_fruit_effects`, `test_red_fruit_range_reaches_further_targets`, `test_progress_survives_scene_change` |
| Purple fruit 1/2/3 s, 1 point per second, no duplicate ticks, staggers, cannot kill, melee still kills | `test_poison_points_per_tier`, `test_purple_fruit_poison_staggers_but_never_kills`, `test_poison_points_and_reapplication_on_purple` |
| Green jar +1/+1, collector only, unique | `test_green_jar_and_unique_ids`, `test_jar_effects_and_stat_calculation` |
| Red jar power, stagger compatibility | `test_red_jar_power_staggers_green_in_one_real_hit` |
| Yellow jar 60 s, 50 %, failed rolls fall through, refresh, bypass | `test_yellow_jar_duration_chance_and_refresh`, `test_yellow_jar_rolls_on_contact`, `test_shields_do_not_stop_falling_or_lava` |
| Blue jar +5 %, other player unchanged, additive, stable | `test_blue_jar_speed_only_for_collector`, `test_jar_effects_and_stat_calculation` |
| Power tiles: one effect per activation, exactly 5 s, activator only, −25 % cooldown, +25 % speed, shield consumed, no repeat while standing, re-entry, both knights, pause, refresh | `test_power_tile_fires_once_per_visit`, `test_both_knights_activate_independently`, `test_tile_effects_values_and_duration`, `test_tile_effects_last_five_seconds_and_refresh`, `test_pause_stops_effect_timers` |
| Persistence and snapshots | `test_progress_survives_scene_change`, `test_snapshot_restore_updates_live_knights`, `test_player_stats_snapshot_round_trip`, `test_collected_ids_and_run_snapshot`, `test_effects_snapshot_round_trip` |
| Simultaneous collection; speed during camera split | `test_two_knights_collect_different_items_at_once`, `test_speed_upgrade_during_camera_split` |

### C. Regression

All 144 Phase 1–4 tests pass. The knight, health, combat and slime changes are additive, and
every earlier test now runs with knights bound to a fresh `RunState`.

### Defects found and fixed during Phase 5

1. **Run binding lost on re-parent.** It was undone in `_exit_tree`, which also fires when the
   camera rig re-parents a level, so knights in rig rooms silently lost their protection filter
   and health mirroring. The test output showed it as disconnect errors. The binding now lasts
   until the knight is deleted (`NOTIFICATION_PREDELETE`).
2. **Timed effects ran one tick too long.** 300 × 1/60 s does not sum to exactly 5.0 in floating
   point. Expiry now uses a 1e-6 s tolerance.
3. **Objects leaked at exit.** The static `RunState` still held objects at shutdown (Godot
   reported leaked instances). The runner now calls `RunState.clear()` before quitting.
4. **Variant inference treated as an error** in a new component (fixed). The validator also
   exposed a jar warning for standalone instancing; the warning now applies only to jars
   placed in a level.
5. **Test-only issues:** a 298-tick wait in place of 300, a measurement taken during the frame
   the level was freed, and a speed test blocked by the room's pillar.

### D. Manual tests

| Test | Status |
|---|---|
| Collectible tests 1–14 (`docs/MANUAL_COLLECTIBLE_TEST.md`) | **Pending user test** |
| Phase 2, 3 and 4 manual tests | **Still pending** |
| Visual inspection of captured frames | Done by Claude from captures, **not** interactive play |
