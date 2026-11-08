# Gameplay Audit (before the overhaul)

2026-11-08, baseline commit `2a9b27b`. Sources: the code, the 24 level specs in
`tools/campaign/`, whole-level renders of l01, l09 and l16, `tools/difficulty_report.gd`, and
the feedback: the user found the game difficult but manageable (cleared level 4 first try);
**friends who played it called it boring**. This audit explains why, with evidence.

## What works and is kept

- **Engineering:** solid, tested foundation (461 automated tests). Movement with coyote time,
  jump buffer, ladders, one-way drops and pushing; split-screen camera; four-slot saves with
  the team-wipe invalidation; RunState progression; puzzle kit; level generator and
  validators. None of this needs replacing.
- **Rules:** fruits, jars, coins, power tiles, slime stagger and permadeath work as the GDD
  says and stay unchanged.
- **Controls:** five keys per player, which suits one shared keyboard.

## Why it feels boring

### 1. The levels are long flat corridors

- The average level is 170 × 45 tiles, but play happens almost entirely on **one floor line**.
- The renders show 70–80 % of every level as empty sky.
- l09 (Sunken Gatehouse) is one flat floor 170 tiles long with three gates. Its main route
  needs **one jump**.
- World 3 needs 1–3 jumps per level; l07 and l17 need 2.
- Long walks between events give the players nothing to do. "Walk right, meet slime, walk
  right" repeats.

### 2. There is only one kind of enemy

- Every one of the **121 enemies** in the campaign is a slime (17–23 per world). Purple ones
  just take more hits.
- Slimes have **no attack**: they walk into you (contact damage).
- Nothing telegraphs, nothing shoots, nothing flies, nothing guards. Positioning does not
  matter, so every fight plays the same: walk up and press attack until it is staggered,
  then once more.

### 3. Combat is one button with one result

- An attack is a fixed tap slash. The knight sheet has **no attack animation**: a generated
  knife arc is drawn over the idle or run pose (KI-26).
- There is no knockback, no hit pause, no screen shake, no heavy attack, no aerial use and
  no reward for timing or teamwork. Hits feel weightless.

### 4. Cooperation is mostly "stand on the plate"

- Co-op appears as two-plate locks, plate-held gates, plate-run lifts and sync targets.
  World 3 alone has 11 gates and 12 logic locks, mostly "one knight stands, the other walks".
- Combat has **no cooperative element**: a second knight just halves the work.
- Waiting on a plate is the "one player waits" pattern the design brief warns against.

### 5. The worlds are mainly palette swaps

- Each world changes the tileset colours and adds one hazard (lava in World 4) or more of
  the same platform types (blinking and collapsing stones in Worlds 4–6).
- All worlds share the same enemies, the same puzzle kit and one music track played at
  different pitches.
- Worlds 2, 3, 5 and 6 add no traversal mechanic of their own.

### 6. Exploration is thin

- Secrets are a fruit on a ledge above the route, visible from the route.
- There are no hidden rooms, breakable walls, challenge rooms or shortcuts.
- Optional bosses exist in three levels only.

### 7. Feedback is weak

- Six bundle sounds cover everything (one "tap" for attacks and menus).
- There are no hit particles, landing dust, impact pause or camera shake.
- Boss fights have a name bar but no health bar.

### 8. Difficulty comes from punishment rather than challenge

- The hard parts are lethal lava jumps and long blinking chains (World 4 has 6–14
  lava-over jumps per level). A miss ends the run, but the challenge in between is thin.
  "Difficult and boring" is the result: high stakes, low engagement.

## What will change (summary; detail in `docs/MASTER_DEVELOPMENT_PLAN.md`)

| Problem | Change |
|---|---|
| Flat corridors | Every level rebuilt: shorter (≈100–140 tiles), denser and much more vertical. Each has a distinct identity, multiple routes, arena encounters, hidden rooms and an optional challenge room (`docs/LEVEL_REDESIGN_PLAN.md`) |
| One enemy | Six new enemy types with distinct attacks and readable telegraphs (orc grunt, brute, shieldbearer, hollow archer, cave bat, ember slime) plus slimes kept as they are |
| Weightless combat | Real soldier attack animations synced to the hitbox; charged heavy slash (hold and release); downward pogo bounce; knockback; hit pause; camera shake; sparks; cooperative strike bonus |
| Plate co-op | Shield enemies that need flanking; co-op strike bonus; arena fights; stack-boost secrets; shared mechanisms that keep both players busy |
| Palette worlds | One signature mechanic per world: forest springs and breakables, cave darkness/bats/updrafts, ruin saw blades and archers, lava ember slimes and fire jets, fortress arenas and gauntlets, frozen citadel ice and wind |
| Thin exploration | Cracked walls hiding rooms, optional challenge rooms (pogo lanterns, springs), placed coin vaults, shortcuts |
| Weak feedback | Synthesised sound effects (swing, heavy swing, clang, arrow, bat, spring, fire), particles, boss health bars |
| No climax | Mini-boss arenas (Orc Warchief, Hollow Captain) and a mandatory multi-phase final boss (The Crowned Hollow) at the end of the campaign; the three optional slime bosses stay optional |

Unchanged rules: slime stagger thresholds and timings, lava instant death, spike, hot-ground
and fall damage, fruit and jar effects, the 10 % coin heal, the team-wide permadeath, the
four save slots and the controls.
