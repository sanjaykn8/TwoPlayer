# Asset Catalog

Phase 0 audit, 2026-11-03. Godot 4.7.2.stable.

Every entry below was verified against the file on disk. Dimensions and frame
rectangles were measured with a headless Godot script (`Image.get_used_rect()`
per grid cell). Animation names come from visual inspection of 6× nearest-neighbour
enlargements. Where the meaning of a frame is an interpretation rather than a label
baked into the sheet, it is marked *(visual interpretation)*.

Source bundle: Brackeys Platformer Bundle. License: **CC0** for all assets
(`res://assets/LICENSE & CREDITS.txt`). Credits: knight, slime, platforms and coin by
analogStudios_; world_tileset and fruit by RottingPixels; sounds by Brackeys / Asbjørn
Thirslund; music by Brackeys / Sofia Thirslund; Pixel Operator font by Jayvee Enaguas.
A credits screen should still list them.

## Summary

| Path | Type | Size | Frame grid |
|---|---|---|---|
| `res://assets/sprites/knight.png` | Sprite sheet | 256×256 | 32×32, 8×8 cells |
| `res://assets/sprites/slime_green.png` | Sprite sheet | 96×72 | 24×24, 4×3 cells |
| `res://assets/sprites/slime_purple.png` | Sprite sheet | 96×72 | 24×24, 4×3 cells |
| `res://assets/sprites/coin.png` | Sprite strip | 192×16 | 16×16, 12×1 cells |
| `res://assets/sprites/fruit.png` | Icon sheet | 64×64 | 16×16, 4×4 cells (3×4 used) |
| `res://assets/sprites/platforms.png` | Tile sheet | 64×64 | 16×16, 4×4 cells (3×4 used) |
| `res://assets/sprites/world_tileset.png` | Tile atlas | 256×256 | 16×16, 16×16 cells (partially used) |
| `res://assets/sounds/coin.wav` | SFX | 0.198 s | 8-bit mono PCM, 44.1 kHz |
| `res://assets/sounds/explosion.wav` | SFX | 0.452 s | 8-bit mono PCM, 44.1 kHz |
| `res://assets/sounds/hurt.wav` | SFX | 0.173 s | 8-bit mono PCM, 44.1 kHz |
| `res://assets/sounds/jump.wav` | SFX | 0.091 s | 8-bit mono PCM, 44.1 kHz |
| `res://assets/sounds/power_up.wav` | SFX | 0.358 s | 8-bit mono PCM, 44.1 kHz |
| `res://assets/sounds/tap.wav` | SFX | 0.034 s | 8-bit mono PCM, 44.1 kHz |
| `res://assets/music/time_for_adventure.mp3` | Music | 40.05 s, 1.6 MB | MP3 |
| `res://assets/fonts/PixelOperator8.ttf` | Font | 19.9 KB | 8 px pixel font |
| `res://assets/fonts/PixelOperator8-Bold.ttf` | Font | 18.6 KB | 8 px pixel font, bold |
| `res://assets/LICENSE & CREDITS.txt` | Text | — | — |
| `res://icon.svg` | Project icon | SVG | Default Godot icon |

All 16 asset files have `.import` sidecars and imported successfully
(`godot --headless --import` completed with no errors).

There are **no** `.tres` / `.tscn` / `.gd` resources in the project: no TileSet,
SpriteFrames, AnimationLibrary, Theme, AudioBusLayout or scene exists yet. Every
animation, tileset and collision shape must be authored.

---

## 1. Characters

### `res://assets/sprites/knight.png` — 256×256, 32×32 cells

The sheet contains **baked-in text labels** (black, anti-aliased). Those cells must
never be referenced as frames. Cell coordinates are (column, row), zero-based.

