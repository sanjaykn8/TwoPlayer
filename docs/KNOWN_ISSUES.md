# Known Issues

Updated 2026-11-03 (end of Phase 1).

## Open

| ID | Severity | Issue | Plan |
|---|---|---|---|
| KI-5 | Major (for Phase 12) | Windows export templates for 4.7.2 are not installed (`%APPDATA%/Godot/export_templates/` is empty). Export and offline verification are impossible until installed | User installs via Editor → Manage Export Templates. Not needed for Phases 1–2 |
| KI-9 | Major (verification gap) | Physical keyboard behaviour is unverified: ghosting/rollover, Windows Alt menu-mode, Left vs Right Alt reporting, AltGr layouts | User runs `docs/MANUAL_KEYBOARD_TEST.md` |
| KI-10 | Minor | Jump, fall, crouch and climb use **placeholder** frames: run stride (2,0), roll recovery (7,5), compact roll pose (2,5), and the idle frame flipped while climbing. No real back-view climb or jump art exists in the bundle | Create frames before art polish (asset gap M-3/M-5) |
| KI-11 | Minor | The test room has a fixed view (no camera). Areas outside 640×360 cannot be tested yet | Phase 2 camera |
| KI-12 | Minor | A rider standing on the other knight overlaps the lower knight's plume by a few pixels (collider 18 px vs sprite plume ~20 px) | Cosmetic; revisit with final art |
| KI-13 | Minor | `knight.tscn` defaults to the P1 profile when instanced alone. Levels must set the P2 profile explicitly | By design; level spawner in later phases will assign profiles |
| KI-14 | Info | Down on a one-way platform always drops, so knights cannot crouch on one-way platforms (GDD §18) | By design |
| KI-15 | Info | Ladder tops must be one-way tiles. A solid tile at a ladder top blocks climbing out | Level-design rule (ARCHITECTURE §13) |
| KI-16 | Info | Pressing and releasing a key within one 16 ms physics tick while it was already held is not seen as a new press. This cannot happen with human input | Accepted |
| KI-4 | Info | WAV files have odd-length data chunks; runtime `load_from_file` warns. Imported resources are fine | Never load WAVs from source at runtime |
| KI-7 | Info | Main scene is the development test room | Replace with the main menu in Phase 9 |

## Resolved

| ID | Issue | Resolution |
|---|---|---|
| KI-1 | Linear (blurry) texture filtering | Nearest filter set project-wide (Phase 1) |
| KI-2 | Pixel font imported with antialiasing | Antialiasing, hinting, subpixel positioning and system fallback off (Phase 1) |
| KI-3 | Music imported without loop | `loop=true` (Phase 1) |
| KI-6 | Save folder tied to project name "2p" | `custom_user_dir_name = "TwoKnightCoop"` (Phase 1) |
| KI-8 | No version control | Git baseline commit `b5c605b` (Phase 1) |
