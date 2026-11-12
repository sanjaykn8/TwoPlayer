# Final Development Audit

Written 2026-11-12, at the start of the final development pass ("level complexity, combat,
power-ups and complete QA"). It records what the project actually contained before the pass,
checked against the code and the built scenes, not against earlier documents. What the pass
then changed is in `docs/COMBAT_AND_POWERUP_CHANGES.md`, `docs/LEVEL_BY_LEVEL_QA.md` and
`docs/FINAL_TEST_REPORT.md`.

## 1. Repository state at the start

| Item | State |
|---|---|
| Branch | `main`, at `89f69d7` ("docs: polish feedback and document the gameplay overhaul") |
| Remote | `origin/main` at the same commit; nothing unpushed |
| Working tree | Clean when the pass began |
| Engine | Godot 4.7.2 stable, Compatibility renderer, 640×360 viewport in a 1280×720 window |
| Main scene | `res://scenes/app/game_app.tscn` (`GameApp`); no autoloads |
| Size | 223 scripts, 115 scenes, 37 resources, 45 test files |
| Tests | 497 automated tests, all passing when `89f69d7` was committed |

## 2. What was in the game

| Area | Finding (verified in code) |
|---|---|
| Players | Two knights from one scene (`knight.tscn`), identity from `KnightProfile`. P1: WASD + V. P2: arrows + Alt. Movement values in `knight_config.tres` |
| Combat | `CombatComponent`: light slash in four directions, charged (heavy) slash, pogo, co-op strike, stack boost. One hit per target per swing; walls block by line of sight |
| Reach | The slash ended **18 px** from the knight's centre (offset 4 + reach 14) in every direction; heavy x1.3 |
| Attack feedback | Weapon frames come from the combat timeline. Nothing showed where the hitbox ended (KI-27, open since Phase 3) |
| Enemies | Green and purple slimes (stagger rule), orc grunt, brute, shieldbearer, hollow archer, cave bat, ember slime; three optional slime bosses; three mandatory arena bosses (Warchief l12, Captain l20, Crowned Hollow l24) |
| Hazards and mechanisms | Spikes, lava, hot ground, falls; moving, timed, blinking and crumbling platforms; springs, updrafts, wind, ice, saws, fire jets, falling rocks, cracked blocks, pogo lanterns, darkness and torches, arenas |
| Puzzles | Plates, switches, targets, logic locks (all / any / sync / sequence), gates (follow / latch / timed), platform controllers, clues |
| Campaign | 6 worlds × 4 levels, generated from `tools/campaign/world_*.gd`. All 24 levels load and pass the static analyzer, the route validator and the level probe |
| Saves | Four slots through `SaveManager`; autosave at flags, puzzle completion and level changes; save on exit; team wipe destroys the run |
| UI | Main menu, slots, settings, controls, pause, game over, victory; `GameHud` with hearts, upgrades and effect indicators |

## 3. Weaknesses found (what the pass had to fix)

### Levels

Seven levels (l01–l06, l09) had been rebuilt in the overhaul with vertical routes and secrets.
The other seventeen had only been "remixed": new enemies and hazards placed on their Phase 10
skeletons. Measured from the specs:

| Finding | Levels |
|---|---|
| Main floor is one flat row for most of the level | l07, l10, l11 (two flat rows), l12, l13, l15, l16, l17, l18, l23, l24 |
| No optional route or secret beyond a ledge with a pickup | l13, l14, l18, l21 |
| No co-op mechanism at all | l05, l06, l19 (a single latch) |
| Reward lying on the main floor with nothing to earn it | yellow jar in l10, l17 and l21; yellow fruit in l07 |
| Finale without a closing test | l16 (the summit was one slime and the exit) |
| No supplies before a mandatory boss | l12, l20, l24 |

### Combat

- The 18 px reach was shorter than every orc's strike (24–30 px), so trading blows always
  favoured the enemy and the knights had to stand inside the enemy's sprite to hit it.
- No visual showed the reach, so players could not learn the distance.

### Power-ups

| Item | Problem |
|---|---|
| Yellow jar | A 50 % chance to negate damage for 60 s: luck-based, invisible when it did nothing, and it was the only "jar" that was not permanent, which broke the jar/fruit distinction |
| Purple fruit | Permanent poison of 1–3 s per hit: permanent like a jar, but a fruit; its effect was hard to notice |
| Yellow fruit | 5/10/20 s: tier 1 often expired before the next enemy |
| Blue jar | +5 % speed: not noticeable |
| "?" tile | Random effect for 5 s: too short to use, and the player had no say in what it gave |
| Red fruit | +10/20/30 % reach, uncapped: with the longer base reach this would have reached x1.9 |
| Green fruit | Taken (and wasted) by a knight at full health |
| Jars in general | No cap: one knight could take every jar and leave the partner with nothing |
| Information | Pop-ups named the item but not its rule; the HUD did not separate permanent from timed |

### QA and tooling

- The level probe and route validator covered the main route of every level, but optional
  routes were only checked statically.
- Co-op edge cases (one knight finishing alone, a death, quit and reopen) were tested in one
  level per world, not in every level.
- No test attacked each enemy type with a real swing at the edge of the reach.

## 4. What was already sound and was left alone

- Controls, four-direction attacks, independent health, the team-wipe rule, quitting without
  dying, autosave and the four slots.
- The save format (the pass adds only values inside existing fields, with conversion of the
  two retired effects).
- The enemy state machine, boss patterns and their wind-ups.
- The campaign's structure, level order, names and story clues.
- The art direction and audio.

## 5. Constraints carried through the pass

- No Windows executable, installer, release package or export pipeline.
- No new mandatory keys and no controller requirement.
- Nothing pushed to any remote. The repository also contains the Tiny RPG source sheets,
  which the pack's licence does not allow to be redistributed (KI-110), so it must not be made
  public as it is.
- The player's save folder (`%APPDATA%\\TwoKnightCoop\\saves\\`) is never touched by tests or
  tools; tests use `user://test_saves*/`.
