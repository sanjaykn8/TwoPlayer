# DEVELOPMENT ROADMAP
## Two-Player Cooperative Platformer

## Development Philosophy

Build a complete playable foundation first.

Do not begin large-scale level production until movement, camera, combat, enemy AI, health, collectibles, death and persistence are working.

Every phase must produce a working and testable result.

---

# PHASE 0 — Existing Project Audit

### Objectives
Understand the existing Godot project and downloaded asset bundle.

### Tasks
- Inspect project.godot.
- Inspect the current Godot version.
- Inventory all extracted assets.
- Identify character sprites.
- Identify slime sprites.
- Identify tilesets.
- Inspect animations and audio.
- Identify suitable collectible assets.
- Check existing scripts and scenes.
- Create an asset catalog.
- Establish a clean project architecture.
- Initialize version control if appropriate.

### Deliverables
- ASSET_CATALOG.md.
- ARCHITECTURE.md.
- Updated project structure proposal.
- Development task checklist.

### Completion gate
No unknown asset paths or undocumented existing systems should be treated as usable resources.

# PHASE 1 — Core Project and Player Foundation

### Objectives
Get both knights moving in the same playable scene.

### Tasks
- Configure project resolution.
- Configure pixel-art rendering.
- Create reusable player scene.
- Configure Player One input.
- Configure Player Two input.
- Implement horizontal movement.
- Implement jumping.
- Implement variable-height jumping if supported.
- Implement crouching.
- Implement one-way platform dropping.
- Implement ladder climbing.
- Implement player collisions.
- Implement controlled pushing between players.
- Configure initial health.
- Add basic animation state management.

### Required controls
Player One: WASD + V.

Player Two: Arrows + Alt.

### Completion gate
Both players must move, jump, climb and interact simultaneously without input interference.

Test on the actual Windows keyboard.

# PHASE 2 — Camera and Split-Screen

### Objectives
Implement a camera that supports both nearby and distant players.

### Tasks
- Shared camera.
- Midpoint tracking.
- Distance-based split trigger.
- Individual player cameras.
- Vertical split mode.
- Horizontal split mode.
- Camera merge threshold.
- Hysteresis.
- Smooth transitions.
- HUD positioning in both modes.

### Completion gate
Players must not disappear from view when separated. Camera switching must not flicker.

# PHASE 3 — Combat and Health

### Objectives
Create reliable directional combat.

### Tasks
- Knife model or sprite.
- Sword-like swing animation.
- Last-movement-based attack direction.
- Four cardinal-direction hitboxes.
- Attack cooldown.
- Attack animation timing.
- Single-hit-per-swing protection.
- Health component.
- Damage processing.
- Temporary post-hit immunity.
- Death handling.

### Completion gate
Both knights can attack independently in all four supported directions.

Health must never become negative, and multiple damage events from one collision must not occur accidentally.

# PHASE 4 — Slime Enemies and Enemy AI

### Objectives
Build the complete enemy foundation.

### Tasks
- Reusable slime base scene.
- Green slime.
- Purple slime.
- Patrol movement.
- Detection area.
- Player detection.
- Chase state.
- Twice-normal chase speed.
- Contact damage.
- Stagger thresholds.
- Stagger animations.
- Vulnerability window.
- Recovery.
- Enemy death.
- Coin drop.

### Completion gate
Verify:
- Green slime staggered after two base-power hits.
- Purple slime staggered after four base-power hits.
- Stagger duration is at least ten seconds.
- One additional melee hit kills a staggered slime.
- Enemy recovery resets the stagger counter.
- Each defeated slime drops four to six coins.

# PHASE 5 — Collectibles and Progression

### Objectives
Implement all collectible systems.

### Tasks
- Coin collection.
- Shared coin counter.
- Independent 10% healing lottery.
- Green health fruit.
- Yellow protective fruit.
- Red attack-range fruit.
- Purple poison fruit.
- Green permanent jar.
- Red permanent jar.
- Yellow timed jar.
- Blue permanent jar.
- Five-second random power tiles.
- Collection persistence.
- Effect timers.
- Player-specific effects.

### Completion gate
Test every collectible independently, including interactions between health upgrades, healing, attack power and poison.

No collectible should apply its effect twice because of duplicate collision events.

