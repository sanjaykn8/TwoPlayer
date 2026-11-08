# New Asset Catalog: Tiny RPG Character Asset Pack 01 v2.0 (Free Soldier & Orc)

Inspected 2026-11-08 from
`C:\Users\Reaper\Downloads\Tiny RPG Character Asset Pack 01 v2.0 -Free Soldier&Orc.zip`
(131 873 bytes). The ZIP was extracted to a scratch folder for inspection only; the original
file is untouched. Every number below was measured with Godot's `Image` API (frame
rectangles are the opaque bounding box inside each 100×100 cell), not guessed from file names.

## Licence

The ZIP contains **no README or licence file**. The pack's itch.io page
(zerie.itch.io/tiny-rpg-character-asset-pack, author **Zerie**) states, for the whole pack:

- Allowed: use in personal and commercial video game projects; editing and modifying the assets.
- Credit: "appreciated but not required". The game credits Zerie anyway (`assets/tiny_rpg/CREDITS.txt`).
- **Not allowed: redistributing, reselling or re-uploading the assets, modified or not**; AI
  training; NFT projects.

Consequence for this project: the sprites may ship **inside the game**, but the raw sheets in
`assets/tiny_rpg/` (and the recoloured sheets generated from them) must not be published on
their own, e.g. in a **public** source repository. The Git remote is not pushed by Claude; if
the repository is ever made public, exclude `assets/tiny_rpg/` and the generated recolours
first. Recorded as KI-110.

## Contents (every file)

| Path in ZIP | Size | Type | Notes |
|---|---|---|---|
| `Arrow(Projectile)/Arrow01(100x100).png` | 100×100 | Projectile | Arrow at (41,47), 19×7, flies right |
| `Arrow(Projectile)/Arrow01(32x32).png` | 32×32 | Projectile | Same arrow at (7,13), 19×7 — **used** |
| `Aseprite file/Orc.aseprite`, `Soldier.aseprite` | — | Source | Aseprite projects (duplicates also inside the character folders). Not used: Godot cannot import them and the PNGs carry the same frames |
| `Characters(100x100 split)/Soldier/Soldier/Soldier.png` | 900×700 | Sheet, 9×7 cells of 100×100 | **No shadow. Used for the knights and hollow soldiers** |
| `…/Soldier/Soldier/Soldier_*.png` (Idle, Walk, Attack01–03, Hurt, Death) | 600–900×100 | Strips | **Quirk:** these "no shadow" strips are byte-identical to the "with shadows" strips (same sizes, same bounding boxes 17×21 incl. shadow). Only the 900×700 grid sheet is truly shadow-free |
| `…/Soldier/Soldier with shadows/*` | — | Same with a ground shadow | Not used (a top-down shadow looks wrong in a side-view platformer) |
| `…/Soldier/Arrow(projectile)/*` | — | Duplicate of the arrow | — |
| `Characters(100x100 split)/Orc/Orc/Orc.png` | 800×600 | Sheet, 8×6 cells | **No shadow. Used for all orc enemies** |
| `…/Orc/Orc/Orc_*.png` (Idle, Walk, Attack01–02, Hurt, Death) | 400–800×100 | Strips | Genuinely shadow-free (match the grid sheet) |
| `…/Orc/Orc with shadows/*` | — | With shadow | Not used |

No NPCs, environment tiles, objects or UI are included in the free pack (the paid pack's other
20 characters and magic projectiles are not in this ZIP).

## Soldier sheet (900×700, cells 100×100, faces right)

Character centre x ≈ 48, feet on y = 57 in every cell. Body ≈ 15×18 px (the Brackeys knight is
13×19: the same scale, so no rescaling is needed).

