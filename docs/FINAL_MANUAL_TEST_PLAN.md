# Final Manual Test Plan

The last check before a release candidate: real people, the real game window, the real
keyboard and monitor. Automated results (`docs/TEST_REPORT.md`,
`docs/LEVEL_VALIDATION_MATRIX.md`) do not replace any item here.

**Nothing in the results table has been manually tested in Phase 11.** The only manual
evidence so far is the user's report: the keyboard works and levels 1–4 were reached and
passed on the first attempt (`docs/PLAYTEST_FEEDBACK.md`). Those entries say "User-reported";
everything else is NOT TESTED.

Statuses: NOT TESTED / PASS / PASS WITH MINOR ISSUES / FAIL / BLOCKED. Write a failure into
`docs/KNOWN_ISSUES.md` with a severity (P0–P3) and put its ID in Notes.

## How to run it

- Launch the game normally (not from the editor's dev rooms). Use a slot you do not need: a
  team wipe resets that slot's run.
- Two players on one keyboard for the campaign items; one person is enough for menus,
  settings and audio.
- Note the clock time at the start of every level (Part F of Phase 11 needs real times).
- Per-level checklists: `docs/CAMPAIGN_PLAYTEST.md`. Two-player checklist:
  `docs/TWO_PLAYER_PLAYTEST.md`. Older focused checklists: `docs/MANUAL_*_TEST.md`.

## Coverage

| Area | Test IDs |
|---|---|
| All 24 levels | M-L01 … M-L24 |
| All six worlds (transitions, theme, music) | M-W1 … M-W6 |
| Optional bosses | M-B1 … M-B4 |
| Cooperative puzzles | M-P1 … M-P3 |
| Camera modes | M-C1 … M-C4 |
| Combat | M-F1 … M-F3 |
| Collectibles | M-K1 … M-K4 |
| Hazards | M-H1 … M-H4 |
| Death | M-D1 … M-D3 |
| Save and resume | M-S1 … M-S5 |
| Menus | M-U1 … M-U4 |
| Audio | M-A1 … M-A2 |
| Settings | M-G1 … M-G3 |
| Final victory | M-V1 |
| Timing | M-T1 |

## Results

| Test ID | Description | Expected result | Actual result | Status | Notes |
|---|---|---|---|---|---|
| M-L01 | Level 1, The Mossy Path | Completable by two players; clues readable; no softlock | Reached and passed on the first attempt | User-reported PASS | Per-check results and time not recorded |
| M-L02 | Level 2, Rootway Hollows | As M-L01 | Reached and passed on the first attempt | User-reported PASS | As above |
| M-L03 | Level 3, Old Watchtrees | As M-L01 | Reached and passed on the first attempt | User-reported PASS | As above |
| M-L04 | Level 4, Heart of the Grove | As M-L01 | Reached and passed on the first attempt | User-reported PASS | "The user reached and passed Level 4 on the first attempt." |
| M-L05 | Level 5, Crystal Descent | As M-L01 | | NOT TESTED | |
| M-L06 | Level 6, Echoing Shafts (blinking bridge, timing changed in Phase 11) | As M-L01; the bridge can be crossed with a normal reaction | | NOT TESTED | KI-102 |
| M-L07 | Level 7, Brood Caverns | As M-L01; exit reachable without the boss | | NOT TESTED | |
| M-L08 | Level 8, The Sunless Lift | As M-L01 | | NOT TESTED | |
| M-L09 | Level 9, Sunken Gatehouse | As M-L01 | | NOT TESTED | |
| M-L10 | Level 10, Hall of Echoes | As M-L01 | | NOT TESTED | |
| M-L11 | Level 11, Twin Sanctums | As M-L01; gates understandable without a nearby clue | | NOT TESTED | 4 gates have no clue within 24 tiles |
| M-L12 | Level 12, The Gilded Seal | As M-L01 | | NOT TESTED | |
| M-L13 | Level 13, Ashen Steps | As M-L01; lava clearly visible before every jump | | NOT TESTED | |
| M-L14 | Level 14, Cinder Bridges (blinking chain changed in Phase 11) | As M-L13; stones vanish behind the knights, not ahead | | NOT TESTED | KI-101 |
| M-L15 | Level 15, Forge of Embers | As M-L13; exit reachable without the boss | | NOT TESTED | |
| M-L16 | Level 16, Heart of the Mountain (blinking chain changed in Phase 11) | As M-L14 | | NOT TESTED | KI-101 |
| M-L17 | Level 17, Iron Gate Keep | As M-L01 | | NOT TESTED | |
| M-L18 | Level 18, Clockwork Halls | As M-L01 | | NOT TESTED | |
| M-L19 | Level 19, Broken Towers | As M-L01 | | NOT TESTED | |
| M-L20 | Level 20, The Black Bastion (vault ladder added) | As M-L01; the coin vault can be left by its ladder | | NOT TESTED | KI-97 |
| M-L21 | Level 21, Frost Causeway | As M-L13 | | NOT TESTED | |
| M-L22 | Level 22, Spire of Silence (spike bed split, blink order changed) | As M-L14; a knight on the spire floor can always climb out | | NOT TESTED | KI-98, KI-101 |
| M-L23 | Level 23, Warden's Vault | As M-L13; exit reachable without the boss | | NOT TESTED | |
| M-L24 | Level 24, Crown of Dawn | As M-L13 | | NOT TESTED | |
| M-W1 | World 1 Ancient Forest: l01→l04 transitions | Each exit loads the next level; progress kept | Levels 1–4 passed in order | User-reported PASS | Transition details not reported |
| M-W2 | World 2 Underground Caves: l04→l08 | As M-W1; cave theme and music | | NOT TESTED | |
| M-W3 | World 3 Abandoned Ruins: l08→l12 | As M-W1 | | NOT TESTED | |
| M-W4 | World 4 Lava Kingdom: l12→l16 | As M-W1 | | NOT TESTED | |
| M-W5 | World 5 Dark Fortress: l16→l20 | As M-W1 | | NOT TESTED | |
| M-W6 | World 6 Final Citadel: l20→l24 | As M-W1 | | NOT TESTED | |
| M-B1 | Brood Mother (l07): fight and win | Seal breaks, reward gate opens, reward collected once | | NOT TESTED | |
| M-B2 | Magma Heart (l15): fight and win | As M-B1 | | NOT TESTED | |
| M-B3 | Citadel Warden (l23): fight and win; needs both knights together | As M-B1 | | NOT TESTED | |
| M-B4 | Skip each boss | Each boss level finishes without the fight | | NOT TESTED | Automated: route validator walks every level without bosses |
| M-P1 | Two-knight plates and latches (l02, l09, l12) | Needs both; a mistake can be undone | | NOT TESTED | |
| M-P2 | Timed gates and sync targets (l17, l20) | Achievable with normal reactions; clue explains it | | NOT TESTED | |
| M-P3 | Plate-held platforms (l15, l16, l20) | Holder and rider can both finish | | NOT TESTED | |
| M-C1 | Shared camera | Both knights always visible together | | NOT TESTED | |
| M-C2 | Side-by-side and stacked split | Splits at distance; each half follows its knight; HUD intact | | NOT TESTED | |
| M-C3 | Merge and hysteresis | No flicker at the threshold; smooth merge | | NOT TESTED | KI-17, KI-19 |
| M-C4 | Window resize / fullscreen | Pixel-sharp at every offered size; HUD readable | | NOT TESTED | KI-78 |
| M-F1 | Attacks in four directions | Slash follows the last movement direction | | NOT TESTED | |
| M-F2 | Green slime: 2 hits stagger, 1 more kills | As described; stagger lasts at least 10 s | | NOT TESTED | |
| M-F3 | Purple slime: 4 hits stagger, 1 more kills; 4–6 coins drop | As described | | NOT TESTED | |
| M-K1 | Coins | Shared total; never counted twice | | NOT TESTED | |
| M-K2 | Fruits (green heal, yellow speed, red range, purple poison) | Effect on the eater only | | NOT TESTED | |
| M-K3 | Jars (green, red, yellow, blue) | Permanent effects kept across levels and saves | | NOT TESTED | |
| M-K4 | Random power tiles | Effect lasts its time; HUD shows the seconds | | NOT TESTED | |
| M-H1 | Spikes and hot ground | 1 health per hit; readable | | NOT TESTED | |
| M-H2 | Lava | Instant death, ends the run; always visible before a jump | | NOT TESTED | |
| M-H3 | Falling | 1 health and respawn on safe ground | | NOT TESTED | |
| M-H4 | Collapsing and blinking platforms | Warning before they vanish | | NOT TESTED | |
| M-D1 | Player One dies | RUN LOST; new run at level 1 with nothing | | NOT TESTED | Use a throwaway slot |
| M-D2 | Player Two dies | As M-D1 | | NOT TESTED | |
| M-D3 | After a wipe: main menu → Continue | Only the new run; the old one never returns | | NOT TESTED | |
| M-S1 | Close the window mid-level (X), relaunch, Continue | Same level, health, coins, upgrades, opened gates | | NOT TESTED | KI-65 |
| M-S2 | Alt+F4 mid-level | As M-S1 | | NOT TESTED | |
| M-S3 | Autosave points | Saving indicator; resume there | | NOT TESTED | |
| M-S4 | Four slots in use | Each keeps its own run; deleting one leaves the others | | NOT TESTED | |
| M-S5 | Save and resume in a later world (e.g. World 5) | As M-S1 | | NOT TESTED | |
| M-U1 | Main menu with the keyboard only | Every item reachable; Esc goes back | | NOT TESTED | KI-79 |
| M-U2 | Save-slot screen | Slot info correct (level, coins, time); confirmations focus Cancel | | NOT TESTED | |
| M-U3 | Pause menu: resume, restart, save and quit | Restart asks first and is not a death | | NOT TESTED | |
| M-U4 | HUD in shared and split view | Both knights' health and effects readable | | NOT TESTED | |
| M-A1 | Sounds: attack, hit, death, coins, gates, menus | Audible, not too loud when many play | | NOT TESTED | KI-77 |
| M-A2 | Music per world, menu, victory | Plays and loops; no doubling on transitions | | NOT TESTED | KI-76 |
| M-G1 | Music and effect volume sliders | Independent; kept after a restart | | NOT TESTED | |
| M-G2 | Display size and fullscreen | Applied and kept after a restart | | NOT TESTED | |
| M-G3 | Controls screen | Shows the real keys | | NOT TESTED | |
| M-V1 | Finish level 24 | Victory screen: 24 of 24, real coins and time; slot shows CAMPAIGN COMPLETE | | NOT TESTED | |
| M-T1 | Full first campaign time | 90–120 min target; write each level's time in CAMPAIGN_PLAYTEST | | NOT TESTED | KI-89 |
