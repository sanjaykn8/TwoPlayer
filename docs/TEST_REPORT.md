# Test Report

Only tests that were actually run are recorded here.

## Phase 0: 2026-11-03

| Check | Command / method | Result |
|---|---|---|
| Godot version | `Godot_v4.7.2-stable_win64_console.exe --version` | `4.7.2.stable.official.ed1daf0bf` |
| Project import | `godot --headless --path . --import` | Completed, no errors or warnings |
| Launch | `godot --headless --path . --quit-after 2` | `Error: Can't run project: no main scene defined` (expected; no scenes exist) |
| Sprite sheets readable | Headless `Image.load_from_file` on all 7 PNGs | All load; dimensions and per-cell rects recorded in ASSET_CATALOG |
| Audio readable | Headless `AudioStreamMP3/WAV.load_from_file` | All load. WAV runtime loader prints `Condition "p_position > length"` for coin, explosion, jump, tap (odd-length data chunk, no pad byte). The editor importer is unaffected |
| Asset paths in docs | Script checking every `res://` path in `docs/*.md` exists | 17/17 existing-asset paths found. The only miss is `res://tests/run_tests.gd`, which is a proposed future file, labelled as such |
| No project files modified | `find . -newer GDD.md -not -path ./.godot/*` | Only `CLAUDE.md`, `ROADMAP.md` (edited by the user before this session) |

Gameplay tests: none yet (no gameplay exists).
Manual keyboard tests: none yet (scheduled for Phase 1.4).