# PHASE 6 — Hazards and Platforming Mechanics

### Objectives
Make the environment dangerous and mechanically interesting.

### Tasks
- Spikes.
- Hot ground.
- Lava.
- Falling boundaries.
- Safe respawn positions.
- Moving platforms.
- Timed platforms.
- Disappearing platforms.
- Collapsing platforms.
- Narrow passages.
- Climbing areas.
- Precision jumps.

### Completion gate
Each hazard must apply its specified consequence exactly once per damage event.

Falling must respawn the affected player with one health point removed.

Lava must cause immediate campaign death.

# PHASE 7 — Cooperative Puzzle Systems

### Objectives
Build the mechanics that make the game genuinely cooperative.

### Tasks
- Pressure plates.
- Simultaneous activation.
- Switch-controlled doors.
- Timed gates.
- Separate paths.
- Moving-platform coordination.
- Enemy distraction puzzles.
- Multiple targets.
- Shared mechanisms.
- Environmental clues.
- Optional sacrifice/risk mechanics.

### Completion gate
Every puzzle must have a valid solution with two players.

Test:
- Players arriving in different orders.
- One player dying during a puzzle.
- Players moving away from activated switches.
- Pausing during timed mechanisms.
- Reloading after puzzle progress is saved.

Prevent softlocks.

# PHASE 8 — Death, Campaign Reset and Save System

### Objectives
Make progression reliable while preserving the unforgiving death rule.

### Tasks
- Four save slots.
- New campaign.
- Continue campaign.
- Local save data.
- Save versioning.
- Save-on-exit.
- Automatic milestone saves.
- Player-state serialization.
- Enemy-state serialization.
- Collectible-state serialization.
- Puzzle-state serialization.
- Timed effect restoration.
- Save validation.
- Invalid-save handling.
- Full campaign reset.
- Fresh campaign creation after team wipe.

### Completion gate
Perform these tests:

1. Start a campaign.
2. Collect coins and permanent upgrades.
3. Complete multiple levels.
4. Activate puzzles and mechanisms.
5. Save and quit.
6. Relaunch the game.
7. Continue the same campaign.
8. Verify all saved states.
9. Die with either knight.
10. Verify that the entire campaign resets.
11. Confirm that the old campaign cannot be resumed through Continue.
12. Confirm the other three save slots remain untouched.

# PHASE 9 — Game Interface and Audio

### Objectives
Make the game understandable and complete.

### Tasks
- Main menu.
- Four-slot selection.
- New Game.
- Continue.
- Settings.
- Pause.
- Player health displays.
- Coin display.
- Timed-effect indicators.
- World and level indicator.
- Game-over screen.
- Victory screen.
- Controls guide.
- Music.
- Sound effects.
- Audio settings.

### Completion gate
Every menu and interface element must work using the keyboard.

HUD elements must remain readable in shared and split-screen modes.

# PHASE 10 — World and Level Production

### Objectives
Build the entire campaign using validated mechanics.

### Campaign structure

Six worlds, four main levels per world.

Total: 24 main levels.

Each world should contain:
- A distinct visual environment.
- New combinations of hazards.
- Increasing enemy difficulty.
- New cooperative puzzle variations.
- Hidden collectibles.
- Difficult optional paths.
- Environmental clues.
- An exit to the next stage.

Include optional boss encounters and reward areas.

### Level progression

World 1:
Teach the basic mechanics without making the opening trivial.

World 2:
Introduce enemy combinations and moving-platform challenges.

World 3:
Introduce complex mechanisms and separated routes.

World 4:
Introduce increasingly dangerous environmental hazards.

World 5:
Combine demanding platforming, combat and multi-stage cooperative puzzles.

World 6:
Use the hardest combinations of previously introduced mechanics.

### Completion gate
All 24 levels must be playable from beginning to end.

Target a measured 90–120-minute successful first playthrough.

Do not inflate duration using excessive empty corridors, repetitive enemy encounters or artificial waiting.

# PHASE 11 — Balancing and Game Testing

### Objectives
Test the game as a complete campaign.

