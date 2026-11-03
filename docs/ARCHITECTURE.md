# Architecture

Status: **proposed** (Phase 0). Nothing below is implemented yet. Sections will be
updated to "implemented / tested" as milestones land.

## 1. Existing project (as audited 2026-11-03)

| Item | Current value | Assessment |
|---|---|---|
| Engine | Godot 4.7.2.stable (`C:/Users/Reaper/Downloads/Godot/`), project features `4.7`, `Forward Plus` | OK |
| Project name | `config/name="2p"` | Placeholder. Also determines the save folder (see §8) |
| Main scene | none | `--quit-after` reports "no main scene defined" |
| Renderer | Forward Plus, `rendering_device/driver.windows="d3d12"` | Heavier than a 2D pixel game needs (see risks R-12) |
| Window | default 1152×648 viewport, `stretch/mode="canvas_items"`, `aspect="expand"` | Not pixel-perfect; `expand` changes the visible area per monitor |
| Texture filter | default (linear) | Blurry pixel art; must be Nearest |
| Physics | `3d/physics_engine="Jolt Physics"`; 2D default | 3D setting irrelevant; Godot 2D physics is used |
| Input map | only built-in `ui_*` actions | No gameplay actions exist |
| Autoloads | none | — |
| Scenes / scripts / resources | **none** (`global_script_class_cache.cfg` lists no classes) | Nothing to preserve or migrate |
| Assets | 7 PNG, 6 WAV, 1 MP3, 2 TTF under `res://assets/` | See `docs/ASSET_CATALOG.md` |
| Version control | not a git repository; `.gitignore` (ignores `.godot/`, `/android/`), `.gitattributes` (LF) present | Should be initialised before Phase 1 |
| Export | `export_presets.cfg` absent; `%APPDATA%/Godot/export_templates/` is **empty** | Templates for 4.7.2 must be installed before any export test |
| User data | `%APPDATA%/Godot/app_userdata/2p/` exists with only `logs/`, `vulkan/`, `objectdb_snapshots/` | No saves yet |

Conclusion: a clean project shell plus an unmodified asset bundle. There are no existing
systems that could conflict with the proposed design. The existing `assets/` layout
(`sprites/`, `sounds/`, `music/`, `fonts/`) is kept as-is. Moving files would break
nothing today, but there is no benefit to renaming third-party assets. New art we create
goes into new sub-folders.

## 2. Directory layout

```
res://
  project.godot  CLAUDE.md  GDD.md  ROADMAP.md
  assets/
    sprites/ sounds/ music/ fonts/          # existing bundle, untouched
    created/                                # art/audio we author (knife, ladder, spikes, UI…)
  autoload/                                 # the only global singletons (see §4)
  components/                               # reusable node components (.gd + .tscn)
    health/ combat/ hurtbox/ persist/ stats/
  scenes/
    main/            # boot + main menu
    players/         # player.tscn
    enemies/         # slime.tscn, bosses
    objects/         # collectibles, power tiles, signs
    hazards/         # spikes, hot ground, lava, kill floor
    puzzles/         # plates, switches, doors, gates, platforms, exit portal
    camera/          # split-screen rig
    ui/              # HUD, pause, menus, slot picker, game over, victory
    levels/          # level_base.tscn + w1_l1.tscn … w6_l4.tscn
  scripts/                                  # non-node logic (state machines, pure helpers)
  resources/
    config/          # balance .tres files (PlayerConfig, CameraConfig, …)
    enemies/         # green_slime.tres, purple_slime.tres
    fruits/ jars/ powerups/
    tilesets/        # world.tres, platforms
    shaders/         # knight palette swap, flash, stagger pulse, hot ground
  data/
    campaign.tres    # ordered list of 6 worlds × 4 levels (scene paths)
  tests/
    run_tests.gd     # headless runner (SceneTree script, exit code = failures)
    unit/ integration/ gameplay/
  docs/
```

Scenes and their script live side by side (`scenes/players/player.tscn` +
`player.gd`), which keeps each unit self-contained. `scripts/` is only for logic that
is not attached to a scene.

## 3. Configuration (balance data)

All balance values live in typed `Resource` classes saved as `.tres` and exported on
the nodes that use them. No magic numbers in gameplay scripts.