| Row | Animation | Frames | Opaque boxes (x,y w×h) | Use in the game |
|---|---|---|---|---|
| 0 | Idle | 6 | 41,39 15×18 … breathing bob of 1 px | Knight idle |
| 1 | Walk | 8 | 41,38–40 15×17–19 | Knight run (played at 14 fps); single frames reused for jump / climb |
| 2 | Attack01: horizontal slash | 6 | frames 3–4 reach 36,40 34×20 (white arc in front) | Knight side attack and charged slash |
| 3 | Attack02: overhead chop | 6 | frames 1–2 sword raised (41,31 19×22), frame 3 vertical arc (42,36 28×23) | Knight up attack (raised frames) and down attack (chop frames) |
| 4 | Attack03: bow | 9 | frame 7 releases the arrow (41,39 36×18) | **Hollow Archer** enemy (recoloured) |
| 5 | Hurt | 4 | frame 1 is a full red flash | Knight hurt |
| 6 | Death | 4 | ends collapsed (48,47 19×10) | Knight death; frame 1 (41,41 16×16, kneeling) is the crouch pose |

Palette: 77 opaque colours, no semi-transparent pixels. Steel helmet `#607581 #425c6b #9badb7
#6f828d #c5d0d5`; red cloth `#672020 #8f3838 #4c1a1a #5e1e13 #621914`; skin `#f2dad2`.

**Missing for a platformer:** jump, fall, climb, crouch, landing. They are composed from
existing frames (walk frame 1 = jump, idle frame 2 = fall, walk 1/3 alternating = climb,
death frame 1 = crouch) — no frames are drawn.

## Orc sheet (800×600, cells 100×100, faces right)

Centre x ≈ 55 (the axe hangs in front), feet on y = 57. Body ≈ 22×15 px incl. axe.

| Row | Animation | Frames | Notes | Use |
|---|---|---|---|---|
| 0 | Idle | 6 | 44,41–42 22×15–16 | All orcs |
| 1 | Walk | 8 | | All orcs |
| 2 | Attack01: axe sweep | 6 | frames 1–2 wind up (axe raised behind), 3 sweep arc (45,36 28×26), 4–5 follow-through | Grunt swing (frames 1–2 = telegraph) |
| 3 | Attack02: overhead smash | 6 | frame 3 big arc (45,36 29×30) | Brute ground slam; Warchief combo |
| 4 | Hurt | 4 | frame 1 red flash | Hurt flash |
| 5 | Death | 4 | collapses forward, axe drops | Death |

Palette: 63 colours; skin greens `#7d984b #425916 #5d772d #a3be71 #b8d08a`.

## Integration (see `docs/ASSET_INTEGRATION_REPORT.md`)

Only the two grid sheets and the 32×32 arrow are copied, to `assets/tiny_rpg/`
(`soldier.png`, `orc.png`, `arrow.png`). Everything derived from them is generated by
`tools/build_overhaul_art.gd` (recolours, sprite frames), never edited by hand:

| Generated | From | Purpose |
|---|---|---|
| `resources/players/knight_frames_p1.tres` | soldier.png (crimson, original) | Player One |
| `assets/created/knight_p2.png` + `knight_frames_p2.tres` | soldier.png, cloth recoloured royal blue, helmet trim gold | Player Two |
| `assets/created/hollow_soldier.png` + frames | soldier.png, cloth violet-black, steel darkened | Hollow Archer, Hollow Captain, Crowned Hollow |
| orc frames (`orc_grunt_frames.tres`) | orc.png | Orc Grunt, Orc Warchief (2× scale) |
| `assets/created/orc_brute.png` + frames | orc.png, skin red-brown | Orc Brute |
| `assets/created/orc_guard.png` + frames | orc.png, skin slate grey | Orc Shieldbearer |
| arrow | arrow.png | Archer arrows |

Assets not in the pack and drawn by the generator because a mechanic needs a readable shape
(small, in the same outline style): cave bat (2 frames), saw blade, fire jet, falling rock,
cracked block overlay, shield, pogo lantern, shockwave, spring mushroom states (the mushroom
itself is the Brackeys tileset's large red mushroom).
