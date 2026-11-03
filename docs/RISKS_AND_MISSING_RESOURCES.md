# Missing Resources and Technical Risks

Phase 0 audit, 2026-11-03.

## Part A: missing or incomplete resources

"Create" means we author it (pixel art drawn to match the bundle's 16 px grid and
palette, or generated with a script). Nothing is downloaded.

### A1. Art

| # | Resource | Needed by | Severity | Plan |
|---|---|---|---|---|
| M-1 | Knife sprite + slash arc (right/left/up/down) | Combat (Phase 3) | **Blocker for Phase 3** | Create ~8×3 px knife + 3–4 frame arc. Rotate/flip for directions |
| M-2 | Knight attack pose | Combat | Major | Overlay the knife on idle/run frames with a 1–2 px lunge offset. New body frames optional |
| M-3 | Knight jump / fall frames | Movement (Phase 1) | Major | Short-term: run frames 2 and 10 (legs extended) as jump/fall. Long-term: 2 created frames |
| M-4 | Knight crouch | Movement | Minor | Use roll frames (5,2)/(5,6) (13×15 px compact pose) |
| M-5 | Knight climb (back view) | Ladders (Phase 1) | Major | Create 2 frames. Interim: idle frame 0 with alternating `flip_h` |
| M-6 | Player 2 colours | Readability | **Blocker for Phase 1 sign-off** | Palette-swap shader: `#0a7030` tunic → blue, `#d2202c` plume → light colour. Exact-colour match (7-colour palette verified) |
| M-7 | Slime death | Enemies (Phase 4) | Major | Hit flash (frame 10) → squash tween → CPU particles in slime colours |
| M-8 | Stagger indicator | Enemies | Major (GDD: must be visible) | Puddle frames 0–1 + pulsing white tint shader + small "dizzy" pixels |
| M-9 | Ladder tile | Ladders | **Blocker for ladder levels** | Create 16×16 tileable ladder (wood colours from tileset) |
| M-10 | Spikes | Hazards (Phase 6) | Blocker for Phase 6 | Create 16×16 (and 16×8) spikes in grey stone palette |
| M-11 | Hot ground | Hazards | Minor | Red-earth tiles (4,1)/(5,1) + animated glow shader |
| M-12 | Doors, gates, pressure plates, switches/levers, exit portal, target | Puzzles (Phase 7) | Blocker for Phase 7 | Create. "!" blocks and crates can stand in during prototyping |
| M-13 | Red jar | Collectibles | Minor | Hue-shift magenta bottle (1,8) to red |
| M-14 | Power tile inactive state | Collectibles | Minor | Modulate "?" block grey while on cooldown |
| M-15 | HUD: hearts, effect icons, panel frames | UI (Phase 9) | Major | Create 8×8 hearts. Reuse fruit/jar sprites as effect icons. 9-slice panel |
| M-16 | Boss art | Optional bosses | Minor (optional content) | Scaled ×2 slime with a third palette, or new art later |
| M-17 | Terrain edges / corners / slopes | Level art | Minor (cosmetic) | None in tileset. Square edges are acceptable; add later if needed |
| M-18 | Platform middle segment | Wide moving platforms | Minor | Chain short pieces or create a middle tile |
| M-19 | World themes 5–6 (Dark Fortress, Final Citadel) | Phase 10 | Minor | Grey stone + purple/grey sky strips with `CanvasModulate` darkening |
| M-20 | Game icon | Export | Minor | Currently the default Godot `icon.svg` |

### A2. Audio

| # | Resource | Plan |
|---|---|---|
| M-21 | Attack swing | Interim: `tap.wav` pitched down. Prefer a created short noise-sweep WAV |
| M-22 | Enemy hit / stagger | Interim: `hurt.wav` pitched up / `tap.wav` |
| M-23 | Hazard sizzle, level transition, game over, victory jingle | Interim: `explosion.wav` / `power_up.wav` variants. Create if feedback is unclear |
| M-24 | Music variety | Only one 40 s track. Acceptable for the vertical slice. Flag for later (risk R-23) |

### A3. Project resources (all must be authored; none exist)

TileSet (`world_tileset.png` + `platforms.png`, physics layers for solid/one-way,
custom data for hazard type), SpriteFrames for knight and slimes, AudioBusLayout
(`Master`/`Music`/`SFX`), Theme (Pixel Operator 8, nearest), balance `.tres` files,
InputMap actions, export preset, main scene.

### A4. Tooling

| # | Item | Status |
|---|---|---|
| T-1 | Godot 4.7.2 editor + console binary | Present: `C:/Users/Reaper/Downloads/Godot/` |
| T-2 | Windows export templates 4.7.2 | **Missing** (`%APPDATA%/Godot/export_templates/` empty). Install via Editor → Manage Export Templates (one-time, development-time download; the game itself stays offline) |
| T-3 | Git | Installed (2.54). Project not yet a repository |
| T-4 | Test framework | None. Plan: own headless runner (no plugin download) |

---