| Animation | Cells | Frames | Notes |
|---|---|---|---|
| idle | row 0, cols 0–3 | 4 | Character body ≈13×19 px, top-left ≈(9,9) |
| run | rows 2–3, cols 0–7 | 16 | Single continuous cycle across two rows |
| roll | row 5, cols 0–7 | 8 | Cols 2 and 6 are a lower, compact pose (13×15 px) *(usable as crouch)* |
| hit | row 6, cols 0–3 | 4 | Col 2 is a full red flash frame |
| death | row 7, cols 0–3 | 4 | Col 3 is the collapsed pose (15×13 px) |

Label cells (do not use): row 0 cols 4–5 "IDLE"; row 1 cols 0–1 "RUN";
row 4 cols 0–1 "ROLL"; row 6 cols 4–5 "HIT"; row 7 cols 4–6 "DEATH".

- Faces **right**. Use `flip_h` for left.
- Feet rest at y ≈ 28 inside the 32-px cell, so the sprite needs a vertical offset
  of about −12 px for a bottom-centre origin. Exact value to be fixed in Phase 1.
- No weapon is drawn.
- Palette of the character (7 opaque colours, measured on idle frame 0):
  `#0e0d0e` outline, `#d2202c` plume, `#eadfd1` highlight, `#b3aaa1` light steel,
  `#7c776f` dark steel, `#0a7030` green tunic, `#eba724` gold trim.
  This small, exact palette makes a palette-swap shader for Player Two reliable:
  swap tunic and plume colours only.
- Semi-transparent pixels exist only in the label text.

**Missing for the GDD:** jump, fall, attack, climb, crouch (only the roll pose is
close), player stagger. No second knight colour. See
`docs/RISKS_AND_MISSING_RESOURCES.md`.

---

## 2. Enemies

### `res://assets/sprites/slime_green.png` — 96×72, 24×24 cells, 12 frames

### `res://assets/sprites/slime_purple.png` — 96×72, 24×24 cells, 12 frames

Both sheets have an identical layout and identical frame rectangles. Frames are numbered
0–11, left to right, top to bottom.

| Frames | Content *(visual interpretation)* |
|---|---|
| 0–3 | Flat puddle rising to full body (0 = 14×9 px puddle, 3 = 14×12 px) |
| 4–9 | Idle bob / hop cycle, eye visible (body up to 14×15 px) |
| 10 | Full red hit flash |
| 11 | Normal pose (recovery after flash) |

- Body ≈14 px wide, horizontally at x = 5..19, bottom at y = 24 (cell bottom).
- Faces: the slime is near-symmetrical. The eye sits slightly left of centre.
- Green: 7 colours (lime body, green base). Purple: 10 colours (pink body, purple base).
- Recommended use: idle/patrol/chase = 4–9; hurt = 10–11; spawn = 0–3;
  **stagger = 0–1 (collapsed puddle) with a pulsing tint**, which communicates
  vulnerability without new art.

**Missing:** death animation, attack animation, boss variant.

---

## 3. Collectibles

### `res://assets/sprites/coin.png` — 192×16, 12 frames of 16×16

Spinning gold coin. Visible coin is 10×10 px at (3,3). Frames 0–11 form two rotation
cycles. Use all 12 as one looping "spin" animation (≈10–12 fps).

### `res://assets/sprites/fruit.png` — 64×64, 16×16 cells

Column 3 is empty. The 3×4 used grid maps exactly onto the GDD's 4 fruit colours × 3 tiers.

| Row | Colour | Col 0 (apple) | Col 1 (pear) | Col 2 (grapes) | GDD fruit |
|---|---|---|---|---|---|
| 0 | Green | (0,0) | (1,0) | (2,0) | Green fruit (healing) |
| 1 | Yellow-orange | (0,1) | (1,1) | (2,1) | Yellow fruit (hit block) |
| 2 | Pink / purple grapes | (0,2) | (1,2) | (2,2) | Purple fruit (poison) |
| 3 | Red | (0,3) | (1,3) | (2,3) | Red fruit (attack range) |

Recommended: column = tier (apple = Tier 1, pear = Tier 2, grapes = Tier 3).
Row 2 apple/pear are pink rather than purple. Acceptable, but a mild hue shift
may improve readability.

