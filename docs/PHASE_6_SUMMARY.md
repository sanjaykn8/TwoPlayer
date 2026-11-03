# Phase 6 Implementation Summary: Hazards and Advanced Platforming

Date: 2026-11-03. Engine: Godot 4.7.2.stable. Starts from Phase 5 commit `3e98623`.

Status key: **Implemented** · **Auto-tested** · **Manually tested** · **Pending user test** · **Not implemented**.

## 1. Status

| Item | Implemented | Auto-tested | Manually tested |
|---|---|---|---|
| Spikes: 1 HP (SPIKE), one event per entry, re-entry hurts again, shields / jar / invulnerability can block | Yes | Yes | **Pending user test** |
| Hot ground: solid floor, 1 HP (HOT_GROUND), one event per entry, configurable size, glow and embers | Yes | Yes | **Pending user test** |
| Lava: instant death through invulnerability and every shield, death emitted once, other knight unaffected | Yes | Yes | **Pending user test** |
| Falling: exactly 1 FALL damage (unblockable), respawn at the knight's last safe position (or level spawn), velocity and state reset, 1 s respawn protection, progression kept, at 0 HP → DEAD, processed once, other knight untouched | Yes | Yes | **Pending user test** |
| Fall detection: FallBoundary hazard **and** a fall line (CameraBounds bottom + 48 px) as a backstop | Yes | Yes | — |
| Safe-position tracking per knight (grounded, hazard-free, not on a knight, not on unsafe platforms, alive, inside the level) | Yes | Yes | **Pending user test** |
| Moving platforms (horizontal, vertical, diagonal; speed, endpoint pause, ping-pong or one-shot, start delay, one-way or solid) carrying both knights and slimes | Yes | Yes | **Pending user test** |
| Timed platforms (INACTIVE / ACTIVE / WARNING / DISABLED / REACTIVATING; `activate()` trigger, optional auto-reactivation) | Yes | Yes | **Pending user test** |
| Disappearing platforms (same state machine on a schedule, `start_offset` staggering) | Yes | Yes | **Pending user test** |
| Collapsing platforms (landing only, shake, collapse, recovery, optional permanent, never a respawn point) | Yes | Yes | **Pending user test** |
| Safe reappearance (timed/disappearing/collapsing platforms wait until nobody overlaps them) | Yes | Yes | — |
| Pause-aware timers (all platform and hazard logic runs in physics frames) | Yes | Yes | **Pending user test** |
| Hazard test room with debug overlay | Yes | Used by tests | **Pending user test** |
| Pressure plates / switches driving timed platforms | **Not implemented** (Phase 7; `TimedPlatform.activate()` is the hook) | — | — |
| Campaign-wide death reset (team wipe → new run from level 1) | **Not implemented** (Phase 8) | — | — |
| Saving hazard/platform state, safe positions | **Not implemented** (Phase 8) | — | — |
| Hazard-specific sounds beyond `hurt.wav` / `explosion.wav`; volume settings | **Not implemented** (Phase 9) | — | — |
| Production levels using these hazards | **Not implemented** (Phase 10) | — | — |

## 2. New files

| Path | Purpose |
|---|---|
| `scripts/hazards/hazard_config.gd`, `resources/config/hazard_config.tres` | `HazardConfig`: spike / hot-ground / fall damage, respawn protection, safe-ground frames, fall margin |
| `scenes/hazards/hazard.gd` | `Hazard` (Area2D, `@tool`): SPIKES, HOT_GROUND, LAVA, FALL; size-driven visual and damage area |
| `scenes/hazards/spikes.tscn`, `hot_ground.tscn`, `lava.tscn`, `fall_boundary.tscn` | Ready-made hazards |
| `components/safety/safe_spot_tracker.gd` | `SafeSpotTracker` ("SafeSpot" child of the knight): safe positions and the single fall consequence |
| `scenes/platforms/platform_body.gd` | `PlatformBody` (AnimatableBody2D, `@tool`): shared drawing, one-way/solid collision, `is_occupied()`, "unsafe_ground" group |
| `scenes/platforms/moving_platform.gd` / `.tscn` | `MovingPlatform` |
| `scenes/platforms/timed_platform.gd`, `timed_platform.tscn`, `disappearing_platform.tscn` | `TimedPlatform` (TRIGGERED / SCHEDULE modes) |
| `scenes/platforms/collapsing_platform.gd` / `.tscn` | `CollapsingPlatform` |
| `assets/created/spikes.png` | Generated 16×16 spike strip (three steel spikes, palette from the bundle). Placeholder art |
| `scenes/dev/hazard_test_level.tscn`, `hazard_test_room.tscn/.gd`, `hazard_debug_hud.tscn/.gd` | Hazard test room |
| `tools/build_phase6_content.gd` | Generator for the spike art and the room |
| `tests/unit/test_hazard_logic.gd`, `tests/gameplay/test_hazards.gd`, `tests/gameplay/test_platforms.gd` | 51 tests |
| `docs/MANUAL_HAZARD_TEST.md`, `docs/PHASE_6_SUMMARY.md` | Documentation |