| Resource class | Holds |
|---|---|
| `PlayerConfig` | run speed, accel, jump velocity, jump cut, gravity, coyote time, jump buffer, climb speed, crouch height, push speed, base health 3, base attack 1, invulnerability time, fall-respawn damage |
| `CombatConfig` | attack cooldown, active-frame window, hitbox size per direction, base range |
| `EnemyConfig` | sprite sheet, stagger threshold (green 2 / purple 4), stagger duration (≥10 s), patrol speed, chase multiplier 2.0, detection radius, lose-target delay, contact damage, coin drop min 4 / max 6 |
| `FruitDef` | colour, tier, effect type, magnitude, duration, hit charges |
| `JarDef` | colour, effect, permanent/timed, magnitude, duration |
| `PowerTileConfig` | effect pool (weighted), duration 5 s, re-trigger rule |
| `CameraConfig` | split enter distance, merge distance, orientation hysteresis angle, smoothing, transition time |
| `CoinConfig` | heal chance 0.10, heal amount 1 |
| `SaveConfig` | schema version, autosave rules |

Tests load the same `.tres` files, so a balance change cannot silently desync from
what tests verify.

## 4. Global systems (autoloads)

Kept to four. Each owns state that must outlive scene changes.

| Autoload | Responsibility | Does NOT do |
|---|---|---|
| `Campaign` | The current run: slot index, `run_id`, world/level, both `PlayerState`s (health, max, permanent stats, active timed effects), coins, collected IDs, per-level persistent object states. Emits `team_wiped`, `level_completed`, `coins_changed`. | Touch nodes in the level; do file I/O |
| `SaveManager` | Four slots in `user://saves/`, versioned JSON, validation, atomic replace, slot metadata for menus. Global settings file `user://settings.cfg`. | Decide *when* to save (Campaign/levels request it) |
| `SceneRouter` | Loads levels/menus, fades, guarantees the old scene is freed before the new one starts. Bumps a `scene_generation` token. | Hold gameplay state |
| `Audio` | SFX pool with per-sound voice limit and pitch variance, music player, `Music`/`SFX` buses. | Know about gameplay rules (it reacts to calls/signals) |

Explicitly **not** singletons: camera, HUD, players, enemies, puzzles. These are
instanced by the level/gameplay scene and wired with signals.

## 5. Gameplay scene composition

```
Gameplay (gameplay.tscn)          # persistent across levels of a run
├─ World (Node2D)                 # level scene instanced here
│   └─ <Level> (level_base.gd)
│        ├─ Terrain (TileMapLayer, solid)     ├─ OneWay (TileMapLayer)
│        ├─ Ladders (Area2D zones)            ├─ Hazards / Puzzles / Collectibles / Enemies
│        ├─ SpawnP1, SpawnP2 (Marker2D)       └─ Bounds (camera limits, kill-Y)
├─ Players: Player1, Player2 (player.tscn ×2, differing only in PlayerInputMap + palette)
├─ CameraRig (split-screen, §7)
└─ HUD (CanvasLayer), PauseMenu (CanvasLayer, process_mode = ALWAYS)
```

Players live outside the level node, so level swaps never destroy them. Their state is
re-applied from `Campaign` on spawn.

### Player (`player.tscn`)

```
Player (CharacterBody2D, player.gd: movement state machine)
├─ Sprite (AnimatedSprite2D, palette shader material)
├─ Body (CollisionShape2D; shrinks when crouching)
├─ Hurtbox (Area2D)                 ← HealthComponent listens
├─ HealthComponent                  (current/max, invulnerability, damage pipeline)
├─ CombatComponent                  (cooldown, direction, 4 hitboxes, hit registry, LOS ray)
│   └─ Weapon (Sprite2D knife + slash, AnimationPlayer)
├─ EffectsComponent                 (timed effects with remaining time, permanent mods)
├─ SafeSpotTracker                  (last safe grounded position for fall respawn)
└─ LadderProbe / OneWayProbe (Area2D / ShapeCast2D)
```

`PlayerInputMap` is a small resource naming the five actions (`p1_left` …). Both
players run the same script. Only the resource and the palette differ, which satisfies
"identical movement systems".

**Movement states:** `Ground`, `Air`, `Crouch`, `Climb`, `DropThrough`, `Hurt`,
`Dead`, `Disabled` (during transitions). The vertical-input context resolution
happens in exactly one function:

| Context (checked in order) | Up | Down |
|---|---|---|
| Climbing | climb up | climb down |
| Overlapping ladder (not climbing) | grab ladder | grab ladder if ladder extends below, else normal rule |
| Designated vertical passage zone | move up (zone-defined) | move down |
| Standing on one-way platform | jump | drop through |
| Standing on solid ground | jump | crouch |
| Airborne | jump-buffer | fast-fall *(optional, decision D-6)* |

**Drop-through** is per-player. The player temporarily removes the one-way physics
layer from its own `collision_mask` until it is clear of the platform. The other player
standing on the same platform is unaffected.

**Player-vs-player contact:** players do not physically block each other via
`CharacterBody2D` collision, which causes stalemates and trapping. They sit on a
`players` layer that is excluded from each other's mask. A small `Area2D` push sensor
applies a capped, symmetric horizontal separation velocity, processed in fixed
order (P1 then P2) in `_physics_process`. Pushing a player into a wall stops; it never
squeezes. Overlap after a respawn resolves the same way. Head-standing is decision D-3.

### Health and damage pipeline (`HealthComponent`)

A `DamageEvent {amount, source, kind: CONTACT|HAZARD|FALL|LETHAL}` passes through
ordered stages. Each stage can consume it:

1. `LETHAL` (lava) → skip all protection → die.
2. Invulnerability window active → ignore (except `LETHAL`; `FALL` per D-4).
3. Power-tile one-hit shield → consume shield.
4. Yellow fruit hit charges → consume one charge.
5. Yellow jar → 50 % roll (campaign RNG) → negate.
6. Apply damage, clamp to ≥ 0, start invulnerability, emit `damaged`.
7. If health == 0 → emit `died` once (guarded flag).

Healing clamps to max. Max-health increase also fills the added point.

### Combat (`CombatComponent`)

- Direction = per decision D-1 (default proposal: a held Up/Down overrides; otherwise
  the last horizontal facing).
- Four `Area2D` hitboxes (right/left/up/down). Only the active one is enabled, only
  during the active frames driven by the `AnimationPlayer` track.
- `hit_this_swing: Dictionary[int, bool]` cleared at swing start. Prevents multi-hits.
- Wall awareness: before applying a hit, a `PhysicsRayQueryParameters2D` from the
  player's chest to the target hurtbox centre on the `world` mask. If blocked, the hit
  is discarded. The hitbox itself also stays short.
- Range multiplier from the red fruit scales the hitbox shape (copy of the shape, not
  the shared resource).
- Emits `hit_landed(target, power, poison_seconds)`. The enemy decides the outcome.

### Enemy (`slime.tscn` + `EnemyConfig`)

One scene and one script. Colour and thresholds come from `green_slime.tres` /
`purple_slime.tres`.

States: `Patrol` → `Detect` (short tell) → `Chase` (2× speed) → `Stagger`
(≥10 s, vulnerable, no contact damage per D-5) → `Dead`. A `ReturnToPatrol` timer
applies after the target has been undetectable for `lose_target_delay`.

- **Detection:** `Area2D` radius + line-of-sight ray. **Target selection:** among visible
  players, keep the current target unless the other is closer by more than a margin
  (hysteresis), which avoids flip-flopping between players.
- **Stagger:** `stagger_points += power`. Reaching the threshold enters Stagger (no
  kill on the same hit). A melee hit while staggered kills. Poison ticks add stagger
  points but never kill. Recovery resets points to 0.
- **Ledge safety:** floor ray ahead. Never walk off platforms while patrolling.
- **Death:** `died(persist_id)` → coin spawner (4–6 via campaign RNG) → `Campaign`
  marks the ID defeated.

### Collectibles

`Pickup` (Area2D) base with a `collected` guard flag set *before* any effect is
applied, then `monitoring = false` and `queue_free()`. This prevents duplicate processing
when both players overlap in the same frame. Subclasses/defs: `Coin`, `Fruit(FruitDef)`,
`Jar(JarDef)`. `PowerTile` is not a pickup: it is a re-usable trigger with a
per-player "must leave before re-trigger" set.

Effects are applied through `EffectsComponent.apply(def)`, which routes to:

- **permanent** → `PlayerState.permanent` (max_health, attack, speed_mult, range_mult, poison_seconds)
- **timed** → `PlayerState.timed[]` entries `{id, remaining, charges}`, ticked in `_physics_process`
  (paused with the tree). Remaining time is what gets saved, so timers stop while the game is closed.