### Jars — bottles in `res://assets/sprites/world_tileset.png`

| Atlas cell | Colour | Size | GDD jar |
|---|---|---|---|
| (0,7) | Green | 8×14 | Green jar (max health +1) |
| (1,7) | Orange-yellow | 8×14 | Yellow jar (50 % negate, 60 s) |
| (0,8) | Blue | 8×14 | Blue jar (+5 % speed) |
| (1,8) | Magenta | 8×14 | Red jar (+1 attack) — **needs a red recolour** to match the GDD colour |

### Power-up tiles — candidates in `world_tileset.png`

"?" blocks at (0,2), (3,2), (4,2), (7,2). "!" blocks at (1,2), (2,3), (5,2), (8,2).
The "?" block suits the random power-up tile. The "!" block suits switches.
Both need an "inactive / cooling down" visual state (tint or modulate).

---

## 4. Environment

### `res://assets/sprites/world_tileset.png` — 256×256, 16×16 atlas

Atlas coordinates are (column, row). Only cells listed here contain pixels.

**Terrain (rows 0–2), five material families**

| Material | Top / surface | Fill | Cobble / brick | Special |
|---|---|---|---|---|
| Grass + dirt | (0,0) grass top | (0,1) | (1,0), (1,1) | "?" (0,2), "!" (1,2) |
| Sand | (2,0) sand top | (2,1) | (3,0), (3,1) | (2,2) sand-capped block, "?" (3,2), "!" (2,3) |
| Red earth (autumn top) | (4,0) yellow top | (4,1) | (5,0), (5,1) | "?" (4,2), "!" (5,2) |
| Grey stone | (6,0) ice-blue top | (6,1) | (8,0), (8,1) | "?" (7,2), "!" (8,2) |
| Ice / snow | (7,0) snow-capped ice | (7,1) snow-capped stone | — | (6,2) ice block |

There are no corner, slope or edge-variant tiles. Terrain autotiling (terrain sets)
must use these simple top/fill pairs. Edges will look square.

**Rope bridges (rows 0–2, cols 9–11)**: beaded segments in brown (row 0, 16×8),
tan (row 1, 16×7 at y = 2), pink (row 2). Suitable as one-way bridge visuals.

**Decoration**

| Cells | Content |
|---|---|
| (0,3)–(0,5) | Tall green tree (canopy + trunk), 1×3 |
| (1,3) | Large green bush / canopy |
| (1,4), (1,5) | Small green bushes |
| (1,6) | Flowering bush |
| (2,4)–(4,6), (3,7), (3,8) | Palm tree, multi-tile (crown cols 2–4, trunk col 3) |
| (5,3)–(5,5) | Tall orange (autumn) tree |
| (5,6)–(5,8) | Orange bushes, large → small |
| (6,3)–(6,5) | Stacked teal tree |
| (6,6)–(6,8) | Teal bushes |
| (7,3), (7,4) | Wooden crate / frame, brown and reddish *(visual interpretation: not a ladder)* |
| (8,3), (8,4) | Signpost, brown and reddish — **use for environmental text clues** |
| (9,3), (9,4) | Two-rail fence, 14×12 |
| (7,5)–(7,8) | Large mushrooms: red, orange, purple, teal |
| (8,5)–(8,8) | Small mushroom clusters: red, orange, purple, teal |
| (2,8) | Wooden post / stump, 8×16 |
| (4,8) | Pumpkin |

**Liquids**

| Cells | Content | Recommended use |
|---|---|---|
| (4,9) surface, (4,10) fill, (5,9) wave strip 16×5 | Bright blue water | Decorative water |
| (6,9) surface, (6,10) fill, (7,9) wave strip | Slate-blue water | Cave water |
| (4,11) surface, (4,12) fill, (5,11) wave strip | Magenta liquid | Poison / decoration |
| (4,13) surface, (4,14) fill, (5,13) wave strip | Orange liquid | **Lava** |

