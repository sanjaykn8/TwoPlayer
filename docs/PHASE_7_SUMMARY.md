# Phase 7 Implementation Summary: Cooperative Puzzles and Interactive Mechanisms

Date: 2026-11-03. Engine: Godot 4.7.2.stable. Starts from Phase 6 commit `db5f214`.

Status key: **Implemented** · **Auto-tested** · **Manually tested** · **Pending user test** · **Not implemented**.

## 1. Status

| Item | Implemented | Auto-tested | Manually tested |
|---|---|---|---|
| Pressure plates: HOLD, LATCH, TIMED; one- or two-knight plates; player-specific plates; identity tracking; death/removal/teleport release | Yes | Yes | **Pending user test** |
| Simultaneous two-player plates (locks with "different knights") | Yes | Yes | **Pending user test** |
| Hold mechanisms (held plate keeps a gate open; release closes it safely) | Yes | Yes | **Pending user test** |
| Attack-activated switches (TOGGLE, MOMENTARY, LATCH) using the existing melee attack: range, hitbox, wall line of sight, attack-instance and cooldown protection, direction and player filters | Yes | Yes | **Pending user test** |
| Simultaneous target puzzles (SYNC locks, 2 s default window, failure and safe reset) | Yes | Yes | **Pending user test** |
| Sequence locks (wrong order fails and resets) | Yes | Yes | — |
| Timed gates (open time, warning, countdown bar, never closes on anyone, controlled reopening, pause-aware) | Yes | Yes | **Pending user test** |
| Follow and latch gates; multi-switch and remote mechanisms (chained locks) | Yes | Yes | **Pending user test** |
| Separate-route puzzle (upper/lower routes, reunion) | Yes | Yes | **Pending user test** |
| Opposite-side mechanism (either side holds the gate for the other) | Yes | Yes | **Pending user test** |
| Moving-platform coordination (plate/switch-driven Phase 6 platforms; two knights on two platforms) | Yes | Yes | **Pending user test** |
| Enemy distraction (real Phase 4 slime guarding a switch) | Yes | Yes | **Pending user test** |
| Controlled risk (holding a plate on hot ground costs 1 HP; survivable) | Yes | Yes | **Pending user test** |
| Environmental clues (short signpost text, revealed on approach) | Yes | Yes | **Pending user test** |
| Puzzle state tracking, scopes (level / campaign), unique ids, snapshot and restore | Yes | Yes | — |
| Softlock prevention (see §6) | Yes | Yes | **Pending user test** |
| Puzzle test room (10 sections) with debug overlay | Yes | Used by tests | **Pending user test** |
| Pushable / carryable weight objects (crates) | **Not implemented** (no asset or GDD requirement beyond "pushing or blocking"; knights are the weights) | — | — |
| Level exit portals and level transitions | **Not implemented** (Phase 8 / Phase 10) | — | — |
| Disk saving, four slots, campaign death reset | **Not implemented** (Phase 8) | — | — |
| Production campaign levels | **Not implemented** (Phase 10) | — | — |

## 2. New files

| Path | Purpose |
|---|---|
| `scripts/puzzles/puzzle_registry.gd` | `PuzzleRegistry`: saved puzzle states (per level / campaign) and live id registration, snapshot / restore |
| `scripts/puzzles/puzzle_config.gd`, `resources/config/puzzle_config.tres` | `PuzzleConfig`: switch cooldown, fail display time, gate slide time and clearance, plate sensor, clue reveal |
| `scripts/physics/space_query.gd` | `SpaceQuery.rect_occupied()`: shared "is anyone here" query (platforms and gates) |
| `scenes/puzzles/puzzle_source.gd` | `PuzzleSource`: base contract (changed / pulsed / credit_changed, ids, scope, persistence) |
| `scenes/puzzles/pressure_plate.gd/.tscn`, `trigger_zone.gd/.tscn` | `PressurePlate`, `TriggerZone` |
| `scenes/puzzles/attack_switch.gd`, `attack_switch.tscn`, `puzzle_target.tscn` | `AttackSwitch` ("!" switch or round target) |
| `scenes/puzzles/puzzle_logic.gd/.tscn` | `PuzzleLogic` lock: ALL / ANY / SYNC / SEQUENCE |
| `scenes/puzzles/puzzle_gate.gd`, `puzzle_gate.tscn`, `timed_gate.tscn` | `PuzzleGate` portcullis: FOLLOW / LATCH / TIMED |
| `scenes/puzzles/platform_controller.gd/.tscn` | `PlatformController`: drives Phase 6 platforms from a puzzle |
| `scenes/puzzles/puzzle_clue.gd/.tscn` | `PuzzleClue` |
| `scenes/dev/puzzle_test_level.tscn`, `puzzle_test_room.tscn/.gd`, `puzzle_debug_hud.tscn/.gd` | Puzzle test room |
| `tools/build_phase7_content.gd` | Generator for the room |
| `tests/unit/test_puzzle_logic.gd`, `tests/gameplay/test_puzzle_mechanisms.gd`, `tests/gameplay/test_puzzle_room.gd` | 67 tests |
| `docs/MANUAL_PUZZLE_TEST.md`, `docs/PHASE_7_SUMMARY.md` | Documentation |