## 3. Modified files (small, additive)

| Path | Change |
|---|---|
| `scenes/players/knight.tscn`, `knight.gd` | `SafeSpot` child (`SafeSpotTracker`), set up after the progress binding |
| `scripts/audio/sfx.gd` | `HURT` (`hurt.wav`) and `EXPLOSION` (`explosion.wav`) |
| `tests/run_tests.gd` | Waits 0.5 s of wall-clock time before quitting so the audio thread releases sounds from the last test (see §6.9) |

No change to `HealthComponent`, `DamageEvent` or `PlayerEffects` was needed: the Phase 3/5
central resolver already implements the hazard table (see §5).

## 4. Values (`resources/config/hazard_config.tres` and scene exports)

| Value | Default |
|---|---|
| Spike / hot-ground / fall damage | 1 / 1 / 1 |
| Respawn protection after a fall | 1.0 s |
| Safe-ground frames before a position is committed | 6 |
| Fall line below CameraBounds | 48 px |
| Spike damaging area | bottom 8 px of the 16 px strip (the drawn spikes) |
| Hot-ground damaging area | 3 px layer on top of its solid body |
| Lava damaging area | below the 3 px wavy surface |
| Moving platform | speed 40 px/s, pause 0.5 s, ping-pong |
| Timed platform scene | TRIGGERED, active 4.0 s, warning 1.2 s, disabled 3.0 s, reactivate ≥ 0.4 s, auto-reactivate on |
| Disappearing platform scene | SCHEDULE, active 2.0 s, warning 1.0 s, invisible 2.0 s, reactivate ≥ 0.4 s |
| Collapsing platform | delay 0.6 s, recovery 3.0 s, reappear ≥ 0.4 s, shake 1 px |

## 5. Damage rules (unchanged resolver, now used by hazards)

| Category | Invulnerability | Shields / yellow jar | Notes |
|---|---|---|---|
| SPIKE | Blocks | Can block (one layer per event) | One event per entry |
| HOT_GROUND | Blocks | Can block | One event per entry |
| FALL | Ignored | Ignored | Sent only by `SafeSpotTracker.resolve_fall()` |
| LAVA | Ignored | Ignored | Lethal: removes all health; checked before everything else |

## 6. Design decisions made in this phase

1. **Hazards detect hurtboxes (layer 5), not bodies.** Climbing knights clear their body
   layers, but their hurtbox stays, so hazards still find them.
2. **One fall path.** FallBoundary areas and the fall line both call `resolve_fall()`, which is
   guarded so a knight is processed once per fall.
3. **Delayed safe-position commit.** A position is committed only after the knight stays safe
   for the following 6 frames. Hazard overlap signals arrive a frame late, so without this a
   knight walking onto hot ground could have that spot recorded as safe (found by a test).
4. **Platforms and hot ground are "unsafe_ground".** A fall never respawns a knight on
   something that can move, vanish or hurt.
5. **Safe reappearance.** Timed, disappearing and collapsing platforms only restore collision
   when a shape query finds no knight body, knight hurtbox or enemy in their space.
6. **Collapsing platforms trigger only on a landing** (knight on the floor, feet at the top
   surface, not rising), detected by a thin sensor above the platform.
7. **No team wipe yet.** Lava and fatal falls make that knight DEAD; the other keeps playing.
   The campaign reset is Phase 8. The room's F3 revives for testing only.
8. **Older dev rooms now apply fall damage.** Their CameraBounds give every knight a fall line,
   so the tracker respawns fallen knights (with 1 FALL damage) before the rooms' old no-damage
   KILL_Y teleport. All Phase 1–5 tests pass with this.
9. **Camera after a respawn.** The tracker does not drive the camera. The rig already cuts
   when a target jumps more than `snap_distance` (192 px) and splits when a knight leaves the
   shared view, so a respawned knight is shown without disturbing the other player's view
   (tested).
10. **Test runner exit.** Headless `--fixed-fps` runs are faster than real time while the audio
   thread is not, so a sound started by the last test was reported as leaked at exit
   (`hurt.wav` playback). The runner now waits 0.5 s of real time before quitting. This was a
   test-harness artefact, reproduced and confirmed with a standalone script.

## 7. Tests

229 tests in total, all passing in two consecutive runs with no `ERROR`/`WARNING` lines:
178 Phase 1–5 tests plus 51 new (9 unit, 22 hazard gameplay, 20 platform gameplay). Details
in `docs/TEST_REPORT.md` (Phase 6).

## 8. Manual tests

`docs/MANUAL_HAZARD_TEST.md`: **pending user test**. The visual check in this phase was done
by Claude from rendered captures, not by interactive play.
