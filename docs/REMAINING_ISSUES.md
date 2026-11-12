# Remaining Issues (after the final pass, 2026-11-12)

What is still open, honestly. No known issue stops a full two-player playthrough. The full
log, with reproduction and cause for each defect, is `docs/KNOWN_ISSUES.md`.

## 1. Not verified by people (the main gap)

| ID | What | Why it matters | How to close it |
|---|---|---|---|
| KI-119 | Nobody has played the game since the overhaul or this pass | Tests prove that things work, not that they are fun, clear or fair | Play the campaign with two people; `docs/FRIEND_PLAYTEST_CHECKLIST.md` |
| KI-114 | Combat and enemies "by feel": the 24 px reach, charge time, wind-ups, boss patterns | Tuned from tests and reasoning | `docs/COMBAT_AND_POWERUP_CHANGES.md` §3 |
| KI-120 | Three optional routes need a lantern bounce or a partner's boost (l01 secret room, l03 green jar, l04 venom islet) and are checked only statically | A reward may be harder to reach than intended; never a blocker | Try them |
| KI-89 | Campaign length is not measured (design estimate about two hours) | Pacing | Time the playtest |
| KI-106 | Some gates have no clue within 24 tiles (l09, l10, l11, l12, l18, l19, l20, l24; arena gates need none) | A pair may not see what opens a door | Note where you get stuck; clues are added only there |
| KI-9 | Keyboard rollover with six keys held, on the keyboard you will use | Hardware | `docs/MANUAL_KEYBOARD_TEST.md` |

## 2. Balance set by reasoning, to watch in the playtest

These are deliberate additions that could turn out too harsh. They are not defects yet.

| Level | What | If it is too much |
|---|---|---|
| l11 | An orc closes in on the knight holding the crypt plate | Move the orc further from the plate |
| l12 | An archer at the end of the gallery during the ordered switches | Remove the archer |
| l14 | Two blades swing through bridges over lava (lava ends the run) | Slow the blades or keep only one |
| l17 | An archer covers the moving platforms under the saws | Move the archer back |
| l20 | Wind against the crumbling rampart | Lower the wind strength |
| l21 | An archer in a five-tile corridor guards the yellow jar | Optional; shorten his line of sight |
| All | Grunts, shieldbearers and brutes strike 4 px further | Revert in `resources/enemies/orc_*.tres` |

## 3. Open defects

| ID | Severity | What | Plan |
|---|---|---|---|
| KI-110 | P2 (licence) | The repository holds the Tiny RPG source sheets, which the pack's licence does not allow to be redistributed, and `origin` is a public GitHub repository that already has them from earlier commits | **Needs your decision:** make the repository private, or remove `assets/tiny_rpg/` from it and its history. Nothing was pushed in this pass |
| KI-85 | P2 | The window title is "UNTITLED" and the project name is "2p" | Set when you choose a title |
| KI-5 | P1 (release only) | Windows export templates are not installed | Not needed to play from Godot; no export was requested |
| KI-121 | P3 | Two single long frames in the performance run (37 ms in l09, 89 ms in l13) | Watch; preload if noticed |
| KI-113 | P3 | A save made inside a level before it was rebuilt restarts that level from its spawn; a pickup with a reused id may already count as collected | Accepted; start a new game for the playtest |
| Others | P3 | Art and polish items (placeholder spike and gate art, platform seams, single-frame jump art, menu backdrop) | `docs/KNOWN_ISSUES.md` |

## 4. Limits of the automated evidence

- The route validator skips steps onto and off moving platforms (65 of them on the main
  routes); the probe solves each platform puzzle, but not jump by jump.
- Route and probe checks remove or freeze enemies where they would add noise, so the
  combination "this jump while that enemy attacks" is never tested.
- Arena and boss fights are won by script in the probe; the fights' rules are tested, their
  difficulty is not.
- Headless runs use a fixed 60 fps step. The real-window run was on one machine at 144 Hz.

## 5. Not done, by instruction

- No Windows executable, installer, release package or export pipeline.
- Nothing pushed to any remote.
- No save data deleted: tests and tools use their own folders under
  `%APPDATA%\\TwoKnightCoop\\` (`test_saves*`, `saves_dev`, `dbg_saves`), never `saves\\`.
  Your three existing slots were checked on copies with the new code, and their files are
  byte-for-byte unchanged: slots 2 and 4 load; slot 1 is a development save from 3 November
  (level id `w1_l1`, from before the campaign existed) that the game has shown as CORRUPTED
  since then; slot 3 is empty.
- Saves made inside a level before this pass restart that level from its spawn (every
  level's layout version changed); coins, upgrades and completed levels are kept.