## Part B: technical risks

Likelihood/Impact: H/M/L. Every risk has a concrete verification step. None is
marked resolved until that step has been run.

### Input

**R-1 Alt opens the window menu / freezes input (Windows).**
A lone Alt press-release sends `WM_SYSKEYUP`, which the default window procedure turns
into `SC_KEYMENU` ("menu mode"). In menu mode the next key goes to the system menu, and
the game can appear to drop input for a moment. Godot's Windows display server is
believed to swallow keyboard-initiated `SC_KEYMENU`. **That is not yet verified on this
machine with 4.7.2.**
L: M · I: H.
*Mitigation:* rely on engine behaviour first. If the menu still activates, handle it
in-engine without intercepting system shortcuts. Never hook Alt+Tab.
*Verify (Phase 1):* run an exported/standalone window (not the editor-embedded Game tab),
tap Alt repeatedly and then press Arrow/WASD immediately. All input must register.
Hold Alt and play P1 for 30 s. Alt+Tab must still switch windows.

**R-2 Right Alt is AltGr on some keyboard layouts.**
With an AltGr layout, Windows reports Right Alt as Left Ctrl + Right Alt. Godot may
then see a Ctrl press and a different key location. The US layout (likely here) does
not do this.
L: L–M · I: M.
*Mitigation:* bind `p2_attack` to `KEY_ALT` with location unspecified. Bind nothing to Ctrl.
*Verify:* an input probe scene shows Left Alt and Right Alt each firing `p2_attack`.
Repeat after switching the Windows layout if the players use another one.

**R-3 Held Alt alters other keys' events.**
While P2 holds Alt, P1's W/A/S/D/V arrive as `WM_SYSKEYDOWN` with `alt_pressed = true`.
Godot action matching ignores extra modifiers when the action's event has none, so this
should work. Combinations such as Alt+Space (system menu) and Alt+F4 (close) are not
bound, so cannot trigger accidentally. Alt+Enter is not bound to fullscreen.
L: M · I: H.
*Verify:* automated test feeding `InputEventKey` with `alt_pressed = true` for P1 keys.
Manual test with Alt held.

**R-4 Keyboard ghosting and rollover limits.**
Membrane keyboards (especially laptops) can drop the 3rd–4th simultaneous key on shared
matrix lines. Worst realistic chord here: P1 A/D + W + V, P2 ←/→ + ↑, plus Alt. That is
5 non-modifier keys plus Alt. Alt is a modifier and is usually wired outside the matrix
and outside the USB 6-key limit, which makes it a robust attack key. V is the most likely
P1 key to ghost with A+W or S+D.
L: H on laptops · I: H. This cannot be fixed in software.
*Mitigation:* (a) ship an in-game **Controls Test** screen showing every action's live state
for both players; (b) level design never requires more than 3 simultaneous keys per player;
(c) jump/attack input buffering (~100 ms) to soften drops; (d) document the tested
keyboard in `docs/TEST_REPORT.md`. Optional key remapping would contradict the fixed GDD
controls. It is listed as decision D-14 rather than assumed.
*Verify (Phase 1):* two people on the actual keyboard run the probe through a chord list
(see `docs/IMPLEMENTATION_PLAN.md` §4).

**R-5 Simultaneous-input fairness.** Both players are processed in a fixed order in
`_physics_process`. The order must not decide outcomes such as who picks up a fruit.
*Mitigation:* pickups are claimed through a guard flag; ties go to the first processed
player deterministically. Push is symmetric.
*Verify:* tests with both players overlapping one pickup on the same frame.

**R-27 Godot editor's embedded Game window.** Godot 4.x can embed the running game in the
editor. Alt and focus behaviour there differs from a real window, so results from it are
invalid for R-1–R-4. *Mitigation:* run input tests in a separate window or an export.

### Movement

**R-6 Context-sensitive vertical input ambiguity.** Up means jump, climb or passage; Down
means crouch, drop or climb. Wrong priority causes accidental jumps off ladders or
inability to crouch. *Mitigation:* one resolution function with the priority table in
ARCHITECTURE §5, unit-tested per context. Known consequence: no crouching on one-way
platforms (Down drops). *Verify:* table-driven unit tests plus manual ladder-top /
ladder-bottom / platform cases.

**R-7 One player traps or blocks the other.** Physical body blocking in 1-tile corridors,
standing on a head under a low ceiling, overlap after respawn. *Mitigation:* no mutual
`CharacterBody2D` collision; capped push via sensor; push into a wall stops. Head-standing
per D-3. *Verify:* corridor test (both walk into each other for 5 s, then both can
reverse), respawn-overlap test.

**R-20 Attacks through walls / thin-wall tunnelling.** *Mitigation:* LOS ray from
chest to target. Hitbox never extends past one tile. *Verify:* slime behind a 1-tile wall
cannot be hit from any direction.

### Camera