**Backgrounds (rows 9–15, cols 0–3)**: four vertical sky-gradient strips with cloud
bands. Col 0 blue/white, col 1 peach→yellow→orange, col 2 salmon→magenta→purple,
col 3 lavender-grey→slate. Each is 1 tile wide and 7 tiles tall, for stretched or
tiled parallax backdrops: blue suits the forest, orange the lava kingdom, purple the
fortress, grey the caves and citadel.

### `res://assets/sprites/platforms.png` — 64×64, 16×16 cells

Four rows of floating platforms. Every piece is 9 px tall, at the top of its cell.

| Row | Material | Short (16 px) | Long (32 px) |
|---|---|---|---|
| 0 | Grass | (0,0) | (1,0)+(2,0) |
| 1 | Sand / wood | (0,1) | (1,1)+(2,1) |
| 2 | Orange / molten | (0,2) | (1,2)+(2,2) |
| 3 | Ice | (0,3) | (1,3)+(2,3) |

The long piece has rounded caps on both outer ends and **no repeatable middle
segment**. Wider moving platforms need several pieces or a new middle tile.
Good for moving, timed, disappearing and collapsing platforms (behaviour via script,
state shown via modulate/shake).

---

## 5. Audio

All six WAV files are 8-bit, mono, 44.1 kHz PCM. Each `data` chunk has an odd byte
length without the RIFF pad byte. The **editor importer handles this**. Imports succeed
and are the path the game will use. A *runtime* `AudioStreamWAV.load_from_file()`
prints `Condition "p_position > length" is true` but still loads. The game must not
load WAVs at runtime from source files.

| File | Length | Recommended use |
|---|---|---|
| `res://assets/sounds/jump.wav` | 0.091 s | Player jump |
| `res://assets/sounds/hurt.wav` | 0.173 s | Player takes damage |
| `res://assets/sounds/coin.wav` | 0.198 s | Coin pickup (pitch-randomised for bursts of 4–6) |
| `res://assets/sounds/power_up.wav` | 0.358 s | Fruit / jar / power tile; level exit (pitched) |
| `res://assets/sounds/explosion.wav` | 0.452 s | Slime death; lava / team wipe |
| `res://assets/sounds/tap.wav` | 0.034 s | UI navigation; fallback for attack swing and enemy hit with pitch variation |

| File | Length | Notes |
|---|---|---|
| `res://assets/music/time_for_adventure.mp3` | 40.05 s | Only music track. Import has `loop=false`, so it must be set to loop. One 40 s loop for a 90–120 min game will become repetitive. |

**Missing:** dedicated attack swing, enemy hit, enemy stagger, hazard sizzle,
level transition, game over and victory sounds, plus menu and per-world music.

---

## 6. Fonts

| File | Recommended use |
|---|---|
| `res://assets/fonts/PixelOperator8.ttf` | Body text, HUD numbers, clue signs |
| `res://assets/fonts/PixelOperator8-Bold.ttf` | Titles, menu headings, player labels |

Pixel Operator 8 is drawn on an 8 px grid. Use sizes of 8, 16 or 24 only.
Current import settings are wrong for pixel text: `antialiasing=1` (grayscale),
`hinting=1`, `subpixel_positioning=4`, `allow_system_fallback=true`.
Phase 1 should set antialiasing to none, hinting to none, subpixel positioning off
and system fallback off.

---

## 7. Import settings applying to all sprites

All PNGs use `compress/mode=0` (lossless) and no mipmaps, which is correct.
`project.godot` does **not** set `rendering/textures/canvas_textures/default_texture_filter`,
so sprites currently render with **linear filtering (blurry)**. This must be changed to
Nearest in Phase 1.

## 8. Asset-to-feature coverage

