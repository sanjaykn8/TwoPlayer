# Known Issues

Updated 2026-11-03 (end of Phase 8).

## Open

| ID | Severity | Issue | Plan |
|---|---|---|---|
| KI-5 | Major (for Phase 12) | Windows export templates for 4.7.2 are not installed (`%APPDATA%/Godot/export_templates/` is empty). Export and offline verification are impossible until installed | User installs via Editor → Manage Export Templates |
| KI-18 | Verification gap | Phase 2 manual camera tests (`docs/MANUAL_CAMERA_TEST.md`) not yet performed | User |
| KI-25 | Verification gap | Phase 3 manual combat tests (`docs/MANUAL_COMBAT_TEST.md`) not yet performed | User |
| KI-32 | Verification gap | Phase 4 manual enemy tests (`docs/MANUAL_ENEMY_TEST.md`) not yet performed | User |
| KI-38 | Verification gap | Phase 5 manual collectible tests (`docs/MANUAL_COLLECTIBLE_TEST.md`) not yet performed | User |
| KI-46 | Verification gap | Phase 6 manual hazard tests (`docs/MANUAL_HAZARD_TEST.md`) not yet performed | User |
| KI-65 | Verification gap | Phase 8 manual save tests (`docs/MANUAL_SAVE_TEST.md`) not yet performed, including closing with the real window X button and Alt+F4 (automated tests send the same close notification to a real child process) | User |
| KI-66 | Major (Phase 9) | No main menu, slot-selection, overwrite-confirmation or game-over screen yet. The campaign is played through `scenes/campaign/campaign_game.tscn` (slot 1, continue) or the dev harness; the frozen world plus a text notice is the only wipe presentation | Phase 9 |
| KI-67 | Major (Phase 10) | Only two development campaign levels (`w1_l1`, `w1_l2`) exist in `LevelCatalog` | Phase 10 |
| KI-68 | Info | Save on exit covers a normal close (window X, Alt+F4). A killed process or power loss keeps the last completed save (atomic writes protect it), but progress since the last autosave is lost. Not claimed recoverable | By design |
| KI-69 | Info | If the team-wipe marker cannot be written (storage failure), the game halts (fail-closed). Nothing can be written then, so the lost campaign is still on disk and would load on the next launch | Inherent; reported to the player |
| KI-70 | Info | The wipe marker is removed once the fresh run's save is verified. A copy of an old save file restored by hand from outside the game would load again; manual file restoration is out of scope | Accepted |
| KI-71 | Info | After loading: slime AI restarts in IDLE (targets re-sensed), slimes start from rest, poison keeps its remaining time but not the fraction of the current 1 s tick, held plates and partial SYNC/SEQUENCE attempts restart | By design (safe restore) |
| KI-72 | Info | During the team-wipe delay the whole level is frozen, including the dying knight's animation | Phase 9 game-over presentation |
| KI-73 | Info | Dropped coins from slimes without a `save_id` (development rooms) get generated ids (`coin_N`) when saved | Campaign slimes always have ids |
| KI-74 | Info | `project.godot` main scene is still the Phase 1 room | Phase 9 main menu |
| KI-55 | Verification gap | Phase 7 manual puzzle tests (`docs/MANUAL_PUZZLE_TEST.md`) not yet performed, including whether the clues are understandable and the solo-proof timings feel fair | User |
| KI-56 | Info | No pushable or carryable objects (crates, weights). Plates are pressed only by knights (or, when enabled, living slimes) | Add if level design needs it (Phase 10) |
| KI-57 | Info | Level exits / portals and level-to-level transitions are not implemented | Phase 8 / Phase 10 |
| KI-58 | Minor | Gate, plate and target visuals are drawn by code (portcullis, slab, ring target); switches reuse the "!" blocks. Placeholder art | Art polish |
| KI-59 | Info | Design rule: a gate bounces open when a knight reaches its doorway while closing, so a crossing that must need a partner has to take longer than the close delay + 0.3 s slide | Level design (documented in ARCHITECTURE §18) |
| KI-60 | Info | Only completed locks, latched gates/plates and toggled/latched switches are saved. Running timers, held plates and platform positions restart safely on reload | By design; revisit in Phase 8 |
| KI-61 | Info | In the room's separate-route section the camera stays shared (both routes fit one view); split-screen puzzle use is covered by a separate test | By design |
| KI-62 | Info | Puzzle feedback sounds reuse `tap.wav` and `power_up.wav` (pitch-varied) | Phase 9 |
| KI-63 | Info | A knight standing on a plate may have that spot recorded as its safe respawn position; a fall then respawns it onto the plate. Harmless (it can step off) | Accepted |
| KI-49 | Minor | Spike art (`assets/created/spikes.png`) is generated placeholder art; the bundle has no spikes. Hot ground reuses the red-earth tile with a drawn glow | Art polish |
| KI-50 | Minor | `platforms.png` has no repeatable middle piece, so platforms wider than two tiles show a seam every two tiles (and a short end piece for odd widths) | Draw a middle piece during art polish |
| KI-51 | Minor | Under the test-room lava pit the next tile row is drawn as grass-topped ground (auto-tiling sees open space above it) | Cosmetic; production lava pits in Phase 10 |
| KI-52 | Info | Older dev rooms (camera, combat, enemy, collectible) now apply 1 FALL damage when a knight falls out, through the new tracker, before their old no-damage teleport | Expected Phase 6 behaviour |
| KI-54 | Info | Hazard sounds reuse `hurt.wav` and `explosion.wav`; no fall-specific sound | Phase 9 |
| KI-39 | Minor | The bundle has no red bottle: the red jar is the magenta bottle tinted red (plus a faint glint) | Draw a red jar during art polish |
| KI-40 | Minor | Effect feedback is pips above the knight and short pop-up text; there is no proper HUD yet (Phase 9). Effect icons are coloured squares, not sprites | Phase 9 HUD |
| KI-41 | Minor | The red-jar route in the test room is tight by design (each step 48 of 57 px jump height; last gap needs ~33 of ~44 px horizontal). Not yet tried by a human | Tune in manual test 9 |
| KI-42 | Info | Sounds reuse `coin.wav` and `power_up.wav` (pitch-varied), capped at 4 at once; no mixer buses or volume settings yet | Phase 9 |
| KI-44 | Info | Climbing speed is not affected by speed upgrades (only running and crawling) | By design; revisit if wanted |
| KI-45 | Info | `RunState` is a static holder rather than the `Campaign` autoload planned in Phase 0, so the run works identically in the editor, the game and the headless test runner | By design (ARCHITECTURE §16) |
| KI-33 | Minor | The slime sheets have no death or attack animation. Death is a placeholder: hit-flash frame, then a 0.5 s squash and fade made by scaling (briefly non-integer scale). Contact damage has no attack animation | Create death frames during art polish |
| KI-34 | Minor | Slimes cannot jump or path-find; a knight on another level makes them wait, then give up after 3 s | By design for Phase 4 (GDD §18); an enemy-jump capability can be added later |
| KI-36 | Info | When both knights' distinct attacks land in the same tick, one can stagger a slime and the other kill it immediately. This follows the rule (the staggering attack never kills; any other attack does) | By design; revisit after manual testing |
| KI-26 | Minor | No knight attack body animation exists in the asset pack. The generated knife slash (`assets/created/knife_slash.png`, placeholder art) overlays the knight's normal idle/run frames | Create attack pose frames during art polish |
| KI-27 | Minor | The knife slash art does not grow with the range multiplier (pixel art cannot be scaled by 1.1–1.3 cleanly). Red-fruit range upgrades will reach further than the drawn arc | Phase 5: add a longer arc variant or a range indicator |
| KI-28 | Info | On solid ground Up also jumps, so an up attack from the ground is always a jump attack | By design (GDD controls); documented in GDD §18 |
| KI-29 | Info | A dead knight stays dead until `revive()`; only the combat room's F6 calls it. The campaign-wide reset is Phase 8 | By design for Phase 3 |
| KI-30 | Info | Line of sight uses two rays per candidate target (centre and nearest point). A target hidden at both points but visible elsewhere (unusual shapes) is protected | Accepted; revisit if enemies get large hurtboxes |
| KI-31 | Info | Hit feedback is visual only (flash and shake); attack and hit sounds are Phase 9 | Phase 9 |
| KI-9 | Minor (verification gap) | Physical keyboard test is a **user-reported pass**; the keyboard model and layout were not supplied, so results cannot be tied to specific hardware | Re-run `docs/MANUAL_KEYBOARD_TEST.md` on any new keyboard |
| KI-10 | Minor | Jump, fall, crouch and climb use **placeholder** frames | Create frames before art polish (M-3/M-5) |
| KI-17 | Minor | While two nearby knights wait out a merge (hold 0.25 s + alignment 0.3 s), both appear in both halves of the screen. It is one world seen by two cameras, not duplicated objects | Inherent to split-screen; tune `merge_hold_time` / `transition_duration` after manual testing |
| KI-19 | Minor | When the knights are on the "wrong" sides for their fixed views (P1 right of or below P2), split and merge cut instead of sliding. An orientation change is always an instant re-layout | By design (fixed player identity); revisit after manual testing |
| KI-20 | Minor (untested) | Camera smoothness on high-refresh monitors (>60 Hz) with physics interpolation is not verified. Captures were taken at 60 Hz | User reports in manual test 10 |
| KI-21 | Info (untested) | `Parallax2D` in the second view (risk R-8) is untested: no parallax layers exist yet | Verify when backgrounds are added |
| KI-22 | Info | The 2D audio listener will belong to view A; split-screen audio panning is undecided | Phase 9 |
| KI-23 | Info | The Phase 1 room keeps its fixed single view (it fits one screen); the camera is exercised in the camera test room | By design |
| KI-12 | Minor | A rider overlaps the lower knight's plume by a few pixels | Cosmetic |
| KI-13 | Minor | `knight.tscn` defaults to the P1 profile when instanced alone | By design |
| KI-14 | Info | No crouching on one-way platforms (Down drops) | By design (GDD §18) |
| KI-15 | Info | Ladder tops must be one-way tiles | Level-design rule |
| KI-16 | Info | A release and re-press within one 16 ms tick is not a new press | Accepted |
| KI-24 | Info | Godot 4.7.2: a static function returning its own class's enum must spell the type `ClassName.Enum`, or typed callers reject it | Convention recorded in CLAUDE.md |
| KI-4 | Info | WAV runtime `load_from_file` warns (odd data chunks); imported resources are fine | Never load WAVs from source at runtime |
| KI-7 | Info | Main scene is the Phase 1 development room | Replace with the main menu in Phase 9 |

