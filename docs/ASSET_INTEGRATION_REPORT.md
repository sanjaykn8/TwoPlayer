# Asset Integration Report

2026-11-08. How the Tiny RPG Character Asset Pack (free Soldier & Orc, by Zerie) was integrated
alongside the Brackeys bundle. The inventory and licence are in `docs/NEW_ASSET_CATALOG.md`.
The original ZIP in `Downloads` was not modified.

## What was copied

Only three files, into `assets/tiny_rpg/`, with `CREDITS.txt` (licence: use and modify in
games; **no redistribution of the raw files**):

| File | Source in the ZIP | Why |
|---|---|---|
| `soldier.png` | `Characters(100x100 split)/Soldier/Soldier/Soldier.png` (900×700) | Truly shadow-free. The pack's "no shadow" strips actually contain the shadow |
| `orc.png` | `Characters(100x100 split)/Orc/Orc/Orc.png` (800×600) | Shadow-free |
| `arrow.png` | `Arrow(Projectile)/Arrow01(32x32).png` | Archer arrows |

Not used: the Aseprite files (Godot cannot import them; the PNGs hold the same frames), the
"with shadows" variants (a top-down ground shadow looks wrong in side view), the 100×100 arrow.

## Generated from them (`tools/build_overhaul_art.gd`, never hand-edited)

| Output | Recolour rule | Used by |
|---|---|---|
| `resources/players/knight_frames_p1.tres` | none (silver helmet, crimson cloth) | Player One |
| `assets/created/knight_p2.png` + `knight_frames_p2.tres` | cloth → royal blue, steel → brass | Player Two |
| `assets/created/hollow_soldier.png` + frames | cloth → violet-black, steel → dark cold grey, skin → grey-green | Hollow Archer, Hollow Captain, Crowned Hollow |
| `orc_grunt_frames.tres` | none | Orc Grunt |
| `assets/created/orc_brute.png` + frames | skin → red-brown | Orc Brute, Orc Warchief (2×, gold tint) |
| `assets/created/orc_guard.png` + frames | skin → slate grey | Orc Shieldbearer (plus a drawn shield) |

Recolours select colours by hue, saturation and value. The near-white slash arcs and the red
hurt flash are excluded, so effects keep their colour. P1 and P2 differ in both cloth
(red/blue) and helmet (silver/brass), so they read apart in shared and split views. They also
keep their HUD colours (P1 red, P2 blue) and "P1"/"P2" tags.

## Frames and alignment

Every frame is a crop of one 100×100 cell, so no frame bleeds into its neighbour (checked by
`test_knight_sprite_frames`):

- **Soldier:** 56×40 crop at cell offset (20,17). The feet (sheet y = 57) sit exactly on the
  crop's bottom edge. The knight sprite sits at (0,−20), so the feet are on the body's origin,
  with no floating or sinking.
- **Orc:** 72×54 crop at (14,14). The smash arc reaches below the feet line. The feet are at
  crop y 43, so the sprite offset is (0,−16); twice that at 2× scale.

The renders in the integration check showed every character standing on the floor line at
1× and 2×.

## Animation mapping

| Knight state | Frames | Note |
|---|---|---|
| idle | soldier row 0 (6) at 8 fps | |
| run | row 1 (8) at 14 fps | Scaled by the speed upgrade |
| jump / fall | walk frame 1 / walk frame 5 | The pack has no jump art |
| crouch | death frame 1 (kneeling) | |
| climb | walk frames 1 and 3, stepped by distance climbed | |
| hurt | row 5 (4) | Frame 1 is the red flash |
| death | row 6 (4), held on the last frame | |
| side and low slash | row 2, frames chosen by the combat timeline: wind-up 1, hit frames 3–4 (the white arc), follow-through 5; heavy uses 2–5 | The arc on screen is exactly the hit window (`test_hit_frames_and_animation_are_synchronised`) |
| up slash | row 3, frames 1–2 (sword raised), plus the knife arc rotated up | |
| down slash (air) | row 3, frames 2–5 (chop), plus the knife arc rotated down | Pogo bounce on hit |

Enemy wind-ups also use real frames: orc axe raised (sweep 1–2) or overhead (smash 1–2),
archer drawing (bow 0–6). Each is played for the full wind-up with a warm flash and a "!"
warning, so every attack is visible before it can hurt.

## Assets drawn because a mechanic needs a readable shape

Drawn in code in the bundle's outlined style (no new image files):

- cave bat (roosting and two flap frames);
- saw blade and rail;
- fire jet (grate, sputter, flame column);
- falling rock;
- cracked-block cracks (over the world's own fill tile);
- pogo lantern;
- shockwave;
- shield;
- the Crowned Hollow's crown;
- torch;
- updraft, wind and ice streaks.

The spring mushroom is the Brackeys tileset's large red mushroom, squashed on bounce.

## Sounds

The Brackeys bundle has six sounds. Eighteen more are synthesised offline by
`tools/build_overhaul_audio.gd` with a fixed seed (identical every build) into
`assets/created/sfx/`:

- sword swing and heavy swing;
- charge ready;
- co-op sparkle;
- shield clang;
- arrow shot and arrow hit;
- bat chirp;
- spring;
- fire;
- rock;
- slam;
- block break;
- boss roar;
- fuse;
- blast;
- orc alert;
- bow draw.

All are routed through the SFX bus, the shared voice limit and the volume settings.

## Replaced

| Before | After | Why |
|---|---|---|
| Brackeys knight + palette shader | Tiny RPG soldier frames per player | Real attack, hurt and death animation instead of a knife drawn over the idle pose (KI-26) |
| `resources/players/knight_frames.tres`, `resources/shaders/knight_palette.gdshader` | Removed (inspected, superseded) | Nothing uses them any more |
| "tap" as the attack sound | synthesised swing | Distinct attack feedback |

`assets/sprites/knight.png` stays in the bundle folder, unused.
