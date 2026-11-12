class_name PlayerStats
extends RefCounted
## The authoritative progression record of one player for the current run.
##
## - Permanent upgrades are stored as bonuses on top of the base values from the knight and
##   combat configs. Every effective value is calculated here and nowhere else.
## - `combat` is a CombatStats cache written only by recompute(). The knight's
##   CombatComponent uses this same object, so attacks always see the current values.
## - Health: while a knight is in the scene, its HealthComponent is the live authority and
##   `current_health` mirrors it on every change. Between scenes this record is the authority
##   and the next knight is initialised from it.

signal changed

enum FruitType { GREEN, YELLOW, RED, PURPLE }
enum JarType { GREEN, RED, YELLOW, BLUE }

var player_id := 1
var config: ProgressionConfig
var base_max_health := 3
var base_attack_power := 1
var base_range_multiplier := 1.0

var max_health_bonus := 0
var attack_power_bonus := 0
## Sum of red-fruit bonuses, relative to the base range (capped by the config).
var range_bonus := 0.0
## Sum of blue-jar bonuses, relative to the base speed (capped).
var speed_bonus := 0.0
var current_health := 3

var effects: PlayerEffects
var combat := CombatStats.new()
## Set while a knight is bound (PlayerProgress); null between scenes.
var health: HealthComponent


func _init(id: int, progression: ProgressionConfig, max_health: int, attack_power: int, range_multiplier: float) -> void:
	player_id = id
	config = progression
	base_max_health = max_health
	base_attack_power = attack_power
	base_range_multiplier = range_multiplier
	current_health = max_health
	effects = PlayerEffects.new(progression)
	effects.changed.connect(recompute)
	recompute()


# --- Effective values (the central stat calculation) ---------------------------------

func max_health() -> int:
	return base_max_health + max_health_bonus


func attack_power() -> int:
	return base_attack_power + attack_power_bonus


func range_multiplier() -> float:
	return base_range_multiplier + range_bonus


## Permanent blue-jar bonus plus the temporary power-tile bonus, relative to base speed.
func speed_multiplier() -> float:
	return 1.0 + speed_bonus + effects.speed_bonus()


func cooldown_multiplier() -> float:
	return effects.cooldown_multiplier()


func is_alive() -> bool:
	return health.is_alive() if _has_health() else current_health > 0


## True while a live knight HealthComponent is bound.
func _has_health() -> bool:
	return health != null and is_instance_valid(health)


## Writes the derived combat values used by the knight's CombatComponent.
func recompute() -> void:
	combat.attack_power = attack_power()
	combat.range_multiplier = range_multiplier()
	combat.cooldown_multiplier = cooldown_multiplier()
	combat.poison_seconds = effects.poison_seconds()
	changed.emit()


# --- Health operations (routed through the live HealthComponent when bound) ---------

## Heals a living player; never revives. Returns the amount restored.
func heal(amount: int) -> int:
	if _has_health():
		return health.heal(amount)
	if current_health <= 0 or amount <= 0:
		return 0
	var applied := mini(amount, max_health() - current_health)
	current_health += applied
	return applied


func add_max_health(amount: int) -> void:
	max_health_bonus += amount
	if _has_health():
		health.increase_max_health(amount, true)
	elif current_health > 0:
		current_health += amount
	recompute()


# --- Collectibles ---------------------------------------------------------------------

## False when the fruit would do nothing for this player right now (full health, reach at
## its cap): the fruit then stays where it is, for later or for the partner.
func can_use_fruit(kind: PlayerStats.FruitType) -> bool:
	match kind:
		FruitType.GREEN:
			var hp := health.current_health if _has_health() else current_health
			return hp < max_health()
		FruitType.RED:
			return range_bonus < config.range_bonus_cap - 0.0001
	return true


## False when this player's upgrade of that kind is at its cap (the jar stays for the partner).
func can_use_jar(kind: PlayerStats.JarType) -> bool:
	match kind:
		JarType.GREEN:
			return max_health_bonus < config.max_health_bonus_cap
		JarType.RED:
			return attack_power_bonus < config.attack_power_bonus_cap
		JarType.YELLOW:
			return effects.ward_level < config.ward_level_cap
		JarType.BLUE:
			return speed_bonus < config.speed_bonus_cap - 0.0001
	return true


func collect_fruit(kind: PlayerStats.FruitType, tier: int) -> void:
	match kind:
		FruitType.GREEN:
			heal(config.tier_value(config.green_fruit_heal, tier))
		FruitType.YELLOW:
			effects.add_fruit_shield(tier)
		FruitType.RED:
			range_bonus = minf(range_bonus + config.tier_value(config.red_fruit_range_bonus, tier), config.range_bonus_cap)
			recompute()
		FruitType.PURPLE:
			effects.add_venom(tier)


func collect_jar(kind: PlayerStats.JarType) -> void:
	match kind:
		JarType.GREEN:
			add_max_health(config.green_jar_max_health)
		JarType.RED:
			attack_power_bonus = mini(attack_power_bonus + config.red_jar_attack_power, config.attack_power_bonus_cap)
			recompute()
		JarType.YELLOW:
			effects.add_ward()
		JarType.BLUE:
			speed_bonus = minf(speed_bonus + config.blue_jar_speed_bonus, config.speed_bonus_cap)
			recompute()


# --- Snapshot -----------------------------------------------------------------------

func snapshot() -> Dictionary:
	return {
		"player_id": player_id,
		"current_health": health.current_health if _has_health() else current_health,
		"max_health_bonus": max_health_bonus,
		"attack_power_bonus": attack_power_bonus,
		"range_bonus": range_bonus,
		"speed_bonus": speed_bonus,
		# Kept for the save format: venom is now a timed effect (in "effects").
		"poison_seconds": 0.0,
		"effects": effects.snapshot(),
	}


## Validates first; on any problem nothing changes and false is returned.
func restore(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	for key in ["player_id", "current_health", "max_health_bonus", "attack_power_bonus",
			"range_bonus", "speed_bonus", "poison_seconds", "effects"]:
		if not data.has(key):
			return false
	var hp_bonus := int(data.max_health_bonus)
	var power_bonus := int(data.attack_power_bonus)
	var rng_bonus := float(data.range_bonus)
	var spd_bonus := float(data.speed_bonus)
	var poison := float(data.poison_seconds)
	var hp := int(data.current_health)
	if int(data.player_id) != player_id or hp_bonus < 0 or hp_bonus > 50 or power_bonus < 0 or power_bonus > 50:
		return false
	if rng_bonus < 0.0 or rng_bonus > 10.0 or spd_bonus < 0.0 or spd_bonus > 5.0 or poison < 0.0 or poison > 10.0:
		return false
	if hp < 0 or hp > base_max_health + hp_bonus:
		return false
	var restored_effects := PlayerEffects.new(config)
	if not restored_effects.restore(data.effects):
		return false
	max_health_bonus = hp_bonus
	attack_power_bonus = power_bonus
	range_bonus = rng_bonus
	speed_bonus = spd_bonus
	current_health = hp
	effects.restore(data.effects)
	# A save from before venom became a timed effect: the permanent poison becomes venom of
	# the matching tier, starting now.
	if poison > 0.0 and not effects.has(PlayerEffects.VENOM):
		effects.add_venom(clampi(roundi(poison), 1, 3))
	recompute()
	return true