## 3. Modified files (small, additive)

| Path | Change |
|---|---|
| `scripts/progression/run_state.gd` | Owns `puzzles: PuzzleRegistry`; snapshot version 2 adds `"puzzles"`; version-1 snapshots still restore (no puzzle progress) |
| `scenes/platforms/moving_platform.gd` | `auto_start`, `running`, `set_running()`, `move_to()`, `snap_to()` (defaults keep Phase 6 behaviour) |
| `scenes/platforms/platform_body.gd` | `is_occupied()` now uses the shared `SpaceQuery` (same result) |

Health, damage, combat, slimes, camera and input were not changed.

## 4. How the pieces fit

- **Sources** (`PuzzleSource`): plates, trigger zones, switches, targets, locks and gates all
  expose `changed(active)`, `pulsed(player_id)`, `credit_changed`, `is_active()`,
  `active_players()` and `reset_source()`.
- **Locks** (`PuzzleLogic`) combine sources: ALL (optionally "different knights"), ANY, SYNC
  (within a window) or SEQUENCE; `latch` makes completion permanent and saved. Locks are sources
  too, so they chain (a route lock feeding an exit lock).
- **Receivers**: `PuzzleGate` and `PlatformController` follow any source by NodePath.
- **State**: persistent elements write small dictionaries to `RunState.current().puzzles` under
  the level's id (`level_id` metadata on the level root) or the campaign scope.
- No custom script per puzzle: every room section is assembled from these scenes by the
  generator.

## 5. Values

| Value | Default |
|---|---|
| Switch cooldown after an accepted hit | 0.35 s (plus one activation per attack id) |
| Sync window | 2.0 s (per lock) |
| Failed lock display before reset | 0.75 s |
| Gate slide time / clearance margin | 0.3 s / 3 px each side |
| Timed gate (room section 4) | open 3.0 s, warning 1.0 s |
| Follow gate close delays (room) | 1.0 s (section 2), 0.5 s (section 6), 1.0 s (section 9) |
| Plate sensor | 6 px above the plate; a knight must be on the floor |
| Clue reveal | dim (35 %) beyond 168 px, fully readable within 112 px |

## 6. Softlock prevention

- Gates are solid only when fully closed. They close only when the doorway (plus margin) holds
  no knight or enemy; a closing gate re-checks every frame and reopens if anyone steps in. They
  never damage or push anyone.
- Plates re-validate their occupants every physics frame: dead, removed, teleported or airborne
  knights release them, so no plate stays pressed by a stale reference.
- Every timed element (timed gates, SYNC attempts, momentary switches, timed plates) returns
  to a safe state on expiry and can be activated again; a failed SYNC/SEQUENCE attempt resets
  its inputs.
- "Different knights" locks can always be completed: striking a latched switch again re-credits
  it to the striking knight, and a second knight joining a pressed plate is re-evaluated.
- Every one-way crossing in the room has a way back: a far-side switch (sections 2, 4) or a
  far-side plate (sections 6, 7, 9).
- Design rule found by the tests: a gate bounces open if a knight reaches its doorway while
  it is closing, so a crossing meant to need a partner must take longer than the close delay
  plus the 0.3 s slide (sections 6 and 9 were widened for this).
- Temporary state (held plates, running timers) is never saved, so a reload always starts it
  in its safe initial state.

## 7. Tests

296 tests, all passing in two consecutive runs with no `ERROR`/`WARNING` lines: 229 Phase 1–6
tests plus 67 new (9 unit, 32 mechanism, 26 room). Details in `docs/TEST_REPORT.md`.

## 8. Manual tests

`docs/MANUAL_PUZZLE_TEST.md`: **pending user test**. Visual checks in this phase were done by
Claude from rendered captures, not by interactive play.
