# Master Development Report: Gameplay Overhaul

2026-11-08, from commit `2a9b27b` (end of Phase 11). Reason: the user found the game
difficult but manageable; **friends who played it called it boring**. Goal: a substantially more
engaging, varied and challenging co-op action-platformer that can be opened and played in
Godot 4.7.2. No Windows release work was done, by request.

**Labels:**

- **Implemented**: in the code.
- **Auto-tested**: an automated test passed.
- **Measured**: a real run on this PC.
- **User-reported**.
- **Pending**: needs people to play.

Nothing in this report was played by people. Every "works" below means Auto-tested or
Measured.

## 1. Why the original felt boring

From `docs/GAMEPLAY_AUDIT.md`:

- **Flat corridors:** levels averaged 170 × 45 tiles but played on one floor line; 70–80 %
  of each level was empty sky. l09 was one flat floor that needed a single jump.
- **One enemy type:** all 121 enemies were slimes, which attack only by touching you.
- **One-button combat:** no knockback, hit pause, heavy attack or teamwork. The attack was a
  knife drawn over the idle pose.
- **Co-op meant waiting:** cooperation was mostly "one knight stands on a plate".
- **Palette-swap worlds:** the worlds changed colour, not play.
- **Thin exploration:** few secrets, little exploration, six sounds.
- **High stakes, low engagement:** difficulty came from lethal jumps, not from things to do.

## 2. New asset pack inspection

Tiny RPG Character Asset Pack 01 v2.0, free Soldier & Orc version, by Zerie
(`docs/NEW_ASSET_CATALOG.md`).

- **Contents:** two characters, each as a grid sheet and strips:
  - Soldier: idle 6, walk 8, slash 6, chop 6, bow 9, hurt 4, death 4;
  - Orc: idle 6, walk 8, sweep 6, smash 6, hurt 4, death 4.
  Plus an arrow and Aseprite sources. No NPCs, tiles or UI.
- **Measured:** frame boxes and feet line (y = 57 in every 100×100 cell); 77-colour and
  63-colour palettes; no semi-transparent pixels.
- **Pack quirk:** the Soldier's "no shadow" strips actually contain the shadow; only the grid
  sheet is shadow-free.
- **Licence:** use and modify in games, credit optional, **no redistribution of the raw files**
  (KI-110). The ZIP has no README; terms are from the pack's page.

## 3. Asset integration

Details in `docs/ASSET_INTEGRATION_REPORT.md`.

- **Copied:** only three files, into `assets/tiny_rpg/` with credits.
- **Generated** by `tools/build_overhaul_art.gd`:
  - P2 knight: blue cloth, brass helmet;
  - hollow soldiers: violet-black;
  - orc brute: red;
  - orc shieldbearer: slate;
  - all sprite frames: crops aligned to the feet; tests check that no frame bleeds into a
    neighbouring cell.
- **Removed (superseded):** the Brackeys knight frames and the palette shader.
- **Checked by render:** characters stand on the floor at 1× and 2×.

## 4. Character and animation improvements

| Change | Status |
|---|---|
| The knights have real slash and chop frames chosen by the combat timeline: wind-up, two hit frames, follow-through. The arc on screen is exactly the hit window | Auto-tested |
| Hurt flash, death collapse | Implemented |
| Run animation scales with speed | Implemented |
| Climb steps with distance climbed | Implemented |
| Crouch uses the kneeling frame | Implemented |
| Charge glint while holding attack | Implemented |
| Knife arc kept only for up and down attacks | Implemented |
| Jump and fall are single frames (the pack has none) | KI-10 |

## 5. New combat mechanics

Same five keys per player; all Auto-tested in `test_combat_expansion`, 8 tests.

| Mechanic | Detail |
|---|---|
| Charged slash | Keep attack held after a swing for 0.5 s, then release. +1 damage, 30 % more reach, breaks shields and cracked blocks, lunges on the ground, longer recovery |
| Pogo | A downward air attack that hits something bounces the knight up (enemies, lanterns) |
| Co-op strike | The second knight's hit within 0.35 s does +1 damage, with a "CO-OP!" pop and sound |
| Feel | Knockback scaled by enemy weight, a 0.05 s hit pause for the attacker only, camera shake on heavy events, sparks |

## 6. New enemy types

All Auto-tested in `test_enemies`, 14 tests. Every attack has a visible wind-up (pose, warm
flash, "!"); hits do not cancel a wind-up, a heavy hit does on movable enemies.

| Enemy | Health | Behaviour | Counter | First appears |
|---|---|---|---|---|
| Orc Grunt | 3 | Telegraphed axe sweep | Step back, punish the recovery | World 1 |
| Orc Brute | 7 | Slow; overhead smash sends shockwaves both ways | Jump the waves | World 2 |
| Orc Shieldbearer | 4 | Blocks light hits from the front (clang, pushback); turns slowly | Flank it, strike from above, or break the guard with a heavy slash | World 3 |
| Hollow Archer | 2 | Keeps its distance; draws, then fires at chest height | Crouch, jump or cut the arrow | World 3 |
| Cave Bat | 1 | Roosts, screeches, swoops along a curve through the knight | Up-attack or step aside | World 2 |
| Ember Slime | 1 | A hit or a nearby knight lights its fuse; the blast deals 1 to knights and 2 to enemies (chains) and breaks cracked blocks | Back away, lure it | World 4 |