### Tasks
- Test all input combinations.
- Test keyboard ghosting.
- Test both players in combat simultaneously.
- Test split-screen transitions.
- Test all enemy thresholds.
- Test damage and invulnerability.
- Test fruit and jar combinations.
- Test random power effects.
- Test difficult platform sequences.
- Test cooperative puzzle completion.
- Test every exit.
- Test all save slots.
- Test campaign reset.
- Test restart after death.
- Test invalid and missing save data.
- Test game exit during gameplay.
- Test game exit during transitions.
- Test performance in crowded areas.

### Completion gate
No critical or major gameplay bugs may remain.

There must be no known campaign-blocking softlocks.

# PHASE 12 — Export and Final Validation

### Objectives
Prepare the finished Windows game.

### Tasks
- Configure Windows export.
- Verify all assets are included.
- Verify scene dependencies.
- Validate save locations.
- Verify offline execution.
- Test a fresh installation.
- Test without the Godot editor open.
- Test after restarting Windows.
- Create a clean release build.
- Write a short user manual.

### Deliverables
- Windows executable.
- Exported game data.
- Four-slot save system.
- Final test report.
- Known-issues document.
- Basic controls and gameplay manual.

### Final completion gate

A fresh player must be able to:
1. Launch the exported game.
2. Start a new two-player campaign.
3. Play all main worlds.
4. Save and resume.
5. Experience the full team-wipe mechanic.
6. Complete the final level.
7. Play without internet connectivity.

Do not declare release readiness until these requirements have been verified.

---

# DEVELOPMENT TRACKING

Maintain a checklist of every task.

For each task, record:
- Not started.
- In progress.
- Implemented.
- Tested.
- Failed.
- Blocked.

Every completed task must have a corresponding validation result.

Do not mark a whole phase complete merely because its scripts exist.

Always prioritize a stable playable game over rapidly generated content.
---

# STATUS LOG

| Phase | Status | Evidence |
|---|---|---|
| Phase 0: Existing Project Audit | Tested | `docs/AUDIT_REPORT.md` (2026-11-03) |
| Phase 1: Core Project and Player Foundation | Tested. Physical keyboard: **user-reported pass** (model and layout not supplied) | `docs/PHASE_1_SUMMARY.md`, `docs/TEST_REPORT.md`; commit `4d5c6b0` |
| Phase 2: Camera and Split-Screen | Implemented and auto-tested (74/74 including Phase 1 regression); **manual camera tests pending** | `docs/PHASE_2_SUMMARY.md`, `docs/TEST_REPORT.md`, `docs/MANUAL_CAMERA_TEST.md` |
| Phase 3: Combat and Health | Implemented and auto-tested (110/110 including Phase 1–2 regression); **manual combat tests pending** | `docs/PHASE_3_SUMMARY.md`, `docs/TEST_REPORT.md`, `docs/MANUAL_COMBAT_TEST.md` |
| Phase 4: Slime Enemies and Enemy AI | Implemented and auto-tested (144/144 including Phase 1–3 regression); **manual enemy tests pending** | `docs/PHASE_4_SUMMARY.md`, `docs/TEST_REPORT.md`, `docs/MANUAL_ENEMY_TEST.md` |
| Phase 5: Collectibles and Progression | Implemented and auto-tested (178/178 including Phase 1–4 regression); **manual collectible tests pending** | `docs/PHASE_5_SUMMARY.md`, `docs/TEST_REPORT.md`, `docs/MANUAL_COLLECTIBLE_TEST.md` |
| Phase 6: Hazards and Platforming Mechanics | Implemented and auto-tested (229/229 including Phase 1–5 regression); **manual hazard tests pending** | `docs/PHASE_6_SUMMARY.md`, `docs/TEST_REPORT.md`, `docs/MANUAL_HAZARD_TEST.md` |
| Phase 7: Cooperative Puzzle Systems | Not started | Waiting for authorisation |
| Phases 8–12 | Not started | — |

Phase 1 task tracking:

| Task | Status |
|---|---|
| Configure project resolution (640×360, integer scale, 1280×720 window) | Tested |
| Configure pixel-art rendering (Compatibility, Nearest, pixel snap) | Tested |
| Create reusable player scene | Tested |
| Configure Player One input | Tested (automated); physical test pending |
| Configure Player Two input (Left/Right Alt) | Tested (automated); physical test pending |
| Horizontal movement | Tested (automated); feel pending |
| Jumping | Tested (automated) |
| Variable-height jumping | Tested (automated) |
| Crouching | Tested (automated) |
| One-way platform dropping | Tested (automated) |
| Ladder climbing (and vertical passages) | Tested (automated) |
| Player collisions | Tested (automated) |
| Controlled pushing between players | Tested (automated) |
| Initial health | Tested (automated) |
| Basic animation state management | Implemented; jump/fall/crouch/climb use placeholder frames |

