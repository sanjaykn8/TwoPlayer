# Development Audit Report: Phase 0

Date: 2026-11-03. Scope: `ROADMAP.md` Phase 0 only. No gameplay files were created,
modified or deleted. Only `docs/` files were added.

## 1. Method

1. Read `CLAUDE.md`, `GDD.md` and `ROADMAP.md` in full.
2. Listed every file outside `.godot/` (42 files) and read `project.godot`, all `.import`
   sidecars, `.gitignore`, `.gitattributes`, `.editorconfig`, the license, and the
   editor metadata (to locate the Godot binary).
3. Ran a headless Godot 4.7.2 script **from a scratch folder outside the project**. It
   read each PNG, measured the used rectangle of every grid cell, counted palettes,
   wrote 6× enlargements for visual inspection, and measured audio lengths.
4. Parsed the WAV RIFF chunks with Python (stdlib, isolated mode) to explain a loader
   warning.
5. Ran `godot --headless --path . --import` (clean, no errors) and a launch attempt
   (`no main scene defined`, as expected).
6. Confirmed afterwards that no file outside `.godot/` had changed.

## 2. Findings

### Project

- Fresh Godot 4.7.2 project named "2p". **No scenes, scripts, resources, autoloads,
  input actions or main scene.** Nothing to preserve beyond the assets and the three
  design documents.
- Rendering is not configured for pixel art: linear texture filtering (blurry),
  `canvas_items` stretch with `expand` aspect, 1152×648 default viewport, Forward+ on D3D12.
- Not a git repository. `.gitignore` is already suitable.
- Windows export templates are **not installed**.
- The save folder would be `%APPDATA%/Godot/app_userdata/2p/`, tied to the project name.

### Assets (details in `ASSET_CATALOG.md`)

- **Knight:** idle 4, run 16, roll 8, hit 4, death 4. The sheet contains baked text labels
  that must be skipped. No jump, fall, attack, climb or weapon. A 7-colour palette makes a
  P2 palette-swap straightforward.
- **Slimes:** green and purple share one 12-frame layout (rise, bob, hit flash). No death
  or attack frames. The collapsed-puddle frames suit the stagger state.
- **Collectibles:** coin spin (12 frames). Fruit sheet is exactly 4 colours × 3 shapes,
  which maps one-to-one onto GDD colours × tiers. Four bottles in the tileset map onto the
  four jars (red needs a recolour). "?" blocks suit power tiles.
- **Environment:** one 16 px atlas with 5 terrain materials (no edge/corner tiles),
  rope bridges, decoration, water/magenta/lava liquids, 4 sky-gradient backdrops, and
  signposts for clues. `platforms.png` has 4 material rows of one-way platforms.
- **Audio:** 6 short 8-bit SFX and one 40 s music track (imported without loop).
- **Fonts:** Pixel Operator 8 regular and bold. Import settings blur them.
- **Not present anywhere:** knife, ladder, spikes, doors/gates/switches/plates, exit
  portal, hearts/UI art, boss art, most combat/feedback sounds.

### GDD vs. available assets

All core visuals have a usable base except combat (knife), ladders, spikes and puzzle
objects. These must be created. They are small (16×16-scale) pieces and do not block
starting Phase 1, except that ladders need a placeholder tile.

## 3. Key technical conclusions

Full detail in `RISKS_AND_MISSING_RESOURCES.md`.

1. **Two-player input:** dedicated physical-key actions per player. Gameplay never uses
   `ui_*`. Alt is bound location-agnostic so Left and Right Alt both attack.
2. **Alt on Windows:** the main danger is Windows "menu mode" after a lone Alt tap. It
   must be verified in a standalone window (not the editor's embedded game view) before
   Phase 1 can pass. Alt+Tab is left alone.
3. **Ghosting:** a hardware limit that software cannot fix. Alt is a modifier key, so it
   is the most ghost-resistant attack key. V is the weakest. Mitigation is measurement
   (Controls Test screen), level design that never needs >3 keys per player, and input
   buffering.
4. **Vertical movement:** one priority-ordered context resolver (ladder → passage →
   one-way → ground). Consequence: no crouch on one-way platforms.
5. **Camera:** two SubViewports sharing one World2D, axis-aware split thresholds strictly
   inside the visible area, orientation hysteresis, no zoom. Parallax in split mode is the
   main unknown.
6. **Combat:** per-player CombatComponent, single active directional hitbox during active
   frames, per-swing hit registry, LOS ray against walls.
7. **Death/reset:** the fresh campaign is committed to disk *before* the game-over screen.
   `run_id` tokens kill stale async events. Wipe is idempotent.
8. **Saves:** 4 JSON slots, versioned, validated before applying, tmp-then-replace. No backup
   of old runs. Remaining-seconds timers. The save folder is pinned.
9. **Offline:** the engine runtime needs no network. A static test guards our code. Final
   proof requires export templates and a launch with networking disabled.

## 4. Phase 0 acceptance

| Requirement (ROADMAP Phase 0) | Result |
|---|---|
| Inspect project.godot | **Pass** |
| Inspect Godot version | **Pass**: 4.7.2.stable (project features "4.7") |
| Inventory all extracted assets | **Pass**: 16 assets + license + icon |
| Identify character sprites | **Pass** |
| Identify slime sprites | **Pass** |
| Identify tilesets | **Pass** (atlas PNGs; no TileSet resource exists) |
| Inspect animations and audio | **Pass**: frame rects measured, audio lengths measured |
| Identify suitable collectible assets | **Pass** |
| Check existing scripts and scenes | **Pass**: none exist |
| Create an asset catalog | **Pass**: `docs/ASSET_CATALOG.md` |
| Establish a clean project architecture | **Pass** (proposal): `docs/ARCHITECTURE.md` |
| Initialize version control if appropriate | **Deferred** by the user (2026-11-03, D-11). Not required by the gate |
| Deliverable: development task checklist | **Pass**: `docs/IMPLEMENTATION_PLAN.md` |
| **Completion gate:** no unknown asset paths or undocumented systems treated as usable | **Pass**: every path in the docs was verified on disk. Interpretive frame meanings are labelled as such. No existing systems are undocumented |

Phase 0 is complete. Version control was deferred by the user and can be added at any time.
