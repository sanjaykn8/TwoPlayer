class_name ProgressionConfig
extends Resource
## All collectible and power-up balance values (resources/config/progression_config.tres).
## Tier arrays are indexed by tier - 1. Probabilities are whole percentages so that
## "10 %" is exactly 10 of the 100 equally likely outcomes of randi_range(0, 99).

@export_group("Coins")
## Percent chance per collected coin to heal BOTH living knights.
@export_range(0, 100) var coin_heal_chance_percent := 10
@export_range(1, 9) var coin_heal_amount := 1
## Seconds after spawning before a dropped coin can be picked up (lets it scatter first).
@export var coin_pickup_delay := 0.35

@export_group("Fruits (tier 1, 2, 3)")
## Green fruit: health restored.
@export var green_fruit_heal: Array[int] = [1, 2, 3]
## Yellow fruit: hits blocked and maximum seconds.
@export var yellow_fruit_charges: Array[int] = [1, 2, 3]
@export var yellow_fruit_seconds: Array[float] = [5.0, 10.0, 20.0]
## Red fruit: permanent attack-range bonus, added to the base multiplier 1.0.
@export var red_fruit_range_bonus: Array[float] = [0.10, 0.20, 0.30]
## Purple fruit: seconds of poison each melee hit applies to a slime.
@export var purple_fruit_poison_seconds: Array[float] = [1.0, 2.0, 3.0]

@export_group("Jars")
@export_range(1, 9) var green_jar_max_health := 1
@export_range(1, 9) var red_jar_attack_power := 1
## Blue jar: permanent movement-speed bonus added to the base multiplier 1.0.
@export var blue_jar_speed_bonus := 0.05
## Yellow jar: percent chance to negate each eligible damage event, for this many seconds.
@export_range(0, 100) var yellow_jar_chance_percent := 50
@export var yellow_jar_seconds := 60.0

@export_group("Power tiles")
@export var tile_effect_seconds := 5.0
## Temporary movement-speed bonus (added to the multiplier while active).
@export var tile_speed_bonus := 0.25
## Fraction removed from the attack cooldown while active.
@export var tile_cooldown_reduction := 0.25
@export_range(1, 9) var tile_shield_charges := 1

@export_group("Protection")
## Seconds of invulnerability granted after a protection layer blocks a hit, so continuous
## contact cannot drain several charges (or re-roll the jar) in a row. 0 = none.
@export var block_invulnerability := 1.0


func tier_value(values: Array, tier: int) -> Variant:
	return values[clampi(tier, 1, values.size()) - 1]


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	for pair: Array in [["green_fruit_heal", green_fruit_heal], ["yellow_fruit_charges", yellow_fruit_charges],
			["yellow_fruit_seconds", yellow_fruit_seconds], ["red_fruit_range_bonus", red_fruit_range_bonus],
			["purple_fruit_poison_seconds", purple_fruit_poison_seconds]]:
		if (pair[1] as Array).size() != 3:
			problems.append("%s needs exactly 3 tiers" % pair[0])
	if tile_cooldown_reduction < 0.0 or tile_cooldown_reduction >= 1.0:
		problems.append("tile_cooldown_reduction must be in [0, 1)")
	return problems