Phase 2 task tracking:

| Task | Status |
|---|---|
| Shared camera | Tested (automated); manual pending |
| Midpoint tracking | Tested |
| Distance-based split trigger (viewport-relative, plus visibility guard) | Tested |
| Individual player cameras | Tested |
| Vertical split mode (side by side) | Tested |
| Horizontal split mode (stacked) | Tested |
| Camera merge threshold | Tested |
| Hysteresis (mode and orientation) | Tested |
| Smooth transitions (seamless split, aligned merge) | Tested (math + rendered pixel comparison); manual pending |
| HUD positioning in both modes | Debug overlay sits outside the rig and works in all modes; the real HUD is Phase 9 |
| Level camera bounds | Tested |
| Window resizing | Tested (rig layout + rendered run at 3 window sizes); manual pending |

Phase 3 task tracking:

| Task | Status |
|---|---|
| Knife model or sprite | Implemented (generated `knife_slash.png`); placeholder art |
| Sword-like swing animation | Implemented (4-frame arc, rotated per direction); body attack pose not available in assets |
| Last-movement-based attack direction | Tested |
| Four cardinal-direction hitboxes (+ D-2 low slash) | Tested |
| Attack cooldown | Tested |
| Attack animation timing | Tested (frame-exact) |
| Single-hit-per-swing protection | Tested |
| Health component | Tested |
| Damage processing (categories) | Tested |
| Temporary post-hit immunity | Tested |
| Death handling (per knight; campaign reset is Phase 8) | Tested |

Phase 4 task tracking:

| Task | Status |
|---|---|
| Reusable slime base scene | Tested |
| Green slime | Tested |
| Purple slime | Tested |
| Patrol movement | Tested |
| Detection area | Tested |
| Player detection (line of sight) | Tested |
| Chase state | Tested |
| Twice-normal chase speed | Tested (exact) |
| Contact damage | Tested |
| Stagger thresholds | Tested |
| Stagger animations | Implemented (puddle frames, pulse, stars); visual check from captures only |
| Vulnerability window (>= 10 s) | Tested (exactly 600 ticks) |
| Recovery | Tested |
| Enemy death | Tested |
| Coin drop (4-6, event + visible coins) | Tested; collection is Phase 5 |

Phase 5 task tracking:

| Task | Status |
|---|---|
| Coin collection | Tested |
| Shared coin counter | Tested |
| Independent 10% healing lottery | Tested (exact 10 of 100 outcomes) |
| Green health fruit (3 tiers) | Tested |
| Yellow protective fruit (3 tiers) | Tested |
| Red attack-range fruit (3 tiers) | Tested |
| Purple poison fruit (3 tiers) | Tested |
| Green permanent jar | Tested |
| Red permanent jar | Tested |
| Yellow timed jar | Tested |
| Blue permanent jar | Tested |
| Five-second random power tiles | Tested |
| Collection persistence (run ids, scene changes) | Tested; disk saving is Phase 8 |
| Effect timers | Tested (pause, freeze between levels, exact expiry) |
| Player-specific effects | Tested |

Phase 6 task tracking:

| Task | Status |
|---|---|
| Spikes | Tested |
| Hot ground | Tested |
| Lava | Tested (per-knight death; campaign restart is Phase 8) |
| Falling boundaries (FallBoundary + fall line) | Tested |
| Safe respawn positions | Tested |
| Moving platforms (horizontal, vertical, one-way/solid) | Tested |
| Timed platforms | Tested (switch triggering is Phase 7) |
| Disappearing platforms | Tested |
| Collapsing platforms | Tested |
| Narrow passages | Existing Phase 1 crouch tunnel and corridor; level use is Phase 10 |
| Climbing areas | Existing Phase 1 ladders and passages; hazards detect climbing knights (hurtbox layer) |
| Precision jumps | Hazard room gaps and platform rows; tuning is manual-test / Phase 10 work |
