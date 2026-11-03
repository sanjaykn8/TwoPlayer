# Architecture

Status: Phase 0 proposal, with **Phases 1–5 implemented**. Section 7 (camera),
section 13 (players), section 14 (combat and health), section 15 (slimes) and section 16
(collectibles and progression) describe what exists now. The planned `Campaign` autoload of
section 4 is realised as the static `RunState` (section 16). The rest of sections 3–12 remain the target
design; where the implementation deviates, those sections say so.

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

## 7. Camera and split-screen (implemented in Phase 2)

### Scene structure

```
<Room or gameplay scene> (Node)
├─ Level (Node2D)                     moved into ViewA/Viewport/World by attach_world()
├─ SplitScreenRig (Control, full rect, split_screen_rig.gd, process_physics_priority 100)
│  ├─ ViewA (SubViewportContainer, stretch off)
│  │  └─ Viewport (SubViewport)        owns the World2D: physics, rendering, level nodes
│  │     ├─ World (Node2D)             ← the level lives here, exactly once
│  │     └─ Camera (Camera2D)          Player One's camera (also the shared camera)
│  ├─ ViewB (SubViewportContainer)     hidden in shared mode
│  │  └─ Viewport (SubViewport)        world_2d = ViewA's World2D; contains ONLY its camera
│  │     └─ Camera (Camera2D)          Player Two's camera
│  └─ Divider (ColorRect)
└─ HUD (CanvasLayer)                  outside the rig, drawn over both views
```

- **One simulation.** All level nodes, knights and physics bodies exist once, inside view A's
  world. View B borrows the same `World2D` and only renders it through a second camera. Tests
  assert that there are exactly 2 knights, 1 terrain layer and 2 SubViewports, and that view B
  contains only its camera.
- **No cost when unused.** In shared mode view B is hidden and its render target is
  `UPDATE_DISABLED`.
- **Pixel art.** Each SubViewport sets `canvas_item_default_texture_filter = NEAREST` (sub-viewports
  do not inherit the project default) and snaps 2D transforms and vertices to pixels. Camera
  positions are rounded to whole pixels, and zoom is a fixed integer (1).
- **Sizes.** The rig fills the root viewport, which is always 640×360 logical pixels because
  the project stretch mode is `viewport` / `keep` / `integer`. The window scales that image by
  whole numbers with letterboxing. The rig sets each SubViewport's size and its container's
  size together (stretch off), so a layout change never shows a frame at the wrong size.
  If the rig itself is resized, it re-lays out on `resized`.
- **Cameras** run in `CAMERA2D_PROCESS_PHYSICS` (required by physics interpolation).
  The rig moves them in `_physics_process` after the knights have moved
  (`process_physics_priority = 100`). Any jump calls `reset_physics_interpolation()`.

### Modes (`SplitScreenRig.Mode`)

| Mode | Screen | Camera A | Camera B |
|---|---|---|---|
| `SHARED` | A = 640×360 | Follows the knights' midpoint (plus `follow_offset`), with a dead zone and exponential smoothing, clamped to bounds | Idle, not rendered |
| `SPLIT` | Side by side 320×360 + 320×360, or stacked 640×180 + 640×180 | Follows Player One | Follows Player Two |
| `MERGING` | Same as split | Eases onto the left/top half of the upcoming shared view | Eases onto the right/bottom half |

**Separation ratio.** `CameraMath.separation_ratio` divides |dx| and |dy| by the shared
view's *safe region* (view size − 2 × `safe_margin`) = 544 × 280 px. The thresholds therefore
follow the actual view size and zoom rather than fixed distances.

- **Split** when max(ratio) > `split_enter_ratio` (0.85 → 462 px horizontally, 238 px
  vertically). Also split at once if either knight's body comes within `visibility_margin`
  of the shared view's edge. This guard covers camera lag, fast falls and teleports.
- **Merge** when max(ratio) < `split_exit_ratio` (0.55 → 299 px and 154 px) continuously for
  `merge_hold_time` (0.25 s). Then `MERGING` runs for `transition_duration` (0.3 s), and
  the shared view takes over showing exactly the same pixels. If the knights separate
  again during `MERGING`, the rig returns to `SPLIT`.
- Between 0.55 and 0.85 nothing changes (hysteresis band). Tests confirm no layout change
  while wandering inside the band, and exactly one switch under jitter at the split threshold.

**Orientation.** A new split uses the dominant normalised axis: ratio.x ≥ ratio.y gives
`SIDE_BY_SIDE` (vertical divider), otherwise `STACKED` (horizontal divider). While split, the
other axis must exceed the current one by `orientation_hysteresis` (×1.35) for
`orientation_hold_time` (0.35 s) before the layout changes.

**Player identity.** Player One always uses view A (left or top). Player Two always uses view B
(right or bottom), whatever their positions.

**Seamless transitions.**
- *Split:* each camera starts at `CameraMath.sub_view_center()` of the old shared centre,
  so its half of the screen shows the same pixels as before. Verified on rendered frames:
  0 changed pixels in the unaffected half. The cameras then ease toward their knights.
