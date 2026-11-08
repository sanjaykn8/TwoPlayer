# Playtest Feedback

Real feedback from people who played the game. Only what the user reported goes in this file;
automated results are in `docs/LEVEL_VALIDATION_MATRIX.md` and `docs/TEST_REPORT.md`.

## Baseline (reported at the start of Phase 11, 2026-11-04)

The user's report, as given:

| # | Feedback |
|---|---|
| F-1 | "The game felt difficult." |
| F-2 | "The difficulty appeared manageable." |
| F-3 | "The user reached and passed Level 4 on the first attempt." |
| F-4 | "The user hopes the overall difficulty is appropriate." |

Not reported, so not recorded: who played (one or two people), which keyboard, completion
times, deaths, which parts felt difficult, camera or save observations. The user's save folder
(`%APPDATA%\TwoKnightCoop\saves\`) held only one slot when Phase 11 began: slot 4, a fresh run
at level 1 with 1.2 s of play time. It contains no level times, so no time is derived from it.

## Friends' feedback (reported 2026-11-08, before the overhaul)

| # | Feedback |
|---|---|
| F-5 | Friends who played the game commented that it was boring. |

This is the reason for the gameplay overhaul (`docs/GAMEPLAY_AUDIT.md`,
`docs/MASTER_DEVELOPMENT_REPORT.md`). Who played, which levels and for how long was not
reported. **Levels 1–4 have since been rebuilt**, so F-3 (first-attempt pass) describes the old
layouts, not the current ones. No one has played the overhauled game yet; the next session
uses `docs/FRIEND_PLAYTEST_CHECKLIST.md`.

## Interpretation used for balancing

- **Levels 1–4: reached and passed on the first attempt** (F-3). This is recorded as a
  user-reported pass of each level as a whole, not of the individual checks in the matrix.
- **Levels 5–24: no feedback.** They are pending manual verification. Nothing here or in any
  other document describes how they feel to play.
- F-1 and F-2 together describe the target: **challenging but manageable**. A first-attempt
  pass of World 1 while it still "felt difficult" means the opening is not too easy and not a
  wall. Phase 11 therefore did **not** lower difficulty. Changes were made only where the
  evidence showed a section to be impossible, a trap, or unfair (see below), never because the
  game was called difficult.

Working definitions for later reports, so that feedback can be classified consistently:

| Word | Meaning here | Action |
|---|---|---|
| Challenging | Needs practice, attention or coordination; failure is understood and avoidable | Keep |
| Unforgiving | A small mistake costs the run (lava, permadeath); still fair and readable | Keep, check the warning and clue |
| Frustrating | Repeated failure for reasons the players do not see or cannot control | Investigate (clue, timing, camera) |
| Unfair | No reaction window, an unseen threat, a jump that only works by luck | Fix (P1/P2) |
| Broken | Impossible, softlock, crash, lost save | Fix (P0/P1) |

## What Phase 11 changed in response

None of the changes below came from the feedback; they came from defects found by the new
automated checks (`docs/RELEASE_READINESS_REPORT.md` §4):

- Blinking-stone chains on levels 14, 16 and 22 vanished in the wrong order (the stone ahead
  disappeared first), so they could not be crossed without waiting on a vanishing stone; on
  level 6 the window was very narrow. The order was reversed (KI-101, KI-102). Timing, stone
  count and spacing are unchanged.
- Two places on levels 20 and 22 where a knight could get stuck forever were given a way out
  (KI-97, KI-98).

## Next feedback to collect

Use `docs/CAMPAIGN_PLAYTEST.md` (per-level checklist) and `docs/TWO_PLAYER_PLAYTEST.md`. For
each level from 5 on, write down: completion time, number of team wipes and their cause,
anything unclear, anything that felt unfair, camera problems, save problems.
