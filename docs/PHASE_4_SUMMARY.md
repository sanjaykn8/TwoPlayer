# Phase 4 Implementation Summary: Slime Enemies, AI and Stagger

Date: 2026-11-03. Engine: Godot 4.7.2.stable. Starts from Phase 3 commit `e4abf92`.

Status key: **Implemented** · **Auto-tested** · **Manually tested** · **Pending user test** · **Not implemented**.

## 1. Status

| Item | Implemented | Auto-tested | Manually tested |
|---|---|---|---|
| Shared slime scene + script; green/purple differ only by `SlimeStats` and sprites | Yes | Yes | **Pending user test** |
| States IDLE, PATROL, DETECT_PLAYER, CHASE, STAGGERED, DEAD | Yes | Yes | **Pending user test** |
| Patrol within limits, turning at limits, walls and platform edges | Yes | Yes | **Pending user test** |
| Detection: radius (Area2D) + line of sight (ray, world layer); dead knights ignored | Yes | Yes | **Pending user test** |
| Target selection: nearest, 24 px switch margin, 1 s grace, dead target dropped at once | Yes | Yes | **Pending user test** |
| Chase speed = exactly 2 × patrol speed | Yes | Yes (velocity and distance) | **Pending user test** |
| Unreachable target (other level): wait, give up after 3 s | Yes | Yes | **Pending user test** |
| Contact damage 1 (CONTACT), respects knight invulnerability; none while staggered or dead | Yes | Yes | **Pending user test** |
| Stagger: green 2, purple 4 attack-power points; 10 s minimum; distinct attack kills | Yes | Yes (frame-exact 600 ticks) | **Pending user test** |
| Recovery resets progress; can be staggered again | Yes | Yes | **Pending user test** |
| Upgraded attack power | Yes | Yes | — |
| `add_stagger_progress(points, source)` for future poison (cannot kill) | Yes | Yes | — |
| Death once, coins 4–6 rolled per enemy, drop event + visible coins | Yes | Yes | **Pending user test** |
| Enemy test room, debug overlay, debug drawing | Yes | Yes | **Pending user test** |
| Coin collection, shared total, 10 % healing chance | **Not implemented** (Phase 5) | — | — |
| Enemy jumping, bosses, poison, production levels | **Not implemented** | — | — |

## 2. New files

| Path | Purpose |
|---|---|
| `scenes/enemies/slime.gd` | `Slime`: shared controller (state machine, senses, movement, contact, stagger, death) |
| `scenes/enemies/slime_base.tscn` | Shared scene (body, hurtbox, contact area, detection area, coin dropper, labels) |
| `scenes/enemies/green_slime.tscn`, `purple_slime.tscn` | Variants: base scene + stats resource |
| `scripts/enemies/slime_stats.gd`, `resources/enemies/green_slime.tres`, `purple_slime.tres` | `SlimeStats` per variety |
| `scripts/enemies/slime_stagger.gd` | `SlimeStagger`: pure stagger rules |
| `scripts/enemies/target_selector.gd` | `TargetSelector`: nearest target with hysteresis |
| `scripts/enemies/coin_drop_result.gd` | `CoinDropResult`: drop event data |
| `components/loot/coin_dropper.gd` | `CoinDropper`: one-shot 4–6 roll, signal, listener group, coin spawning |
| `scenes/objects/dropped_coin.tscn`, `.gd` | `DroppedCoin`: visible spinning coin (`coin.png`), not collectable yet |
| `resources/enemies/green_slime_frames.tres`, `purple_slime_frames.tres` | Slime animations (generated from the real sheets) |
| `scenes/dev/enemy_test_level.tscn`, `enemy_test_room.tscn`, `.gd` | Enemy test room |
| `scenes/dev/enemy_debug_hud.tscn`, `.gd` | Enemy overlay |
| `tools/build_phase4_content.gd` | Generator: slime frames, level, room |
| `tests/unit/test_enemy_logic.gd`, `tests/gameplay/test_slimes.gd` | 34 tests |
| `docs/MANUAL_ENEMY_TEST.md`, `docs/PHASE_4_SUMMARY.md` | Documentation |

Modified: documentation only (`GDD.md`, `ROADMAP.md`, `CLAUDE.md`, `docs/ARCHITECTURE.md`,
`docs/TEST_REPORT.md`, `docs/KNOWN_ISSUES.md`). **No Phase 1–3 script or scene was changed:**
the slimes use the existing `HurtboxComponent`, `DamageEvent`, `HealthComponent`, knight
group and `is_dead()`.

## 3. Configuration (`resources/enemies/*.tres`)

| Value | Green | Purple |
|---|---|---|
| Stagger threshold (attack-power points) | **2** | **4** |
| Stagger duration | 10 s (minimum enforced) | 10 s |
| Patrol speed / chase speed | 30 / **60** px/s | 30 / **60** px/s |
| Detection radius | 96 px (per-instance override) | 96 px |
| Reaction ("!") before chasing | 0.2 s | 0.2 s |
| Grace period after losing sight | 1.0 s | 1.0 s |
| Target switch margin | 24 px | 24 px |
| Give up on unreachable target / re-acquire delay | 3.0 s / 1.5 s | same |
| Contact damage / min. interval per knight | 1 / 0.25 s | same |
| Idle before patrol / pause when turning | 1.0 s / 0.4 s | same |
| Coins on defeat | 4–6 | 4–6 |

Per-instance settings in levels: `patrol_left`, `patrol_right` (relative to spawn),
`detection_radius_override`, `start_facing_right`.
