# Master Development Plan: Overhaul

Started 2026-11-08 from commit `2a9b27b`. Goal: a substantially more engaging two-player
action-platformer, playable from the Godot editor (no Windows release work). Based on
`docs/GAMEPLAY_AUDIT.md` and `docs/NEW_ASSET_CATALOG.md`. Each milestone ends with tests, a
review of the diff, documentation and a commit. Status is tracked at the bottom.

## Fixed constraints

- Godot 4.7.2, GDScript, Compatibility renderer, 640×360, fully offline, no autoloads (the
  existing architecture), no new keyboard buttons (five per player).
- Unchanged rules: slime stagger (green 2, purple 4, ≥ 10 s, one more hit kills, chase =
  2 × patrol, no contact damage while staggered, 4–6 coins); lava instant death; spikes, hot
  ground and falls 1 health (falls bypass shields); fruit and jar effects; 10 % coin heal;
  team-wide permadeath; four save slots; quitting is not dying.
- Generated content stays generated: edit `tools/`, rebuild, never hand-edit generated scenes.
- The user's real saves (`%APPDATA%\TwoKnightCoop\saves\`) are never written by tests or tools.

## Milestones

### M1 — Asset integration and knight redesign

- Copy the soldier sheet, orc sheet and arrow into `assets/tiny_rpg/` (with credits). Add
  `tools/build_overhaul_art.gd`, which builds the recolours, the extra small sprites and every
  SpriteFrames resource.
- Knights use the soldier: Player One crimson, Player Two royal blue with gold trim. Frames
  come from `KnightProfile.sprite_frames`, which replaces the palette shader.
- Attack animation frames are driven by the combat timeline, so the frame shown always
  matches the open hitbox. The knife overlay remains only as the up/down arc.
- HUD portraits and the menu backdrop use the new frames.

### M2 — Combat expansion (same five keys)

- **Charged slash:** keep attack held after a swing for 0.5 s (a glint shows when ready),
  then release for a heavy slash: +1 power, 30 % longer reach, breaks shields and cracked
  blocks, short lunge, longer recovery.
- **Pogo:** a downward air attack that hits an enemy, a hazard top or a lantern bounces the
  knight up.
- **Co-op strike:** both knights hitting the same enemy within 0.35 s get +1 damage on the
  second hit, a "CO-OP" pop, a spark and bonus coins on a kill.
- **Feel:** knockback on enemies (heavier enemies resist), a 0.05 s hit pause for attacker
  and target, a camera shake service on the rig, hit sparks.

### M3 — Enemy expansion

A shared `EnemyBase` (health, hurtbox, contact, detection, knockback, flash, death, drops,
save id, save state) with data in `EnemyStats` resources. Slimes keep their own script and
rules.

| Enemy | Purpose | Key behaviour |
|---|---|---|
| Orc Grunt | Basic duelist | Patrols and chases (2×); telegraphed axe sweep (0.45 s wind-up, flash) that punishes standing in front; open during recovery |
| Orc Brute | Heavy | Slow; overhead slam with a 0.7 s tell sends ground shockwaves both ways (jump them); resists knockback |
| Orc Shieldbearer | Co-op flanking | Blocks frontal light hits (clang, knight pushed back); turns slowly; hit it from behind or above, or break the guard with a charged slash |
| Hollow Archer | Ranged | Keeps distance; draws for 0.6 s, then fires an arrow at chest height (jump over or crouch under); arrows can be cut down |
| Cave Bat | Flyer | Sleeps on the ceiling, swoops at a knight in an arc, returns; one hit |
| Ember Slime | Bomb | Fuses for 1 s near a knight or when hit, then explodes: hurts knights, damages enemies, breaks cracked blocks |

Mini-bosses and the final boss use the same base plus phase scripts:

- **Orc Warchief** (l12): 2× orc. Combos, a telegraphed charge, slam shockwaves; summons
  grunts at half health.
- **Hollow Captain** (l20): 2× hollow soldier. Sword dash, three-arrow volley, a guarded stance
  that needs flanking.
- **The Crowned Hollow** (l24 finale, three phases).

The three optional slime bosses stay optional.

### M4 — Hazards, traversal and co-op objects

| Object | Notes |
|---|---|
| Spring mushroom | Bounce pad |
| Updraft | Rising wind column |
| Wind gust | Horizontal push |
| Ice floor | Low friction |
| Saw blade on a rail | 1 damage |
| Fire jet | Timed with a warning flicker, hot-ground damage |
| Falling rock | Shakes, then falls; respawns |
| Cracked block | Heavy attack or explosion breaks it; saved |
| Pogo lantern | Bounce target |
| Encounter zone | Arena lock: gates close when both knights are in, open when its enemies are dead; saved |
| Dark area | Darkness with a light around each knight and torches |
| Stack boost | A knight jumping off its partner's head jumps higher |

Every object is a reusable scene with values in config resources. The level analyzer learns
springs, updrafts, breakables, encounter gates and stack boost (optional areas only). The
route validator removes damaging hazards the way it removes enemies.

### M5 — Level redesign (24 levels)

`docs/LEVEL_REDESIGN_PLAN.md` maps each level to an identity. Every level is rewritten as a
denser, more vertical layout with:

- arenas and ambushes;
- at least one signature mechanic;
- a hidden room;
- an optional challenge room.

Worlds introduce mechanics in order and combine them later. Levels get a layout version, so
old mid-level saves start the redesigned level from its spawn instead of restoring positions
that no longer exist (run progress is kept).

### M6 — Feedback, HUD, audio

- Synthesised sound effects generated offline by a tool (swing, heavy swing, clang, arrow,
  bat, spring, fire, boss roar, shockwave).
- Particles for sparks, dust and death puffs.
- A boss health bar in the HUD.
- Per-world atmosphere: darkness in the caves, embers in the lava world, snow in the citadel.

### M7 — Validation, balance, regression

- Unit and gameplay tests for every new system.
- Updated level probe, route and timing validators.
- Full regression twice.
- A real-window performance run with high enemy counts.
- Docs: GDD §18, ARCHITECTURE, TEST_REPORT, KNOWN_ISSUES, `MASTER_DEVELOPMENT_REPORT.md`,
  `FRIEND_PLAYTEST_CHECKLIST.md`, `ASSET_INTEGRATION_REPORT.md`.

## Status

| Milestone | Status |
|---|---|
| M0 Audit, asset inspection, plan | Done (this file, GAMEPLAY_AUDIT, NEW_ASSET_CATALOG) |
| M1 Assets and knights | In progress |
| M2 Combat | Not started |
| M3 Enemies and bosses | Not started |
| M4 Hazards and co-op objects | Not started |
| M5 Level redesign | Not started |
| M6 Feedback and audio | Not started |
| M7 Validation and docs | Not started |
