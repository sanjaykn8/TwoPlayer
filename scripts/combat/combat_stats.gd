class_name CombatStats
extends Resource
## One knight's current combat values. Starts from CombatConfig. Future permanent upgrades
## (red jar: +1 power, red fruit: +10/20/30 % range) and timed effects modify it; the save
## system will persist it. Phase 3 only provides the values; no upgrade is implemented.

## Attack-power points added per successful hit. Contributes to slime stagger in Phase 4.
@export_range(1, 99) var attack_power := 1
## Multiplies hitbox reach. Kept separate from attack power.
@export_range(0.1, 4.0) var range_multiplier := 1.0


static func from_config(config: CombatConfig) -> CombatStats:
	var stats := CombatStats.new()
	stats.attack_power = config.base_attack_power
	stats.range_multiplier = config.base_range_multiplier
	return stats