- *Merge:* the reverse. The cameras line up with the halves of the upcoming shared view,
  and then one shared camera replaces them.
- *Crossed knights:* when the knights are on the "wrong" sides for their fixed views, lining
  up would sweep each camera across the other knight, so the split or merge cuts instead.
- *Teleports:* a target jump larger than `snap_distance` (192 px) cuts instead of sliding.
- *Orientation change:* an instant re-layout; each camera keeps its centre.

### Level bounds (`components/camera/camera_bounds.gd`)

Each level contains one `CameraBounds` node (group `camera_bounds`). It defines either an
explicit rectangle (`size`, starting at the node position) or `fit_to_tile_map` (the used
rectangle of a TileMapLayer). `attach_world()` / `refresh_world()` find it. Every camera
centre is clamped so its view stays inside the bounds (`CameraMath.clamp_center`). On an axis
where the bounds are smaller than the view, the view is centred on the bounds. Without a
`CameraBounds` node the cameras are unclamped.

### Reuse in future levels

A gameplay scene instantiates the rig and calls `rig.attach_world(level)`. The level needs:
- the two knights (group `knights`, assigned to views by `player_id()`);
- a `CameraBounds` node.

After a respawn or any teleport, call `rig.snap_to_targets()`. All tuning lives in
`resources/config/camera_config.tres`.

### Not covered yet

- **Parallax** (risk R-8) is untested because no `Parallax2D` layer exists yet.
- **Audio:** the 2D audio listener will be view A's (Phase 9).
- **HUD:** the real HUD (Phase 9) will sit outside the rig in its own CanvasLayer, as the debug overlays do now.

## 8. Save system

- Files: `user://saves/slot_{1..4}.json`, plus `.tmp` during writes.
  `user://settings.cfg` for audio/video settings (not per-slot).