Slimes are unchanged: green 2, purple 4, stagger ≥ 10 s, one more hit kills, chase 2×, 4–6
coins.

## 7. Bosses and mini-bosses

| Boss | Level | Role | Health | Moves |
|---|---|---|---|---|
| Orc Warchief | l12 | Mandatory arena | 16 | Two-hit combo; slam with shockwaves; telegraphed charge (dazed if it hits a wall). Two grunts and faster wind-ups at half health |
| Hollow Captain | l20 | Mandatory arena | 18 | Sword dash; arrow volleys at set heights; guard stance that needs flanking. Double dashes and longer volleys in phase 2 |
| The Crowned Hollow | l24 | Final boss | 30 | Three phases: the captain's moves, then two archers summoned plus ground slams, then everything faster |

- The three slime bosses (Brood Mother, Magma Heart, Citadel Warden) stay optional.
- A HUD boss bar shows the boss's name and health, with a trailing damage segment.
- Phase changes, minions and HUD reporting: Auto-tested.

## 8. Cooperative mechanics

- **Flanking:** the shieldbearer and the Captain's guard block only from the front.
- **Co-op strike** bonus.
- **Arena locks** (both knights must enter; Auto-tested).
- **Stack boost:** jump off your partner's head; secrets in l01 and l04 need it.
- **Kept:** two-plate locks, held-plate lifts, sync targets and split routes, now with enemies
  in them:
  - the l09 battlement sync: one knight duels the archer above while the other strikes below;
  - l11's roof and crypt each have their own enemies.

## 9. World and level redesign

All 24 levels are mapped in `docs/LEVEL_REDESIGN_PLAN.md`.

- **Rebuilt from scratch:** l01–l06 and l09. They are vertical and multi-tier, with:
  - canopies and tree climbs;
  - dark caves and updraft shafts;
  - a gatehouse assault.
- **Remixed:** the other 17 keep their best set pieces (the boss lairs, the co-op machines,
  the three-lock seals) and gain:
  - the new enemies;
  - fire jets, saws, wind and ice;
  - arenas;
  - mandatory boss halls.
- **World signatures:**
  - forest: springs and cracked blocks;
  - caves: darkness, bats, rocks, updrafts;
  - ruins: shields, archers, saws;
  - lava: embers and fire jets;
  - fortress: mixed packs and wind;
  - citadel: ice and everything.
- **Arena locks:** 8 levels (l04, l07, l08, l09, l12, l16, l20, l24), including the three boss
  halls.

## 10. New environmental hazards and interactions

| Kind | Objects |
|---|---|
| Hazards | Saw blades on rails (SPIKE damage); fire jets with a sputter warning (HOT_GROUND); falling rocks that shake first and regrow |
| Traversal | Spring mushrooms (about 6 tiles); updrafts (no falling down through them); wind; ice; pogo lanterns |
| Interactions | Cracked blocks (heavy slash or blast; saved); cave darkness with carried lights and torches |

- All Auto-tested in `test_mechanisms`, 11 tests.
- Rules unchanged: lava instant death; spikes, hot ground and falls 1 health; shields never
  block falls or lava.

## 11. Progression improvements

- **Secrets behind cracked walls and floors:** l01, l02, l04, l05, l09, l13.
- **Skill challenges:** the l03 lantern chain to the green jar; the l05 updraft chimney to the
  yellow jar.
- **Pockets:** stack-boost secrets; spring pockets.
- **Boss rewards:** the slime bosses keep their jars; mini-bosses drop 10–18 coins.
- **Coins tuned per enemy** (orcs 3–7, bats and embers 1–2), so the 10 % coin heal stays a
  bonus despite more enemies.
- **Unchanged:** jar and fruit effects.

## 12. Difficulty changes

- **Harder through things to do, not numbers:** enemy telegraphs to read, shields to flank,
  arrows to dodge, shockwaves to jump, darkness, mandatory boss fights, arena locks, denser
  enemy placement.
  - Before: 2–4 slimes near each route.
  - After: 1–6 orcs, hollows, bats or embers plus slimes (`tools/difficulty_report.gd`).
- **Easier:** World 1 has the same or easier jumps; its challenge is new mechanics.
- **Unchanged:** damage numbers and team-wide permadeath.
- **Not tuned by people (KI-114):** wind-up lengths, boss health and arrow speed.

## 13. Save system verification

| Check | Status | Tests |
|---|---|---|
| New enemies save health and position; the killed stay dead | Auto-tested | `test_overhaul_saves` |
| Cracked blocks stay broken; finished arenas stay finished | Auto-tested | `test_overhaul_saves` |
| Each world save records its layout version; an older layout or a pre-versioning save restarts that level at its spawn and keeps the run; such saves still validate (no slot is rejected) | Auto-tested | `test_overhaul_saves` |
| Earlier save guarantees (four slots, wipe invalidation, corruption refusal) | Auto-tested | `test_release_saves`, `test_save_slots`, `test_team_wipe` |