### Hazards

`Hazard` Area2D with `DamageEvent` kind. Spikes and hot ground use `CONTACT`-like
damage gated by invulnerability. Lava uses `LETHAL`. The kill floor uses `FALL`: respawn
at `SafeSpotTracker.last_safe` (updated only when grounded on solid, non-hazard,
non-moving ground for N frames), then 1 damage.

### Puzzles

Components emit/consume signals with explicit wiring in the level scene (exported
`NodePath`s / `Array[Node]`), not a global bus:

- Sources: `PressurePlate` (occupancy count, so either player and enemies count per config),
  `Switch` (toggle/hold), `Target` (hit by attack).
- Logic: `AndGate`, `TimedWindow` (all inputs within N s), `Latch`, `Sequence`.
- Sinks: `Door`, `Gate`, `MovingPlatform`, `ExitPortal`.

Recoverability rule: every latch must either be resettable in-level or proven not to
block progression. Each level script provides `validate_puzzles()`, used by an automated
test that runs the documented solution with two scripted players.

## 6. Persistence identity

Every object whose state is saved (enemies, pickups, plates, switches, doors, gates,
latched mechanisms) has a `PersistComponent` child with an exported `persist_id: String`.
IDs are unique per level. A validation test loads each level and fails on duplicates or
blanks. Node paths are **not** used as IDs: they change whenever a level is edited.

Per-level state in `Campaign`: `levels[level_key][persist_id] = {…}`. On level load, each
`PersistComponent` reads its entry and restores, or frees itself if it was consumed or
defeated.

## 7. Camera and split-screen

```
CameraRig (Control, full rect, inside a CanvasLayer below the HUD)
├─ ViewA (SubViewportContainer, stretch) → SubViewport A (world_2d = shared) → Camera2D A
└─ ViewB (SubViewportContainer, stretch) → SubViewport B (world_2d = shared) → Camera2D B
```

Both SubViewports share the gameplay `World2D`. The world is rendered once per active
view. That is cheap for 2D.

- **Shared mode:** ViewA fills the screen and follows the players' midpoint. ViewB is hidden
  and its viewport set to `UPDATE_DISABLED`.
- **Split mode:** both visible. Orientation comes from the angle of the P1→P2 vector:
  mostly horizontal separation → left|right; mostly vertical → top/bottom. The angle
  has its own hysteresis band so the orientation cannot flip on diagonals.
- **Thresholds:** split when separation exceeds `enter` on either axis (axis-specific,
  because the screen is 16:9). Merge only when below `exit` (< enter) on both axes for
  `merge_hold` seconds. `enter` must be smaller than the distance at which either player
  would leave the shared view (margin ≥ 1 player height). This guarantees that
  neither player can leave the screen in shared mode.
- **Transitions:** on split, both cameras start at the shared camera position and
  ease toward their player. On merge, they ease to the midpoint before ViewB hides.
  No zoom in v1 (non-integer zoom shimmers on pixel art). This is decision D-8.
- **Limits:** each camera clamps to the level `Bounds`. Teleports (fall respawn, level
  start) snap the camera with `reset_smoothing()`.
- **Pixel-perfect:** base resolution 640×360 (decision D-7). Halves become 320×360 or
  640×180, i.e. 20 tiles wide or 11 tiles tall.
- **Parallax:** `Parallax2D` follows the viewport it is rendered in. That must be verified
  for the second SubViewport sharing a World2D (risk R-8). The fallback is a per-view
  background layer.

HUD is a separate `CanvasLayer` on top of the rig: P1 status top-left, P2 top-right,
coins and world/level top-centre, in every mode. Timed effects are listed under each
player's health.

## 8. Save system

- Files: `user://saves/slot_{1..4}.json`, plus `.tmp` during writes.
  `user://settings.cfg` for audio/video settings (not per-slot).
- **Pin the user-data folder** with `application/config/use_custom_user_dir=true` and a
  fixed `custom_user_dir_name`. Otherwise renaming the project ("2p") moves every save.
- Format: JSON `{ "version": N, "run_id": "...", "saved_at": "...", "meta": {...},
  "campaign": {...} }`. Human-readable, so failures are diagnosable.
