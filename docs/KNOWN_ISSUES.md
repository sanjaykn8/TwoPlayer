# Known Issues

| ID | Severity | Issue | Status |
|---|---|---|---|
| KI-1 | Major | Pixel art renders with linear filtering (project default) | Open, fix in Phase 1.1 |
| KI-2 | Minor | Pixel Operator 8 imported with antialiasing/subpixel positioning | Open, fix in Phase 1.1 |
| KI-3 | Minor | `time_for_adventure.mp3` imported with `loop=false` | Open, fix in Phase 1.1 |
| KI-4 | Minor | WAV files have odd-length data chunks; runtime `load_from_file` warns. Imported resources are fine | Accepted. Never load WAVs from source at runtime |
| KI-5 | Major | Windows export templates not installed; offline/export verification impossible until installed | Open, user action |
| KI-6 | Major | Save folder tied to project name "2p" | Open, fix in Phase 1.1 (D-12) |
| KI-7 | Info | No main scene; project cannot be launched yet | Expected before Phase 1 |
| KI-8 | Info | Not under version control: there are no rollback points, so existing files are inspected before every overwrite | Deferred by user (D-11) |