- **User-data folder is pinned (Phase 1):** `application/config/use_custom_user_dir=true`,
  `application/config/custom_user_dir_name="TwoKnightCoop"`. `user://` is
  `%APPDATA%\TwoKnightCoop\` and saves go in `user://saves/`
  (`%APPDATA%\TwoKnightCoop\saves\`, created by `SavePaths.ensure_save_dir()`). The project
  title (`config/name`) can change freely. Nothing is ever saved inside the project or repository.
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
| `p1_move_left` | A | `p2_move_left` | Left Arrow |
| `p1_move_right` | D | `p2_move_right` | Right Arrow |
| `p1_move_up` | W | `p2_move_up` | Up Arrow |
| `p1_move_down` | S | `p2_move_down` | Down Arrow |
| `p1_attack` | V | `p2_attack` | Left Alt (location LEFT), Right Alt (location RIGHT), Alt (location unspecified, fallback) |

All events use `device = -1` (all devices) and physical keycodes. In Godot 4.7.2, an action
event with a specific location matches only that side, so both sides are bound explicitly.
The unspecified-location fallback catches drivers or remote sessions that report no side.

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

## 13. Implemented in Phase 1

### Project configuration (`project.godot`)

| Setting | Value |
|---|---|
| Renderer | `gl_compatibility` (desktop and mobile). Verified at runtime: OpenGL 3.3, NVIDIA RTX 4050 Laptop GPU |
| Logical resolution | 640 × 360 (`display/window/size/viewport_*`) |
| Window | 1280 × 720 (`window_*_override`) |
| Stretch | mode `viewport`, aspect `keep` (letterbox), scale mode `integer` |
| Texture filter | Nearest (`rendering/textures/canvas_textures/default_texture_filter=0`) |
| Pixel snap | `rendering/2d/snap/snap_2d_transforms_to_pixel=true` |
| Physics | 60 ticks/s (default), `physics/common/physics_interpolation=true` |
| GUI font | `res://assets/fonts/PixelOperator8.ttf`, antialiasing off |
| Main scene | `res://scenes/dev/phase_1_test_room.tscn` (temporary, until the main menu exists) |
| User data | `TwoKnightCoop` custom user dir (see §8) |
| Physics layer names | As §11 (1 world … 11 triggers) |

The unused `rendering_device/driver.windows="d3d12"` line was left untouched. It only
applies if the project is switched back to a RenderingDevice renderer.

### Knight scene (`scenes/players/knight.tscn`)

```
Knight (CharacterBody2D, knight.gd)    layer 3 players; mask 1 world + 2 one_way + 3 players
│                                       floor_snap_length 4, platform_floor_layers = world + one_way
├─ Sprite (AnimatedSprite2D)           knight_frames.tres, palette ShaderMaterial, offset y -12
├─ Body (CollisionShape2D)             Rectangle 10×18 standing / 10×11 crouching, origin at feet
├─ Health (HealthComponent)
└─ Tag (Label)                         "P1"/"P2", development rooms only
```

- `profile: KnightProfile` (identity, actions, palette) and `config: KnightConfig` (all movement
  values) are the only differences between instances. `knight.tscn` defaults to the P1 profile.
- The shape and material are duplicated per instance in `_ready()` (a test confirms this).
- The proposed `Hurtbox`, `CombatComponent`, `EffectsComponent` and `SafeSpotTracker` children
  are **not** created yet. They belong to Phases 3, 5 and 6.
- **Deviation from §5:** ladders are found with physics point queries on the `climb` layer
  instead of a `LadderProbe` Area2D, which removes enter/exit signal bookkeeping.

**States:** `GROUNDED`, `AIRBORNE`, `CROUCHING`, `CLIMBING`, `DISABLED`. A drop-through is an
`AIRBORNE` knight with its one-way mask bit temporarily cleared. `state_changed`, `jumped`,
`landed` and `attack_requested(direction)` are emitted for later systems (HUD, audio, combat).

**Per tick (`_physics_process`):** read input → timers → attack request → state logic
(platforming or climbing) → push → `move_and_slide` → classify floor (solid, one-way or knight)
→ carry riders → post-move state → restore suspended collisions → animation.

**Vertical input** goes through `VerticalIntent.resolve()` (GDD §18 priority table, unit-tested).

**Collision suspension and restore:**
- *Drop-through:* clears mask bit 2 for this knight only. The bit is restored once the feet are
  8 px below the surface (or after 0.35 s) **and** the body no longer overlaps any one-way
  platform. The knight therefore passes exactly one platform and never falls through the level.
- *Climbing:* clears one-way mask bit 2 and the players layer/mask bit 3 while on the climbable,
  so ladder tops and the other knight never block a climb. Both are restored when no longer overlapping.
- *Teleport/spawn:* suspends players bit 3 until the knights no longer overlap. A spawn on top of
  the other knight therefore cannot fling either of them.

**Knight-to-knight interaction (D-3):**
- *Push:* a test move detects the other knight directly ahead. That knight is moved by
  `push_speed × delta` with `move_and_collide` (walls stop it). The pusher's speed is capped to
  `push_speed`. No velocity is transferred, so there are no impulses.
- *Riders:* a knight whose floor is the other knight is carried horizontally with it. It is lifted
  with the same upward velocity when the lower knight jumps.
- Low ceilings block the rider's carry move, so it slides off.

### Climbable component (`components/climb/climbable.gd`)

Area2D on layer 10 (`climb`). Its origin is at the top-centre and must sit on the exit surface
(a one-way tile for ladders). `kind = LADDER` snaps the knight to the centre, and sideways input
lets go. `kind = PASSAGE` allows free movement inside. The collision shape is created at runtime
from `size` (internal child, never saved). `@tool` draws the ladder texture or passage tint in
the editor.

**Level-design rule:** the tile at a ladder's top must be **one-way**, not solid. Otherwise
knights cannot climb out of the top or climb down from it.

### Health (`components/health/health_component.gd`)

`max_health` (≥ 1) and `current_health` (clamped to 0..max).
- `initialize(max)` fills to full.
- `set_max_health(value, fill_added)` supports the green jar.
- `apply_damage(n)` and `heal(n)` return the amount actually applied.
- Signals: `health_changed`, `damaged`, `healed`, and `depleted` (emitted once).
- A depleted entity is not healed.

Invulnerability, shields and damage kinds are Phase 3.

### Development-only content

- `scenes/dev/phase_1_test_room.tscn`: a 40×22-tile room containing flat ground, a step,
  one-way stack, crouch tunnel, corridor, floating platform, ladder, ledge edge, passage and
  landing area. F1–F4 hurt/heal, F6 reset, F7 HUD toggle.
- `scenes/dev/input_debug_hud.tscn`: live action states, attack direction, and a raw key log
  with Alt location counters.
- `tools/build_phase1_content.gd`: regenerates `knight_frames.tres`, `dev_world_tileset.tres`,
  `ladder.png` and the test room from code. Instances are created with `GEN_EDIT_STATE_INSTANCE`
  so only real overrides are saved.

### Commands

| Purpose | Command (from the project folder) |
|---|---|
| Run all tests | `Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 60 --script res://tests/run_tests.gd` |
| Run one test file | same, plus `-- test_logic` (substring filter) |
| Regenerate Phase 1 content | `... --headless --path . --script res://tools/build_phase1_content.gd -- content` |
| Play the test room in its own window | `Godot_v4.7.2-stable_win64.exe --path .` |
| Play the camera test room | `Godot_v4.7.2-stable_win64.exe --path . res://scenes/dev/camera_test_room.tscn` |
| Regenerate Phase 2 content | `... --headless --path . --script res://tools/build_phase2_content.gd` |
| Play the combat test room | `Godot_v4.7.2-stable_win64.exe --path . res://scenes/dev/combat_test_room.tscn` |
| Regenerate Phase 3 content | `... --script res://tools/build_phase3_content.gd -- art`, then `--import`, then `-- content` |
| Play the enemy test room | `Godot_v4.7.2-stable_win64.exe --path . res://scenes/dev/enemy_test_room.tscn` |
| Regenerate Phase 4 content | `... --script res://tools/build_phase4_content.gd -- frames`, then `-- content` |
| Play the collectible test room | `Godot_v4.7.2-stable_win64.exe --path . res://scenes/dev/collectible_test_room.tscn` |
| Regenerate Phase 5 content | `... --script res://tools/build_phase5_content.gd` |

## 14. Combat and health (implemented in Phase 3)

### Knight scene additions

```
Knight
├─ Hurtbox (HurtboxComponent, Area2D)   layer 5 player_hurtbox; box follows standing/crouch size
│  └─ Shape (RectangleShape2D)
└─ Combat (CombatComponent, Node2D)     config = combat_config.tres; stats = CombatStats
   ├─ Hitbox (HitboxComponent, Node2D)  ONE reusable damage area, reshaped per attack
   └─ Weapon (Sprite2D)                 knife_slash.png, 4 frames, rotated/mirrored per direction
```

Both knights use the same scene and script. Combat lives in the component, not in `knight.gd`.
The knight only resolves the direction and calls `combat.request_attack(direction, grounded)`.

### Attack flow

1. **Direction.** The knight resolves it with `AttackDirection.resolve(up_held, down_held, facing)`:
   Up wins, then Down; both or neither give the last horizontal facing. Only horizontal input
   changes `facing`, which defaults to right.
2. **Shape.** `HitboxGeometry.profile_for(direction, grounded)` picks SIDE, UP, DOWN or LOW.
   LOW is a grounded DOWN, the low forward slash of D-2.
   `HitboxGeometry.local_rect()` builds the rectangle from `CombatConfig` and
   `CombatStats.range_multiplier` (it scales only the reach) and the current body height.
3. **Timeline.** The tick an attack starts on is elapsed time 0. All times are in `combat_config.tres`.

   | Elapsed | State | Hitbox | Weapon frame |
   |---|---|---|---|
   | 0–0.05 s (ticks 0–3) | ATTACKING (windup) | closed | 0 |
   | 0.05–0.15 s (ticks 4–9) | ATTACKING (hit frames) | **open** | 1, then 2 |
   | 0.15–0.23 s | ATTACK_RECOVERY | closed | 3 (trail) |
   | until 0.30 s | ATTACK_RECOVERY | closed | hidden |
   | 0.30 s | IDLE | — | — |

   A press within 0.10 s of the end of the cooldown is buffered and starts exactly at 0.30 s.
   Earlier presses are dropped. Holding the button never repeats. The weapon frame is updated
   before hits are applied, so damage always lands while a slash frame is showing.
4. **Hits.** On every open tick, `HitboxComponent.find_targets()` runs one shape query against
   `hit_mask` (layer 7, enemy_hurtbox). It then keeps only the hurtboxes that are:
   - enabled;
   - not the attacker's own;
   - in line of sight.

   Each target entity is hit at most once per attack (`attack_id`, unique across both knights).
   One swing can hit several targets. Each hit sends a `DamageEvent(MELEE, attack_power,
   attack_id, direction, attacker_player_id)` to `HurtboxComponent.receive_hit()`.
5. **Line of sight.** A ray on `obstruction_mask` (layer 1, world) runs from the attack origin
   to the target's centre and to the target point nearest the origin. The origin is the body
   centre, or 4 px above the feet for the low slash. The hit counts if either ray is clear.
   Thin walls and pillars block attacks, a target peeking over a low step can be hit, and one-way
   platforms (layer 2) never block.
6. **Friendly fire.** Knights' hurtboxes are on layer 5 (player_hurtbox), which knight attacks
   never query, so there is no friendly fire.

No node is created or freed per attack; a test checks the node count over 20 attacks.

### Health and damage

`HealthComponent.take_damage(event)` applies the category rules in this order:

| Step | Rule |
|---|---|
| 1 | Already dead → blocked (`damage_blocked(event, &"dead")`) |
| 2 | `LAVA` → all remaining health removed, ignoring everything else |
| 3 | Invulnerable and the category respects invulnerability → blocked (`&"invulnerable"`) |
| 4 | Category can be protected → each protection filter may block it (`&"protected"`) |
| 5 | Remove `amount`; `damage_received(event, applied)`; if still alive start invulnerability |

| Category | Invulnerability | Protection (future shields, fruit, jars) |
|---|---|---|
| MELEE, CONTACT, SPIKE, HOT_GROUND | respected | can block |
| FALL | ignored | cannot block (D-4) |
| LAVA | ignored (instant death) | cannot block |

- **Invulnerability:** `invulnerability_time` (knights 1.0 s from `knight_config.tres`;
  training dummies 0) is counted down in `_physics_process`, which is enabled only while
  active. The knight shows it by blinking its sprite to 35 % opacity every 0.08 s.
- **Operations:** `apply_damage` (raw), `heal`, `increase_max_health(n, fill)`,
  `set_max_health`, `set_current_health`, `restore_full`, `is_alive`, `is_invulnerable`,
  `revive`.
- **Signals:** `health_changed`, `damaged`, `damage_received`, `damage_blocked`, `healed`,
  `depleted` (exactly once), `revived`, `invulnerability_changed`.
- **Revival:** healing, `set_current_health`, `restore_full` and max-health changes never
  revive a depleted entity. Only `revive()` does.

### Death

On `depleted` the knight:
- leaves any ladder;
- cancels its attack (hitbox closed, weapon hidden) and disables combat;
- enters `State.DEAD` and emits `died` once;
- plays `death`.

While dead it ignores input, cannot attack, push, lift or be healed, and takes no further
damage. Gravity still applies, so a knight killed on a ladder falls to the floor.
`knight.revive()` is the only way back: the development reset now, the campaign reset in Phase 8.

### Training dummy (`scenes/objects/training_dummy.tscn`, development only)

- **Hurtbox:** a 10×16 hurtbox on layer 7, with a `HealthComponent` (configurable `max_health`,
  no invulnerability).
- **Feedback:** each hit is logged in `damage_log` (and printed in debug builds); the dummy
  flashes white and shakes 1 px.
- **Breaking:** it breaks (greyed, hurtbox disabled) at 0 HP. It repairs after
  `respawn_delay` seconds, or on `reset()`.
- **Art:** the wooden post from `world_tileset.png` (cell 2,8).
- **Excluded:** no AI, stagger or drops.

### Development-only tools

- **Room keys:** `scenes/dev/combat_test_room.tscn` keys F1–F7 and F9, and its overlay.
- **Hitbox drawing:** `HitboxComponent.debug_visible` (static, default false) draws hitboxes
  only when it is true **and** `OS.is_debug_build()`. Only development rooms turn it on, and
  they turn it off again on exit. Nothing in the knight or components reads dev keys.

## 15. Slime enemies (implemented in Phase 4)

### Scene

```
GreenSlime / PurpleSlime            = slime_base.tscn + stats (green_slime.tres / purple_slime.tres)
Slime (CharacterBody2D, slime.gd)   layer 4 enemies; mask world + one_way; origin at the feet
├─ Sprite (AnimatedSprite2D)        stats.sprite_frames (generated from slime_green/purple.png)
├─ Body (CollisionShape2D 12x10)
├─ Hurtbox (HurtboxComponent)       layer 7 enemy_hurtbox, 14x12: what knights' attacks hit
├─ ContactArea (Area2D)             mask 5 player_hurtbox: contact damage
├─ DetectionArea (Area2D)           mask 5 player_hurtbox, circle radius = detection radius
├─ CoinDropper                      4-6 coins, spawns DroppedCoin scenes
├─ Alert (Label "!")                gameplay feedback when a knight is noticed
└─ DebugLabel                       development builds only
```

Slimes do not physically block knights (knights' mask excludes layer 4). Touching is
handled by the contact area. Detection uses the knights' **hurtboxes** (layer 5) rather
than their bodies, because a knight's body leaves the "players" layer while climbing a ladder.

### Behaviour

| State | Behaviour | Leaves when |
|---|---|---|
| IDLE | Stands still (start: 1 s; after turning: 0.4 s; after recovery: 0.4 s rising) | Timer ends → PATROL; target seen → DETECT_PLAYER |
| PATROL | Walks at `patrol_speed` between `home_x + patrol_left` and `home_x + patrol_right`. Turns (with a short idle) at a limit, a wall or a missing floor. Outside its area after a chase, walks back | Target seen → DETECT_PLAYER |
| DETECT_PLAYER | Stops, faces the knight, shows "!" (0.2 s) | → CHASE (or PATROL if the target was lost) |
| CHASE | Walks toward the target at `chase_speed() = patrol_speed × 2` (exact). Stops at walls, edges and on top of the target | Target lost → PATROL. Stuck below/above an unreachable target, or at an edge or wall, for 3 s → gives up (that knight is ignored for 1.5 s) |
| STAGGERED | Does not move, deal contact damage or sense. Pulsing puddle with circling stars | 10 s without a hit → IDLE (recovering); distinct melee hit → DEAD |
| DEAD | Hurtbox, contact and detection off, collision layer cleared, coins dropped, squash-and-fade (0.5 s), then freed | — |

- **Ground checks:** two reused rays per tick while walking. Downward ahead of the slime
  (world + one-way): no floor means an edge. Forward at body height (world): a hit means a wall.
- **Senses:** every `sense_interval` (0.1 s) each knight inside the circle is checked:
  - alive (`is_dead()` false), in the tree, and not temporarily ignored;
  - visible: a line-of-sight ray from the slime's eye to the knight's body centre on the
    **world** layer only. Solid terrain blocks it; one-way platforms do not.
- **Target selection:** `TargetSelector.pick()`:
  - takes the nearest visible knight, with ties going to Player One;
  - keeps the current target unless another is closer by more than 24 px.

  A dead target is dropped on the next tick. A living target out of sight is kept for
  `lose_target_time` (1 s) while the slime heads for it.
- **Being hit:** reveals the attacker as a target.

### Contact damage

On every tick when `can_damage()` is true (not STAGGERED or DEAD), each enabled player
hurtbox overlapping the ContactArea receives `DamageEvent(CONTACT, contact_damage)`. To
avoid sending an event every tick, the slime waits `contact_interval` (0.25 s) per knight
between events. The knight's `HealthComponent` still decides: the 1 s invulnerability blocks
repeats, and the blocked events show up as `damage_blocked(…, &"invulnerable")`.

### Stagger (`scripts/enemies/slime_stagger.gd`)

- `register_melee_hit(points, attack_id)`: points are the event's `amount`, which is the
  attacker's `CombatStats.attack_power`.
  - Progress accumulates. Reaching `threshold` (green 2, purple 4) staggers the slime for
    `max(stagger_duration, 10 s)`.
  - While staggered, a hit from the **same** attack id is ignored; a hit from any other attack
    id kills.
  - Further hits never restart the timer.
- `add_stagger_progress(points)`, exposed on the slime as `add_stagger_progress(points, source)`:
  non-melee progress (Phase 5 poison). It can stagger, never kills, and is ignored while staggered.
- `tick(delta)`: on expiry the slime is no longer staggered and progress returns to 0.
  Only one timer exists per slime.
- **Simultaneous hits:** the first killing hit sets DEAD and disables the hurtbox, so a
  second knight's hit in the same tick is ignored. `defeated` fires once.

### Coin drops (`components/loot/coin_dropper.gd`)

On death, `CoinDropper.drop(position, slime, level)` does the following, once per enemy:
1. Rolls `randi_range(4, 6)` with the dropper's own `RandomNumberGenerator`. It is
   randomised per enemy, or seeded via `rng_seed` for tests.
2. Builds a `CoinDropResult {count, position, source, source_name}`.
3. Emits `coins_dropped` and calls `on_coins_dropped(result)` on every node in the
   `coin_drop_listeners` group. The Phase 5 shared coin manager will join this group.
4. Spawns `count` `DroppedCoin` nodes into the level. They pop out, bounce and rest, spinning
   with `coin.png`.

The slime also emits `defeated(slime, result)`.
**Not implemented (Phase 5):** collecting coins, the shared coin total, the 10 % healing
chance per coin.

### Debugging (development builds only)

- **`Slime.debug_visible`** (static, default false; the enemy room turns it on in debug
  builds) draws the detection circle, patrol limits, line of sight to the target and the
  edge probe, and shows the label.
- **Overlay:** `enemy_debug_hud` lists, per slime: state, patrol/chase speed, detection radius,
  target, line of sight, stagger progress and timer, contact status and coin count.
- **Release builds:** every drawing check also requires `OS.is_debug_build()`.

## 16. Collectibles and player progression (implemented in Phase 5)

### Who owns what (single source of truth)

| State | Authority | Notes |
|---|---|---|
| Shared coins, collected unique item ids | `RunState` | One instance, held in a static variable (`RunState.current()`). Survives scene and level changes without an autoload; works in the headless test runner. `RunState.reset()` starts a fresh run |
| Per-player permanent upgrades, poison, timed effects | `PlayerStats` (one per player, owned by `RunState`) | Bonuses stored over base values from `knight_config.tres` / `combat_config.tres` |
| Effective power, range, cooldown multiplier, poison | `PlayerStats` calculates them; written into `PlayerStats.combat` (a `CombatStats`) by `recompute()` | The knight's `CombatComponent.stats` **is** that object, a derived cache with one writer |
| Effective movement speed | `PlayerStats.speed_multiplier()` = 1 + blue-jar bonus + power-tile bonus | Knight: `run_speed × multiplier` |
| Current health during a level | the knight's `HealthComponent` | `PlayerProgress` mirrors every change into `PlayerStats.current_health` |
| Current health between levels | `PlayerStats.current_health` | The next knight is initialised from it |

**Binding.** At the end of `Knight._ready()`, `PlayerProgress.bind(knight)`:
1. fetches the player's record;
2. initialises health from it;
3. points `combat.stats` at the record's `CombatStats`;
4. registers `PlayerEffects.resolve_protection` as the health protection filter;
5. connects the mirroring.

The binding lasts the knight's lifetime. It is deliberately not undone in `_exit_tree`,
because the camera rig re-parents levels. On `NOTIFICATION_PREDELETE` the record drops its
health reference.

### Timed effects (`PlayerEffects`)

`{remaining seconds, charges}` per effect id:
- `speed_boost`, `attack_speed`, `tile_shield` (power tiles);
- `fruit_shield` (yellow fruit);
- `jar_luck` (yellow jar).

They count down only in `PlayerProgress._physics_process`. They therefore stop when the tree
is paused, freeze while no level is loaded, and are saved as remaining seconds, which cannot
run while the game is closed. An effect ends on its exact tick (expiry tolerance 1e-6 s).

Refresh rules:
- **Same tile effect again:** back to the full 5 s; the strength never stacks.
- **Yellow fruit while shielded:** charges become max(current, new) and time becomes
  max(current, new), so it never exceeds the strongest tier.
- **Yellow jar again:** back to 60 s, still 50 %.

### Damage resolution order

`HealthComponent.take_damage(event)`:
1. invalid (amount ≤ 0, not lethal) or duplicate `event_id` → rejected;
2. dead → blocked;
3. LAVA → all health removed;
4. invulnerable → blocked (FALL and LAVA ignore invulnerability);
5. **the protection filter** `PlayerEffects.resolve_protection(event)`. FALL and LAVA always
   pass. Otherwise, in order:
   - the power-tile shield (consume 1);
   - else the yellow-fruit shield (consume 1);
   - else the yellow-jar roll (50 %).

   **At most one layer acts.** A block starts `block_invulnerability_time` (1 s), so
   continuous contact cannot drain several charges or re-roll the jar every frame.
6. damage applied; invulnerability 1 s.

### Coins

`CoinDropper` (Phase 4) still rolls 4–6 per enemy death, once. The spawned `DroppedCoin`
bodies now have a `CoinPickup` area (0.35 s pickup delay, so they scatter first).

On collection:
- `RunState.collect_coin(collector)` adds exactly 1;
- it then rolls once: `randi_range(0, 99) < 10`, exactly 10 % of the outcomes;
- on a hit, `PlayerStats.heal(1)` runs for **both** players, through the live
  `HealthComponent.heal()`, which never revives;
- `coin_collected` and `coins_changed` are emitted.

### Collectibles

- **`Collectible` (Area2D, layer 8; detects player hurtboxes, layer 5):** `collect()` sets
  `claimed` and stops monitoring **before** applying the effect, so two knights touching an item
  in the same frame cannot both collect it. With a `collectible_id`, the item is recorded in
  `RunState.collected` and removes itself on level load if it was already collected.
- **`Fruit`:** sprite from `fruit.png`; row = colour (green 0, yellow 1, purple 2, red 3),
  column = tier. Calls `PlayerStats.collect_fruit(type, tier)`.
- **`Jar`:** sprite from the bottles in `world_tileset.png`. The bundle has no red bottle, so the
  red jar is the magenta bottle tinted red, with a faint periodic glint. Calls
  `PlayerStats.collect_jar(type)`.
- **`PowerTile`:** solid "?" block (`world_tileset.png` 0,2) with a top sensor.
  - **Firing:** once per knight per visit, when that knight stands on it (inside the sensor
    *and* on the floor). Leaving the sensor re-arms it for that knight.
  - **Effect choice:** its own seedable RNG picks from `effect_pool`; `forced_effect` overrides it for tests.

### Poison

- **Applying it:** a melee hit carries `poison_seconds` (the attacker's highest purple-fruit
  tier). If the hit only adds progress (it neither staggers nor kills), the slime's
  `PoisonStatus` refreshes to max(remaining, seconds); there is never a second timer.
- **Effect:** each full second of active poison calls the Phase 4
  `add_stagger_progress(1, source)`, which can stagger but never kills.
- **Ending:** poison is cleared when the slime becomes staggered or dies.

### Snapshot / restore (for Phase 8)

`RunState.snapshot()` returns `{version, coins, collected: [{id, player, kind}], players: {"1": {...}, "2": {...}}}`,
JSON-compatible and covering current health, all bonuses, poison and timed effects.

`RunState.restore(data)` validates everything first and only then applies it:
- it rejects a newer version, missing fields, out-of-range values and unknown effect ids;
- bound knights resynchronise through the `restored` signal.

There is no disk I/O here; the four-slot SaveManager is Phase 8.

## 17. Hazards and advanced platforms (implemented in Phase 6)

### Hazards (`scenes/hazards/hazard.gd`, class `Hazard`)

One `@tool` Area2D script with `kind` = SPIKES, HOT_GROUND, LAVA or FALL and a `size`. The
origin is the top-left corner; the drawing and the damaging rectangle both come from `size`,
so they cannot drift apart. Ready-made scenes: `spikes.tscn`, `hot_ground.tscn`, `lava.tscn`,
`fall_boundary.tscn`.

- **Layers.** The hazard sits on layer 9 (hazards) and detects layer 5 (player hurtboxes), so a
  climbing knight (whose body layers are suppressed) is still detected.
- **One event per entry.** A per-knight `_inside` set: entering sends one `DamageEvent`,
  continuous overlap sends nothing, and leaving then re-entering sends another.
- **Damage.** SPIKE / HOT_GROUND events go to `knight.health.take_damage()`, so invulnerability
  and `PlayerEffects.resolve_protection()` apply as for any other hit. LAVA is a lethal event.
  FALL hazards call `knight.safe_spot.resolve_fall()`. Hazards never check shields themselves.
- **Damaging area.** Spikes: the bottom 8 px (the drawn spikes). Hot ground: a 3 px layer on
  top of an internal `StaticBody2D` (world layer, "unsafe_ground" group). Lava: everything
  below the 3 px wavy surface. Fall boundary: the whole rectangle (drawn only in the editor).
- `triggered(knight, applied)` is emitted after each event (used by the dev room's log).

### Safe positions and falling (`components/safety/safe_spot_tracker.gd`)

Every knight has a `SafeSpot` child (`SafeSpotTracker`), set up at the end of `Knight._ready()`.

- **Safe now** = alive, GROUNDED or CROUCHING, on the floor, not standing on a knight, inside
  no hazard (`hazard_contacts == 0`, maintained by hazards), above the fall line, and the floor
  collider is not in the `unsafe_ground` group (all `PlatformBody` platforms and hot ground).
- **Delayed commit.** Positions from consecutive safe frames are queued; a position becomes
  `last_safe_position` only after `safe_ground_frames` (6) more safe frames. Hazard overlap
  signals arrive a frame late, so this stops a spot at a hazard's edge from being committed.
- **Fall line.** The bottom of the level's `CameraBounds` + `fall_margin` (48 px); `INF` when
  the level has none. It backs up `FallBoundary` hazards.
- **`resolve_fall(source)`** is the only fall consequence and is guarded against re-entry: FALL
  damage (`fall_damage`, ignores invulnerability and protection) if alive, teleport to the last
  safe position (or `spawn_position`), clear the queue, and if still alive start
  `respawn_protection` (1 s) invulnerability with a "-1 FALL" pop-up. Emits `fell(knight,
  survived)`. A knight already dead is only moved back (no damage, no second death).
- Teleporting resets velocity, coyote/jump buffers and the state (except DEAD), and suspends
  knight-knight collision until they no longer overlap. Progression lives in `RunState`, so a
  respawn keeps upgrades, coins and timed effects.
- The camera rig needs no call: it cuts when a target jumps more than `snap_distance` and splits
  if a knight leaves the shared view.

### Platforms (`scenes/platforms/`)

`PlatformBody` (`@tool` AnimatableBody2D) is the shared base:
- origin top-left, `width_tiles` × 16 px, drawn from `platforms.png` (pairs of the two-cell long
  piece, a short piece for odd widths; `material_row` 0 grass, 1 sand, 2 orange, 3 ice);
- `one_way = true`: layer 2 (one_way), 6 px one-way shape; `false`: layer 1 (world), 9 px solid
  shape; mask 0;
- always in `unsafe_ground`;
- `set_collision_enabled()` (deferred shape toggle) is the only way collision changes;
- `is_occupied()`: a shape query over the platform's space for knight bodies (layer 3), enemies
  (layer 4) and knight hurtboxes (layer 5);
- `visual_alpha` / `visual_offset` / `visual_tint` change only the drawing, never collision.

| Script | Behaviour |
|---|---|
| `MovingPlatform` | `position = start + travel × progress`, advanced at `speed` px/s in `_physics_process`; `pause_time` at each end; `ping_pong` or one-shot; `start_delay`. `sync_to_physics = true`, so knights and slimes standing on it are carried by Godot's moving-platform handling (no teleporting) |
| `TimedPlatform` | INACTIVE → (activate) → REACTIVATING → ACTIVE → WARNING → DISABLED → INACTIVE (TRIGGERED) or REACTIVATING (SCHEDULE / `auto_reactivate`). Collision only in ACTIVE and WARNING. REACTIVATING lasts at least `reactivate_time` and until `is_occupied()` is false. `start_offset` staggers rows. `activate()` is the Phase 7 hook for switches |
| `CollapsingPlatform` | STABLE → SHAKING (`collapse_delay`) → COLLAPSED (`recovery_time`, or forever if `permanent`) → REAPPEARING (≥ `reappear_time`, until unoccupied) → STABLE. A thin sensor above the top (hurtbox layer) tracks knights; it starts only for a knight on the floor, not rising, with its feet within 2 px of the top surface. Slimes never trigger it |

`timed_platform.tscn` is TRIGGERED with auto-reactivation (it cycles until Phase 7 switches
drive it); `disappearing_platform.tscn` is SCHEDULE.

All timers count `delta` in `_physics_process`, so everything stops while the tree is paused.

### Configuration

`resources/config/hazard_config.tres` (`HazardConfig`): spike, hot-ground and fall damage,
respawn protection, safe-ground frames, fall margin. Platform timings are per-instance exports.

### Development-only content

- `scenes/dev/hazard_test_room.tscn` (+ `hazard_test_level.tscn`, `hazard_debug_hud.tscn`):
  every hazard and platform in one corridor; F1–F9 dev keys (see `docs/MANUAL_HAZARD_TEST.md`);
  `SafeSpotTracker.debug_visible` draws safe-position markers.
- `tools/build_phase6_content.gd`: `-- art` writes `assets/created/spikes.png`; `-- content`
  regenerates the room.
