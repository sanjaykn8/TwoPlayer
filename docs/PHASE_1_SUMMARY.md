# Phase 1 Implementation Summary: Core Project and Player Foundation

Date: 2026-11-03. Engine: Godot 4.7.2.stable.official.ed1daf0bf.
Baseline commit before Phase 1: `b5c605b` ("chore: baseline existing Godot project before Phase 1").

Status key: **Implemented** (code exists) · **Auto-tested** (automated test passes) ·
**Manually tested** (verified by a person playing) · **Pending user test**.

## 1. Status of every Phase 1 item

| Item | Implemented | Auto-tested | Manually tested |
|---|---|---|---|
| Compatibility renderer, 640×360, integer scale, Nearest filter, 1280×720 window | Yes | Yes (settings test + real rendered run, OpenGL 3.3) | Visual check of captured frames only |
| Permanent save dir `TwoKnightCoop` → `%APPDATA%\TwoKnightCoop\saves\` | Yes | Yes | — |
| Reusable knight scene, instanced twice | Yes | Yes | — |
| P1 / P2 InputMap actions (Alt left, right and unspecified) | Yes | Yes (InputMap matching + raw key events) | **Pending user test** |
| Independent and simultaneous movement | Yes | Yes | **Pending user test** |
| Run / accelerate / decelerate / air control | Yes | Yes | **Pending user test** (feel) |
| Jump, variable jump height, coyote time, jump buffer, no double jump | Yes | Yes | **Pending user test** |
| Crouch with clearance check | Yes | Yes | **Pending user test** |
| One-way drop-through (per player, solid unaffected, one platform at a time) | Yes | Yes | **Pending user test** |
| Ladder climb (up, down, hold, top exit, bottom exit, side release) | Yes | Yes | **Pending user test** |
| Designated vertical passage (free movement) | Yes | Yes | **Pending user test** |
| Knight collision, pushing, wall/corridor anti-trap, edge push | Yes | Yes | **Pending user test** |
| Standing on the other knight: carry and lift (D-3) | Yes | Yes | **Pending user test** |
| Health component (3/3, limits, max-health upgrade support) | Yes | Yes | — |
| Attack input and direction resolver (no combat) | Yes | Yes | **Pending user test** |
| Animations: idle, run, hurt (real); jump, fall, crouch, climb (placeholders) | Yes | Frame-mapping test | Visual check of captured frames only |
| Development test room + debug HUD | Yes | Loads and instantiates in tests | **Pending user test** |
| Physical keyboard / ghosting / Alt behaviour | n/a | **Cannot be automated** | **Pending user test** |

## 2. New files

| Path | Purpose |
|---|---|
| `scenes/players/knight.tscn`, `knight.gd` | Reusable knight (`Knight`, CharacterBody2D) |
| `scripts/players/knight_config.gd` | `KnightConfig` resource class (movement and base stats) |
| `scripts/players/knight_profile.gd` | `KnightProfile`: player id, action names, palette |
| `scripts/players/knight_input_frame.gd` | `KnightInputFrame`: one tick of one player's input |
| `scripts/players/vertical_intent.gd` | `VerticalIntent`: context-sensitive Up/Down resolver |
| `scripts/combat/attack_direction.gd` | `AttackDirection`: D-1 attack direction resolver (for Phase 3) |
| `scripts/systems/save_paths.gd` | `SavePaths`: `user://saves/` location and slot paths (no SaveManager yet) |
| `components/health/health_component.gd` | `HealthComponent` |
| `components/climb/climbable.gd` | `Climbable` (ladder / passage) |
| `scenes/objects/ladder.tscn`, `climb_passage.tscn` | Reusable climbables |
| `scenes/dev/phase_1_test_room.tscn`, `.gd` | Development test room (current main scene) |
| `scenes/dev/input_debug_hud.tscn`, `.gd` | Input debug overlay |
| `resources/config/knight_config.tres` | Shared movement values |
| `resources/players/p1_profile.tres`, `p2_profile.tres` | Player identities |
| `resources/players/knight_frames.tres` | Knight SpriteFrames (generated) |
| `resources/shaders/knight_palette.gdshader` | Tunic/plume palette swap |
| `resources/tilesets/dev_world_tileset.tres` | Tileset: solid terrain + one-way platforms (generated) |
| `assets/created/ladder.png` | 16×16 ladder art (generated, fence wood palette) |
| `tools/build_phase1_content.gd` | Generator for frames, tileset, ladder PNG, test room |
| `tests/run_tests.gd`, `tests/framework/game_test_case.gd` | Headless test runner |
| `tests/unit/*.gd`, `tests/gameplay/*.gd` | 42 automated tests |
| `*.gd.uid`, `*.gdshader.uid` | Godot 4.7 UID sidecars (keep in Git) |
| `docs/MANUAL_KEYBOARD_TEST.md`, `docs/PHASE_1_SUMMARY.md` | Documentation |

## 3. Modified files

| Path | Change |
|---|---|
| `project.godot` | Renderer, resolution, stretch, filter, pixel snap, physics interpolation, custom user dir, main scene, GUI font, physics layer names, 10 input actions |
| `assets/fonts/PixelOperator8*.ttf.import` | Antialiasing off, hinting off, subpixel positioning off, system fallback off |
| `assets/music/time_for_adventure.mp3.import` | `loop=true` |
| `.gitignore` | Exports, logs, local saves, secrets (baseline commit) |
| `GDD.md` | Section 18: approved decisions D-1…D-14 |
| `ROADMAP.md`, `CLAUDE.md`, `docs/*.md` | Status and documentation updates |

## 4. Movement parameters (`resources/config/knight_config.tres`)

| Group | Parameter | Value |
|---|---|---|
| Run | run_speed | 110 px/s (~6.9 tiles/s) |
| | ground_acceleration / deceleration | 900 / 1200 px/s² |
| | air_acceleration / deceleration | 700 / 350 px/s² |
| | crouch_speed | 40 px/s |
| Jump | jump_velocity | 320 px/s → peak 56.9 px (~3.5 tiles) |
| | rise_gravity / fall_gravity | 900 / 1250 px/s² |
| | max_fall_speed | 380 px/s |
| | jump_cut_multiplier | 0.45 |
| | coyote_time / jump_buffer_time | 0.08 s / 0.10 s |
| Climb | climb_speed | 70 px/s |
| | ladder_release_speed / regrab_delay | 60 px/s / 0.25 s |
| One-way | drop_clear_distance / drop_max_time | 8 px / 0.35 s |
| Body | standing_size / crouch_size | 10×18 / 10×11 px |
| Interaction | push_speed | 45 px/s |
| Health | base_max_health | 3 |

Physics runs at 60 ticks/s with physics interpolation enabled, so movement is identical at any
display frame rate.

## 5. Known limitations

See `docs/KNOWN_ISSUES.md`. The main ones:
- jump, fall, crouch and climb use placeholder frames;
- physical keyboard behaviour is untested;
- the test room uses a fixed view (no camera system until Phase 2);
- export templates are not installed.
