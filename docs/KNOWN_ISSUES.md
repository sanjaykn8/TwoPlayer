# Known Issues

Updated 2026-11-03 (end of Phase 2).

## Open

| ID | Severity | Issue | Plan |
|---|---|---|---|
| KI-5 | Major (for Phase 12) | Windows export templates for 4.7.2 are not installed (`%APPDATA%/Godot/export_templates/` is empty). Export and offline verification are impossible until installed | User installs via Editor → Manage Export Templates |
| KI-18 | Verification gap | Phase 2 manual camera tests (`docs/MANUAL_CAMERA_TEST.md`) not yet performed | User |
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
| KI-11 | No camera system | Phase 2 `SplitScreenRig` (camera test room) |
| KI-1 | Linear (blurry) texture filtering | Nearest filter (Phase 1); SubViewports set Nearest explicitly (Phase 2) |
| KI-2 | Pixel font imported with antialiasing | Fixed (Phase 1) |
| KI-3 | Music imported without loop | Fixed (Phase 1) |
| KI-6 | Save folder tied to project name | `TwoKnightCoop` (Phase 1) |
| KI-8 | No version control | Git: `b5c605b`, `4d5c6b0` |
