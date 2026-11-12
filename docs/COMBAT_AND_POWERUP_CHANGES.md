# Combat and Power-up Changes (final pass, 2026-11-12)

What changed in combat reach, enemy balance and the power-up system, why, and how each
change was tested. Values live in `resources/config/combat_config.tres`,
`resources/config/progression_config.tres` and `resources/enemies/*.tres`; the approved rules
are in `GDD.md` §18 "Final pass".

## 1. Attack reach

### What changed

| Value (`combat_config.tres`) | Before | After |
|---|---|---|
| `side_reach` | 14 | 20 |
| `vertical_reach` (up and down) | 14 | 20 |
| `low_reach` (crouched) | 14 | 20 |
| `side_thickness` | 14 | 16 |
| `vertical_thickness` | 16 | 18 |
| Far edge of the slash from the knight's centre (offset 4 + reach) | 18 px | **24 px (x1.33)** |
| Charged slash (reach x1.3) | 22 px | 30 px |

Both knights use the same config, so the change is identical for both, in all four
directions, standing, crouched and in the air. No new key was added.

The requested range was about 1.35–1.5×. The final value is 1.33× on the far edge (1.43× on
the reach value itself). It was kept at the low end on purpose: red fruit still adds up to
+40 % on top, which gives 32 px for a knight who finds every red fruit, and anything longer
let a knight hit across a two-tile gap.

### Visual

`CombatComponent._draw()` now draws a crescent on the far edge of the hitbox while the hit
window is live, and fainter during the trail. It is computed from the same rectangle the
hit query uses (`HitboxGeometry.local_rect`), so it cannot drift from the hitbox. It is white
for a light slash, warm for a charged slash and purple while the knight has venom. This also
closes KI-27 ("nothing shows where the slash ends", open since Phase 3).

### What did not change

- One hit per target per swing (attack ids).
- Line of sight: a wall between knight and target blocks the hit.
- Wind-up, active time and cooldown.
- The charged slash, pogo, co-op strike and stack boost rules.

### Enemy balance for the longer blade

