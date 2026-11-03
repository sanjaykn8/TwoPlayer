# Phase 2 Implementation Summary: Dynamic Shared and Split-Screen Camera

Date: 2026-11-03. Engine: Godot 4.7.2.stable. Starts from Phase 1 commit `4d5c6b0`.

Status key: **Implemented** · **Auto-tested** · **Manually tested** · **Pending user test**.

## 1. Status

| Item | Implemented | Auto-tested | Manually tested |
|---|---|---|---|
| Shared camera (midpoint, deadzone, smoothing, bounds) | Yes | Yes | **Pending user test** |
| Split activation from viewport-relative thresholds + visibility guard | Yes | Yes | **Pending user test** |
| Merge with hysteresis + hold time + seamless alignment | Yes | Yes | **Pending user test** |
| Orientation selection + hysteresis + hold time | Yes | Yes | **Pending user test** |
| Fixed player-to-view assignment (P1 = left/top, P2 = right/bottom) | Yes | Yes | **Pending user test** |
| Independent split cameras | Yes | Yes | **Pending user test** |
| Seamless split (first split frame identical to last shared frame) | Yes | Yes (math) + rendered pixel comparison: 0 changed pixels | **Pending user test** |
| Level bounds (CameraBounds, explicit rect or TileMapLayer fit) | Yes | Yes | **Pending user test** |
| One world, one simulation (shared World2D) | Yes | Yes | — |
| Pixel-art sharpness (nearest, pixel snap, integer camera positions, no zoom) | Yes | Settings tested; frames inspected | **Pending user test** |
| Window resizing | Yes (engine stretch + rig relayout) | Layout at several rig sizes; rendered run at 1920×1080, 1000×620, 800×450 | **Pending user test** |
| Camera does not affect physics | Yes | Yes (identical trajectory with and without the camera) | — |
| No resource accumulation | Yes | Yes (40 switch cycles) | **Pending user test** (long session) |
| Camera test room | Yes | Loads, runs, all tests use it | **Pending user test** |
| Phase 1 regression | — | 42/42 Phase 1 tests + Phase 1 mechanics inside the rig | Phase 1 keyboard: **user-reported pass** |

## 2. New files

| Path | Purpose |
|---|---|
| `scenes/camera/split_screen_rig.tscn`, `.gd` | `SplitScreenRig`: the camera system |
| `scripts/cameras/camera_math.gd` | `CameraMath`: pure split, merge, orientation, layout and clamp rules |
| `scripts/cameras/camera_config.gd` | `CameraConfig` resource class |
| `resources/config/camera_config.tres` | Camera values (section 4) |
| `components/camera/camera_bounds.gd` | `CameraBounds`: per-level camera limits |
| `scenes/dev/camera_test_level.tscn` | 1920×960 test level (generated) |
| `scenes/dev/camera_test_room.tscn`, `.gd` | Level + rig + overlay, dev keys F1–F3/F6/F7 |
| `scenes/dev/camera_debug_hud.tscn`, `.gd` | Camera overlay |
| `tools/level_builder.gd` | Shared tile/scene helpers for the generators |
| `tools/build_phase2_content.gd` | Generates the camera level and room |
| `tests/unit/test_camera_math.gd` | 11 unit tests |
| `tests/gameplay/test_camera_rig.gd` | 21 gameplay tests |
| `docs/MANUAL_CAMERA_TEST.md`, `docs/PHASE_2_SUMMARY.md` | Documentation |

## 3. Modified files

| Path | Change |
|---|---|
| `tools/build_phase1_content.gd` | Uses `tools/level_builder.gd`. Verified to generate an identical Phase 1 room (only generated IDs differ); the committed room file was left unchanged |
| `GDD.md`, `ROADMAP.md`, `CLAUDE.md`, `docs/ARCHITECTURE.md`, `docs/TEST_REPORT.md`, `docs/KNOWN_ISSUES.md`, `docs/MANUAL_KEYBOARD_TEST.md` | Documentation |

No Phase 1 movement, input, knight or test file was changed.

## 4. Camera parameters (`resources/config/camera_config.tres`)

| Parameter | Value | Meaning |
|---|---|---|
| zoom | 1 | Integer zoom only (D-8). Views are 640×360, 320×360 or 640×180 world px |
| safe_margin | (48, 40) | Safe region = 544 × 280 px of the shared view |
| follow_offset | (0, −24) | Frame the body, not the feet |
| shared_deadzone | (12, 8) | Shared camera ignores smaller midpoint movement |
| split_enter_ratio | 0.85 | Split at > 462 px horizontal or > 238 px vertical separation |
| split_exit_ratio | 0.55 | Merge below 299 px horizontal **and** 154 px vertical |
| merge_hold_time | 0.25 s | Must stay within the merge distance this long |
| transition_duration | 0.3 s | Split cameras line up with the shared view, then merge |
| visibility_margin | (6, 4) | Immediate split if a knight's body comes this close to the shared view edge |
| target_body_size | (10, 18) | Body box used by the visibility check |
| orientation_hysteresis | 1.35 | Other axis must dominate by 35 %… |
| orientation_hold_time | 0.35 s | …for this long before the orientation changes |
| shared_follow_speed / split_follow_speed | 6 / 8 per s | Exponential follow (frame-rate independent) |
| snap_distance | 192 px | Larger target jumps (teleports) cut instead of sliding |
| divider_width / divider_color | 2 px / near-black | Split divider |

## 5. Known limitations

See `docs/KNOWN_ISSUES.md` (KI-17 to KI-23).