- **Never touched:** the user's real saves (`%APPDATA%\TwoKnightCoop\saves\`) were neither
  read nor written by tests or tools. Test and debug runs used their own folders, which are
  deleted afterwards.

## 14. Performance

Measured in a real 1280×720 window, vsync on, on Windows 11, i5-13450HX, RTX 4050 Laptop.

| Item | Result |
|---|---|
| All 24 levels | 60.0 fps average each; p99 16.8–19.4 ms; one 37.4 ms frame in l09; 188–341 nodes; 0 orphans; one audio player |
| Stress: l12 plus 24 extra enemies of all six kinds and a warchief around both knights | 60.0 fps; worst frame 16.8 ms; 531 nodes |
| After 24 levels, back on the menu | 39 nodes, 0 orphans, 87.8 MB static memory |
| Menu | One 527 ms frame at start-up (KI-111) |

- **Harness note:** the run's autopilot knights fell into pits across levels; falls bypass
  invulnerability, so the run-lost screen appeared during the run. The frame times are
  unaffected; gameplay screenshots were taken separately.
- **Not measured:** headroom above 60 fps (vsync).

## 15. Bugs found and fixed

| Bug | Kind |
|---|---|
| KI-108: a short downward jump could pass through solid ground | Analyzer bug |
| KI-109: the l05 ceiling sealed the way down | Level design |
| l09 floor heights did not match its target, gate and grunt | Level design |
| Arena edge detection missed enemies on its bottom edge | Code |
| Weak updraft | Tuning |
| The probe misjudged an arena (analysed the live level) and ember hits | Test tooling |
| The base enemy scene had no default stats | Code |
| Slimes too close to two spawns | Level design |
| Boss bar text crowded its bar | UI |
| The cave bat was hard to see | Art |
| Stale "Phase 9" build label | UI |

## 16. Remaining known issues

From `docs/KNOWN_ISSUES.md`:

- **P0:** none.
- **P1:** only KI-5 (export templates; not needed to play in the editor).
- **P2:**
  - KI-85: placeholder title;
  - KI-27: slash art vs range;
  - KI-106: gates without nearby clues;
  - KI-110: licence (do not publish the raw sheets).
- **P3:**
  - placeholder art: frames, gates, spikes;
  - KI-111: start-up hitch;
  - KI-112: knight script size;
  - KI-113: rare id matches in pre-overhaul saves;
  - camera cosmetics.
- **Verification gaps:**
  - KI-88: nobody has played the overhaul;
  - KI-89: length unmeasured;
  - KI-114: combat feel.

## 17. Automated test results

- **Full suite:** 497 passed, 0 failed before the documentation commit, with no error,
  warning or leak lines. Final numbers are in `docs/TEST_REPORT.md`.
- **New tests:**
  - `test_combat_expansion`: 8;
  - `test_enemies`: 14;
  - `test_mechanisms`: 11;
  - `test_overhaul_saves`: 2;
  - a regression for KI-108.
- **Campaign validators** (rewritten or extended for the new content):
  - all 24 levels pass the 20-check probe, including arena fights;
  - every main route is walked by the real knight with base stats and no bosses;
  - every blinking chain is crossable;
  - no level can trap a knight.

## 18. Manual testing still required

Everything about how it plays, with two people on one keyboard
(`docs/FRIEND_PLAYTEST_CHECKLIST.md`):

- Is it fun?
- Is it too hard or too easy?
- Are the boss patterns readable?
- Do the new moves feel good?
- Is the cave darkness too dark?
- Does the stack boost feel natural?
- Are the clues enough?
- Keyboard rollover with six keys held.
- Playtime.

## 19. Git commit history (this overhaul; nothing pushed)

| Commit | Content |
|---|---|
| `9924969` | Tiny RPG art, combat expansion, new enemies and bosses |
| `59de68b` | Hazards, co-op mechanisms, campaign redesign |
| (final) | Feedback polish, reports, documentation |

## 20. How to open and play

1. Start **Godot 4.7.2** (`C:\Users\Reaper\Downloads\Godot\Godot_v4.7.2-stable_win64.exe`)
   and open the project folder `C:\Users\Reaper\Desktop\code\game` (the `project.godot` file).
2. Wait for the first import to finish, then press **F5** (Run Project). The main menu opens.
3. Choose **New Game** in a free slot. Your existing slots are kept. A mid-level save from
   before the overhaul starts its level from the beginning.
4. **Player One:** W A S D, **V** to attack. **Player Two:** arrow keys, **Alt** to attack.
   - Tap attack to slash.
   - Keep attack held after a slash until the knight glints, then release for a heavy slash.
   - Attack downward in the air to bounce.
   - Strike the same enemy together for a co-op strike.
   - Jump off your partner to reach higher.
   - **Controls** in the menu lists all of this; **Esc** pauses.
5. If either knight dies, the whole run restarts at level 1. Quitting from the pause menu
   or the window saves.