- Write: serialise → write `slot_N.tmp` → close → validate by re-reading → replace
  `slot_N.json` (rename-with-replace, verified on Windows in Phase 8, risk R-15).
- Load: parse → version check (migrate older, reject newer) → schema/type/range validation
  → only then apply. Invalid → slot shown as "Damaged" with a Delete option. Never crash,
  never apply partial data.
- **Team wipe:** `Campaign.team_wipe()` first writes a *fresh* campaign (new `run_id`,
  World 1-1, base stats) to the slot **synchronously**, then plays the game-over
  transition. Quitting during or after the transition cannot resurrect the old run.
  No backup copy of an old run is kept.
- **Save-on-exit:** `auto_accept_quit = false`; on `NOTIFICATION_WM_CLOSE_REQUEST`
  (also Alt+F4) save unless in `GAME_OVER` (already committed) or a transition, then quit.
- Player position on resume: the last *safe* position, not the mid-air one
  (decision D-9).

## 9. Run lifecycle and stale-event safety

```
MainMenu → SlotSelect → (New | Continue) → Gameplay(level) ⇄ Pause
   Gameplay --exit portal--> LevelTransition --autosave--> Gameplay(next level)
   Gameplay --any player died--> TeamWipe(commit fresh save) → GameOver → Gameplay(W1-L1)
   Gameplay(W6-L4 exit) → Victory
```

- `Campaign.state` ∈ `MENU, PLAYING, TRANSITION, GAME_OVER, VICTORY`. Exit portals,
  deaths and saves check the state first. The first event wins: a death in the same
  frame as an exit trigger is processed before the transition starts, because damage
  runs in physics and the exit is deferred.
- `team_wipe()` is idempotent (both players dying on the same frame → one wipe).
- Every deferred callback, `Timer`, `Tween` and `await` that touches campaign state
  captures `Campaign.run_id` / `SceneRouter.scene_generation` and aborts on mismatch.
  Gameplay nodes are freed with the level, so their timers die with them.

## 10. Input

Ten actions, using **physical keycodes** so the keys stay in place on non-QWERTY layouts:

| Action | Key | Action | Key |
|---|---|---|---|
| `p1_left` | A | `p2_left` | Left |
| `p1_right` | D | `p2_right` | Right |
| `p1_up` | W | `p2_up` | Up |
| `p1_down` | S | `p2_down` | Down |
| `p1_attack` | V | `p2_attack` | Alt (location unspecified → Left **and** Right Alt) |

Gameplay never reads `ui_*` actions. Menus use `ui_*` (arrows + Enter/Space/Esc).
Pause = Esc (not a gameplay button). Input is polled in `_physics_process` with
`Input.is_action_pressed` / `is_action_just_pressed`. Attack also uses a short input
buffer. See risks R-1 to R-4 for Alt and ghosting.

## 11. Physics layers

| # | Name | Used by |
|---|---|---|
| 1 | world | solid tiles, doors, gates, moving platforms |
| 2 | one_way | one-way tiles/platforms |
| 3 | players | player bodies (not in each other's mask) |
| 4 | enemies | slime bodies |
| 5 | player_hurtbox | player Hurtbox |
| 6 | player_attack | knife hitboxes |
| 7 | enemy_hurtbox | slime hurtbox |
| 8 | pickups | coins, fruit, jars |
| 9 | hazards | spikes, hot ground, lava, kill floor |
| 10 | climb | ladders, vertical passages |
| 11 | triggers | plates, switches, exits, autosave zones |

## 12. Testing architecture

No third-party test plugin (GUT would be a download and a plugin, both disallowed).
Instead:

- `tests/run_tests.gd` (extends `SceneTree`) discovers `tests/**/test_*.gd`, runs every
  `test_*` method, prints results and exits with the failure count. It is run with
  `godot --headless --path . --script res://tests/run_tests.gd`.
- Gameplay tests instance real scenes, drive input with `Input.action_press/release`,
  and step physics frames with `await physics_frame`, using a seeded campaign RNG.
- Static validation: a script that loads every `.tscn`/`.tres` (catches parse errors and
  missing dependencies), checks `persist_id` uniqueness, and greps for `HTTPRequest`,
  `http://`/`https://` in game code (offline guard).
- Manual test checklists in `docs/TEST_REPORT.md` for things automation cannot prove:
  real keyboard ghosting, Alt behaviour, feel, readability.
