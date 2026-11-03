# Implementation Plan

Phase 0 output, 2026-11-03. Follows `ROADMAP.md` phase order. Adds the system
dependencies, the decisions needed before coding, and a task checklist with the status
vocabulary from ROADMAP: Not started · In progress · Implemented · Tested · Failed · Blocked.

## 1. System dependency graph

An arrow means "must exist before".

```
Project config (resolution, filter, layers, InputMap, user dir)
  ├─> Balance config resources (.tres)
  ├─> TileSet (solid / one-way / ladder / hazard data)
  │
  ├─> Player movement ──────────┬─> Camera rig (needs 2 moving targets + level bounds)
  │     (needs InputMap,        │      └─> HUD layout (needs camera modes)
  │      TileSet, PlayerConfig) │
  │                             ├─> HealthComponent ──┬─> Hazards (+ SafeSpotTracker)
  │                             │                     ├─> Enemy contact damage
  │                             │                     └─> Fruit/jar/coin healing & shields
  │                             └─> CombatComponent ──> Enemy stagger/death ──> Coin drops
  │
  ├─> Campaign state (PlayerState, run_id, coins, collected IDs)
  │     ├─> Effects (permanent vs timed) ──> Collectibles, Power tiles
  │     ├─> PersistComponent (persist_id) ──> Enemies, pickups, puzzles record state
  │     ├─> Team wipe / reset  (needs Health.died, SceneRouter)
  │     └─> SaveManager (serialises Campaign; needs every persist_id user to exist)
  │
  ├─> Puzzle components (need players, triggers layer, PersistComponent)
  ├─> SceneRouter (level load, transitions, generation token)
  ├─> Menus (need SaveManager slot metadata)
  └─> Audio (consumes signals from everything; can land any time after Phase 1)

Vertical slice (World 1, Level 1, all mechanics) ──> Level production (24 levels)
```

**Ordering adjustment to ROADMAP (no scope change):** the `Campaign` state container and
`PersistComponent` should be created as thin skeletons in Phase 1/3, not first in Phase 8.
Health, effects, enemies and puzzles then write their state to one place from day one, and
Phase 8 only adds serialisation. Retrofitting persistence into 10+ components later is
the most likely source of save bugs.

## 2. Design decisions (approved 2026-11-03)

All 14 defaults below were **approved** by the project owner and are recorded in `GDD.md` §18.
D-11 (Git) was completed with baseline commit `b5c605b`. D-12 uses the identifier `TwoKnightCoop`.

| ID | Question | Recommended default | Why |
|---|---|---|---|
| D-1 | "Direction comes from the last valid movement direction". After jumping (Up) and landing, should the next attack still go up? | Held Up/Down sets a vertical attack only **while held**. Otherwise the attack uses the last horizontal facing | Otherwise every attack after a jump swings upward, which feels broken |
| D-2 | Down-attack while standing on the ground? | Grounded + Down held = crouch, and attack becomes a low forward slash. True down-slash only in the air or on ladders | A downward swing into the floor is useless |
| D-3 | May one knight stand on the other's head? | **Yes**, as a co-op boost, but the lower player can always walk out and the upper player is pushed off under low ceilings | Classic co-op mechanic that fits the GDD's "mutual assistance" |
| D-4 | Does fall damage respect shields, yellow fruit or jar negation? | Fall respawn damage is **unblockable** | Otherwise shields make pits free |
| D-5 | Can a staggered slime damage players by contact? | **No** | Stagger is the reward window |
| D-6 | Down in mid-air: fast-fall? | No (keep controls minimal) | Avoid accidental platform drops |
| D-7 | Internal resolution | **640×360**, integer scaling, Nearest filter | Split halves stay 20 tiles wide; scales cleanly to 720p/1080p/1440p |
| D-8 | Camera zoom when players spread? | **No zoom**, split instead | Fractional zoom shimmers on pixel art. GDD warns against excessive zoom |
| D-9 | Position restored on Continue | Last **safe grounded** position (per player) of the saved level | Avoid resuming mid-air above lava |
| D-10 | Renderer | Switch to **Compatibility** | Lighter, more compatible for 2D. Current Forward+/D3D12 offers nothing this game needs |
| D-11 | Version control | `git init` + baseline commit of the current state | ROADMAP Phase 0 lists it. Gives a safe rollback point |
| D-12 | Game title / save folder name | Fixed folder name now (title can change later) | Prevents saves moving if `config/name` changes |
| D-13 | Do slimes press pressure plates? | No, only players | Prevents unintended puzzle states |
| D-14 | Optional key remapping (ghosting workaround) | Not in v1. Revisit only if the keyboard test fails | GDD fixes the controls |

## 3. Phase checklist

### Phase 0: audit (this phase)

