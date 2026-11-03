# Phase 3 Implementation Summary: Directional Combat and Player Health

Date: 2026-11-03. Engine: Godot 4.7.2.stable. Starts from Phase 2 commit `d5b5d47`.

Status key: **Implemented** · **Auto-tested** · **Manually tested** · **Pending user test** · **Not implemented**.

## 1. Status

| Item | Implemented | Auto-tested | Manually tested |
|---|---|---|---|
| Independent and simultaneous attacks (V / Left Alt / Right Alt) | Yes | Yes | **Pending user test** |
| Four directions (LEFT, RIGHT, UP, DOWN) + D-2 low slash | Yes | Yes | **Pending user test** |
| Direction rule (Up > Down > last facing; both → facing) | Yes | Yes | **Pending user test** |
| Short configurable range, separate range multiplier | Yes | Yes | **Pending user test** |
| Attack power (base 1, used as damage and as future stagger points) | Yes | Yes | — |
| States IDLE / ATTACKING / ATTACK_RECOVERY, cooldown, input buffer | Yes | Yes | **Pending user test** |
| Hitbox active only on hit frames; visual frames in sync | Yes | Yes (frame-exact) | **Pending user test** |
| One hit per target per attack; several targets per swing | Yes | Yes | **Pending user test** |
| Wall/obstacle blocking (line of sight); one-way platforms don't block | Yes | Yes | **Pending user test** |
| No friendly fire, no self-hits | Yes | Yes | — |
| Health component (damage, heal, max up, set, restore, alive) | Yes | Yes | — |
| Damage categories (MELEE, CONTACT, SPIKE, HOT_GROUND, FALL, LAVA) | Yes (rules only) | Yes | — |
| Invulnerability 1.0 s + blinking | Yes | Yes | **Pending user test** |
| Protection-filter hook for future shields | Yes (hook only) | Yes | — |
| Death state (once, no move/attack/damage/heal, death animation) | Yes | Yes | **Pending user test** |
| Explicit revive (dev reset) | Yes | Yes | — |
| Training dummies + combat test room + debug overlay + hitbox drawing | Yes | Yes | **Pending user test** |
| Knight attack body animation | **Placeholder**: the asset pack has none; the knife slash overlays the normal body animation | — | — |
| Slimes, stagger, coins, jars, fruit, shields, hazards, campaign reset | **Not implemented** (Phases 4–8) | — | — |

## 2. New files

| Path | Purpose |
|---|---|
| `components/combat/combat_component.gd` | `CombatComponent`: attack state machine, timeline, hit tracking, knife visual |
| `components/combat/hitbox_component.gd` | `HitboxComponent`: one reusable damage area; shape query plus line of sight |
| `components/combat/hurtbox_component.gd` | `HurtboxComponent`: area that receives hits |
| `scripts/combat/combat_config.gd`, `resources/config/combat_config.tres` | Central combat values |
| `scripts/combat/combat_stats.gd` | `CombatStats`: per-knight power and range multiplier |
| `scripts/combat/hitbox_geometry.gd` | `HitboxGeometry`: pure per-direction hitbox rectangles |
| `scripts/combat/damage_event.gd` | `DamageEvent` and its categories |
| `assets/created/knife_slash.png` | Generated 4-frame knife slash (knight palette) |
| `scenes/objects/training_dummy.tscn`, `.gd` | `TrainingDummy` (uses tileset post art) |
| `scenes/dev/combat_test_level.tscn`, `combat_test_room.tscn`, `.gd` | Combat test room |
| `scenes/dev/combat_debug_hud.tscn`, `.gd` | Combat overlay |
| `tools/build_phase3_content.gd` | Generator for the slash art, level and room |
| `tests/unit/test_combat_logic.gd`, `tests/gameplay/test_combat.gd` | 36 tests |
| `docs/MANUAL_COMBAT_TEST.md`, `docs/PHASE_3_SUMMARY.md` | Documentation |

## 3. Modified files

| Path | Change |
|---|---|
| `components/health/health_component.gd` | Rule-based `take_damage(DamageEvent)`, invulnerability, protection filters, `increase_max_health`, `set_current_health`, `restore_full`, `is_alive`, explicit `revive`; new signals. Phase 1 API unchanged |
| `scenes/players/knight.gd` | `DEAD` state, `died` signal, `revive()`, combat wiring, hurtbox, invulnerability blink, hurtbox follows crouch. Movement code unchanged |
| `scenes/players/knight.tscn` | Added `Hurtbox`, `Combat/Hitbox`, `Combat/Weapon` |
| `scripts/players/knight_config.gd`, `resources/config/knight_config.tres` | `invulnerability_time = 1.0` |
| Docs | `GDD.md`, `ROADMAP.md`, `CLAUDE.md`, `docs/ARCHITECTURE.md`, `docs/TEST_REPORT.md`, `docs/KNOWN_ISSUES.md` |

## 4. Values (`resources/config/combat_config.tres`, `knight_config.tres`)

| Value | Setting |
|---|---|
| Attack power | 1 |
| Range multiplier | 1.0 (red fruit later: 1.1 / 1.2 / 1.3) |
| Windup | 0.05 s (3 ticks) |
| Hit frames | 0.10 s (6 ticks, ticks 4–9 of the attack) |
| Cooldown between attack starts | 0.30 s (18 ticks) |
| Input buffer | 0.10 s before the cooldown ends |
| Trail visible after hit frames | 0.08 s |
| Side slash | x +4…+18 px from the centre line, 14 px tall at body centre |
| Up / down slash | 14 px beyond head / feet, 16 px wide, 2 px overlap |
| Low slash | x +4…+18 px, 8 px tall at the feet |
| Invulnerability after ordinary damage | 1.0 s |
