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
## Sum of red-fruit bonuses, relative to the base range (0.1 + 0.3 -> x1.4).
var range_bonus := 0.0
## Sum of blue-jar bonuses, relative to the base speed.
var speed_bonus := 0.0
## Poison seconds each melee hit applies (0 = no poison). The highest collected tier wins.
var poison_seconds := 0.0
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
	combat.poison_seconds = poison_seconds
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

func collect_fruit(kind: PlayerStats.FruitType, tier: int) -> void:
	match kind:
		FruitType.GREEN:
			heal(config.tier_value(config.green_fruit_heal, tier))
		FruitType.YELLOW:
			effects.add_fruit_shield(tier)
		FruitType.RED:
			range_bonus += config.tier_value(config.red_fruit_range_bonus, tier)
			recompute()
		FruitType.PURPLE:
			poison_seconds = maxf(poison_seconds, config.tier_value(config.purple_fruit_poison_seconds, tier))
			recompute()


func collect_jar(kind: PlayerStats.JarType) -> void:
	match kind:
		JarType.GREEN:
			add_max_health(config.green_jar_max_health)
		JarType.RED:
			attack_power_bonus += config.red_jar_attack_power
			recompute()
		JarType.YELLOW:
			effects.add_jar_luck()
		JarType.BLUE:
			speed_bonus += config.blue_jar_speed_bonus
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
		"poison_seconds": poison_seconds,
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
	poison_seconds = poison
	current_health = hp
	effects.restore(data.effects)
	recompute()
	return true