A standing knight's longest poke is `24 px + half the enemy's hurtbox`. Three melee enemies
could have been hit from just outside their own strike, so their strike was lengthened by the
same 4 px margin they had before. Nothing else about them changed.

| Enemy | `attack_range` (starts the wind-up) | `attack_rect` reach | Wind-up |
|---|---|---|---|
| Orc grunt | 20 → 24 | 24 → 28 px | 0.45 s (unchanged) |
| Orc shieldbearer | 20 → 24 | 24 → 28 px | 0.50 s (unchanged) |
| Orc brute | 30 → 34 | 30 → 34 px | 0.75 s (unchanged) |
| Warchief, Captain, Crowned Hollow | 40 (unchanged) | 40–44 px (unchanged) | 0.55–0.60 s |
| Slimes, bats, ember slimes | contact or blast enemies: no strike range to adjust | | |
| Hollow archer | ranged; unchanged | | |

Health, damage, speed and detection of every enemy are unchanged. The slime bosses' rules
(Magma Heart only while dazed, Citadel Warden only by a co-op strike) do not depend on reach.

### How it was tested (`tests/gameplay/test_final_range.gd`, 5 tests)

| Test | What it proves |
|---|---|
| `test_reach_is_between_1_35_and_1_5_times_the_old_one` | The far edge grew between 1.3× and 1.5× in every direction, and all directions are equal |
| `test_a_real_swing_reaches_every_enemy_type_once_and_no_further` | For all 14 enemy types (2 slimes, 6 overhaul enemies, 3 arena bosses, 3 slime bosses): a real attack-key swing from 3 px beyond the reach misses; with a wall between them it misses; from the edge of the new reach (beyond the old 18 px) it hits **exactly once** |
| `test_up_and_down_swings_reach_as_far_as_side_swings` | A real up-swing hits a target 2 px inside the vertical reach |
| `test_no_melee_enemy_can_be_poked_from_outside_its_own_strike` | For grunt, shieldbearer, brute and the three arena bosses: the enemy's strike covers the knight's longest poke, and every wind-up is at least 0.2 s |
| `test_a_grunt_answers_a_knight_standing_at_full_reach` | A live grunt walks in, winds up and hits a knight who stands still at the edge of its own reach |

The existing combat suites were updated to the new numbers and pass (`test_combat`,
`test_combat_expansion`, `test_combat_logic`, `test_enemies`, `test_slimes`, `test_boss`).
Platforming is unaffected: reach is not used by movement, and every level's main route is
still replayed with base stats (`test_campaign_routes`).

**Not tested by a person:** how the new distance *feels*, and whether the crescent reads well
on a monitor at 2× scale. See the manual test at the end.

## 2. Power-ups

### The rule of the system

| Family | Rule | Shown as |
|---|---|---|
| **Jars** | Permanent for the run, capped per knight, saved | The "upgrades" line of the HUD; pop-up ends in "KEPT" |
| **Fruits** | Act at once (heal) or for a time shown in seconds | An effect indicator with seconds (and hits left) |
| **"?" tiles** | A 12 s boost the player picks by timing | The tile shows the boost's name and cycles; then an indicator |

Everything applies to the knight who takes it. The only shared things are coins and the
partner's share of a feast.

### Every item

| Item | Before | After | Stack / refresh rule |
|---|---|---|---|
| Green jar | +1 max health | +1 max health, **cap +3** | Adds until the cap; then the jar is left for the partner |
| Red jar | +1 attack power | +1 attack power, **cap +2** | As above |
| Blue jar | +5 % speed | **+8 % speed, cap +24 %** | As above |
| Yellow jar | 50 % chance to negate damage for 60 s | **Ward (permanent):** blocks one hit, recharges in 25 s | Each further jar shortens the recharge by 5 s (min 15 s); cap 3 |
| Green fruit | Heal 1/2/3 | Heal 1/2/3; tier 3 is a **feast** (+1 to the partner, anywhere). Refused at full health | — |
| Yellow fruit | Shield 1/2/3 hits for 5/10/20 s | Shield 1/2/3 hits for **20/30/45 s** | Never stacks: hits and time each become the larger value |
| Red fruit | Reach +10/20/30 %, no cap | Reach **+10/15/20 %, cap +40 %**. Refused at the cap | Adds until the cap |
| Purple fruit | Permanent poison 1/2/3 s per hit | **Venom for 30/45/60 s:** every hit poisons 3 s | Keeps the longer time |
| "?" tile | Random: speed +25 %, cooldown −25 % or one block, 5 s | **Cycling, shown:** HASTE +30 %, FRENZY −35 % cooldown, GUARD one block (20 s); boosts last 12 s | Same boost again refreshes; strength never stacks |
| Coin | 10 % chance to heal 1 | Unchanged | — |

Protection order when a hit lands: tile GUARD, then fruit SHIELD, then the WARD. One layer is
used per hit. Falls and lava ignore all of them (unchanged rule D-4).

### Why each change

- **Yellow jar → ward.** The old jar was luck, lasted a minute and then was gone, which made
  it a weak "jar". A ward is always the same, visible (golden arcs when ready, a countdown in
  the HUD when not), and stays for the run like every other jar.
- **Purple fruit → timed venom.** Permanent effects belong to jars. As a timed fruit it can be
  placed before a fight on purpose, and the purple blade shows that it is on.
- **Caps.** Without them one knight could take everything. With them the second jar of a kind
  is usually worth more to the partner, and the game says so ("MAXED: FOR YOUR PARTNER").
- **Refusals.** A fruit that would do nothing stays where it is, so a hurt partner can have it.
- **Tiles.** Five seconds was too short to reach the next enemy, and a random boost could not
  be planned. Now two players can each time the tile for the boost they want.
- **Longer shields.** Tier 1 at 5 s rarely survived the walk to the next danger.

### Feedback

- Pop-up at pickup with the rule: "MAX HEALTH +1 KEPT", "POWER +1 KEPT", "WARD KEPT",
  "SPEED UP KEPT", "HEAL +3 (BOTH)", "SHIELD x2 30s", "REACH +15% KEPT", "VENOM 45s".
- Refusal text, at most once every 1.5 s: "FULL HEALTH", "REACH MAXED", "MAXED: FOR YOUR
  PARTNER".
- HUD: upgrades line ("PWR 2  REACH +10%  SPEED +8%"); indicators "WARD READY" / "WARD 18s",
  "SHIELD x2 28s", "VENOM 44s", "HASTE 11s", "FRENZY 9s", "GUARD x1 17s". The row wraps to a
  second line, so six indicators never cover the coin panel.
- On the knight: pips above the head for running effects, golden arcs while the ward is
  ready, "WARD BLOCKED" / "BLOCKED" and a block sound when a hit is absorbed, a chime and
  "WARD READY" when it recharges, the effect's name when it runs out.
- Sounds reuse existing cues (`shield_block`, `charge_ready`, the pickup cues).

### Saving

- Jars, reach and speed bonuses are in `PlayerStats.snapshot()` as before (now clamped to the
  caps when collected).
- Timed effects are saved as remaining seconds and hits. The ward is saved as its level and
  the seconds left on its recharge.
- Old saves: `jar_luck` becomes a level-1 ward; a permanent `poison_seconds` becomes venom of
  the matching tier, starting at load. Both are validated before they are applied.
- A team wipe removes everything, wards included (they were earned in the lost run).

### Placement (intentional)

| Where | What | Why there |
|---|---|---|
| l04 lantern islet, l07 coin ledge, l09 cistern, l15 forge cellar | Venom | Just before a fight (the grove's orcs, the Brood Mother, the guard hall, the Magma Heart) |
| l12, l20, l24 before the boss gate | Feast (and venom in l12, l24) | Both knights enter a mandatory boss fight healed |
| l05, l10, l17, l21 | Yellow jars (wards) | Each behind a co-op or skill test: a door held by the partner, a ledge swept by a saw, a crumbling catwalk under an archer, an archer's corridor |
| l08 hidden room | Blue jar | Reward for finding the cracked wall beside the lift |
| l01 tree roof, l05 cliff room, l07 gallery, l14 shelf, l18 clock ledge, l19 tower foot, l22 cache | Shield fruit | At the end of an optional route, before the next hard stretch |
| l02 root tunnel, l03 nest | Small green fruit | A heal in the middle of a level for exploring |

There are four wards, four green jars, three red jars and three blue jars in the campaign, so
two knights can share them without reaching the caps early.

### How it was tested

| Suite | Tests | Covers |
|---|---|---|
| `tests/unit/test_progression_logic.gd` | 13 | Ward (block, recharge, levels, cap), venom (tiers, refresh), caps, protection order, snapshot and restore, legacy conversion |
| `tests/gameplay/test_collectibles.gd` | 23 | Each fruit, jar and tile on real knights: effect, collector only, feast, refusals, a capped jar left for the partner, tile cycle, durations to the tick, duplicate-pickup protection |
| `tests/gameplay/test_hud.gd` | 10 | Indicator text and seconds, upgrades line, wrap with six effects |
| `tests/gameplay/test_final_coop.gd` | 9 | Pickup far from the partner; both knights on one jar in one frame; death under effects; quit and reopen in every level with venom, haste and a recharging ward |
| `tests/gameplay/test_release_saves.gd`, `test_team_wipe.gd`, `test_campaign_save.gd` | 28 | Effects and upgrades through saves, slots and wipes |
| `tests/gameplay/test_level_validation.gd` | 6 (24 levels) | Every placed fruit, jar, stash and tile in every level is collected by a knight and does what its type says |

## 3. Targeted manual test (about 15 minutes, two players)

These are the things automated tests cannot judge. Start a new game in an empty slot.

1. **Reach, level 1.** Each player: stand so the crescent just touches the first slime and
   attack. Expected: it hits. Step back half a body: it misses. Try up (jump under the first
   ledge's coin sign) and down (in the air above a slime: you bounce).
2. **Reach vs walls, level 1.** Stand left of the cracked wall and attack: only chips fly.
   Hold attack until the knight glints, release: the wall breaks.
3. **Does 24 px feel right?** Fight the first orc (after the plate gate). If you can kill it
   without it ever swinging, the reach is too long; if you must touch it, too short. Report
   which.
4. **Tile, level 1.** Stand next to the "?" block after the gate and watch the name change.
   Player One jumps on it when it says HASTE, Player Two when it says FRENZY (wait for it to
   come back). Expected: each HUD shows the boost each player chose, with 12 s.
5. **Refusal.** At full health walk onto the green fruit in level 1's secret room: "FULL
   HEALTH", and the fruit stays. Let a slime hit you, come back: it heals.
6. **Ward, level 5.** One knight stands on the stone at the bottom; the other jumps into the
   wind, takes the yellow jar behind the door. Expected: "WARD KEPT", golden arcs. Take a hit
   from a slime: "WARD BLOCKED", no heart lost, HUD counts down from 25, then "WARD READY".
7. **Caps.** If one knight has two red jars, the third stays on the ground for the other with
   "MAXED: FOR YOUR PARTNER".
8. **HUD readability.** With three or more effects on one knight, check that the row wraps
   and nothing covers the coin counter.
