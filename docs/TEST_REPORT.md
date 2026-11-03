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
| Physical keyboard tests 1–10 and Alt checks A–D (`docs/MANUAL_KEYBOARD_TEST.md`) | **Pending user test** |
| Keyboard model and layout | **Not yet supplied** |
| Movement feel, responsiveness, readability with two people | **Pending user test** |
| Running the test room from the editor (F5) by the user | **Pending user test** |
