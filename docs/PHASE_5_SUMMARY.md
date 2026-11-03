# Phase 5 Implementation Summary: Collectibles and Player Progression

Date: 2026-11-03. Engine: Godot 4.7.2.stable. Starts from Phase 4 commit `55c012a`.

Status key: **Implemented** · **Auto-tested** · **Manually tested** · **Pending user test** · **Not implemented**.

## 1. Status

| Item | Implemented | Auto-tested | Manually tested |
|---|---|---|---|
| Enemy drops create 4–6 collectable coins | Yes | Yes | **Pending user test** |
| Either knight collects; shared total; one increment per coin; no double pickup | Yes | Yes | **Pending user test** |
| Independent 10 % heal roll per coin (exactly 10 of 100 outcomes), both living knights, capped, no revival | Yes | Yes | **Pending user test** |
| Green / yellow / red / purple fruit, all tiers | Yes | Yes | **Pending user test** |
| Green / red / yellow / blue jars, unique per run | Yes | Yes | **Pending user test** |
| Random power tiles (5 s speed +25 %, cooldown −25 %, one-hit shield) | Yes | Yes | **Pending user test** |
| Central protection resolution (tile shield → fruit shield → jar roll; FALL/LAVA bypass) | Yes | Yes | — |
| Poison on slimes through the Phase 4 `add_stagger_progress` (can stagger, never kills) | Yes | Yes | **Pending user test** |
| Run state survives scene changes; timers pause with the game and freeze between levels | Yes | Yes | **Pending user test** |
| Snapshot / restore (JSON-compatible, validated, versioned) | Yes | Yes | — |
| Four-slot disk saving | **Not implemented** (Phase 8) | — | — |
| Shop / spending coins | **Not implemented** (not in scope) | — | — |
| Production level placement of collectibles | **Not implemented** (Phase 10) | — | — |

## 2. New files

| Path | Purpose |
|---|---|
| `scripts/progression/run_state.gd` | `RunState`: the run (coins, collected ids, player records), snapshot/restore |
| `scripts/progression/player_stats.gd` | `PlayerStats`: authoritative per-player progression and stat calculation |
| `scripts/progression/player_effects.gd` | `PlayerEffects`: timed effects and the single protection resolver |
| `scripts/progression/poison_status.gd` | `PoisonStatus`: one poison timer per enemy |
| `scripts/progression/progression_config.gd`, `resources/config/progression_config.tres` | All collectible balance values |
| `components/progression/player_progress.gd` | `PlayerProgress`: binds a knight to its run record, ticks effects, shows effect pips |
| `components/collectibles/collectible.gd`, `coin_pickup.gd` | `Collectible` base (claim-once), `CoinPickup` |
| `scenes/collectibles/fruit.tscn/.gd`, `jar.tscn/.gd`, `power_tile.tscn/.gd` | `Fruit`, `Jar`, `PowerTile` |
| `scripts/fx/floating_text.gd`, `scripts/audio/sfx.gd` | Pop-up text; capped one-shot sounds (`coin.wav`, `power_up.wav`) |
| `scenes/dev/collectible_test_level.tscn`, `collectible_test_room.tscn/.gd`, `collectible_debug_hud.tscn/.gd` | Collectible test room |
| `tools/build_phase5_content.gd` | Generator for the room |
| `tests/unit/test_progression_logic.gd`, `tests/gameplay/test_collectibles.gd` | 34 tests |
| `docs/MANUAL_COLLECTIBLE_TEST.md`, `docs/PHASE_5_SUMMARY.md` | Documentation |

## 3. Modified files (small, additive)

| Path | Change |
|---|---|
| `scenes/players/knight.gd`, `knight.tscn` | `Progress` child; binds to the run on ready; run speed × `speed_multiplier()`; run animation speed follows it |
| `components/health/health_component.gd` | Rejects invalid and duplicate events (`event_id`); a protection block grants `block_invulnerability_time` |
| `components/combat/combat_component.gd` | `effective_cooldown()` (cooldown × multiplier); hit events carry `poison_seconds` |
| `scripts/combat/combat_stats.gd` | `cooldown_multiplier`, `poison_seconds` |
| `scripts/combat/damage_event.gd` | `event_id`, `poison_seconds` |
| `scenes/enemies/slime.gd` | Poison: applied on non-staggering melee hits, ticks into `add_stagger_progress`, cleared on stagger/death, green tint with bubbles |
| `scenes/objects/dropped_coin.tscn/.gd` | `Pickup` child (CoinPickup); removed if it falls out of the world |
| `tests/run_tests.gd` | Fresh `RunState` before every test; cleared at exit |

## 4. Values (`resources/config/progression_config.tres`)

| Item | Tier 1 | Tier 2 | Tier 3 |
|---|---|---|---|
| Green fruit: heal | 1 | 2 | 3 |
| Yellow fruit: hits blocked / max seconds | 1 / 5 s | 2 / 10 s | 3 / 20 s |
| Red fruit: range (+, relative to base) | +10 % (×1.10) | +20 % (×1.20) | +30 % (×1.30) |
| Purple fruit: poison seconds per hit (= stagger points) | 1 | 2 | 3 |

| Item | Effect |
|---|---|
| Coin | +1 shared coin; 10 % (10 of 100 outcomes) to heal both living knights by 1 |
| Green jar | +1 max health, filled |
| Red jar | +1 attack power |
| Yellow jar | 60 s; each eligible hit 50 % (50 of 100) negated; re-collect refreshes |
| Blue jar | +5 % movement speed (relative to base, additive per jar) |
| Power tile | 5 s: speed +25 %, or cooldown −25 % (0.30 s → 0.225 s), or 1-hit shield |
| Protection block | grants 1.0 s invulnerability (stops continuous contact draining charges) |
| Coin pickup delay | 0.35 s after a coin spawns |