**R-8 Parallax in the second SubViewport.** `Parallax2D` derives its offset from its own
viewport's camera. When two SubViewports share one `World2D`, the node exists once.
The second view may show the wrong background offset. L: M · I: L (cosmetic).
*Mitigation:* verify early. The fallback is a static or per-view background.

**R-9 Visibility guarantee in split/shared modes.** Vertical shafts and long corridors
can push a player off-screen before the split threshold triggers if the thresholds are
not axis-aware. *Mitigation:* axis-specific thresholds strictly inside the visible
half-extents minus a margin. Automated check that, every frame of a scripted separation,
each player's rect lies inside at least one active camera rect.

**R-10 Pixel jitter.** Smoothed cameras at sub-pixel positions with viewport stretch
cause sprite shimmer. *Mitigation:* 640×360 base, integer scaling, snap 2D transforms to
pixel. Test both modes at 1080p and 720p.

**R-11 HUD in split mode.** *Mitigation:* HUD is a separate CanvasLayer with fixed
corners, independent of view layout. *Verify:* screenshot each mode/orientation.

**R-12 Renderer.** Forward+ with D3D12 is a 3D-oriented pipeline. On older or integrated
GPUs it adds startup cost and first-run shader-compile hitches. The Compatibility
renderer (OpenGL 3.3) is the usual choice for 2D pixel games and runs on more machines.
*Decision D-10.*

### Campaign, death and saves

**R-13 Stale async events after a team wipe.** Tweens, timers, `await`, deferred calls
from the old run (for example a coin pickup finishing, a timed gate closing, an autosave
zone firing) could modify the fresh run. *Mitigation:* `run_id` / `scene_generation`
tokens checked by every async continuation; the old level freed before the new one is
created; `team_wipe()` idempotent. *Verify:* test that dies while a timed effect, a
collectible tween and an autosave are pending, then asserts fresh state after 5 s.

**R-14 Death vs quit race.** If the game is closed between the death and the save commit,
the old run would survive. *Mitigation:* the fresh campaign is written synchronously
inside `team_wipe()` before any transition, and save-on-exit is skipped in `GAME_OVER`.
Residual risk: a hard kill (Task Manager / power loss) inside the few-millisecond write
window. Documented as accepted.

**R-15 Atomic replacement on Windows.** Rename-over-existing semantics and antivirus or
indexer file locks differ from POSIX. *Mitigation:* write `.tmp`, verify by re-reading,
replace, and retry briefly on failure. Never leave the slot without a valid file.
Deliberately **no** `.bak` of a previous run (it could resurrect a wiped campaign).
*Verify:* tests that simulate interrupted writes (truncated `.tmp`, leftover `.tmp`,
corrupt main file) and confirm safe outcomes.

**R-16 Save schema drift.** 24 levels × many objects. *Mitigation:* `persist_id` per
object, validation test for uniqueness, save `version` plus migration functions,
strict validation before applying.

**R-17 Timed effects while closed.** Store *remaining seconds*, never wall-clock
timestamps. Ticked only while unpaused.

**R-18 Save location tied to project name.** `user://` resolves to
`%APPDATA%/Godot/app_userdata/2p/`. Renaming the project moves saves.
*Mitigation:* pin `custom_user_dir_name` before the first save exists (decision D-12).

**R-21 Duplicate pickup or damage events.** Area overlaps can fire twice (both players,
re-entry, same frame). *Mitigation:* claim-before-apply guard on pickups; invulnerability
plus a per-source cooldown on hazards. *Verify:* automated duplicate-overlap tests.

### Offline and export

**R-19 Export templates missing.** Without them, "offline execution verified" and
"release build launched" cannot be checked. *Mitigation:* install templates now and do
a throwaway export of the vertical slice in Phase 2–3, not in Phase 12.

**Offline guard.** Godot's exported runtime makes no network calls by itself. Risk comes
only from our code. *Mitigation:* static test fails on `HTTPRequest`, `HTTPClient`,
`StreamPeerTCP`, `WebSocket*`, `ENet*` or URL literals in game scripts. Font
`allow_system_fallback` turned off so rendering does not depend on installed system fonts.
*Final verification:* launch the export with the network adapter disabled.

### Content and process

**R-22 Art gaps** (M-1…M-12) can stall phases. Create placeholders that follow the final
dimensions so swapping art never changes collision.

**R-23 Music fatigue.** One 40 s loop over 90–120 minutes. Low priority. Raise at Phase 9.

**R-24 Content scale.** 24 substantial levels hitting 90–120 minutes is the largest
production cost. *Mitigation:* the vertical slice validates the level-authoring workflow
(TileMapLayer + component scenes + `persist_id` validation) before Phase 10.

**R-25 Test limits.** I can run headless and automated tests and launch the game, but I
cannot physically press two players' keys on your keyboard. Keyboard ghosting, Alt
behaviour, feel and readability need you (and a second person) to run the manual
checklists. Results will be recorded only as reported.

**R-26 Pixel font rendering.** Current import settings (antialiasing on, subpixel
positioning) blur Pixel Operator 8. Fix in Phase 1.