## Resolved

| ID | Issue | Resolution |
|---|---|---|
| KI-64 | Live puzzle elements kept the registry of the old run after `RunState.reset()` | Phase 8: the team wipe and new runs always rebuild the level |
| KI-53 | Timed platforms could only cycle on their own | Phase 7: `PlatformController` TRIGGER calls `activate()` (the default scene still auto-reactivates when unwired) |
| KI-47 | No campaign-wide team wipe | Phase 8 `CampaignGame` team wipe (dev rooms still revive with F3) |
| KI-43 | Dropped coins not saved | Phase 8 world snapshot with stable coin ids |
| KI-37 | Defeated slimes not saved | Phase 8 `save_id` + defeat record |
| KI-48 | Platform states and safe positions not saved | Phase 8 world snapshot |
| KI-35 | Dropped coins could not be collected | Phase 5: CoinPickup, shared RunState total, 10 % heal |
| KI-11 | No camera system | Phase 2 `SplitScreenRig` (camera test room) |
| KI-1 | Linear (blurry) texture filtering | Nearest filter (Phase 1); SubViewports set Nearest explicitly (Phase 2) |
| KI-2 | Pixel font imported with antialiasing | Fixed (Phase 1) |
| KI-3 | Music imported without loop | Fixed (Phase 1) |
| KI-6 | Save folder tied to project name | `TwoKnightCoop` (Phase 1) |
| KI-8 | No version control | Git: `b5c605b`, `4d5c6b0` |
