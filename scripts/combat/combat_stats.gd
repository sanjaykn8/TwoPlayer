class_name CombatStats
extends Resource
## One knight's current combat values. Starts from CombatConfig. When a knight is bound to
## the run, this object is PlayerStats.combat: a cache written only by PlayerStats.recompute()
## from the permanent upgrades and timed effects.

## Attack-power points added per successful hit. Contributes to slime stagger in Phase 4.
@export_range(1, 99) var attack_power := 1
## Multiplies hitbox reach. Kept separate from attack power.
@export_range(0.1, 4.0) var range_multiplier := 1.0
## Multiplies the attack cooldown (power-tile attack-speed boost: 0.75).
@export_range(0.1, 1.0) var cooldown_multiplier := 1.0
## Seconds of poison each melee hit applies (purple fruit). 0 = none.
@export var poison_seconds := 0.0


static func from_config(config: CombatConfig) -> CombatStats:
	var stats := CombatStats.new()
	stats.attack_power = config.base_attack_power
	stats.range_multiplier = config.base_range_multiplier
	return stats