| Task | Status | Validation |
|---|---|---|
| Inspect project.godot | Tested | Values recorded in ARCHITECTURE §1 |
| Inspect Godot version | Tested | `--version` → 4.7.2.stable.official.ed1daf0bf |
| Inventory all assets | Tested | 16 asset files + license, all in ASSET_CATALOG |
| Character / slime / tileset / audio / collectible identification | Tested | Frame rects measured; sheets inspected at 6× |
| Check existing scripts/scenes | Tested | None exist; class cache empty |
| Asset catalog | Implemented | `docs/ASSET_CATALOG.md` |
| Architecture | Implemented | `docs/ARCHITECTURE.md` |
| Project structure proposal | Implemented | ARCHITECTURE §2 |
| Task checklist | Implemented | this file |
| Initialise version control | Tested | Baseline commit `b5c605b` before Phase 1 |

### Phase 1: core project and player foundation

Status: implemented and auto-tested (42/42). Task 1.4 (manual keyboard test) is **pending the user**. See `docs/PHASE_1_SUMMARY.md`.

| # | Task | Depends on |
|---|---|---|
| 1.1 | Project settings: 640×360, `viewport` stretch, integer scale, Nearest filter, pixel snap, renderer (D-10), custom user dir (D-12), physics layer names, music loop flag, font import fix | D-7, D-10, D-12 |
| 1.2 | InputMap: 10 gameplay actions (physical keys; Alt with unspecified location) | — |
| 1.3 | **Input probe scene** (Controls Test): live per-action display for both players, plus raw key log with location | 1.2 |
| 1.4 | **Manual keyboard test on your keyboard** (§4 chord list) → TEST_REPORT | 1.3 |
| 1.5 | Test runner skeleton `tests/run_tests.gd` + static resource validator | — |
| 1.6 | TileSet resource (solid, one-way, ladder zone tiles) + sandbox test level | 1.1 |
| 1.7 | `PlayerConfig` + knight SpriteFrames (idle/run/hit/death + interim jump/fall/crouch) | 1.1 |
| 1.8 | P2 palette-swap shader | 1.7 |
| 1.9 | Player movement state machine: run, jump (variable height, coyote, buffer), crouch, drop-through, ladders, vertical passages | 1.2, 1.6, 1.7, D-1…D-6 |
| 1.10 | Player-vs-player push and anti-trap | 1.9, D-3 |
| 1.11 | `Campaign` skeleton + `PlayerState` (health 3) | — |
| 1.12 | Automated tests: simultaneous movement, context table, drop-through per player, ladder enter/exit, push/corridor/respawn-overlap | 1.5, 1.9, 1.10 |
| 1.13 | Manual two-person test in a standalone window | all |

**Gate:** both knights move, jump, crouch, climb and drop simultaneously with no
interference. Alt verified standalone. Ghosting results recorded.

### Phases 2–12

Unchanged from `ROADMAP.md`. The adjustments are:

- Phase 2: include the visibility-invariant automated test (R-9) and parallax check (R-8).
  Do a throwaway Windows export once templates are installed (R-19).
- Phase 3: `PersistComponent` skeleton lands with the first saved object.
- Phase 4–7: every stateful object gets a `persist_id` immediately.
- Phase 8: serialisation, slots, atomic writes, wipe-commit and the stale-event test (R-13).
- **Vertical slice milestone** after Phase 9: one complete World 1 level using every
  mechanic, saved, resumed, wiped and replayed, before Phase 10 level production starts.

## 4. Manual keyboard test (Phase 1.4)

Run in the Controls Test screen, in a standalone window, with two people.
For each chord, hold all keys for 2 s and record any action that fails to light.

| # | P1 holds | P2 holds |
|---|---|---|
| K-1 | D + W | → + ↑ |
| K-2 | D + W + V | → + ↑ + Alt(L) |
| K-3 | A + W + V | ← + ↑ + Alt(R) |
| K-4 | S + D + V | ↓ + → + Alt |
| K-5 | A + S + V | ↓ + ← + Alt |
| K-6 | W + S (both) | ↑ + ↓ (both) |
| K-7 | A + D + W | ← + → + ↑ |
| K-8 | tap V ×10 fast | tap Alt ×10 fast, alternating L/R |
| K-9 | play normally 60 s | play normally 60 s; one person taps Alt alone repeatedly |
| K-10 | — | Alt+Tab out and back (must still work; game must not keep Alt "stuck") |

Pass: no dropped action in K-1…K-5 and K-8…K-10. K-6/K-7 are informational (opposite
directions are not required gameplay). Any failure gets recorded with the keyboard
model and leads to a level-design constraint or decision D-14.

## 5. Before Phase 1 can start

1. Your answer on D-12 (folder name). D-11 (git) is deferred. The other decisions can use the
   defaults unless you object.
2. Install Godot 4.7.2 Windows export templates (Editor → Manage Export Templates). Not
   needed for Phase 1 itself, but needed by Phase 2's early export check.
3. Confirm the physical keyboard you will test on (laptop or external, layout), so the
   ghosting results can be recorded against it.
4. A second person available for task 1.4 / 1.13.