| Feature | Available asset | Status |
|---|---|---|
| Player 1 knight | knight.png | Partial: idle/run/hit/death; roll pose usable as crouch |
| Player 2 knight | knight.png + palette shader | Shader to create |
| Knife + slash | — | **Create** |
| Green / purple slimes | slime_green.png, slime_purple.png | Usable; death VFX to create |
| Boss | — | **Create** (scaled/recoloured slime is the cheapest path) |
| Coins | coin.png | Complete |
| Fruits (4×3 tiers) | fruit.png | Complete |
| Jars (4) | world_tileset bottles | 3 match; red needs recolour |
| Power-up tile | "?" blocks | Usable; inactive state via modulate |
| Terrain | world_tileset rows 0–2 | Usable; no edge/corner/slope tiles |
| One-way platforms | platforms.png, rope bridges | Usable |
| Ladders | — | **Create** |
| Spikes | — | **Create** |
| Hot ground | red earth tiles | Usable with an animated glow shader |
| Lava | world_tileset (4,13)/(4,14)/(5,13) | Usable |
| Doors, gates, switches, plates, exit portal | "!" blocks, crates only | **Create** |
| Signs for clues | signposts (8,3), (8,4) | Usable |
| Backgrounds | sky gradient strips | Usable for 4 of 6 themes; others via tint |
| HUD hearts, icons, panels | `assets/created/ui_icons.png` (Phase 9) + fruit / jar / "?" sprites + font | Done (Phase 9) |
| Music | 1 × 40 s track | Thin |
| SFX | 6 files | Partial |

## 9. Phase 9 additions and audio assignment

### Created art

| File | Size | Content | Made by |
|---|---|---|---|
| `res://assets/created/ui_icons.png` | 32×8 (four 8×8 cells) | Heart (full), heart (empty), slider grabber, menu pointer arrow | `tools/build_phase9_content.gd` |

The HUD and menus reuse bundle art directly through `AtlasTexture` regions:

| Element | Source |
|---|---|
| Effect icons | Yellow fruit `fruit.png (0,16,16,16)`; yellow jar `world_tileset.png` cell (1,7); "?" tile cell (0,2) |
| Coin icon | `coin.png` frame 0 |
| HUD portraits | `knight.png (8,12,16,16)` with the palette shader |
| Main-menu backdrop | Sky strip cell column 2 rows 9–15 at 3×; grass and dirt; teal and orange trees, bush, mushrooms and signpost; both knights and both slimes idling |
| Fonts | Pixel Operator 8 (regular and bold) at 8, 16 and 32 px |

### Audio assignment (`resources/config/audio_config.tres`)

| Use | File | Pitch | Volume |
|---|---|---|---|
| Menu music | `time_for_adventure.mp3` | 0.85 | −9 dB |
| World 1 music (default world track) | `time_for_adventure.mp3` | 1.0 | −11 dB |
| Victory music | `time_for_adventure.mp3` | 1.1 | −7 dB |
| Game-over music | none (silence) | — | — |
| Menu move / confirm / cancel | `tap.wav` | 1.5 / 1.0 / 0.7 | — |
| Menu error | `hurt.wav` | 1.3 | — |
| Attack swing | `tap.wav` | 1.9 ±10 % | — |
| Jump | `jump.wav` | 1.0 | −17 dB |
| Enemy hit / stagger | `hurt.wav` | 1.6 / 0.8 | — |
| Enemy death | `explosion.wav` | 1.4 | — |
| Player damage / death | `hurt.wav` / `explosion.wav` | 1.0 / 0.7 | — |
| Level transition | `power_up.wav` | 0.8 | — |
| Victory jingle | `power_up.wav` | 1.25 | — |
| Game over | `explosion.wav` | 0.55 | — |
| Coins, fruit, jars, tiles, switches, gates, puzzles, hazards | Unchanged since Phases 5–7 | — | — |

**Still missing from the bundle:**

- a dedicated sword swing;
- a gate, level-transition, victory or game-over sound;
- a menu-specific click;
- any second music track.

Each use above reuses one of the six effects or the single track (KI-76, KI-77).
